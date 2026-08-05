# FAST Multiplayer Build 21 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship iOS TestFlight build 1.02 (21) with one-frame local Multiplayer tap acknowledgement, lane-safe fast GameKit input, deterministic sealed-frontier reconciliation, and a corrected Pixel Multiplayer back button while preserving PHP proof v1.

**Architecture:** Keep speculative presentation separate from the canonical reducer. Negotiate an additive live-wire capability in the legacy-decodable hello, then use independent fast-input, evidence, canonical, and control packet sequences; stable input IDs, cumulative seals, and reliable resolutions let the coordinator publish only complete global frontiers without the fixed 250 ms sleep. Keep the single-target proof-v1 transcript, lexical backend-compatible coordinator, score, lives, streak, shared tone order, and settlement unchanged.

**Tech Stack:** Swift 6, SwiftUI, UIKit `CADisplayLink`, GameKit `GKMatch`, OSLog signposts, XCTest, Swift Testing, XcodeGen, iOS 17+, Xcode 26.6.

## Global Constraints

- Edit only `/Users/vlad/Documents/PimPoPom-admob`; never edit the PHP/web repository.
- Preserve `20260729-1` / `multiplayer-own-color-v1` / protocol 1 / proof 1 and its exact integer transcript tuples.
- Do not enable first-render scoring, concurrent per-seat targets, or a non-lexical coordinator until the PHP v2 contract is implemented and staged.
- A predicted tap may change only local presentation; canonical score, lives, streak, transcript, shared accepted-hit tone order, results, and settlement remain reducer-owned.
- A mixed or missing live-wire capability fails before Ready, roster confirmation, or start, and no new payload kind is sent before capability unanimity.
- Preserve the original `UITouch.timestamp`; do not route taps through PHP.
- Use one editing task in this linked worktree, write every behavioral test before production code, run `Scripts/check.sh` and `git diff --check`, and archive only an exact clean committed source.
- Simulator evidence is not physical-iPhone evidence; TestFlight build 21 must retain the real 2/3/4-device FAST acceptance matrix as open.

---

### Task 1: Live-Wire Contract and Capability Gate

**Files:**
- Modify: `App/Services/MultiplayerGameKitTransport.swift:297-568,627-735`
- Modify: `App/Features/MultiplayerController.swift:486-520,829-1085`
- Test: `Tests/Unit/MultiplayerGameKitTransportTests.swift`
- Create: `Tests/Unit/MultiplayerControllerPolicyTests.swift`

**Interfaces:**
- Produces: `MultiplayerLiveWire.version: Int`, `MultiplayerLiveWire.requiredCapabilities: Set<String>`, `MultiplayerLiveCompatibility`, optional hello fields `liveWireVersion` and `capabilities`, and `MultiplayerPeerConsistency.liveCompatibility(hellos:expectedPlayerIDs:)`.
- Consumes: existing hello transport, waiting-room connection state, and legacy PHP roster confirmation.

- [ ] **Step 1: Write legacy/new hello and compatibility tests**

```swift
func testLegacyHelloDecodesWithoutFastFieldsButIsIncompatible() throws {
    let data = #"{"participantId":"22222222-2222-4222-8222-222222222222","seat":0,"colorIndex":0,"gamePlayerId":"G:alpha"}"#.data(using: .utf8)!
    let hello = try JSONDecoder().decode(MultiplayerHelloPacket.self, from: data)
    XCTAssertNil(hello.liveWireVersion)
    XCTAssertNil(hello.capabilities)
    XCTAssertFalse(MultiplayerLiveWire.isCompatible(hello))
}

func testExactFastHelloIsCompatible() {
    XCTAssertTrue(MultiplayerLiveWire.isCompatible(.fastFixture(seat: 0)))
}
```

Add controller-policy cases proving a legacy/mismatched seat blocks Ready/start and exact capabilities for every expected GameKit player permit roster confirmation.

- [ ] **Step 2: Run the focused tests and verify RED**

Run:

```sh
xcodegen -s project.yml
xcodebuild -quiet -project PimPoPom.xcodeproj -scheme PimPoPom -destination 'platform=iOS Simulator,name=PimPoPom iPhone 17' -only-testing:PimPoPomTests/MultiplayerGameKitTransportTests -only-testing:PimPoPomTests/MultiplayerControllerPolicyTests test
```

Expected: compile failures because `MultiplayerLiveWire`, optional hello fields, and compatibility policy do not exist.

- [ ] **Step 3: Implement the additive hello and fail-before-start policy**

```swift
enum MultiplayerLiveWire {
    static let version = 2
    static let requiredCapabilities: Set<String> = [
        "fast-input-v1", "sealed-frontier-v1", "input-resolution-v1",
    ]

    static func isCompatible(_ hello: MultiplayerHelloPacket) -> Bool {
        hello.liveWireVersion == version
            && Set(hello.capabilities ?? []) == requiredCapabilities
    }
}
```

Encode those values on every new hello, keep both fields optional for old decoders, require exact unanimity before `confirmRosterIfComplete`, `toggleReady(true)`, `startMatch`, roster confirmation, or start-manifest send, and show `Update Required` on mismatch. Do not add or send a new payload kind in this task.

- [ ] **Step 4: Run focused tests and verify GREEN**

Run the command from Step 2. Expected: all selected tests pass.

- [ ] **Step 5: Commit the capability gate**

```sh
git add App/Services/MultiplayerGameKitTransport.swift App/Features/MultiplayerController.swift Tests/Unit/MultiplayerGameKitTransportTests.swift Tests/Unit/MultiplayerControllerPolicyTests.swift
git commit -m 'feat: gate FAST multiplayer live wire'
```

### Task 2: Stable Input Identity, Resolution Ledger, and Sealed Frontier

**Files:**
- Create: `Packages/PimPoPomCore/Sources/PimPoPomCore/MultiplayerFastPolicy.swift`
- Create: `Packages/PimPoPomCore/Tests/PimPoPomCoreTests/MultiplayerFastPolicyTests.swift`
- Modify: `App/Features/MultiplayerPeerConsistency.swift`
- Modify: `Tests/Unit/MultiplayerPeerConsistencyTests.swift`

**Interfaces:**
- Produces: `MultiplayerInputID`, `MultiplayerInputSeal`, `MultiplayerInputFrontier`, `MultiplayerFrozenNetworkPolicy`, `MultiplayerInputResolution`, and `MultiplayerInputLedger`.
- Consumes: seat count 2–4, input contact time, input sequence, canonical event sequence, and ignored coordinator outcomes.

- [ ] **Step 1: Write pure frontier and ledger tests**

```swift
@Test func earlierMissingInputBlocksLaterPublishUntilRecovered() throws {
    var frontier = try MultiplayerInputFrontier(seats: [0, 1])
    try frontier.recordInput(id: .init(seat: 0, inputSequence: 1), inputAt: 90)
    try frontier.recordSeal(.init(seat: 0, throughInputAt: 100, highestInputSequence: 1))
    try frontier.recordInput(id: .init(seat: 1, inputSequence: 2), inputAt: 95)
    try frontier.recordSeal(.init(seat: 1, throughInputAt: 100, highestInputSequence: 2))
    #expect(frontier.publishWatermark == nil)
    try frontier.recordInput(id: .init(seat: 1, inputSequence: 1), inputAt: 80)
    #expect(frontier.publishWatermark == 100)
}
```

Add tests for monotonic seals, no contact at/before an effective seal, same-time `(inputAt, seat, inputSequence)` ordering, no watermark rollback, 40–100 ms staleness clamping, 120–250 ms recovery clamping, InputID collision resistance, identical dedupe, conflicting evidence failure, evidence-before-resolution, resolution-before-evidence, ignored resolution cleanup, and exactly-once committed consumption.

- [ ] **Step 2: Run pure tests and verify RED**

Run:

```sh
swift test --package-path Packages/PimPoPomCore --filter MultiplayerFastPolicyTests
xcodegen -s project.yml
xcodebuild -quiet -project PimPoPom.xcodeproj -scheme PimPoPom -destination 'platform=iOS Simulator,name=PimPoPom iPhone 17' -only-testing:PimPoPomTests/MultiplayerPeerConsistencyTests test
```

Expected: missing-type compile failures for the FAST policy and ledger.

- [ ] **Step 3: Implement the pure deterministic state machines**

```swift
public struct MultiplayerInputID: Codable, Hashable, Sendable {
    public let seat: Int
    public let inputSequence: Int
}

public struct MultiplayerInputSeal: Codable, Equatable, Sendable {
    public let seat: Int
    public let throughInputAt: Int
    public let highestInputSequence: Int
}
```

`MultiplayerInputFrontier.recordInput` stores sequence/time per seat, `recordSeal` advances a seat only when all `1...highestInputSequence` inputs are present, and `publishWatermark` is the monotonic minimum effective seal over all seats. `MultiplayerInputLedger` stores complete evidence by InputID and exactly one resolution; identical duplicates dedupe, conflicting content throws, ignored pairs are removed immediately, and committed pairs are removed only when the named event is applied.

- [ ] **Step 4: Run both focused suites and verify GREEN**

Run the commands from Step 2. Expected: all focused tests pass.

- [ ] **Step 5: Commit deterministic FAST policy**

```sh
git add Packages/PimPoPomCore/Sources/PimPoPomCore/MultiplayerFastPolicy.swift Packages/PimPoPomCore/Tests/PimPoPomCoreTests/MultiplayerFastPolicyTests.swift App/Features/MultiplayerPeerConsistency.swift Tests/Unit/MultiplayerPeerConsistencyTests.swift
git commit -m 'feat: add sealed multiplayer input ledger'
```

### Task 3: Four GameKit Lanes, Evidence Journal, and Cumulative ACKs

**Files:**
- Modify: `App/Services/MultiplayerGameKitTransport.swift:140-250,327-568,683-1540`
- Test: `Tests/Unit/MultiplayerGameKitTransportTests.swift`

**Interfaces:**
- Consumes: `MultiplayerInputID`, `MultiplayerInputSeal`, `MultiplayerInputResolution`, and capability unanimity from Tasks 1–2.
- Produces: `MultiplayerTransportLane`, `MultiplayerGameKitSendMode`, envelope `lane`, `sendInput`, `sendInputSeal`, `sendInputResolution`, lane-keyed sequence/ACK state, and bounded reliable evidence replay after reconnect.

- [ ] **Step 1: Write transport ordering, loss, duplicate, and reconnect tests**

```swift
func testFastInputCannotSuppressEarlierReliableEvidence() async throws {
    let transport = try await makeCompatibleTransport()
    try transport.sendInput(.fixture(sequence: 1), logicalMatchMilliseconds: 90)
    XCTAssertEqual(client.sent.map(\.mode), [.unreliable, .reliable])
    XCTAssertEqual(decoded(client.sent[0]).lane, .fastInput)
    XCTAssertEqual(decoded(client.sent[1]).lane, .evidence)
    client.receive(client.sent[0].data, from: "G:beta")
    client.receive(client.sent[1].data, from: "G:beta")
    XCTAssertEqual(receivedInputIDs, [.init(seat: 1, inputSequence: 1)])
}
```

Add independent lane-sequence tests, reliable-before-fast, missing fast, duplicate, conflicting content delivery, cumulative lane ACK removal, bounded evidence journal, reconnect resend, canonical/control reliable mode, and a proof that no `inputSeal`/`inputResolution` packet is emitted before capability unanimity.

- [ ] **Step 2: Run transport tests and verify RED**

Run:

```sh
xcodegen -s project.yml
xcodebuild -quiet -project PimPoPom.xcodeproj -scheme PimPoPom -destination 'platform=iOS Simulator,name=PimPoPom iPhone 17' -only-testing:PimPoPomTests/MultiplayerGameKitTransportTests test
```

Expected: missing lane/send-mode/payload APIs and mode assertions fail.

- [ ] **Step 3: Implement lane-safe transport**

```swift
enum MultiplayerTransportLane: String, Codable, CaseIterable {
    case fastInput, evidence, canonical, control
}

enum MultiplayerGameKitSendMode: Equatable { case reliable, unreliable }
```

Map only `fastInput` to `GKMatch.SendDataMode.unreliable`. Give each lane its own outgoing counter and each `(sender,lane)` its own incoming high-water sequence. Broadcast input intent once on `fastInput` and once on `evidence`; send seals repeatedly on fast and checkpoint them reliably; keep resolutions/events on `canonical`; keep hello/clock/plans/snapshot/lifecycle on `control`. ACK reliable lanes cumulatively by `(lane, throughPacketSequence)`, retain at most `maximumEvents` local evidence records, and replay unacknowledged evidence to reconnected peers.

- [ ] **Step 4: Run transport tests and verify GREEN**

Run the command from Step 2. Expected: all transport tests pass.

- [ ] **Step 5: Commit four-lane transport**

```sh
git add App/Services/MultiplayerGameKitTransport.swift Tests/Unit/MultiplayerGameKitTransportTests.swift
git commit -m 'feat: add fast multiplayer transport lanes'
```

### Task 4: One-Frame Prediction and Frame-Driven Presentation

**Files:**
- Create: `App/Features/MultiplayerFastPresentation.swift`
- Create: `App/Features/MultiplayerFrameScheduler.swift`
- Create: `App/Services/MultiplayerLatencySignposts.swift`
- Create: `Tests/Unit/MultiplayerFastPresentationTests.swift`
- Modify: `App/Features/MultiplayerPresentation.swift`
- Modify: `App/Features/MultiplayerViews.swift:880-1360`
- Test: `Tests/Unit/MultiplayerPresentationTests.swift`

**Interfaces:**
- Consumes: `MultiplayerInputID`, active target ID/owner/cell, input resolution, canonical event sequence, and original touch timestamp.
- Produces: `MultiplayerLocalPrediction`, `MultiplayerFrameScheduling`, `MultiplayerDisplayLinkScheduler`, cell `isPendingLocalInput`, and release-disabled `MultiplayerLatencySignposts`.

- [ ] **Step 1: Write prediction and presentation tests**

```swift
func testBurstContactsSendOneInputForOneActivation() throws {
    var prediction = MultiplayerLocalPrediction()
    let first = try prediction.begin(
        inputID: .init(seat: 0, inputSequence: 1), activationID: 7,
        tappedCell: 4, ownedTargetCell: 4
    )
    XCTAssertTrue(first.accepted)
    XCTAssertFalse(try prediction.begin(
        inputID: .init(seat: 0, inputSequence: 2), activationID: 7,
        tappedCell: 4, ownedTargetCell: 4
    ).accepted)
}
```

Add correct-target consumed overlay, wrong-cell neutral pressure without hiding the target, committed-resolution hold until event application, ignored-resolution one-time restore, phase/snapshot clear, canonical score/lives/streak immutability, and unchanged-state publication suppression tests.

- [ ] **Step 2: Run presentation tests and verify RED**

Run:

```sh
xcodegen -s project.yml
xcodebuild -quiet -project PimPoPom.xcodeproj -scheme PimPoPom -destination 'platform=iOS Simulator,name=PimPoPom iPhone 17' -only-testing:PimPoPomTests/MultiplayerFastPresentationTests -only-testing:PimPoPomTests/MultiplayerPresentationTests test
```

Expected: missing prediction/scheduler/pending-cell APIs.

- [ ] **Step 3: Implement presentation-only prediction and display-link scheduler**

`MultiplayerLocalPrediction.begin` accepts only the first contact for an activation, records whether the owned target should be hidden, and records a neutral pressed cell otherwise. `MultiplayerDisplayLinkScheduler` invokes one MainActor callback per display refresh; it owns and invalidates one `CADisplayLink`. Add `isPendingLocalInput` rendering without reducer mutation and compare newly derived `LiveMatchState` with the published value before assignment. Wrap non-PII timing points in `#if DEBUG` OSLog signposts.

- [ ] **Step 4: Run presentation tests and verify GREEN**

Run the command from Step 2. Expected: all focused tests pass.

- [ ] **Step 5: Commit the immediate local presentation**

```sh
git add App/Features/MultiplayerFastPresentation.swift App/Features/MultiplayerFrameScheduler.swift App/Services/MultiplayerLatencySignposts.swift App/Features/MultiplayerPresentation.swift App/Features/MultiplayerViews.swift Tests/Unit/MultiplayerFastPresentationTests.swift Tests/Unit/MultiplayerPresentationTests.swift
git commit -m 'feat: acknowledge multiplayer taps in one frame'
```

### Task 5: Controller Integration and Deterministic Network Matrix

**Files:**
- Modify: `App/Features/MultiplayerController.swift`
- Modify: `App/Features/MultiplayerPeerConsistency.swift`
- Create: `Tests/Unit/MultiplayerFastNetworkTests.swift`
- Modify: `Tests/Unit/MultiplayerPresentationTests.swift`
- Modify: `Packages/PimPoPomCore/Tests/PimPoPomCoreTests/MultiplayerProtocolTests.swift`

**Interfaces:**
- Consumes: all Tasks 1–4 APIs and existing `MultiplayerCoordinatorEngine`/v1 reducer.
- Produces: frame-generated cumulative seals, event-first coordinator processing through `publishWatermark`, exactly one reliable resolution per input, resolution/evidence buffering, watchdog recovery, and a v1 transcript compatibility gate.

- [ ] **Step 1: Write controller/network matrix tests**

Create a deterministic virtual packet scheduler and cover 2, 3, and 4 seats under Clean LAN `(10,2,0,0)`, Normal `(60,15,1,1)`, Edge `(100,25,3,3)`, and Unsupported profiles. Assert fast-loss/reliable-recovery ordering, 2–5 contact burst dedupe, every InputID has one disposition, no orphan at terminal, byte-identical transcripts, no rollback, and unsupported quality cancels without settlement.

```swift
XCTAssertLessThanOrEqual(report.normalCanonicalP95Milliseconds, 150)
XCTAssertEqual(report.orphanedInputIDs, [])
XCTAssertEqual(Set(report.transcriptDigests).count, 1)
XCTAssertFalse(report.predictionMutatedCanonicalState)
```

Add a core regression that the event tuples produced through the sealed frontier round-trip and replay under the unchanged v1 manifest.

- [ ] **Step 2: Run controller/network tests and verify RED**

Run:

```sh
swift test --package-path Packages/PimPoPomCore --filter MultiplayerProtocolTests
xcodegen -s project.yml
xcodebuild -quiet -project PimPoPom.xcodeproj -scheme PimPoPom -destination 'platform=iOS Simulator,name=PimPoPom iPhone 17' -only-testing:PimPoPomTests/MultiplayerFastNetworkTests -only-testing:PimPoPomTests/MultiplayerPresentationTests test
```

Expected: the controller still uses the fixed 250 ms frame watermark and has no sealed-frontier/resolution integration.

- [ ] **Step 3: Integrate FAST input without changing proof v1**

On contact, latch prediction before sending, send the same `MultiplayerInputPacket` through fast/evidence lanes, record local evidence once, and never enqueue an identical copy twice. On each display frame, emit the local cumulative seal; every 100 ms add a reliable checkpoint. The coordinator records every seat's seal/input, immediately processes complete inputs sorted by `(inputAt, seat, inputSequence)`, advances only to `frontier.publishWatermark`, and emits one committed/ignored live-only resolution. Replace the 33 ms full-state loop with the display-link callback and unchanged-state suppression. On a gap/stale frontier request recovery/snapshot, keep input locked, pause interaction, and cancel without settlement after the frozen recovery budget.

- [ ] **Step 4: Run core, focused controller, and network tests and verify GREEN**

Run the commands from Step 2. Expected: all selected tests pass, normal p95 is at most 150 ms in the deterministic model, and proof-v1 replay remains byte-identical.

- [ ] **Step 5: Commit FAST controller integration**

```sh
git add App/Features/MultiplayerController.swift App/Features/MultiplayerPeerConsistency.swift Tests/Unit/MultiplayerFastNetworkTests.swift Tests/Unit/MultiplayerPresentationTests.swift Packages/PimPoPomCore/Tests/PimPoPomCoreTests/MultiplayerProtocolTests.swift
git commit -m 'feat: reconcile multiplayer through sealed frontiers'
```

### Task 6: Pixel Multiplayer Back Button Regression

**Files:**
- Modify: `App/Features/MultiplayerViews.swift:141-162`
- Modify: `Tests/UITests/PimPoPomUITests.swift:803-820`

**Interfaces:**
- Consumes: current theme palette and existing `multiplayer-back` accessibility identifier.
- Produces: a 44-point Pixel toolbar allocation that contains the square button's 4-point offset shadow; other theme geometry remains 40 points.

- [ ] **Step 1: Tighten the Pixel UI regression before changing the view**

```swift
XCTAssertGreaterThanOrEqual(back.frame.width, 44)
XCTAssertGreaterThanOrEqual(back.frame.height, 38)
XCTAssertGreaterThanOrEqual(back.frame.minX, app.windows.firstMatch.frame.minX + 4)
```

- [ ] **Step 2: Run the Pixel UI test and verify RED**

Run:

```sh
xcodegen -s project.yml
xcodebuild -quiet -project PimPoPom.xcodeproj -scheme PimPoPom -destination 'platform=iOS Simulator,name=PimPoPom iPhone 17' -only-testing:PimPoPomUITests/PimPoPomUITests/testPixelMultiplayerHubUsesThemedLoweredBackButtonAndLegibleSmallCopy test
```

Expected: the width assertion reports the current 40-point allocation.

- [ ] **Step 3: Allocate the Pixel shadow without changing other themes**

```swift
.frame(width: palette.isPixel ? 44 : 40)
```

Keep the 38-point hit label, five-point vertical offset, theme styling, label, and accessibility identifier unchanged.

- [ ] **Step 4: Re-run the Pixel UI test and inspect its screenshot**

Run the command from Step 2 with a result bundle, export the attached screenshot, and confirm the square Pixel border/shadow is not clipped or displaced. Expected: test passes; Classic/Disco/Light code path still allocates 40 points.

- [ ] **Step 5: Commit the Pixel fix**

```sh
git add App/Features/MultiplayerViews.swift Tests/UITests/PimPoPomUITests.swift
git commit -m 'fix: contain Pixel multiplayer back button'
```

### Task 7: Build 21 Gate, Review, Archive, and TestFlight

**Files:**
- Modify: `Config/Base.xcconfig`
- Modify: `Scripts/check.sh`
- Modify: `release/app-store/1.0/metadata/en-US.md`
- Modify: `docs/CURRENT_VERSION.md`
- Modify after processing: `docs/RELEASE.md`
- Modify after processing: `docs/TESTING.md`
- Modify after visual inspection: `docs/DESIGN_QA.md`

**Interfaces:**
- Consumes: exact reviewed FAST implementation and Pixel fix commits.
- Produces: clean source commit for `1.02 (21)`, validated Staging archive/export, processed TestFlight build record, retained app dSYM, and explicit physical-device gaps.

- [ ] **Step 1: Change candidate build number and current TestFlight notes**

Set `CURRENT_PROJECT_VERSION = 21`, update the matching `Scripts/check.sh` assertion, and write concise What to Test copy covering immediate Multiplayer input, reconciliation/reconnect, mixed-version refusal, terminal settlement, and Pixel back-button appearance.

- [ ] **Step 2: Run focused suites, full gate, and source checks**

Run:

```sh
swift test --package-path Packages/PimPoPomCore
Scripts/check.sh
git diff --check
git status --short
```

Expected: all tests/build/config/privacy/asset/format checks pass; status lists only intentional build-21 files.

- [ ] **Step 3: Request code review and resolve only verified findings**

Review the exact diff for capability safety, lane sequence isolation, proof-v1 invariants, prediction authority boundaries, resolution completeness, frontier monotonicity, PHP absence, and Pixel-only geometry. Re-run every affected focused suite after any accepted correction.

- [ ] **Step 4: Commit the exact archive source and verify clean reproducibility**

```sh
git add Config/Base.xcconfig Scripts/check.sh release/app-store/1.0/metadata/en-US.md docs/CURRENT_VERSION.md App Packages Tests docs/superpowers/plans/2026-08-05-fast-multiplayer.md
git commit -m 'release: prepare FAST multiplayer build 21'
Scripts/check.sh
git diff --check
test -z "$(git status --short)"
```

- [ ] **Step 5: Archive the Staging scheme and inspect the artifact**

Archive exact HEAD with `PimPoPom Staging`, inspect Info.plist, entitlements, signature, privacy report, UUIDs, app dSYM, asset catalog, and absence of `.p8`, `.storekit`, `Local.xcconfig`, credentials, and untracked content. Compute and retain the archive manifest SHA-256 and app dSYM UUID/hash.

- [ ] **Step 6: Upload with ignored App Store Connect credentials and wait for processing**

Export using `Config/ExportOptions-TestFlight.plist`, upload without printing credentials, poll App Store Connect until build 21 is `VALID` or a concrete processing failure appears, and confirm the existing Internal QA/External QA assignment behavior. Do not submit an App Store production version.

- [ ] **Step 7: Record exact release evidence and commit it**

Update `docs/RELEASE.md`, `docs/TESTING.md`, and `docs/DESIGN_QA.md` with source SHA, toolchain, bundle/team/version, App Store Connect ID/state, archive hash, dSYM UUID/hash/path, named iPhone 17 Simulator results, Pixel screenshot evidence, deterministic network matrix, and the still-open real 2/3/4-iPhone/60 Hz/ProMotion/TestFlight matrix. Commit only these records.
