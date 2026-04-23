# Tasks: Auto SMS Sync

## Task List

- [x] 1. Android manifest and dependency setup
  - [x] 1.1 Add `android.permission.READ_SMS` to `frontend/android/app/src/main/AndroidManifest.xml`
  - [x] 1.2 Add `sms_advanced` and `permission_handler` dependencies to `frontend/pubspec.yaml`
  - [x] 1.3 Run `flutter pub get` to resolve new dependencies

- [x] 2. Implement `SmsSyncService`
  - [x] 2.1 Create `frontend/lib/services/sms_sync_service.dart` as a singleton class
  - [x] 2.2 Implement `isTransactionSms(SmsMessage message)` — returns `true` iff body contains `debited`, `credited`, or `INR` (case-insensitive)
  - [x] 2.3 Implement `autoSync()` — reads `lastSyncTime` from SharedPreferences, applies 5-minute cooldown guard, delegates to `syncSms()`
  - [x] 2.4 Implement `syncSms()` — requests `READ_SMS` permission, fetches 50–100 inbox messages via `sms_advanced`, runs filter pipeline, parses, saves, updates `lastSyncTime`
  - [x] 2.5 Implement duplicate prevention — load processed-ID set at start of `syncSms()`, skip already-processed messages, persist updated set at end
  - [x] 2.6 Wire `onTransaction` callback — invoke after each successful `SmsDatabase.saveTransaction()` call, matching `SmsPipeline` pattern
  - [x] 2.7 Verify no Flutter UI library imports in the service file (only `package:flutter/foundation.dart` allowed)

- [x] 3. Integrate `AppLifecycleObserver` into the app root widget
  - [x] 3.1 Add `WidgetsBindingObserver` mixin to `_AuthWrapperState` (or a dedicated wrapper widget) in `frontend/lib/main.dart`
  - [x] 3.2 Register observer in `initState` and call `SmsSyncService.instance.autoSync()` (fire-and-forget)
  - [x] 3.3 Implement `didChangeAppLifecycleState` — call `autoSync()` only on `AppLifecycleState.resumed`
  - [x] 3.4 Remove observer in `dispose` to prevent memory leaks
  - [x] 3.5 Wire `SmsSyncService.instance.onTransaction` to `FinanceProvider.prependSmsTransaction` in `main.dart` (alongside existing `SmsPipeline` wiring)

- [-] 4. Unit tests — example-based
  - [x] 4.1 Create `frontend/test/sms_sync_service_test.dart`
  - [x] 4.2 Test: permission denied → sync aborted, `lastSyncTime` not updated
  - [x] 4.3 Test: permission granted → inbox fetch proceeds
  - [x] 4.4 Test: empty inbox → `lastSyncTime` updated, no errors
  - [x] 4.5 Test: `syncSms()` called directly bypasses cooldown
  - [x] 4.6 Test: `lastSyncTime` written as ISO 8601 string under key `sms_sync_last_sync_time`
  - [x] 4.7 Test: processed-ID set loaded once at start of `syncSms()`, persisted once at end
  - [ ] 4.8 Test: `SmsParser.parse()` called for each message passing all filters
  - [ ] 4.9 Test: `SmsDatabase.saveTransaction()` called with the parsed transaction
  - [ ] 4.10 Test: `onTransaction` callback invoked after successful save

- [ ] 5. Property-based tests
  - [ ] 5.1 Create `frontend/test/sms_sync_service_property_test.dart`
  - [ ] 5.2 Property 1 — `isTransactionSms` keyword contract: for any body with/without keywords, return value matches keyword presence (≥100 iterations)
    - `// Feature: auto-sms-sync, Property 1: isTransactionSms returns true iff body contains debited/credited/INR`
  - [ ] 5.3 Property 2 — Cooldown within window: for any `lastSyncTime` in `[now-299s, now]`, `syncSms` is not called (≥100 iterations)
    - `// Feature: auto-sms-sync, Property 2: cooldown guard skips sync when within 5-minute window`
  - [ ] 5.4 Property 3 — Cooldown outside window: for any `lastSyncTime` ≥300s ago or null, `syncSms` is called (≥100 iterations)
    - `// Feature: auto-sms-sync, Property 3: cooldown guard triggers sync when outside 5-minute window`
  - [ ] 5.5 Property 4 — Timestamp filter: for any message with timestamp ≤ `lastSyncTime`, it is never parsed or saved (≥100 iterations)
    - `// Feature: auto-sms-sync, Property 4: messages with timestamp on or before lastSyncTime are excluded`
  - [ ] 5.6 Property 5 — Duplicate prevention: for any message whose ID is in the processed set, `saveTransaction` is never called (≥100 iterations)
    - `// Feature: auto-sms-sync, Property 5: already-processed messages are skipped`
  - [ ] 5.7 Property 6 — Processed ID round-trip: for any saved message, its ID appears in the persisted processed set (≥100 iterations)
    - `// Feature: auto-sms-sync, Property 6: saved message ID is persisted to processed set`
  - [ ] 5.8 Property 7 — Exception does not update `lastSyncTime`: for any exception from fetch, `lastSyncTime` is not written (≥100 iterations)
    - `// Feature: auto-sms-sync, Property 7: fetch exception does not update lastSyncTime`
  - [ ] 5.9 Property 8 — Non-resumed states: for any `AppLifecycleState` ≠ `resumed`, `autoSync` is not called (enumerate all non-resumed states)
    - `// Feature: auto-sms-sync, Property 8: non-resumed lifecycle states do not trigger autoSync`
  - [ ] 5.10 Property 9 — `onTransaction` callback fires for every saved transaction: for any saved message, callback called exactly once (≥100 iterations)
    - `// Feature: auto-sms-sync, Property 9: onTransaction callback fires exactly once per saved transaction`
  - [ ] 5.11 Property 10 — Database idempotency: inserting the same transaction twice results in exactly one row (≥100 iterations)
    - `// Feature: auto-sms-sync, Property 10: duplicate saveTransaction calls produce a single database record`

- [ ] 6. Widget tests
  - [ ] 6.1 Create `frontend/test/app_lifecycle_observer_test.dart`
  - [ ] 6.2 Test: `initState` triggers `SmsSyncService.instance.autoSync()`
  - [ ] 6.3 Test: `AppLifecycleState.resumed` triggers `autoSync()`
  - [ ] 6.4 Test: `dispose` removes observer from `WidgetsBinding.instance`
  - [ ] 6.5 (Optional) Test: manual refresh button calls `syncSms()` directly
  - [ ] 6.6 (Optional) Test: loading indicator shown/hidden around `syncSms()`
  - [ ] 6.7 (Optional) Test: error message displayed when `syncSms()` throws

- [-] 7. Manual verification
  - [x] 7.1 Run `flutter analyze` in `frontend/` — zero new warnings or errors
  - [x] 7.2 Run `flutter test` in `frontend/` — all tests pass
  - [ ] 7.3 Smoke test on Android device/emulator: grant `READ_SMS`, open app, verify historical transactions appear in the transaction list
  - [ ] 7.4 Smoke test: background and foreground the app within 5 minutes — verify sync is skipped (cooldown)
  - [ ] 7.5 Smoke test: background and foreground the app after 5 minutes — verify sync runs and new transactions appear
