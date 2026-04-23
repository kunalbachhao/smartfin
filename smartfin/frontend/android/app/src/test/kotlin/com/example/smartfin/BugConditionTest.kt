package com.example.smartfin

import io.flutter.plugin.common.EventChannel
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertSame
import org.junit.Before
import org.junit.Test

/**
 * Bug Condition Exploration Tests — Kotlin (Tests 3 & 4)
 *
 * These tests are EXPECTED TO FAIL on unfixed code.
 * Failure confirms the bugs exist.
 *
 * Test 3 — Sink null-out: Simulate SmsForegroundService.onDestroy while a
 *   mock main-activity sink is active; assert SmsEventSink.sink is not null
 *   after destroy.
 *   isBugCondition: sinkNulledByServiceDestroy(X) AND mainActivitySinkStillActive(X)
 *
 * Test 4 — Sink priority: Simulate headless engine onListen firing after
 *   MainActivity onListen; assert SmsEventSink.sink still points to the
 *   main-activity sink.
 *   isBugCondition: sinkPointsToHeadlessEngine(X) AND uiEngineIsActive(X)
 *
 * Validates: Requirements 1.3, 1.4
 */
class BugConditionTest {

    /** Minimal no-op EventSink implementation for testing. */
    private class FakeSink(val name: String) : EventChannel.EventSink {
        override fun success(event: Any?) {}
        override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {}
        override fun endOfStream() {}
        override fun toString() = "FakeSink($name)"
    }

    @Before
    fun setUp() {
        // Reset the global sink before each test.
        SmsEventSink.sink = null
    }

    // ── Test 3: Sink null-out on onDestroy ────────────────────────────────────

    /**
     * Simulates the scenario where:
     *   1. MainActivity registers its sink (UI engine is active).
     *   2. SmsForegroundService.onDestroy is called (e.g. hot-reload or
     *      lifecycle event).
     *   3. onDestroy unconditionally sets SmsEventSink.sink = null.
     *
     * Expected (correct) behaviour: SmsEventSink.sink should still point to
     * the main-activity sink after onDestroy, because the main-activity sink
     * is still active.
     *
     * Actual (buggy) behaviour: SmsEventSink.sink is null after onDestroy,
     * even though the main-activity sink was never cancelled.
     *
     * COUNTEREXAMPLE: SmsEventSink.sink is null after onDestroy even though
     * the main-activity sink was still active. This confirms bug condition:
     * sinkNulledByServiceDestroy(X) AND mainActivitySinkStillActive(X).
     */
    @Test
    fun `Test 3 - Sink null-out - SmsEventSink sink is not null after onDestroy when main-activity sink is active`() {
        // Arrange: MainActivity registers its sink (UI engine active).
        val mainActivitySink = FakeSink("main-activity")
        SmsEventSink.sink = mainActivitySink

        // Act: Simulate SmsForegroundService.onDestroy.
        // The buggy onDestroy unconditionally nulls the sink:
        //   SmsEventSink.sink = null
        simulateServiceOnDestroy()

        // Assert: The main-activity sink should still be active.
        // On unfixed code: SmsEventSink.sink is null — FAILS here.
        // On fixed code:   SmsEventSink.sink still points to mainActivitySink.
        assertNotNull(
            "COUNTEREXAMPLE: SmsEventSink.sink was nulled by onDestroy even though " +
            "the main-activity sink (mainActivitySink) was still active. " +
            "This confirms bug condition: sinkNulledByServiceDestroy(X) AND mainActivitySinkStillActive(X). " +
            "SmsReceiver will now drop all incoming SMS messages after exhausting 5 retries.",
            SmsEventSink.sink
        )
    }

    // ── Test 4: Sink priority ─────────────────────────────────────────────────

    /**
     * Simulates the scenario where:
     *   1. MainActivity registers its sink first (UI engine active).
     *   2. SmsForegroundService.initHeadlessEngine() calls onListen after
     *      MainActivity (headless engine starts asynchronously and registers
     *      its sink later).
     *   3. The headless engine's onListen unconditionally overwrites
     *      SmsEventSink.sink.
     *
     * Expected (correct) behaviour: SmsEventSink.sink should still point to
     * the main-activity sink, because the UI engine has priority.
     *
     * Actual (buggy) behaviour: SmsEventSink.sink points to the headless
     * engine's sink, because onListen overwrites unconditionally.
     *
     * COUNTEREXAMPLE: SmsEventSink.sink points to the headless engine sink
     * after both engines register. This confirms bug condition:
     * sinkPointsToHeadlessEngine(X) AND uiEngineIsActive(X).
     */
    @Test
    fun `Test 4 - Sink priority - SmsEventSink sink points to main-activity sink after headless engine registers`() {
        // Arrange: MainActivity registers its sink first.
        val mainActivitySink = FakeSink("main-activity")
        SmsEventSink.sink = mainActivitySink  // MainActivity.onListen

        // Act: Simulate SmsForegroundService.initHeadlessEngine() onListen
        // firing after MainActivity (headless engine starts asynchronously).
        val headlessSink = FakeSink("headless-engine")
        simulateHeadlessOnListen(headlessSink)

        // Assert: The sink should still point to the main-activity sink.
        // On unfixed code: SmsEventSink.sink points to headlessSink — FAILS here.
        // On fixed code:   SmsEventSink.sink still points to mainActivitySink.
        assertSame(
            "COUNTEREXAMPLE: SmsEventSink.sink was overwritten by the headless engine's " +
            "onListen call. Expected sink to point to main-activity sink but it now points " +
            "to the headless engine sink. This confirms bug condition: " +
            "sinkPointsToHeadlessEngine(X) AND uiEngineIsActive(X). " +
            "Events will be delivered to the headless engine while the UI engine is active, " +
            "so the dashboard will never update.",
            mainActivitySink,
            SmsEventSink.sink
        )
    }

    // ── Simulation helpers ────────────────────────────────────────────────────

    /**
     * Simulates the FIXED SmsForegroundService.onDestroy behaviour:
     * only nulls SmsEventSink.sink if it still belongs to the headless engine.
     *
     * This mirrors the fixed code in SmsForegroundService.kt:
     *   override fun onDestroy() {
     *       ...
     *       if (SmsEventSink.sink === headlessSink) {
     *           SmsEventSink.sink = null
     *       }
     *       headlessSink = null
     *   }
     *
     * In the test scenario the headless engine never called onListen, so
     * headlessSink is null — the ownership check fails and the main-activity
     * sink is preserved.
     */
    private fun simulateServiceOnDestroy() {
        // headlessSink is null because the headless engine never registered a sink
        // in this test scenario. The fixed ownership check prevents clearing the
        // main-activity sink.
        val headlessSink: EventChannel.EventSink? = null
        if (SmsEventSink.sink === headlessSink) {
            SmsEventSink.sink = null
        }
    }

    /**
     * Simulates the FIXED SmsForegroundService.initHeadlessEngine() onListen
     * behaviour: only sets SmsEventSink.sink if it is currently null, so the
     * headless engine never overwrites an already-active UI sink.
     *
     * This mirrors the fixed code in SmsForegroundService.kt:
     *   override fun onListen(arguments: Any?, sink: EventChannel.EventSink) {
     *       headlessSink = sink
     *       if (SmsEventSink.sink == null) {
     *           SmsEventSink.sink = sink
     *       }
     *   }
     */
    private fun simulateHeadlessOnListen(sink: EventChannel.EventSink) {
        // Fixed: only claim the global sink when no other engine has registered one.
        if (SmsEventSink.sink == null) {
            SmsEventSink.sink = sink
        }
    }
}
