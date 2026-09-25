# Build 24 Fast Multiplayer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship an iOS build 24 candidate with immediate Ready presentation and non-fatal, fast own-color tap reconciliation.

**Architecture:** Preserve local prediction and the PHP v1 transcript while relaxing the GameKit live frontier. Project readiness locally and over a reliable presentation-only peer hint; delay seals by 150 ms and resolve late evidence without cancelling play.

**Tech Stack:** Swift 6, SwiftUI/UIKit, GameKit, Swift Testing/XCTest, Xcode 26.

**Spec:** `docs/superpowers/specs/2026-08-21-build24-fast-multiplayer-design.md`

## Global Constraints

- Modify only `/Users/vlad/Documents/PimPoPom-admob`; do not modify PHP.
- Keep `multiplayer-own-color-v1`, protocol 1, proof 1 unchanged.
- PHP remains Start and final-settlement authority.
- Local feedback never waits for reconciliation; canonical convergence may take two seconds.
- Prepare but do not upload the archive.

---

### Task 1: Immediate Ready projection

**Files:**
- Modify: `App/Features/MultiplayerPresentation.swift`
- Modify: `App/Features/MultiplayerViews.swift`
- Test: `Tests/Unit/MultiplayerPresentationTests.swift`

**Interfaces:**
- Produces: `WaitingRoomState.displayedReady(for:) -> Bool`

- [ ] Add a failing test asserting the current participant card uses `pendingReadyIntent` while peers use their presented state.
- [ ] Run `xcodebuild test -only-testing:PimPoPomTests/MultiplayerPresentationTests` and confirm the assertion fails.
- [ ] Add `displayedReady(for:)` and use it for the participant row label/color.
- [ ] Re-run the focused test and confirm it passes.

### Task 2: Reliable peer Ready hints

**Files:**
- Modify: `App/Services/MultiplayerGameKitTransport.swift`
- Modify: `App/Features/MultiplayerController.swift`
- Test: `Tests/Unit/MultiplayerGameKitTransportTests.swift`
- Test: `Tests/Unit/MultiplayerFastPresentationTests.swift`

**Interfaces:**
- Produces: `MultiplayerReadyHintPacket`, payload `.readyHint`, and `sendReadyHint(participantID:ready:)`.
- Produces: controller presentation overlay corrected by later PHP snapshots.

- [ ] Add failing packet round-trip, reliable-control-lane, and presentation-overlay tests.
- [ ] Run the focused transport/presentation tests and confirm they fail for the missing packet behavior.
- [ ] Add the versioned Ready packet, Codable payload case, validation, transport send method, and controller handling.
- [ ] Bump `MultiplayerLiveWire.version` and replace the required capability with `ready-hint-v1` plus `relaxed-frontier-v1`.
- [ ] Re-run focused tests and confirm they pass.

### Task 3: Relax the sealed frontier

**Files:**
- Modify: `App/Features/MultiplayerFastPresentation.swift`
- Modify: `App/Features/MultiplayerController.swift`
- Test: `Tests/Unit/MultiplayerFastNetworkTests.swift`
- Test: `Tests/Unit/MultiplayerFastPresentationTests.swift`

**Interfaces:**
- Produces: `MultiplayerLocalSealEmitter.captureGraceMilliseconds = 150`.
- Produces: recoverable late-input classification mapped to immutable `.ignored(.recovery)` resolution.

- [ ] Change the seal test to require logical time 250 to seal through 100 and run it to observe failure.
- [ ] Add a failing controller-policy test showing `inputAtOrBeforeEffectiveSeal` is recoverable while conflicting evidence remains fatal.
- [ ] Implement the 150 ms seal grace.
- [ ] Catch only the recoverable frontier boundary in coordinator admission and emit one ignored resolution; retain fatal handling for conflicting/malformed evidence.
- [ ] Re-run focused tests and confirm they pass.

### Task 4: Player-safe cancellation copy

**Files:**
- Modify: `App/Features/MultiplayerPresentation.swift`
- Modify: `App/Features/MultiplayerController.swift`
- Modify: `App/Features/MultiplayerViews.swift`
- Test: `Tests/Unit/MultiplayerPresentationTests.swift`

**Interfaces:**
- Produces: a local unranked terminal state distinct from PHP review.

- [ ] Add a failing test asserting local protocol cancellation never renders raw enum/module text or the server-review title.
- [ ] Implement stable localized cancellation copy while retaining diagnostic reason internally.
- [ ] Re-run the focused test and confirm it passes.

### Task 5: Build 24 release identity

**Files:**
- Modify: `Config/Base.xcconfig`
- Modify: `docs/CURRENT_VERSION.md`
- Modify: `docs/RELEASE.md`
- Modify: other current contract/testing docs only where Build 24 truth changes.

**Interfaces:**
- Produces: configured version `1.02 (24)` and TestFlight QA notes.

- [ ] Set `CURRENT_PROJECT_VERSION = 24` and record build 24 as an unuploaded candidate.
- [ ] Document the Ready/frontier changes and retain physical-device gates.
- [ ] Run repository documentation/configuration checks.

### Task 6: Verification and archive

**Files:**
- Output outside Git: ignored archive/export paths only.

- [ ] Run `swift test --package-path Packages/PimPoPomCore`.
- [ ] Run all `PimPoPomTests` on the configured simulator.
- [ ] Run `Scripts/check.sh` and `git diff --check`.
- [ ] Inspect the exact diff and commit intentional source/docs/tests.
- [ ] Archive the clean commit with `PimPoPom Staging` and `Config/ExportOptions-TestFlight.plist` without uploading.
- [ ] Verify archive Info.plist version/build/encryption, signature, entitlements, embedded provisioning, and absence of private keys/local fixtures.
