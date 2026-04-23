import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Manages all [SharedPreferences] state for the SMS sync system.
///
/// Two concerns:
/// 1. [lastSyncTime] — ISO 8601 timestamp of the most recent successful sync.
///    Used by [SmsSyncService.autoSync] to enforce the 5-minute cooldown.
///
/// 2. Processed-ID set — a persisted set of SMS identifiers that have already
///    been saved to [SmsDatabase]. Prevents duplicate inserts across app
///    restarts.
///
/// All methods are static and stateless — no singleton needed.
class SmsStorageHelper {
  SmsStorageHelper._();

  // ── SharedPreferences keys ─────────────────────────────────────────────────

  /// Key under which the last successful sync timestamp is stored.
  static const keyLastSyncTime = 'sms_sync_last_sync_time';

  /// Key under which the JSON-encoded processed-ID list is stored.
  static const keyProcessedIds = 'sms_sync_processed_ids';

  // ── lastSyncTime ───────────────────────────────────────────────────────────

  /// Returns the timestamp of the last successful sync, or `null` if no sync
  /// has ever completed.
  static Future<DateTime?> getLastSyncTime() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(keyLastSyncTime);
    if (raw == null) return null;
    return DateTime.tryParse(raw);
  }

  /// Persists [time] as the new last-sync timestamp.
  ///
  /// Call this only after a sync cycle completes without error.
  static Future<void> setLastSyncTime(DateTime time) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(keyLastSyncTime, time.toIso8601String());
  }

  /// Clears the stored last-sync timestamp.
  ///
  /// Useful for forcing a full re-sync (e.g. after a factory reset or
  /// during development).
  static Future<void> clearLastSyncTime() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(keyLastSyncTime);
  }

  /// Returns `true` if the cooldown period has not yet elapsed since the last
  /// successful sync.
  ///
  /// [cooldownSeconds] defaults to 300 (5 minutes).
  static Future<bool> isCooldownActive({int cooldownSeconds = 300}) async {
    final last = await getLastSyncTime();
    if (last == null) return false;
    final elapsed = DateTime.now().difference(last).inSeconds;
    return elapsed < cooldownSeconds;
  }

  // ── Processed-ID set ───────────────────────────────────────────────────────

  /// Loads the full set of already-processed SMS identifiers from storage.
  ///
  /// Returns an empty set if no IDs have been persisted yet or if the stored
  /// value is malformed.
  static Future<Set<String>> loadProcessedIds() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(keyProcessedIds);
    if (raw == null) return {};
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list.cast<String>().toSet();
    } catch (_) {
      return {};
    }
  }

  /// Persists [ids] as the complete processed-ID set.
  ///
  /// Replaces any previously stored set. Call once at the end of a sync
  /// cycle — not per-message — to minimise write amplification.
  static Future<void> saveProcessedIds(Set<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(keyProcessedIds, jsonEncode(ids.toList()));
  }

  /// Merges [newIds] into the existing processed-ID set and persists the
  /// result in a single write.
  ///
  /// Equivalent to [loadProcessedIds] + union + [saveProcessedIds] but
  /// performed atomically within one [SharedPreferences] instance.
  static Future<void> addProcessedIds(Set<String> newIds) async {
    if (newIds.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final existing = _parseIds(prefs.getString(keyProcessedIds));
    final merged = {...existing, ...newIds};
    await prefs.setString(keyProcessedIds, jsonEncode(merged.toList()));
  }

  /// Returns `true` if [id] is already in the persisted processed-ID set.
  ///
  /// Prefer loading the full set once at the start of a sync cycle via
  /// [loadProcessedIds] and checking membership in memory — this method
  /// performs a full read on every call and is intended for one-off checks
  /// only.
  static Future<bool> isProcessed(String id) async {
    final ids = await loadProcessedIds();
    return ids.contains(id);
  }

  /// Clears the entire processed-ID set.
  ///
  /// Forces all previously seen messages to be re-evaluated on the next sync.
  static Future<void> clearProcessedIds() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(keyProcessedIds);
  }

  // ── Bulk reset ─────────────────────────────────────────────────────────────

  /// Clears both [lastSyncTime] and the processed-ID set.
  ///
  /// Use during development or after a full database wipe to force a clean
  /// re-sync from scratch.
  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      prefs.remove(keyLastSyncTime),
      prefs.remove(keyProcessedIds),
    ]);
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  static Set<String> _parseIds(String? raw) {
    if (raw == null) return {};
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list.cast<String>().toSet();
    } catch (_) {
      return {};
    }
  }
}
