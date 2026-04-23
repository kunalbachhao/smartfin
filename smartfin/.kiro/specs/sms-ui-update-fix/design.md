# SMS UI Update Bugfix Design

## Overview

After an incoming bank SMS is received and processed by the pipeline, the dashboard screen does not reflect the new transaction in real time. The user must manually refresh or restart the app to see the update.

The bug has four distinct root causes spanning both the Dart layer and the Android native layer:

1. `SmsPipeline._process()` uses `SchedulerBinding.instance.addPostFrameCallback` after an `await`, so if the Flutter scheduler is idle (no frame scheduled), the callback is never invoked and the UI never updates.
2. `SmsService.messages` getter calls `receiveBroadcastStream()` on every access, creating a new native stream subscription each time — duplicate subscriptions may receive events independently of the one the pipeline is listening to.
3. `SmsForegroundService.onDestroy` nulls `SmsEventSink.sink` unconditionally, dropping messages if the main-activity engine's sink is still active.
4. Both `MainActivity` and `SmsForegroundService` register a stream handler on the same `EventChannel`, so `SmsEventSink.sink` may point to the headless engine while the UI engine is active.

The fix is minimal and targeted: replace `addPostFrameCallback` with a direct call (or `scheduleMicrotask`), cache the broadcast stream, guard the `onDestroy` null-out, and ensure the main-activity sink takes priority.

## Glossary

- **Bug_Condition (C)**: The condition that triggers the bug — a bank SMS completes pipeline processing but the UI callback is never invoked, or the event is dropped before reaching the Dart layer
- **Property (P)**: The desired behavior — after a bank SMS is processed, the dashboard updates within one frame without manual intervention
- **Preservation**: Existing behaviors that must remain unchanged — non-bank SMS dropping, background processing, pipeline deduplication guard, `notifyListeners()` firing, and dashboard re-rendering
- **SmsPipeline._process()**: The async method in `frontend/lib/services/sms_pipeline.dart` that classifies, parses, persists, and notifies the UI for each incoming SMS
- **SmsService.messages**: The getter in `frontend/lib/services/sms_service.dart` that returns a stream of `SmsMessage` objects from the Android `EventChannel`
- **SmsEventSink**: The singleton object in `SmsEventSink.kt` that holds the active `EventChannel.EventSink` used by `SmsReceiver` to forward events to Flutter
- **SmsForegroundService**: The Android foreground service in `SmsForegroundService.kt` that hosts a headless `FlutterEngine` for background SMS processing
- **MainActivity**: The main Flutter activity in `MainActivity.kt` that registers the foreground UI engine's `EventChannel` stream handler
- **addPostFrameCallback**: A Flutter scheduler API that defers a callback until the next rendered frame — if no frame is scheduled, the callback is never called
- **scheduleMicrotask / direct call**: Alternatives to `addPostFrameCallback` that execute immediately on the current microtask queue or synchronously, guaranteeing the callback fires regardless of frame scheduling state

## Bug Details

### Bug Condition

The bug manifests when a bank SMS completes pipeline processing but the UI is not notified. There are four independent sub-conditions, any one of which is sufficient to cause the failure.

**Formal Specification:**
```
FUNCTION isBugCondition(X)
  INPUT: X of type SmsEvent (a bank SMS that has been received and processed)
  OUTPUT: boolean

  RETURN (
    schedulerIsIdle(X) AND addPostFrameCallbackUsed(X)
  ) OR (
    duplicateStreamSubscriptionCreated(X)
  ) OR (
    sinkNulledByServiceDestroy(X) AND mainActivitySinkStillActive(X)
  ) OR (
    sinkPointsToHeadlessEngine(X) AND uiEngineIsActive(X)
  )
END FUNCTION
```

### Examples

- **Root cause 1**: App is idle (no animation running), bank SMS arrives → `_process()` calls `addPostFrameCallback` after `await` → no frame is scheduled → callback never fires → dashboard never updates
- **Root cause 2**: `SmsService.messages` is accessed twice (e.g. pipeline start + a second listener) → two separate `receiveBroadcastStream()` calls → two native subscriptions → events may be delivered to the second subscription only, bypassing the pipeline listener
- **Root cause 3**: Hot-reload or Flutter lifecycle event triggers `SmsForegroundService.onDestroy` → `SmsEventSink.sink = null` → `SmsReceiver` exhausts 5 retries → message dropped even though `MainActivity` sink is still valid
- **Root cause 4**: `SmsForegroundService.initHeadlessEngine()` calls `onListen` after `MainActivity.configureFlutterEngine()` → `SmsEventSink.sink` now points to the headless engine → events delivered to headless engine while UI engine is active → dashboard never sees the event

## Expected Behavior

### Preservation Requirements

**Unchanged Behaviors:**
- Non-bank SMS messages must continue to be dropped in `SmsClassifier` without storing or updating the UI
- Background/killed-app processing via the headless `SmsForegroundService` engine must continue to persist transactions so data is available on next app open
- `SmsPipeline.start()` called more than once must continue to be a no-op (guarded by `_running` flag)
- `FinanceProvider.prependSmsTransaction()` must continue to prepend the new `TransactionModel` and call `notifyListeners()`
- The dashboard screen must continue to re-render `provider.recentTransactions` via `context.watch<FinanceProvider>()` without manual refresh
- `SmsReceiver` must continue to retry up to 5 times with a 1-second delay when the sink is null before dropping the message

**Scope:**
All inputs that do NOT involve a bank SMS completing pipeline processing are completely unaffected. This includes:
- Non-bank SMS messages (dropped at classifier stage)
- Mouse/touch interactions with the dashboard
- Manual refresh / `loadAll()` calls
- Other keyboard or system inputs

## Hypothesized Root Cause

Based on code inspection, all four root causes are confirmed:

1. **Idle-scheduler callback loss** (`sms_pipeline.dart`): `SchedulerBinding.instance.addPostFrameCallback((_) => callback(tx))` is called after `await SmsDatabase.instance.saveTransaction(tx)`. If the Flutter scheduler has no pending frame (app is idle), the callback is queued but never executed. The fix is to call `callback(tx)` directly (it already runs on the main isolate after the `await`) or wrap it in `scheduleMicrotask`.

2. **Duplicate stream subscriptions** (`sms_service.dart`): The `messages` getter calls `_channel.receiveBroadcastStream()` on every access. Each call creates a new native-side stream subscription. The pipeline's `listen()` call and any subsequent access create independent subscriptions. The fix is to cache the stream in a private field and return the same instance on every access.

3. **Unconditional sink null-out on destroy** (`SmsForegroundService.kt`): `onDestroy` sets `SmsEventSink.sink = null` regardless of which engine currently owns the sink. If `MainActivity` registered its sink after the headless engine, destroying the service clears the active UI sink. The fix is to only null the sink in `onDestroy` if the sink currently held belongs to the headless engine (tracked via a local reference).

4. **Sink ownership race between two engines** (`SmsForegroundService.kt` / `MainActivity.kt`): Both engines register on the same `EventChannel` name. Whichever calls `onListen` last wins. The headless engine starts asynchronously and may call `onListen` after `MainActivity`, overwriting the UI sink. The fix is to give `MainActivity`'s sink explicit priority: `MainActivity.onListen` always overwrites; `SmsForegroundService.onListen` only writes if the sink is currently null.

## Correctness Properties

Property 1: Bug Condition - Bank SMS Triggers Immediate UI Update

_For any_ `SmsEvent` where `isBugCondition(X)` is true (i.e. a bank SMS completes pipeline processing under any of the four failure sub-conditions), the fixed pipeline and sink management SHALL invoke `FinanceProvider.prependSmsTransaction` on the main isolate within the same event-loop turn (or at most one microtask later), causing the dashboard to display the new transaction without any manual refresh.

**Validates: Requirements 2.1, 2.2, 2.3, 2.4**

Property 2: Preservation - Non-Buggy Inputs Produce Identical Behavior

_For any_ input where `isBugCondition(X)` is false (non-bank SMS, background processing, pipeline already running, `notifyListeners` call, dashboard re-render), the fixed code SHALL produce exactly the same result as the original code, preserving all existing behaviors for non-bank SMS dropping, background persistence, pipeline deduplication, provider notification, and dashboard rendering.

**Validates: Requirements 3.1, 3.2, 3.3, 3.4, 3.5, 3.6**

## Fix Implementation

### Changes Required

**File 1**: `frontend/lib/services/sms_pipeline.dart`

**Function**: `_process`

**Specific Changes**:
1. **Replace `addPostFrameCallback` with a direct call**: Remove `SchedulerBinding.instance.addPostFrameCallback((_) => callback(tx))`. After the `await`, execution is already on the main isolate, so call `callback(tx)` directly. If a frame-boundary guarantee is needed, use `scheduleMicrotask(() => callback(tx))` instead — microtasks are always drained regardless of frame scheduling state.
2. **Remove the `scheduler` import** if `SchedulerBinding` is no longer referenced.

---

**File 2**: `frontend/lib/services/sms_service.dart`

**Getter**: `messages`

**Specific Changes**:
1. **Cache the broadcast stream**: Add a private field `Stream<SmsMessage>? _messages` to `SmsService`. In the `messages` getter, return `_messages ??= _channel.receiveBroadcastStream()...` so `receiveBroadcastStream()` is called at most once per app lifecycle.

---

**File 3**: `frontend/android/app/src/main/kotlin/com/example/smartfin/SmsForegroundService.kt`

**Functions**: `initHeadlessEngine` (`onListen` / `onCancel`) and `onDestroy`

**Specific Changes**:
1. **Track the headless sink locally**: In `initHeadlessEngine`, store the sink in a local variable `headlessSink` when `onListen` fires.
2. **Conditional `onListen`**: Only assign `SmsEventSink.sink = sink` if `SmsEventSink.sink == null`, so the headless engine never overwrites an already-active UI sink.
3. **Conditional `onCancel`**: Only null `SmsEventSink.sink` if the current sink is the headless engine's own sink (`SmsEventSink.sink === headlessSink`).
4. **Conditional `onDestroy`**: Only null `SmsEventSink.sink` if the current sink is the headless engine's own sink, not the main-activity sink.

---

**File 4**: `frontend/android/app/src/main/kotlin/com/example/smartfin/MainActivity.kt`

**Function**: `configureFlutterEngine` (`onListen`)

**Specific Changes**:
1. **Always overwrite on `onListen`**: `MainActivity.onListen` should unconditionally set `SmsEventSink.sink = sink`, giving the UI engine priority over any previously registered headless sink. (This is already the case in the current code — confirm no change needed here, or add a comment clarifying the priority contract.)

## Testing Strategy

### Validation Approach

The testing strategy follows a two-phase approach: first, surface counterexamples that demonstrate the bug on unfixed code, then verify the fix works correctly and preserves existing behavior.

### Exploratory Bug Condition Checking

**Goal**: Surface counterexamples that demonstrate the bug BEFORE implementing the fix. Confirm or refute the root cause analysis.

**Test Plan**: Write unit/widget tests that simulate each of the four failure sub-conditions and assert the expected correct behavior. Run these tests on the UNFIXED code to observe failures and confirm root causes.

**Test Cases**:
1. **Idle-scheduler test**: Call `SmsPipeline._process()` with a mock bank SMS when no frame is scheduled — assert `onTransaction` callback is invoked (will fail on unfixed code: callback never fires)
2. **Duplicate subscription test**: Access `SmsService.instance.messages` twice — assert both accesses return the same `Stream` instance (will fail on unfixed code: two different stream objects)
3. **Sink null-out test**: Simulate `SmsForegroundService.onDestroy` while a mock main-activity sink is active — assert `SmsEventSink.sink` is not null after destroy (will fail on unfixed code: sink is nulled)
4. **Sink priority test**: Simulate headless engine `onListen` firing after `MainActivity` `onListen` — assert `SmsEventSink.sink` still points to the main-activity sink (will fail on unfixed code: headless sink overwrites)

**Expected Counterexamples**:
- `onTransaction` callback is never invoked when scheduler is idle
- `SmsService.messages` returns a new stream object on each access
- `SmsEventSink.sink` is null after `onDestroy` even when main-activity sink was active
- `SmsEventSink.sink` points to the headless engine sink after both engines register

### Fix Checking

**Goal**: Verify that for all inputs where the bug condition holds, the fixed pipeline and sink management produce the expected behavior.

**Pseudocode:**
```
FOR ALL X WHERE isBugCondition(X) DO
  result := processSms_fixed(X)
  ASSERT onTransactionCallbackInvoked(result)
    AND dashboardShowsNewTransaction(result)
    AND noManualRefreshRequired(result)
END FOR
```

### Preservation Checking

**Goal**: Verify that for all inputs where the bug condition does NOT hold, the fixed code produces the same result as the original code.

**Pseudocode:**
```
FOR ALL X WHERE NOT isBugCondition(X) DO
  ASSERT processSms_original(X) = processSms_fixed(X)
END FOR
```

**Testing Approach**: Property-based testing is recommended for preservation checking because:
- It generates many SMS inputs automatically to verify non-bank messages are still dropped
- It catches edge cases (empty body, unknown sender, OTP messages) that manual tests might miss
- It provides strong guarantees that background processing and pipeline deduplication are unchanged

**Test Plan**: Observe behavior on UNFIXED code first for non-bank SMS and background scenarios, then write property-based tests capturing that behavior.

**Test Cases**:
1. **Non-bank SMS preservation**: Verify non-bank SMS messages are dropped at the classifier stage — unchanged before and after fix
2. **Pipeline deduplication preservation**: Verify calling `SmsPipeline.start()` twice is still a no-op after fix
3. **`notifyListeners` preservation**: Verify `FinanceProvider.prependSmsTransaction` still calls `notifyListeners()` after fix
4. **Dashboard re-render preservation**: Verify `context.watch<FinanceProvider>()` still triggers rebuild when provider notifies

### Unit Tests

- Test `SmsPipeline._process()` invokes `onTransaction` immediately when scheduler is idle (Dart)
- Test `SmsService.messages` returns the same stream instance on repeated access (Dart)
- Test `SmsEventSink.sink` is not nulled by `SmsForegroundService.onDestroy` when main-activity sink is active (Kotlin)
- Test `SmsEventSink.sink` retains main-activity sink when headless engine registers after `MainActivity` (Kotlin)
- Test edge cases: null `onTransaction` callback, `SmsEventSink.sink` already null on destroy

### Property-Based Tests

- Generate random non-bank SMS bodies and verify they are always dropped by `SmsClassifier` (preservation)
- Generate random bank SMS bodies and verify `onTransaction` is always invoked after fix (fix checking)
- Generate random sequences of `onListen`/`onCancel`/`onDestroy` calls and verify `SmsEventSink.sink` always points to the correct engine (sink ownership invariant)

### Integration Tests

- Test full flow: bank SMS arrives → `SmsReceiver` → `SmsEventSink` → `EventChannel` → `SmsPipeline` → `FinanceProvider.prependSmsTransaction` → dashboard re-renders
- Test app-backgrounded flow: bank SMS arrives while app is backgrounded → headless engine processes and persists → data available on next foreground
- Test hot-reload scenario: hot-reload triggers `onDestroy` → main-activity sink survives → next bank SMS still updates the UI
