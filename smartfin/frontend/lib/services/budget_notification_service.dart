import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../providers/finance_provider.dart';

/// Manages local push notifications for budget threshold alerts.
///
/// Responsibilities:
///   • One-time initialisation of [FlutterLocalNotificationsPlugin]
///   • Requesting notification permission on Android 13+ (API 33+)
///   • Showing a styled notification for each [BudgetAlert]
///
/// Anti-spam contract:
///   Duplicate prevention is handled upstream by [FinanceProvider] via
///   the persisted threshold-flag system.  This service fires exactly once
///   per [show] call — it never checks or stores state itself.
///
/// Usage:
///   ```dart
///   await BudgetNotificationService.instance.init();
///   await BudgetNotificationService.instance.show(alert);
///   ```
class BudgetNotificationService {
  BudgetNotificationService._();
  static final BudgetNotificationService instance = BudgetNotificationService._();

  static const _channelId   = 'budget_alerts';
  static const _channelName = 'Budget Alerts';
  static const _channelDesc = 'Notifications when your monthly budget reaches key thresholds.';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialised = false;

  // ── Initialisation ─────────────────────────────────────────────────────────

  /// Initialises the plugin and requests notification permission.
  ///
  /// Safe to call multiple times — subsequent calls are no-ops.
  /// Must be called before [show].
  Future<void> init() async {
    if (_initialised) return;

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinInit  = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: false,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidInit,
      iOS:     darwinInit,
      macOS:   darwinInit,
    );

    await _plugin.initialize(initSettings);

    // Request Android 13+ runtime permission.
    // On older API levels this is a no-op.
    final androidImpl = _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidImpl != null) {
      final granted = await androidImpl.requestNotificationsPermission();
      if (kDebugMode) {
        debugPrint(
          '[BudgetNotificationService] Android notification permission: '
          '${granted == true ? 'granted' : 'denied'}',
        );
      }
    }

    _initialised = true;
    if (kDebugMode) {
      debugPrint('[BudgetNotificationService] initialised');
    }
  }

  // ── Notification content ───────────────────────────────────────────────────

  /// Returns the user-facing title for [alert].
  static String titleFor(BudgetAlert alert) {
    return switch (alert.thresholdPct) {
      25  => '💰 Budget Update',
      50  => '⚠️ Halfway Through Budget',
      75  => '🔶 Budget Warning',
      90  => '🚨 Budget Critical',
      100 => '❌ Budget Exceeded',
      _   => '💸 Budget Alert',
    };
  }

  /// Returns the user-facing body message for [alert].
  static String bodyFor(BudgetAlert alert) {
    return switch (alert.thresholdPct) {
      25  => "You've used 25% of your budget. Good start, stay on track.",
      50  => 'Half of your budget is used. Monitor your spending.',
      75  => "You're nearing your budget limit. Spend carefully.",
      90  => 'Almost at your budget limit. Avoid unnecessary expenses.',
      100 => 'Budget exceeded! Review your spending immediately.',
      _   => 'You have used ${alert.thresholdPct}% of your monthly budget.',
    };
  }

  // ── Show ───────────────────────────────────────────────────────────────────

  /// Posts a local notification for [alert].
  ///
  /// Uses [alert.thresholdPct] as the notification ID so that if the same
  /// threshold fires again (e.g. after a reinstall that cleared prefs), the
  /// new notification replaces the old one rather than stacking.
  ///
  /// Failures are caught and logged — a notification error must never
  /// propagate to the caller or affect the transaction flow.
  Future<void> show(BudgetAlert alert) async {
    if (!_initialised) {
      if (kDebugMode) {
        debugPrint(
          '[BudgetNotificationService] show() called before init() — skipping',
        );
      }
      return;
    }

    try {
      final androidDetails = AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDesc,
        importance: alert.isExceeded ? Importance.max : Importance.high,
        priority:   alert.isExceeded ? Priority.max   : Priority.high,
        // Use a distinct colour per severity level.
        color: _colorFor(alert.thresholdPct),
        // Show the usage percentage as a sub-text line.
        subText: '${alert.usagePercent.toStringAsFixed(0)}% used',
        styleInformation: BigTextStyleInformation(bodyFor(alert)),
        // Group all budget alerts under one key so they collapse in the
        // notification shade rather than stacking.
        groupKey: 'budget_alerts_group',
        playSound: true,
        enableVibration: true,
      );

      const darwinDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentSound: true,
        presentBadge: false,
      );

      final details = NotificationDetails(
        android: androidDetails,
        iOS:     darwinDetails,
        macOS:   darwinDetails,
      );

      await _plugin.show(
        alert.thresholdPct, // notification ID — unique per threshold
        titleFor(alert),
        bodyFor(alert),
        details,
      );

      if (kDebugMode) {
        debugPrint(
          '[BudgetNotificationService] notification shown: '
          'id=${alert.thresholdPct} threshold=${alert.thresholdPct}%',
        );
      }
    } catch (e) {
      // Best-effort — never throw from a notification call.
      if (kDebugMode) {
        debugPrint('[BudgetNotificationService] show error: $e');
      }
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  /// Returns an Android notification accent colour matching the severity.
  static Color _colorFor(int pct) {
    if (pct >= 100) return const Color(0xFFD32F2F); // red
    if (pct >= 90)  return const Color(0xFFE64A19); // deep orange
    if (pct >= 75)  return const Color(0xFFF57C00); // orange
    if (pct >= 50)  return const Color(0xFFFBC02D); // amber
    return              const Color(0xFF388E3C);    // green (25%)
  }
}
