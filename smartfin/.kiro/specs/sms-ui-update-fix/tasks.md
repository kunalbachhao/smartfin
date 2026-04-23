# Implementation Plan

- [x] 1. Write bug condition exploration tests
  - **Property 1: Bug Condition** - Bank SMS Triggers Immediate UI Update
  - **CRITICAL**: Write these tests BEFORE implementing any fix
  - **CRITICAL**: These tests MUST FAIL on unfixed code — failure confirms the bugs exist
  - **DO NOT attempt to fix the test or the code when it fails**
  - **GOAL**: Surface counterexamples that demonstrate each of the four root causes
  - **Scoped PBT Approach**: For deterministic bugs, scope each property to the concrete failing case(s) for reproducibility
  - Test 1 — Idle-scheduler: Call `SmsPipeline._process()` with a mock bank SMS when no frame is scheduled; assert `onTransaction` callback is invoked (isBugCondition: `schedulerIsIdle(X) AND addPostFrameCallbackUsed(X)`)
  - Test 2 — Duplicate subscription: Access `SmsService.instance.messages` twice; assert both accesses return the same `Stream` instance (isBugCondition: `duplicateStreamSubscriptionCreated(X)`)
  - Test 3 — Sink null-out: Simulate `SmsForegroundService.onDestroy` while a mock main-activity sink is active; assert `SmsEventSink.sink` is not null after destroy (isBugCondition: `sinkNulledByServiceDestroy(X) AND mainActivitySinkStillActive(X)`)
  - Test 4 — Sink priority: Simulate headless engine `onListen` firing after `MainActivity` `onListen`; assert `SmsEventSink.sink` still points to the main-activity sink (isBugCondition: `sinkPointsToHeadlessEngine(X) AND uiEngineIsActive(X)`)
  - Run all four tests on UNFIXED code
  - **EXPECTED OUTCOME**: All four tests FAIL (this is correct — it proves the bugs exist)
  - Document counterexamples found (e.g. "onTransaction never fires when scheduler is idle", "messages getter returns a new Stream object on each call", "SmsEventSink.sink is null after onDestroy even though MainActivity sink was active", "SmsEventSink.sink points to headless engine after both engines register")
  - Mark task complete when tests are written, run, and failures are documented
  - _Requirements: 1.1, 1.2, 1.3, 1.4_

- [x] 2. Write preservation property tests (BEFORE implementing fix)
  - **Property 2: Preservation** - Non-Buggy Inputs Produce Identical Behavior
  - **IMPORTANT**: Follow observation-first methodology — run UNFIXED code with non-buggy inputs first, observe outputs, then encode as property-based tests
  - Observe: non-bank SMS (e.g. OTP, promotional) is dropped by `SmsClassifier` without storing or notifying the UI on unfixed code
  - Observe: calling `SmsPipeline.start()` a second time is a no-op (`_running` guard) on unfixed code
  - Observe: `FinanceProvider.prependSmsTransaction()` prepends the transaction and calls `notifyListeners()` on unfixed code
  - Observe: `context.watch<FinanceProvider>()` triggers a dashboard rebuild when the provider notifies on unfixed code
  - Observe: `SmsReceiver` retries up to 5 times with a 1-second delay when sink is null on unfixed code
  - Write property-based test: for all non-bank SMS bodies, `SmsClassifier.isBankSms` returns false and no transaction is stored (from Preservation Requirements in design)
  - Write property-based test: for all sequences of `SmsPipeline.start()` calls after the first, `_running` remains true and no new subscription is created
  - Write property-based test: for all valid `SmsTransaction` inputs, `prependSmsTransaction` always prepends and always calls `notifyListeners()`
  - Verify all preservation tests PASS on UNFIXED code
  - **EXPECTED OUTCOME**: Tests PASS (this confirms baseline behavior to preserve)
  - Mark task complete when tests are written, run, and passing on unfixed code
  - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 3.6_

- [x] 3. Fix sms_pipeline.dart — idle-scheduler callback loss

  - [x] 3.1 Replace `addPostFrameCallback` with a direct call or `scheduleMicrotask`
    - In `SmsPipeline._process()`, remove `SchedulerBinding.instance.addPostFrameCallback((_) => callback(tx))`
    - Replace with `callback(tx)` directly (execution is already on the main isolate after the `await`), or `scheduleMicrotask(() => callback(tx))` if a frame-boundary guarantee is preferred
    - Remove the `import 'package:flutter/scheduler.dart'` import if `SchedulerBinding` is no longer referenced anywhere in the file
    - _Bug_Condition: `schedulerIsIdle(X) AND addPostFrameCallbackUsed(X)` — callback queued but never executed when no frame is pending_
    - _Expected_Behavior: `onTransaction` callback is invoked immediately on the main isolate within the same event-loop turn (or at most one microtask later) regardless of frame scheduling state_
    - _Preservation: `SmsPipeline.start()` called more than once remains a no-op; non-bank SMS still dropped before reaching this code path_
    - _Requirements: 2.1, 3.1, 3.3_

  - [x] 3.2 Verify bug condition exploration test now passes (idle-scheduler sub-case)
    - **Property 1: Expected Behavior** - Idle-Scheduler Callback Fires
    - **IMPORTANT**: Re-run the SAME test from task 1 (Test 1) — do NOT write a new test
    - The test from task 1 encodes the expected behavior: `onTransaction` is invoked when scheduler is idle
    - Run the idle-scheduler exploration test from step 1 on the fixed code
    - **EXPECTED OUTCOME**: Test PASSES (confirms idle-scheduler bug is fixed)
    - _Requirements: 2.1_

  - [x] 3.3 Verify preservation tests still pass
    - **Property 2: Preservation** - Non-Buggy Inputs Unchanged After sms_pipeline.dart Fix
    - **IMPORTANT**: Re-run the SAME tests from task 2 — do NOT write new tests
    - Run all preservation property tests from step 2 on the fixed code
    - **EXPECTED OUTCOME**: All tests PASS (confirms no regressions from this change)
    - Confirm non-bank SMS still dropped, pipeline deduplication guard still works

- [x] 4. Fix sms_service.dart — duplicate stream subscriptions

  - [x] 4.1 Cache the broadcast stream in a private field
    - In `SmsService`, add a private field: `Stream<SmsMessage>? _messages;`
    - Change the `messages` getter to return `_messages ??= _channel.receiveBroadcastStream().where(...).map(...).handleError(...)` so `receiveBroadcastStream()` is called at most once per app lifecycle
    - _Bug_Condition: `duplicateStreamSubscriptionCreated(X)` — `receiveBroadcastStream()` called on every getter access, creating independent native subscriptions_
    - _Expected_Behavior: `SmsService.instance.messages` returns the same cached `Stream<SmsMessage>` instance on every access; only one native subscription is ever active_
    - _Preservation: `SmsPipeline.start()` still subscribes to the same stream; `_running` guard still prevents duplicate pipeline subscriptions_
    - _Requirements: 2.2, 3.3_

  - [x] 4.2 Verify bug condition exploration test now passes (duplicate-subscription sub-case)
    - **Property 1: Expected Behavior** - Messages Getter Returns Cached Stream
    - **IMPORTANT**: Re-run the SAME test from task 1 (Test 2) — do NOT write a new test
    - Run the duplicate-subscription exploration test from step 1 on the fixed code
    - **EXPECTED OUTCOME**: Test PASSES (both accesses return the same `Stream` instance)
    - _Requirements: 2.2_

  - [x] 4.3 Verify preservation tests still pass
    - **Property 2: Preservation** - Non-Buggy Inputs Unchanged After sms_service.dart Fix
    - **IMPORTANT**: Re-run the SAME tests from task 2 — do NOT write new tests
    - Run all preservation property tests from step 2 on the fixed code
    - **EXPECTED OUTCOME**: All tests PASS (confirms no regressions from this change)

- [x] 5. Fix SmsForegroundService.kt — unconditional sink null-out and sink ownership race

  - [x] 5.1 Track the headless sink locally and apply conditional sink assignment
    - In `initHeadlessEngine`, declare a local variable `var headlessSink: EventChannel.EventSink? = null` in the enclosing scope (or as a property of the service)
    - In `onListen`: assign `headlessSink = sink`, then only set `SmsEventSink.sink = sink` if `SmsEventSink.sink == null` (headless engine never overwrites an already-active UI sink)
    - In `onCancel`: only null `SmsEventSink.sink` if `SmsEventSink.sink === headlessSink` (do not clear a sink that belongs to another engine)
    - In `onDestroy`: only null `SmsEventSink.sink` if `SmsEventSink.sink === headlessSink` (same ownership check as `onCancel`)
    - _Bug_Condition: `sinkNulledByServiceDestroy(X) AND mainActivitySinkStillActive(X)` — `onDestroy` unconditionally sets `SmsEventSink.sink = null`, dropping the active UI sink; `sinkPointsToHeadlessEngine(X) AND uiEngineIsActive(X)` — headless `onListen` overwrites the UI engine's sink_
    - _Expected_Behavior: `SmsEventSink.sink` always points to the main-activity engine's sink while the UI is active; headless engine only claims the sink when no other engine has registered_
    - _Preservation: `SmsReceiver` retry logic (5 retries, 1-second delay) unchanged; headless engine still processes and persists transactions when app is killed_
    - _Requirements: 2.3, 2.4, 3.2, 3.6_

  - [x] 5.2 Verify bug condition exploration tests now pass (sink sub-cases)
    - **Property 1: Expected Behavior** - Sink Ownership Correctly Maintained
    - **IMPORTANT**: Re-run the SAME tests from task 1 (Tests 3 and 4) — do NOT write new tests
    - Run the sink null-out exploration test (Test 3) on the fixed code
    - Run the sink priority exploration test (Test 4) on the fixed code
    - **EXPECTED OUTCOME**: Both tests PASS (sink is not nulled by onDestroy when main-activity sink is active; main-activity sink retains priority after headless engine registers)
    - _Requirements: 2.3, 2.4_

  - [x] 5.3 Verify preservation tests still pass
    - **Property 2: Preservation** - Non-Buggy Inputs Unchanged After SmsForegroundService.kt Fix
    - **IMPORTANT**: Re-run the SAME tests from task 2 — do NOT write new tests
    - Run all preservation property tests from step 2 on the fixed code
    - **EXPECTED OUTCOME**: All tests PASS (confirms no regressions — background processing and retry logic intact)

- [x] 6. Fix MainActivity.kt — confirm UI engine sink priority

  - [x] 6.1 Confirm or document that `onListen` unconditionally overwrites `SmsEventSink.sink`
    - Review `MainActivity.configureFlutterEngine` — `onListen` already sets `SmsEventSink.sink = sink` unconditionally, giving the UI engine priority
    - If the unconditional assignment is already present, add a comment clarifying the priority contract: `// UI engine always takes priority — unconditionally overwrite any previously registered headless sink`
    - If the unconditional assignment is missing, add `SmsEventSink.sink = sink` in `onListen`
    - No functional change is expected here; this task is a confirmation + documentation step
    - _Bug_Condition: `sinkPointsToHeadlessEngine(X) AND uiEngineIsActive(X)` — MainActivity's `onListen` must always win to ensure events reach the visible UI_
    - _Expected_Behavior: `SmsEventSink.sink` is set to the main-activity engine's sink whenever `MainActivity.onListen` fires, regardless of what was previously registered_
    - _Preservation: `onCancel` in `MainActivity` intentionally does not null the sink (headless engine will re-register); this behavior must remain unchanged_
    - _Requirements: 2.4, 3.2_

  - [x] 6.2 Verify bug condition exploration test still passes (sink priority sub-case)
    - **Property 1: Expected Behavior** - MainActivity Sink Always Takes Priority
    - **IMPORTANT**: Re-run the SAME test from task 1 (Test 4) — do NOT write a new test
    - Run the sink priority exploration test from step 1 on the fully fixed code
    - **EXPECTED OUTCOME**: Test PASSES (main-activity sink retains priority)
    - _Requirements: 2.4_

  - [x] 6.3 Verify preservation tests still pass
    - **Property 2: Preservation** - Non-Buggy Inputs Unchanged After MainActivity.kt Fix
    - **IMPORTANT**: Re-run the SAME tests from task 2 — do NOT write new tests
    - Run all preservation property tests from step 2 on the fixed code
    - **EXPECTED OUTCOME**: All tests PASS (confirms no regressions)

- [x] 7. Checkpoint — Ensure all tests pass
  - Re-run the full test suite (all exploration tests from task 1 + all preservation tests from task 2)
  - All four bug condition exploration tests must PASS (confirming all four root causes are fixed)
  - All preservation property tests must PASS (confirming no regressions)
  - Ensure all tests pass; ask the user if any questions arise
  - _Requirements: 2.1, 2.2, 2.3, 2.4, 3.1, 3.2, 3.3, 3.4, 3.5, 3.6_
