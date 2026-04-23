# Bugfix Requirements Document

## Introduction

After an incoming SMS is received and processed by the pipeline, the dashboard screen does not reflect the new transaction data in real time. The user must manually refresh or restart the app to see the update. The root causes span both the Dart layer (`SmsPipeline`, `SmsService`) and the Android native layer (`SmsEventSink`, `SmsForegroundService`), and together they prevent the UI from being notified reliably after a bank SMS arrives.

## Bug Analysis

### Current Behavior (Defect)

1.1 WHEN an incoming bank SMS is processed and `SmsPipeline._process()` calls `SchedulerBinding.instance.addPostFrameCallback` after the `await SmsDatabase.instance.saveTransaction(tx)` THEN the system does not invoke the `onTransaction` callback if the Flutter scheduler is idle (no frame is currently scheduled), causing the UI to never update.

1.2 WHEN `SmsService.messages` getter is accessed THEN the system calls `receiveBroadcastStream()` on every access, creating a new native stream subscription each time, so any subsequent access after `SmsPipeline.start()` creates a duplicate subscription that may receive events independently of the one the pipeline is listening to.

1.3 WHEN `SmsForegroundService.onCancel` or `SmsForegroundService.onDestroy` is called (e.g. due to a Flutter lifecycle event or hot-reload) THEN the system nulls `SmsEventSink.sink`, causing `SmsReceiver.forwardToFlutter()` to drop the message after exhausting its 5 retries if the main-activity sink has not yet re-registered.

1.4 WHEN both `MainActivity` and `SmsForegroundService` register a stream handler on the same `EventChannel` name `"com.example.smartfin/sms"` THEN the system assigns `SmsEventSink.sink` to whichever engine called `onListen` last, so the sink may point to the headless engine's event sink while the UI engine is active, causing events to be delivered to the wrong engine.

### Expected Behavior (Correct)

2.1 WHEN an incoming bank SMS is processed and `SmsPipeline._process()` is ready to notify the UI after saving to the database THEN the system SHALL invoke the `onTransaction` callback immediately on the main isolate (e.g. via `WidgetsBinding.instance.addPostFrameCallback` with a scheduled frame, or directly via a microtask/`scheduleMicrotask`) so the UI updates regardless of whether a frame is already scheduled.

2.2 WHEN `SmsService.messages` getter is accessed THEN the system SHALL return the same cached broadcast stream instance so that only one native stream subscription is ever created per app lifecycle, preventing duplicate subscriptions and lost events.

2.3 WHEN `SmsForegroundService.onCancel` is called while the main-activity engine's sink is still active THEN the system SHALL NOT null `SmsEventSink.sink` if the sink currently held belongs to the main-activity engine, preserving event delivery to the foreground UI.

2.4 WHEN both `MainActivity` and `SmsForegroundService` attempt to register on the same `EventChannel` THEN the system SHALL ensure that the main-activity engine's sink takes and retains priority while the app is in the foreground, so events are always delivered to the engine that drives the visible UI.

### Unchanged Behavior (Regression Prevention)

3.1 WHEN a non-bank SMS is received THEN the system SHALL CONTINUE TO drop the message in `SmsClassifier` without storing it or updating the UI.

3.2 WHEN the app is in the background or killed and a bank SMS arrives THEN the system SHALL CONTINUE TO process and persist the transaction via the headless `SmsForegroundService` engine so the data is available when the user next opens the app.

3.3 WHEN `SmsPipeline.start()` is called more than once THEN the system SHALL CONTINUE TO ignore subsequent calls (guarded by `_running` flag) so no duplicate stream subscriptions are created at the pipeline level.

3.4 WHEN `FinanceProvider.prependSmsTransaction()` is called THEN the system SHALL CONTINUE TO prepend the new `TransactionModel` to `_transactions` and call `notifyListeners()` so all widgets observing the provider rebuild correctly.

3.5 WHEN the dashboard screen is visible and `FinanceProvider` notifies listeners THEN the system SHALL CONTINUE TO re-render `provider.recentTransactions` (first 4 transactions) via `context.watch<FinanceProvider>()` without requiring a manual refresh.

3.6 WHEN `SmsReceiver` cannot deliver an event because the sink is null THEN the system SHALL CONTINUE TO retry up to 5 times with a 1-second delay before dropping the message.

---

## Bug Condition

### Bug Condition Function

```pascal
FUNCTION isBugCondition(X)
  INPUT: X of type SmsEvent (a bank SMS that has been received and processed)
  OUTPUT: boolean

  // The bug is triggered when a bank SMS completes pipeline processing
  // but the UI callback is never invoked in the current frame cycle.
  RETURN (
    schedulerIsIdle(X) AND addPostFrameCallbackUsed(X)
  ) OR (
    sinkNulledByServiceCancel(X)
  ) OR (
    sinkPointsToWrongEngine(X)
  ) OR (
    duplicateStreamSubscriptionCreated(X)
  )
END FUNCTION
```

### Property: Fix Checking

```pascal
// Property: Fix Checking — UI updates after bank SMS
FOR ALL X WHERE isBugCondition(X) DO
  result ← processSms'(X)   // fixed pipeline + sink management
  ASSERT uiUpdatedWithinOneFrame(result)
    AND dashboardShowsNewTransaction(result)
    AND noManualRefreshRequired(result)
END FOR
```

### Property: Preservation Checking

```pascal
// Property: Preservation Checking
FOR ALL X WHERE NOT isBugCondition(X) DO
  ASSERT processSms(X) = processSms'(X)
  // Non-bank SMS dropped, background processing intact,
  // existing transactions unaffected, notifyListeners() still fires.
END FOR
```
