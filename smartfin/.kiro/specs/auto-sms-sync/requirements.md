# Requirements Document

## Introduction

The **Auto SMS Sync** feature adds incremental, lifecycle-aware SMS reading to the SmartFin Flutter app. When the app starts or returns to the foreground, `SmsSyncService` reads the device inbox via the `sms_advanced` package, filters for new transaction-related messages, parses them, and persists them to the existing SQLite store — all without blocking the UI. A 5-minute cooldown prevents redundant syncs on rapid foreground/background cycles. Duplicate prevention ensures each SMS is processed exactly once across app restarts.

This feature complements the existing real-time `SmsPipeline` (which handles *incoming* SMS via `EventChannel`) by back-filling *historical* inbox messages that arrived while the app was closed or backgrounded.

---

## Glossary

- **SmsSyncService**: The new Dart service class responsible for orchestrating inbox sync. Exposes `autoSync()`, `syncSms()`, and `isTransactionSms()`.
- **SmsDatabase**: The existing SQLite-backed store (`frontend/lib/services/sms_database.dart`) that persists `BankSmsRecord` rows.
- **SmsClassifier**: The existing classifier (`frontend/lib/services/sms_classifier.dart`) that determines whether an SMS is bank/transaction-related.
- **SmsParser**: The existing parser (`frontend/lib/services/sms_parser.dart`) that extracts structured fields from a raw SMS body.
- **SmsTransaction**: The existing domain model (`frontend/lib/models/sms_transaction.dart`) representing a parsed transaction.
- **lastSyncTime**: A `DateTime` value persisted in `SharedPreferences` recording when the most recent successful sync completed.
- **Cooldown Period**: A fixed 5-minute interval. If `lastSyncTime` is within the cooldown period of the current time, `autoSync()` skips the sync.
- **Processed SMS ID**: A unique identifier for a processed SMS — either the platform-provided message ID or a composite of sender + timestamp — stored to prevent duplicate processing.
- **AppLifecycleObserver**: A `WidgetsBindingObserver` mixin that detects `AppLifecycleState.resumed` transitions.
- **Transaction SMS**: An SMS message that passes `SmsSyncService.isTransactionSms()` — i.e., its body contains at least one of the keywords: `debited`, `credited`, or `INR`, and its timestamp is after `lastSyncTime`.
- **Inbox Batch**: The most recent 50–100 SMS messages fetched from the device inbox using `sms_advanced`.

---

## Requirements

### Requirement 1: Android READ_SMS Permission

**User Story:** As a user, I want the app to request permission to read my SMS inbox, so that the auto-sync feature can access historical transaction messages.

#### Acceptance Criteria

1. THE `AndroidManifest` SHALL declare `android.permission.READ_SMS` as a `uses-permission` entry.
2. WHEN `SmsSyncService.syncSms()` is called for the first time, THE `SmsSyncService` SHALL request the `READ_SMS` runtime permission from the user before attempting to read the inbox.
3. IF the user denies the `READ_SMS` permission, THEN THE `SmsSyncService` SHALL abort the sync and log a debug message without throwing an unhandled exception.
4. IF the user grants the `READ_SMS` permission, THEN THE `SmsSyncService` SHALL proceed with fetching the inbox batch.

---

### Requirement 2: App Lifecycle Integration

**User Story:** As a user, I want the app to automatically sync SMS transactions when I open or return to the app, so that my transaction history is always up to date without manual intervention.

#### Acceptance Criteria

1. THE `AppLifecycleObserver` SHALL implement `WidgetsBindingObserver` and register itself with `WidgetsBinding.instance` during `initState`.
2. WHEN the host widget's `initState` is called, THE `AppLifecycleObserver` SHALL call `SmsSyncService.instance.autoSync()`.
3. WHEN `AppLifecycleState.resumed` is received by `AppLifecycleObserver.didChangeAppLifecycleState()`, THE `AppLifecycleObserver` SHALL call `SmsSyncService.instance.autoSync()`.
4. WHEN the host widget is disposed, THE `AppLifecycleObserver` SHALL remove itself from `WidgetsBinding.instance` to prevent memory leaks.
5. THE `AppLifecycleObserver` SHALL NOT trigger `autoSync()` for any lifecycle state other than `resumed` (e.g., `paused`, `inactive`, `detached`).

---

### Requirement 3: Cooldown Guard

**User Story:** As a developer, I want the sync to be skipped if it ran less than 5 minutes ago, so that rapid foreground/background cycles do not cause redundant inbox reads.

#### Acceptance Criteria

1. WHEN `SmsSyncService.autoSync()` is called, THE `SmsSyncService` SHALL read `lastSyncTime` from `SharedPreferences`.
2. IF `lastSyncTime` exists AND the elapsed time since `lastSyncTime` is less than 300 seconds, THEN THE `SmsSyncService` SHALL return without calling `syncSms()`.
3. IF `lastSyncTime` does not exist OR the elapsed time since `lastSyncTime` is greater than or equal to 300 seconds, THEN THE `SmsSyncService` SHALL call `syncSms()`.
4. THE `SmsSyncService` SHALL evaluate the cooldown using `DateTime.now()` at the moment `autoSync()` is invoked, not at the time of a previous call.

---

### Requirement 4: Inbox SMS Fetching

**User Story:** As a user, I want the app to fetch recent inbox messages efficiently, so that sync completes quickly without reading the entire SMS history.

#### Acceptance Criteria

1. WHEN `SmsSyncService.syncSms()` is called, THE `SmsSyncService` SHALL fetch between 50 and 100 of the most recent inbox SMS messages using the `sms_advanced` package.
2. THE `SmsSyncService` SHALL fetch only messages from the `SmsBox.INBOX` folder.
3. WHEN the `sms_advanced` package returns an empty list, THE `SmsSyncService` SHALL complete without error and update `lastSyncTime`.
4. IF the `sms_advanced` package throws an exception during fetch, THEN THE `SmsSyncService` SHALL catch the exception, log a debug message, and return without updating `lastSyncTime`.

---

### Requirement 5: Transaction SMS Filtering

**User Story:** As a user, I want only relevant financial SMS messages to be processed, so that non-transaction messages (promotions, OTPs from non-banks, etc.) do not pollute my transaction history.

#### Acceptance Criteria

1. THE `SmsSyncService.isTransactionSms()` method SHALL accept an SMS message and return `true` if and only if the message body contains at least one of the keywords: `debited`, `credited`, or `INR` (case-insensitive).
2. WHEN `SmsSyncService.syncSms()` filters the inbox batch, THE `SmsSyncService` SHALL pass each message through `SmsClassifier.instance.isBankSms()` as the primary filter.
3. WHEN `SmsSyncService.syncSms()` filters the inbox batch, THE `SmsSyncService` SHALL additionally call `isTransactionSms()` to confirm keyword presence before processing.
4. WHEN `SmsSyncService.syncSms()` filters the inbox batch, THE `SmsSyncService` SHALL exclude any message whose timestamp is on or before `lastSyncTime`.
5. THE `SmsSyncService` SHALL process only messages that pass all three filters: bank classification, keyword match, and timestamp after `lastSyncTime`.

---

### Requirement 6: Duplicate Prevention

**User Story:** As a user, I want each SMS transaction to appear in my history exactly once, so that duplicate entries do not distort my financial summary.

#### Acceptance Criteria

1. THE `SmsSyncService` SHALL maintain a set of processed SMS identifiers persisted in `SharedPreferences` under a dedicated key.
2. WHEN processing a fetched SMS, THE `SmsSyncService` SHALL compute a unique identifier for the message using the platform-provided message ID if available, or a composite of `sender + timestamp.millisecondsSinceEpoch` otherwise.
3. IF a message's identifier is already present in the processed set, THEN THE `SmsSyncService` SHALL skip that message without inserting a duplicate record into `SmsDatabase`.
4. WHEN a message is successfully saved to `SmsDatabase`, THE `SmsSyncService` SHALL add its identifier to the processed set and persist the updated set to `SharedPreferences`.
5. THE `SmsSyncService` SHALL load the processed set from `SharedPreferences` once at the start of each `syncSms()` call and persist it once at the end, not on every individual message.

---

### Requirement 7: Transaction Parsing and Storage

**User Story:** As a user, I want parsed transaction details (sender, amount, type, date) saved locally, so that I can view my transaction history even without an internet connection.

#### Acceptance Criteria

1. WHEN a message passes all filters in `syncSms()`, THE `SmsSyncService` SHALL pass the message to `SmsParser.parse()` to extract a structured `SmsTransaction`.
2. WHEN `SmsParser.parse()` returns an `SmsTransaction`, THE `SmsSyncService` SHALL call `SmsDatabase.instance.saveTransaction()` to persist the record.
3. THE `SmsDatabase` SHALL store the following fields for each transaction: `sender`, `body` (raw SMS), `amount` (numeric, nullable), `amountDisplay` (formatted string), `type` (credit/debit/otp/unknown), `timestamp`, `bankName`, `accountNumber`, `counterparty`.
4. WHEN `SmsDatabase.instance.saveTransaction()` is called with a duplicate record (same `sender` + `timestamp` + `body`), THE `SmsDatabase` SHALL silently ignore the insert using `ConflictAlgorithm.ignore`.
5. WHEN a transaction is successfully saved, THE `SmsSyncService` SHALL invoke the `onTransaction` callback (if registered) with the saved `SmsTransaction` so the UI can update without polling.

---

### Requirement 8: Sync Time Update

**User Story:** As a developer, I want `lastSyncTime` to be updated after each successful sync, so that the cooldown guard uses an accurate reference point.

#### Acceptance Criteria

1. WHEN `SmsSyncService.syncSms()` completes processing all filtered messages without an unhandled exception, THE `SmsSyncService` SHALL write the current `DateTime.now()` as the new `lastSyncTime` to `SharedPreferences`.
2. THE `SmsSyncService` SHALL store `lastSyncTime` as an ISO 8601 string under the key `sms_sync_last_sync_time`.
3. IF `syncSms()` exits early due to a permission denial or a fetch exception, THEN THE `SmsSyncService` SHALL NOT update `lastSyncTime`.

---

### Requirement 9: Non-Blocking Execution

**User Story:** As a user, I want the SMS sync to run silently in the background, so that the app remains responsive during sync.

#### Acceptance Criteria

1. THE `SmsSyncService.autoSync()` method SHALL be declared `async` and SHALL NOT be `await`-ed by the caller at the call site in `initState` or `didChangeAppLifecycleState()`.
2. THE `SmsSyncService.syncSms()` method SHALL use `async`/`await` for all I/O operations (permission checks, SMS fetch, database writes, SharedPreferences reads/writes).
3. THE `SmsSyncService` SHALL NOT display any loading indicator or block the widget tree during sync.
4. WHERE a manual refresh button is present, THE `SmsSyncService` SHALL allow the button to display a loading state managed by the calling widget, but the service itself SHALL NOT own any UI state.

---

### Requirement 10: Service Class Structure

**User Story:** As a developer, I want SMS sync logic encapsulated in a dedicated service class, so that the UI layer and other services remain decoupled from sync implementation details.

#### Acceptance Criteria

1. THE `SmsSyncService` SHALL be implemented as a singleton class in `frontend/lib/services/sms_sync_service.dart`.
2. THE `SmsSyncService` SHALL expose the following public methods: `autoSync()`, `syncSms()`, and `isTransactionSms(SmsMessage message)`.
3. THE `SmsSyncService` SHALL expose an `onTransaction` callback property of type `void Function(SmsTransaction)?`, consistent with the existing `SmsPipeline.onTransaction` pattern.
4. THE `SmsSyncService` SHALL NOT import any widget or UI library (`package:flutter/material.dart`, etc.) — it SHALL only import `package:flutter/foundation.dart` for `debugPrint` and `kDebugMode`.
5. THE `SmsSyncService` SHALL reuse `SmsClassifier`, `SmsParser`, and `SmsDatabase` rather than duplicating their logic.

---

### Requirement 11: Manual Refresh (Optional)

**User Story:** As a user, I want a manual "Refresh" button in the app, so that I can trigger an SMS sync on demand without waiting for the next automatic trigger.

#### Acceptance Criteria

1. WHERE a manual refresh button is implemented, THE refresh button SHALL call `SmsSyncService.instance.syncSms()` directly (bypassing the cooldown guard).
2. WHERE a manual refresh button is implemented, THE host widget SHALL display a loading indicator while `syncSms()` is in progress and hide it upon completion.
3. WHERE a manual refresh button is implemented, THE host widget SHALL handle errors from `syncSms()` gracefully and display a user-facing error message if the sync fails.
