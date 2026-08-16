# Own Color Multiplayer Stability Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Preserve immediate Own Color taps while preventing routine GameKit delay from blocking Ready, displaying a centered syncing overlay, crashing the lobby, or ending a match before a 15-second recovery ceiling.

**Architecture:** Keep the four existing GameKit lanes and deterministic PHP v1 transcript. Make GameKit callbacks enter through a main-actor, active-match boundary; make network quality diagnostic rather than a start rejection; retain Ready intent until live-wire compatibility; and separate canonical recovery from input/presentation so sub-second gaps are invisible and longer gaps use a small HUD status.

**Tech Stack:** Swift 6, SwiftUI, GameKit `GKMatch`, OSLog, XCTest, Swift Testing, XcodeGen, shell release gates.

## Global Constraints

- Work only in `/Users/vlad/Documents/PimPoPom-admob`; never edit or deploy PHP.
- Keep marketing version `1.02`, use build `23`, and do not upload to TestFlight in this task.
- Keep immediate local prediction and the exact Multiplayer v1 PHP transcript/proof tuple.
- Packet recovery is invisible below `1_000 ms`, nonblocking through `15_000 ms`, and never uses the centered `SYNCING` stamp.
- Only actual disconnect/lifecycle pause, terminal completion, or local prediction ownership may block input.
- Missing unreliable packets recover through cumulative seals, reliable journals, and snapshots; contradictory evidence still cancels immediately.
- Live-wire compatibility must reject builds 21/22 before corrected gameplay begins.
- Commit only intentional iOS files and integrate through the remote iOS `main`; the separate dirty local main worktree is off-limits.

---

## File Structure

- `App/Services/MultiplayerGameKitTransport.swift`: callback isolation, match-attempt generation, live-wire version/capability, and transport policy events.
- `Packages/PimPoPomCore/Sources/PimPoPomCore/MultiplayerFastPolicy.swift`: fixed stability health windows and diagnostic-only quality validation.
- `App/Features/MultiplayerFastPresentation.swift`: pure Ready-intent and recovery-window state machines.
- `App/Features/MultiplayerPresentation.swift`: local Ready projection and typed nonblocking live status.
- `App/Features/MultiplayerController.swift`: queued Ready flushing, immediate handshake retrigger, frontier/watchdog/terminal timing, input-mode separation, and privacy-safe diagnostics.
- `App/Features/MultiplayerViews.swift`: compact HUD status with no centered recovery stamp.
- `Tests/Unit/MultiplayerGameKitTransportTests.swift`: callback executor/generation and measured-policy transport regressions.
- `Tests/Unit/MultiplayerPresentationTests.swift`: Ready projection and live-status/input behavior.
- `Tests/Unit/MultiplayerFastPresentationTests.swift`: 1-second/15-second watchdog and Ready-intent state machines.
- `Packages/PimPoPomCore/Tests/PimPoPomCoreTests/MultiplayerFastPolicyTests.swift`: fixed stability policy and tolerant measurements.
- `Tests/Unit/MultiplayerFastNetworkTests.swift`: deterministic 2/3/4-seat loss/reorder/retry recovery.
- `Config/Base.xcconfig`, `Scripts/check.sh`: build 23 and release-gate expectation.
- Current documentation: replace the superseded 40–100/120–250 ms claims with the implemented 1,000/15,000 ms contract and exact test/release state.

### Task 1: Isolate GameKit callbacks and invalidate stale matches

**Files:**
- Modify: `App/Services/MultiplayerGameKitTransport.swift:164-301`
- Test: `Tests/Unit/MultiplayerGameKitTransportTests.swift`

**Interfaces:**
- Produces: a per-match, nonisolated `GKMatchDelegate` relay that copies `Data`/player ID, hops to `MainActor`, and accepts events only for the current `GKMatch`/attempt generation.
- Consumes: existing `MultiplayerGameKitClientEvent` and `eventHandler`.

- [ ] **Step 1: Write the failing callback tests**

Add tests that invoke the production relay from `Task.detached`, fulfill only when `MainActor` receives the event, then adopt another match and prove queued old-generation and wrong-match events are dropped.

```swift
func testGameKitCallbackFromDetachedExecutorArrivesOnMainActor() async {
    let client = LiveMultiplayerGameKitClient()
    let delivered = expectation(description: "main actor delivery")
    client.eventHandler = { event in
        XCTAssertTrue(Thread.isMainThread)
        XCTAssertEqual(event, .rosterChanged)
        delivered.fulfill()
    }
    let relay = client.adoptTestMatchAndReturnRelay()
    await Task.detached {
        relay.match(match, didReceive: Data([1]), fromRemotePlayer: player)
    }.value
    await fulfillment(of: [delivered], timeout: 1)
}
```

The illustrative test helpers may differ, but the test must exercise the same relay used by every production `GKMatchDelegate` callback.

- [ ] **Step 2: Run the focused test and verify RED**

Run:

```sh
xcodebuild -quiet -project PimPoPom.xcodeproj -scheme PimPoPom \
  -destination 'platform=iOS Simulator,name=PimPoPom iPhone 17' \
  -only-testing:PimPoPomTests/MultiplayerGameKitTransportTests test
```

Expected: compile/test failure because the isolated callback boundary and generation are absent.

- [ ] **Step 3: Implement the minimal callback boundary**

Remove `GKMatchDelegate` conformance from the main-actor client. Give each adopted match an immutable, strongly retained `LiveMultiplayerGameKitDelegateRelay` with a `(generation, ObjectIdentifier(match))` context. The relay copies Sendable callback values and dispatches one ordered event batch to a main-actor sink. Accept that batch only when its complete context is still active. Invalidate the context before clearing the old delegate/relay/match, and reject stale `findMatch` completions.

```swift
func match(
    _ sourceMatch: GKMatch,
    didReceive data: Data,
    fromRemotePlayer player: GKPlayer
) {
    guard ObjectIdentifier(sourceMatch) == context.matchIdentity else { return }
    let playerID = player.gamePlayerID
    DispatchQueue.main.async {
        sink(context, [.received(data, fromGamePlayerID: playerID)])
    }
}
```

- [ ] **Step 4: Run the focused test and verify GREEN**

Run the Task 1 command and require exit `0` with no actor-isolation trap.

- [ ] **Step 5: Commit Task 1**

```sh
git add App/Services/MultiplayerGameKitTransport.swift Tests/Unit/MultiplayerGameKitTransportTests.swift
git commit -m "fix: isolate GameKit multiplayer callbacks"
```

### Task 2: Replace harsh network admission with stable health windows

**Files:**
- Modify: `Packages/PimPoPomCore/Sources/PimPoPomCore/MultiplayerFastPolicy.swift:286-415`
- Test: `Packages/PimPoPomCore/Tests/PimPoPomCoreTests/MultiplayerFastPolicyTests.swift:317-409`
- Test: `Tests/Unit/MultiplayerFastNetworkTests.swift:100-340`
- Test: `Tests/Unit/MultiplayerGameKitTransportTests.swift`

**Interfaces:**
- Produces: `MultiplayerFrozenNetworkPolicy(frontierStalenessMilliseconds: 1_000, evidenceRecoveryMilliseconds: 15_000)` for every structurally valid measurement set.
- Preserves: measured RTT, variation, loss, and reorder fields for diagnostics and consensus equality.

- [ ] **Step 1: Write failing policy tests**

Replace the old latency-clamp assertions with literal stability expectations and add the exact build-22 failure sample.

```swift
#expect(
    try MultiplayerFrozenNetworkPolicy.negotiate([
        .init(
            p95RoundTripMilliseconds: 50,
            p95JitterMilliseconds: 0,
            lossPercent: 34,
            reorderPercent: 25
        )
    ]) == .init(
        frontierStalenessMilliseconds: 1_000,
        evidenceRecoveryMilliseconds: 15_000
    )
)
```

Keep rejection tests for negative/structurally invalid values; remove the intentional rejection of ordinary high RTT/loss.

- [ ] **Step 2: Run core policy tests and verify RED**

```sh
swift test --package-path Packages/PimPoPomCore --filter MultiplayerFastPolicyTests
```

Expected: old `40...100`, `120...250`, and `loss <= 3` behavior fails the new literals.

- [ ] **Step 3: Implement fixed health windows**

Validate nonnegative measurements, then return the two approved constants. Do not sleep on the clean path and do not discard diagnostic fields.

- [ ] **Step 4: Update transport fixtures and the 2/3/4-seat matrix**

Use literal packet schedules containing an unreliable loss, duplicate, reorder, reliable retry, and reconnect checkpoint. Assert every seat reaches the same ordered evidence/resolution ledger and byte-identical transcript without an unsupported-network branch.

- [ ] **Step 5: Run focused core/native tests and verify GREEN**

```sh
swift test --package-path Packages/PimPoPomCore --filter MultiplayerFast
xcodebuild -quiet -project PimPoPom.xcodeproj -scheme PimPoPom \
  -destination 'platform=iOS Simulator,name=PimPoPom iPhone 17' \
  -only-testing:PimPoPomTests/MultiplayerFastNetworkTests \
  -only-testing:PimPoPomTests/MultiplayerGameKitTransportTests test
```

- [ ] **Step 6: Commit Task 2**

```sh
git add Packages/PimPoPomCore Tests/Unit/MultiplayerFastNetworkTests.swift Tests/Unit/MultiplayerGameKitTransportTests.swift
git commit -m "fix: tolerate ordinary multiplayer packet delay"
```

### Task 3: Make Ready immediate but compatibility-safe

**Files:**
- Modify: `App/Features/MultiplayerFastPresentation.swift`
- Modify: `App/Features/MultiplayerPresentation.swift:205-240`
- Modify: `App/Features/MultiplayerController.swift:115-180,518-557,782-1275,2790-2860`
- Modify: `App/Features/MultiplayerViews.swift:790-825`
- Test: `Tests/Unit/MultiplayerFastPresentationTests.swift`
- Test: `Tests/Unit/MultiplayerPresentationTests.swift:110-145`

**Interfaces:**
- Produces: `MultiplayerReadyIntent` with `request(_:)`, `displayedReady(serverReady:)`, `flushableIntent(isCompatible:)`, `acknowledge(_:)`, and `reset()`.
- Produces: `WaitingRoomState.displayedCurrentPlayerReady`.

- [ ] **Step 1: Write failing Ready-intent tests**

```swift
func testReadyIntentRespondsLocallyAndFlushesOnceAfterCompatibility() {
    var intent = MultiplayerReadyIntent()
    intent.request(true)
    XCTAssertTrue(intent.displayedReady(serverReady: false))
    XCTAssertNil(intent.flushableIntent(isCompatible: false))
    XCTAssertEqual(intent.flushableIntent(isCompatible: true), true)
    intent.acknowledge(true)
    XCTAssertNil(intent.flushableIntent(isCompatible: true))
}
```

Change the presentation test so `.matching` and `.confirmingRoster` allow Ready when a participant exists and no mutation is pending.

- [ ] **Step 2: Run presentation tests and verify RED**

```sh
xcodebuild -quiet -project PimPoPom.xcodeproj -scheme PimPoPom \
  -destination 'platform=iOS Simulator,name=PimPoPom iPhone 17' \
  -only-testing:PimPoPomTests/MultiplayerFastPresentationTests \
  -only-testing:PimPoPomTests/MultiplayerPresentationTests test
```

- [ ] **Step 3: Implement queued readiness**

Project pending local intent into the Ready button immediately. Flush `true` only after unanimous corrected live-wire compatibility; permit `false` to clear already-published backend readiness safely. Clear intent on failure, leave, and explicit GameKit retry. Keep Start gated on backend-ready participants and exact roster/clock compatibility.

- [ ] **Step 4: Trigger handshake progress immediately**

After `.networkMeasurement` or `.networkPolicyVote`, call `confirmRosterIfComplete()` before `refreshWaitingConnectionState()`. On compatibility becoming unanimous, flush the retained Ready intent idempotently. Bump `MultiplayerLiveWire.version` and add `stable-recovery-v1` to required capabilities.

- [ ] **Step 5: Run focused tests and verify GREEN**

Run the Task 3 test command and the transport compatibility tests.

- [ ] **Step 6: Commit Task 3**

```sh
git add App/Features/MultiplayerFastPresentation.swift App/Features/MultiplayerPresentation.swift App/Features/MultiplayerController.swift App/Features/MultiplayerViews.swift Tests/Unit
git commit -m "fix: make multiplayer Ready immediate"
```

### Task 4: Make catch-up nonblocking and use one 15-second ceiling

**Files:**
- Modify: `App/Features/MultiplayerFastPresentation.swift:203-253`
- Modify: `App/Features/MultiplayerPresentation.swift:290-335`
- Modify: `App/Features/MultiplayerController.swift:1395-1760,2100-2330,2650-2860`
- Modify: `App/Features/MultiplayerViews.swift:930-1080`
- Test: `Tests/Unit/MultiplayerFastPresentationTests.swift:285-320`
- Test: `Tests/Unit/MultiplayerPresentationTests.swift`

**Interfaces:**
- Produces: watchdog action API with independent `noticeAfterMilliseconds` and `cancelAfterMilliseconds`.
- Produces: `LiveNetworkStatus` values `.catchingUp`, `.reconnecting`, and `.finalizing` rendered in the HUD.
- Preserves: `.pending` for the one-input-per-activation latch and `.syncing` only for actual disconnect/lifecycle pause.
- Produces: per-activation local prediction ownership so a delayed disposition for activation N never blocks a newly presented activation N+1.

- [ ] **Step 1: Write failing recovery-boundary tests**

Assert no action at 999 ms, one snapshot request at 1,000 ms, no cancellation at 14,999 ms, cancellation at 15,000 ms, and no second snapshot request.

```swift
XCTAssertEqual(watchdog.action(now: 1_099, noticeAfter: 1_000, cancelAfter: 15_000), .none)
XCTAssertEqual(watchdog.action(now: 1_100, noticeAfter: 1_000, cancelAfter: 15_000), .requestSnapshot(inputID))
XCTAssertEqual(watchdog.action(now: 15_099, noticeAfter: 1_000, cancelAfter: 15_000), .none)
XCTAssertEqual(watchdog.action(now: 15_100, noticeAfter: 1_000, cancelAfter: 15_000), .cancelWithoutSettlement(inputID))
```

Add a presentation policy test proving `.catchingUp` leaves input `.interactive`, while `.reconnecting` selects `.syncing`.

Add a prediction test that begins input for activation 7, then accepts activation 8 before activation 7 resolves, while still rejecting a duplicate input for activation 8.

- [ ] **Step 2: Run focused presentation tests and verify RED**

Use the Task 3 presentation command.

- [ ] **Step 3: Implement watchdog/frontier timing**

Start repairs immediately. Keep recovery invisible before one second, set a typed HUD status after one second, and cancel only at the 15-second ceiling. Remove every assignment of recovery-only `SYNCING` from frontier and resolution paths. Keep contradiction cancellation unchanged.

- [ ] **Step 4: Separate input mode from canonical catch-up**

Compute input mode from lives, actual app/transport pause, terminal state, and ownership of the currently presented activation. Do not include frontier or resolution catch-up. Track unresolved predictions by activation/input identity so an older delayed disposition does not block a later activation. Continue the display link and preannounced activation rendering.

- [ ] **Step 5: Apply 15 seconds to terminal drain**

Use the same hard budget for coordinator and peer terminal evidence; peer completion must not receive a second accidental 15-second extension. Render `Finalizing` in the small status, not the centered announcement.

- [ ] **Step 6: Add the compact HUD status**

Overlay a small, noninteractive, accessible status on the center live HUD card. It must not change the 5-point HUD-to-board layout, cover the board, tilt, or use `GlowStampView`.

- [ ] **Step 7: Run focused tests and verify GREEN**

Run presentation, FAST network, and transport test classes on `PimPoPom iPhone 17`.

- [ ] **Step 8: Commit Task 4**

```sh
git add App/Features Tests/Unit
git commit -m "fix: keep Own Color playable while catching up"
```

### Task 5: Add TestFlight-safe diagnostics and current documentation

**Files:**
- Modify: `App/Features/MultiplayerController.swift`
- Modify: `Config/Base.xcconfig`
- Modify: `Scripts/check.sh`
- Modify: `README.md`
- Modify: `docs/CURRENT_VERSION.md`
- Modify: `docs/DECISIONS.md`
- Modify: `docs/TESTING.md`
- Modify: `docs/RELEASE.md`
- Replace/shorten: `docs/MULTIPLAYER_FAST_TASK.md`
- Modify: `docs/MULTIPLAYER_STABILITY_DESIGN.md`

**Interfaces:**
- Produces: privacy-safe OSLog reason codes and exact build-23 current slice.
- Preserves: no player, participant, match, transcript, proof, or token identifiers in logs.

- [ ] **Step 1: Add reason-coded logs**

Use static public reason names and numeric ages/counts only:

```swift
logger.notice("recovery_begin reason=frontier age_ms=\(age, privacy: .public)")
logger.notice("recovery_end reason=frontier")
logger.error("terminal_cancel reason=frontier age_ms=\(age, privacy: .public)")
```

- [ ] **Step 2: Bump build metadata to 23**

Change only `CURRENT_PROJECT_VERSION` in `Config/Base.xcconfig` and the matching Staging assertion in `Scripts/check.sh`.

- [ ] **Step 3: Make documentation current-only**

Mark the stability design implemented, replace D-13's superseded 40–100/120–250 ms decision, record build 22's crash/rollback limitation, and keep physical 2/3/4-device acceptance explicitly open. Do not claim TestFlight deployment.

- [ ] **Step 4: Run static checks**

```sh
xcrun swift-format lint --strict --recursive App Packages Tests
git diff --check
```

- [ ] **Step 5: Commit Task 5**

```sh
git add App/Features/MultiplayerController.swift Config/Base.xcconfig Scripts/check.sh README.md docs
git commit -m "release: prepare stable multiplayer build 23"
```

### Task 6: Full verification and integration

**Files:**
- Verify all intentional files from Tasks 1–5.
- Do not modify the dirty local main worktree at `/Users/vlad/Documents/SpeedyTapper/PimPoPom`.

**Interfaces:**
- Produces: exact clean build-23 source commit integrated into remote iOS `main`.

- [ ] **Step 1: Run the complete gate**

```sh
Scripts/check.sh
git diff --check
```

Require project generation, strict formatting, 69+ core tests, all native unit tests, the focused Multiplayer theme/back-button UI tests, generic builds, privacy, ads, assets, and build-23 assertions to pass.

- [ ] **Step 2: Review the exact diff and source state**

```sh
git status --short
git diff HEAD~5..HEAD --stat
git log --oneline --decorate --max-count=10
```

Confirm no key/profile/archive/DerivedData/TestFlight artifact is tracked.

- [ ] **Step 3: Integrate through reviewed remote main**

Re-fetch origin, prove `origin/main` is an ancestor, push the feature branch, open/review an iOS pull request, and merge it. If PR tooling is unavailable but direct fast-forward is permitted and ancestry is unchanged, push the exact reviewed commit to `origin/main`. Never update the dirty local main worktree by force, reset, stash, or checkout.

- [ ] **Step 4: Verify remote integration**

Fetch again and require `origin/main` to equal the verified build-23 commit. Report that the dirty local main worktree was preserved.

- [ ] **Step 5: Provide the deployment-person task without deploying**

The handoff must name the exact main SHA and instruct the deployment person to archive `PimPoPom Staging`, use the configured local App Store Connect API key without exposing it, wait for build 23 to become `VALID`, and assign only Internal QA. No archive, upload, group write, or TestFlight claim occurs in this implementation task.
