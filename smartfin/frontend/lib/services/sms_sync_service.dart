import 'package:another_telephony/telephony.dart' as tel;
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/sms_transaction.dart';
import 'sms_classifier.dart';
import 'sms_database.dart';
import 'sms_parser.dart';
import 'sms_service.dart' as app_sms;
import 'sms_storage_helper.dart';

/// Signature for the inbox-fetch function injected into [SmsSyncService].
///
/// Production: delegates to [tel.Telephony.instance.getInboxSms].
/// Tests: returns a pre-built list without touching the platform channel.
typedef InboxFetcher = Future<List<tel.SmsMessage>> Function();

/// Orchestrates incremental inbox reading for SmartFin.
///
/// Sync pipeline per cycle:
///   permission check
///     → inbox fetch (up to [_fetchLimit] messages, newest first)
///       → gate 1: bank classification  (sender pattern + body keywords)
///       → gate 2: transaction keywords (debited/credited/INR/spent/…)
///       → gate 3: timestamp after lastSyncTime
///       → gate 4: not in processed-ID set
///         → parse → save → notify UI
///
/// Complements [SmsPipeline] (real-time incoming SMS) by back-filling
/// historical inbox messages that arrived while the app was closed.
///
/// Privacy contract
/// ────────────────
/// - Non-bank / non-transaction messages are dropped immediately.
/// - Bank messages are stored locally only — no network calls.
/// - Debug logs never include message body, sender address, or counterparty.
class SmsSyncService {
  SmsSyncService._() : _inboxFetcher = _defaultFetcher;

  /// Visible for testing — allows injecting a stub inbox fetcher so tests
  /// never touch the platform channel (which asserts `isAndroid == true`).
  SmsSyncService.withFetcher(InboxFetcher fetcher) : _inboxFetcher = fetcher;

  static final SmsSyncService instance = SmsSyncService._();

  final InboxFetcher _inboxFetcher;

  // ── Tuning constants ───────────────────────────────────────────────────────

  /// Maximum number of inbox messages fetched per sync cycle.
  static const _fetchLimit = 100;

  /// Cooldown between [autoSync] calls (seconds).
  static const _cooldownSeconds = 300; // 5 minutes

  // ── Transaction keyword filter ─────────────────────────────────────────────
  // Applied as gate 2 after bank classification.
  // Covers all keywords requested: debited, credited, INR, spent, UPI,
  // transaction, payment, purchase — plus common Indian bank variants.
  static final RegExp _transactionKeywords = RegExp(
    r'\b(debited|credited)\b|'
    r'\binr\b|'
    r'\bspent\b|'
    r'\bupi\b|'
    r'\b(transaction|txn)\b|'
    r'\b(payment|paid)\b|'
    r'\b(purchase|purchased)\b|'
    r'(?:rs\.?|₹)\s*[\d,]+',        // Rs./₹ followed by digits
    caseSensitive: false,
  );

  // ── Callback ───────────────────────────────────────────────────────────────

  /// Called with each successfully parsed and stored [SmsTransaction].
  /// Wired to [FinanceProvider.prependSmsTransaction] in main.dart.
  void Function(SmsTransaction)? onTransaction;

  /// Called with each saved [SmsTransaction] that contains a valid account
  /// number, so the UI layer can auto-create the account if needed.
  /// Wired to [FinanceProvider.ensureAccountExists] in main.dart.
  void Function(SmsTransaction)? onAccountDetected;

  // ── Default production fetcher ─────────────────────────────────────────────

  static Future<List<tel.SmsMessage>> _defaultFetcher() async {
    final messages = await tel.Telephony.instance.getInboxSms(
      columns: [
        tel.SmsColumn.ID,
        tel.SmsColumn.ADDRESS,
        tel.SmsColumn.BODY,
        tel.SmsColumn.DATE,
      ],
      sortOrder: [tel.OrderBy(tel.SmsColumn.DATE, sort: tel.Sort.DESC)],
    );
    return messages.length > _fetchLimit
        ? messages.sublist(0, _fetchLimit)
        : messages;
  }

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Lifecycle entry point — called from [initState] and [AppLifecycleState.resumed].
  ///
  /// Skips the sync if the 5-minute cooldown is still active.
  /// Must NOT be awaited at the call site (fire-and-forget).
  Future<void> autoSync() async {
    try {
      final active = await SmsStorageHelper.isCooldownActive(
        cooldownSeconds: _cooldownSeconds,
      );
      if (active) {
        if (kDebugMode) {
          debugPrint('[SmsSyncService] autoSync skipped — cooldown active '
              '(< ${_cooldownSeconds}s since last sync)');
        }
        return;
      }
      await syncSms();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[SmsSyncService] autoSync error: $e');
      }
    }
  }

  /// Full sync cycle: permission → fetch → filter → parse → save.
  ///
  /// Bypasses the cooldown guard — safe to call directly from a manual
  /// refresh button. All I/O is async; the widget tree is never blocked.
  Future<void> syncSms() async {
    // ── 1. Permission check ────────────────────────────────────────────────
    final permStatus = await Permission.sms.request();

    if (kDebugMode) {
      debugPrint('[SmsSyncService] permission status: ${permStatus.name}');
    }

    if (!permStatus.isGranted) {
      if (kDebugMode) {
        debugPrint('[SmsSyncService] READ_SMS denied — aborting sync');
      }
      return; // do NOT update lastSyncTime
    }

    // ── 2. Load persisted state ────────────────────────────────────────────
    final lastSyncTime = await SmsStorageHelper.getLastSyncTime();
    final Set<String> processedIds = await SmsStorageHelper.loadProcessedIds();

    if (kDebugMode) {
      debugPrint('[SmsSyncService] lastSyncTime: '
          '${lastSyncTime?.toIso8601String() ?? 'none (first run)'}');
      debugPrint('[SmsSyncService] processedIds in store: ${processedIds.length}');
    }

    // ── 3. Fetch inbox messages ────────────────────────────────────────────
    List<tel.SmsMessage> rawMessages;
    try {
      rawMessages = await _inboxFetcher();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[SmsSyncService] inbox fetch error: $e');
      }
      return; // do NOT update lastSyncTime on fetch failure
    }

    if (kDebugMode) {
      debugPrint('[SmsSyncService] fetched: ${rawMessages.length} message(s) '
          '(limit: $_fetchLimit)');
    }

    // ── 4. Filter pipeline + parse + save ─────────────────────────────────
    int countSkippedPromotional = 0;
    int countSkippedTelecom     = 0;
    int countSkippedOld         = 0;
    int countSkippedDuplicate   = 0;
    int countSkippedNonBank     = 0;
    int countSkippedNoKeyword   = 0;
    int countMatched            = 0;
    int countSaved              = 0;
    int countSaveFailed         = 0;

    final Set<String> newlyProcessedIds = {};

    for (final raw in rawMessages) {
      final msg = _toAppMessage(raw);

      // Single classify() call covers gates 0 (promotional), 1 (telecom),
      // 2 (bank sender), and 3 (body keywords) in one pass.
      final classification = SmsClassifier.instance.classify(msg);

      // Gate 0: promotional sender (TRAI DLT -P).
      if (classification.matchedRule == 'promotional') {
        countSkippedPromotional++;
        if (kDebugMode) {
          debugPrint(
            '[SmsSyncService] skip promotional  sender=${msg.sender}',
          );
        }
        continue;
      }

      // Gate 0b: telecom service message (recharge, data pack, validity, SIM).
      if (classification.matchedRule == 'telecom') {
        countSkippedTelecom++;
        if (kDebugMode) {
          debugPrint(
            '[SmsSyncService] skip telecom-svc  sender=${msg.sender}',
          );
        }
        continue;
      }

      // Gate 1: not a bank/financial message.
      if (!classification.isBankSms) {
        countSkippedNonBank++;
        continue;
      }

      // Gate 2: transaction keyword check.
      if (!_isTransactionSms(msg)) {
        countSkippedNoKeyword++;
        continue;
      }

      // Gate 3: timestamp must be strictly after lastSyncTime.
      if (lastSyncTime != null && !msg.timestamp.isAfter(lastSyncTime)) {
        countSkippedOld++;
        continue;
      }

      // Gate 4: duplicate prevention — skip already-processed IDs.
      final id = _computeId(raw);
      if (processedIds.contains(id)) {
        countSkippedDuplicate++;
        continue;
      }

      countMatched++;

      // Parse and persist.
      try {
        final tx = SmsParser.parse(msg);
        await SmsDatabase.instance.saveTransaction(tx);

        newlyProcessedIds.add(id);
        countSaved++;

        // Notify UI layer (main isolate — safe after await).
        onTransaction?.call(tx);

        // Trigger account auto-creation if a valid account number was parsed.
        if (tx.accountNumber != SmsTransaction.unknown) {
          onAccountDetected?.call(tx);
        }

        if (kDebugMode) {
          debugPrint(
            '[SmsSyncService] saved  id=$id '
            'type=${tx.transactionType.name} '
            'bank=${tx.bankName} '
            'amount=${tx.amountDisplay} '
            'rule=${classification.matchedRule} '
            'ts=${tx.timestamp}',
          );
        }
      } catch (e) {
        countSaveFailed++;
        if (kDebugMode) {
          debugPrint('[SmsSyncService] save error id=$id: $e');
        }
        // Continue — do NOT add to processed set for failed saves.
      }
    }

    // ── 5. Persist updated state ───────────────────────────────────────────
    if (newlyProcessedIds.isNotEmpty) {
      await SmsStorageHelper.addProcessedIds(newlyProcessedIds);
    }

    // Update lastSyncTime only on successful completion.
    await SmsStorageHelper.setLastSyncTime(DateTime.now());

    // ── 6. Summary log ────────────────────────────────────────────────────
    if (kDebugMode) {
      debugPrint(
        '[SmsSyncService] sync complete ──────────────────────\n'
        '  fetched        : ${rawMessages.length}\n'
        '  promotional    : $countSkippedPromotional\n'
        '  telecom svc    : $countSkippedTelecom\n'
        '  non-bank       : $countSkippedNonBank\n'
        '  no keyword     : $countSkippedNoKeyword\n'
        '  too old        : $countSkippedOld\n'
        '  duplicates     : $countSkippedDuplicate\n'
        '  matched        : $countMatched\n'
        '  saved          : $countSaved\n'
        '  save errors    : $countSaveFailed\n'
        '─────────────────────────────────────────────────────',
      );
    }
  }

  // ── Public filter (exposed for direct testing) ─────────────────────────────

  /// Returns `true` if [message] body contains at least one financial
  /// transaction keyword (case-insensitive).
  ///
  /// Keywords: debited, credited, INR, Rs./₹ + amount, spent, UPI,
  /// transaction/txn, payment/paid, purchase/purchased.
  bool isTransactionSms(app_sms.SmsMessage message) =>
      _isTransactionSms(message);

  // ── Private helpers ────────────────────────────────────────────────────────

  static bool _isTransactionSms(app_sms.SmsMessage message) =>
      _transactionKeywords.hasMatch(message.body);

  /// Compute a stable unique identifier for a [tel.SmsMessage].
  ///
  /// Prefers the platform-provided integer ID; falls back to
  /// `"<sender>_<timestampMs>"` when the ID is absent.
  String _computeId(tel.SmsMessage raw) {
    final platformId = raw.id;
    if (platformId != null) return platformId.toString();
    final sender = raw.address ?? 'unknown';
    final ts = raw.date ?? 0;
    return '${sender}_$ts';
  }

  /// Convert a [tel.SmsMessage] to the app's internal [app_sms.SmsMessage]
  /// DTO consumed by [SmsClassifier] and [SmsParser].
  app_sms.SmsMessage _toAppMessage(tel.SmsMessage raw) {
    return app_sms.SmsMessage(
      sender: raw.address ?? 'unknown',
      body: raw.body ?? '',
      timestamp: raw.date != null
          ? DateTime.fromMillisecondsSinceEpoch(raw.date!)
          : DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}
