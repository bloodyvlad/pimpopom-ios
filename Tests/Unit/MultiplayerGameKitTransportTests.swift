import Foundation
import GameKit
import PimPoPomCore
import XCTest

@testable import PimPoPom

@MainActor
final class MultiplayerGameKitTransportTests: XCTestCase {
    func testLegacyHelloDecodesButCannotEnableFastPackets() throws {
        let data = Data(
            #"{"participantId":"22222222-2222-4222-8222-222222222222","seat":0,"colorIndex":0,"gamePlayerId":"G:alpha"}"#
                .utf8
        )
        let hello = try JSONDecoder().decode(MultiplayerHelloPacket.self, from: data)

        XCTAssertNil(hello.liveWireVersion)
        XCTAssertNil(hello.capabilities)
        XCTAssertFalse(MultiplayerLiveWire.isCompatible(hello))
    }

    func testExactFastHelloRequiresTheFrozenCapabilitySet() {
        let exact = MultiplayerHelloPacket(
            participantId: Self.localParticipantID,
            seat: 0,
            colorIndex: 0,
            gamePlayerId: "G:alpha",
            liveWireVersion: MultiplayerLiveWire.version,
            capabilities: MultiplayerLiveWire.requiredCapabilities.sorted()
        )
        let missing = MultiplayerHelloPacket(
            participantId: Self.localParticipantID,
            seat: 0,
            colorIndex: 0,
            gamePlayerId: "G:alpha",
            liveWireVersion: MultiplayerLiveWire.version,
            capabilities: ["fast-input-v1"]
        )

        XCTAssertTrue(MultiplayerLiveWire.isCompatible(exact))
        XCTAssertFalse(MultiplayerLiveWire.isCompatible(missing))
    }

    func testGameplayPacketsStayBlockedUntilEverySeatSendsExactHello() async throws {
        let client = MultiplayerGameKitClientFake(
            localGamePlayerID: "G:alpha",
            remotePlayers: [
                MultiplayerGameKitPlayer(gamePlayerID: "G:beta", displayName: "Beta")
            ]
        )
        let transport = MultiplayerGameKitTransport(client: client)
        try await transport.connect(
            matchID: Self.matchID,
            playerGroup: 8,
            participantCount: 2
        )
        try transport.sendHello(
            participantID: Self.localParticipantID,
            seat: 0,
            colorIndex: 0
        )

        XCTAssertEqual(transport.liveCompatibility, .collecting)
        XCTAssertThrowsError(
            try transport.sendInput(
                MultiplayerInputPacket(
                    inputSequence: 1,
                    seat: 0,
                    cell: 4,
                    coordinatorInputMilliseconds: 90
                ),
                logicalMatchMilliseconds: 90
            )
        )

        let remoteHello = MultiplayerPacketEnvelope(
            version: 1,
            matchId: Self.matchID,
            packetSequence: 1,
            eventSequence: 0,
            logicalMatchMilliseconds: 0,
            payload: .hello(
                MultiplayerHelloPacket(
                    participantId: Self.remoteParticipantID,
                    seat: 1,
                    colorIndex: 1,
                    gamePlayerId: "G:beta",
                    liveWireVersion: MultiplayerLiveWire.version,
                    capabilities: MultiplayerLiveWire.requiredCapabilities.sorted()
                )
            )
        )
        client.receive(try JSONEncoder().encode(remoteHello), from: "G:beta")

        XCTAssertEqual(transport.liveCompatibility, .unanimous)
        XCTAssertNoThrow(
            try transport.sendInput(
                MultiplayerInputPacket(
                    inputSequence: 1,
                    seat: 0,
                    cell: 4,
                    coordinatorInputMilliseconds: 90
                ),
                logicalMatchMilliseconds: 90
            )
        )
        XCTAssertEqual(Array(client.sent.suffix(2).map(\.mode)), [.unreliable, .reliable])
        let inputEnvelopes = try client.sent.suffix(2).map {
            try JSONDecoder().decode(MultiplayerPacketEnvelope.self, from: $0.data)
        }
        XCTAssertEqual(inputEnvelopes.map(\.lane), [.fastInput, .evidence])
        XCTAssertEqual(inputEnvelopes.map(\.packetSequence), [1, 1])
    }

    func testReorderedFastLanePacketsAreDeliveredOnceWithoutSuppressingControl() async throws {
        let client = MultiplayerGameKitClientFake(
            localGamePlayerID: "G:alpha",
            remotePlayers: [
                MultiplayerGameKitPlayer(gamePlayerID: "G:beta", displayName: "Beta")
            ]
        )
        let transport = MultiplayerGameKitTransport(client: client)
        var receivedSequences: [Int] = []
        transport.eventHandler = { event in
            guard case .packet(let packet) = event,
                case .input(let input) = packet.envelope.payload
            else { return }
            receivedSequences.append(input.inputSequence)
        }
        try await transport.connect(
            matchID: Self.matchID,
            playerGroup: 7,
            participantCount: 2
        )
        try transport.sendHello(
            participantID: Self.localParticipantID,
            seat: 0,
            colorIndex: 0
        )
        let hello = MultiplayerHelloPacket(
            participantId: Self.remoteParticipantID,
            seat: 1,
            colorIndex: 1,
            gamePlayerId: "G:beta",
            liveWireVersion: MultiplayerLiveWire.version,
            capabilities: MultiplayerLiveWire.requiredCapabilities.sorted()
        )
        client.receive(
            try encodedEnvelope(sequence: 1, lane: .control, payload: .hello(hello)),
            from: "G:beta"
        )
        let second = MultiplayerInputPacket(
            inputSequence: 2,
            seat: 1,
            cell: 8,
            coordinatorInputMilliseconds: 91
        )
        let first = MultiplayerInputPacket(
            inputSequence: 1,
            seat: 1,
            cell: 7,
            coordinatorInputMilliseconds: 90
        )

        client.receive(
            try encodedEnvelope(sequence: 2, lane: .fastInput, payload: .input(second)),
            from: "G:beta"
        )
        client.receive(
            try encodedEnvelope(sequence: 1, lane: .fastInput, payload: .input(first)),
            from: "G:beta"
        )
        client.receive(
            try encodedEnvelope(sequence: 1, lane: .fastInput, payload: .input(first)),
            from: "G:beta"
        )

        XCTAssertEqual(receivedSequences, [2, 1])
    }

    func testFastLaneRejectsPacketsOlderThanItsBoundedReorderWindow() async throws {
        let client = MultiplayerGameKitClientFake(
            localGamePlayerID: "G:alpha",
            remotePlayers: [
                MultiplayerGameKitPlayer(gamePlayerID: "G:beta", displayName: "Beta")
            ]
        )
        let transport = MultiplayerGameKitTransport(client: client)
        var receivedSequences: [Int] = []
        transport.eventHandler = { event in
            guard case .packet(let packet) = event,
                case .input(let input) = packet.envelope.payload
            else { return }
            receivedSequences.append(input.inputSequence)
        }
        try await makeCompatible(transport, client: client, localSeat: 0)

        client.receive(
            try encodedEnvelope(
                sequence: 130,
                lane: .fastInput,
                payload: .input(
                    MultiplayerInputPacket(
                        inputSequence: 130,
                        seat: 1,
                        cell: 8,
                        coordinatorInputMilliseconds: 130
                    )
                )
            ),
            from: "G:beta"
        )
        client.receive(
            try encodedEnvelope(
                sequence: 1,
                lane: .fastInput,
                payload: .input(
                    MultiplayerInputPacket(
                        inputSequence: 1,
                        seat: 1,
                        cell: 7,
                        coordinatorInputMilliseconds: 1
                    )
                )
            ),
            from: "G:beta"
        )

        XCTAssertEqual(receivedSequences, [130])
    }

    func testICloudUnavailableFailurePreservesGameKitCodeAndBlocksRetry() {
        let error = NSError(
            domain: GKErrorDomain,
            code: MultiplayerGameKitFailure.iCloudUnavailableCode,
            userInfo: [NSLocalizedDescriptionKey: "Not signed in to iCloud."]
        )
        let failure = MultiplayerGameKitFailure(error: error)
        var gate = MultiplayerMatchmakingAttemptGate()

        XCTAssertEqual(failure.domain, GKErrorDomain)
        XCTAssertEqual(failure.code, MultiplayerGameKitFailure.iCloudUnavailableCode)
        XCTAssertEqual(failure.kind, .iCloudUnavailable)
        XCTAssertTrue(gate.allowsAttempt)

        XCTAssertTrue(gate.beginAttempt())
        XCTAssertFalse(gate.allowsAttempt)
        XCTAssertFalse(gate.beginAttempt())

        gate.block(with: failure)
        XCTAssertFalse(gate.allowsAttempt)
        XCTAssertEqual(gate.failure, failure)

        gate.clear()
        XCTAssertTrue(gate.allowsAttempt)
        XCTAssertFalse(gate.hasStartedAttempt)
    }

    func testRosterUsesExactPlayerGroupAndElectsLexicographicallySmallestPlayer() async throws {
        let client = MultiplayerGameKitClientFake(
            localGamePlayerID: "G:beta",
            remotePlayers: [
                MultiplayerGameKitPlayer(gamePlayerID: "G:alpha", displayName: "Alpha")
            ]
        )
        var events: [MultiplayerGameKitTransportEvent] = []
        let transport = MultiplayerGameKitTransport(client: client)
        transport.eventHandler = { events.append($0) }

        try await transport.connect(
            matchID: Self.matchID,
            playerGroup: 123_456_789,
            participantCount: 2
        )

        XCTAssertEqual(
            client.configuration,
            try MultiplayerMatchmakingConfiguration(
                playerGroup: 123_456_789,
                participantCount: 2
            )
        )
        XCTAssertEqual(transport.state, .connected)
        XCTAssertEqual(transport.roster?.coordinatorGamePlayerID, "G:alpha")
        XCTAssertFalse(transport.isCoordinator)
        XCTAssertTrue(
            events.contains { event in
                if case .rosterReady = event { return true }
                return false
            })

        try transport.sendHello(
            participantID: Self.localParticipantID,
            seat: 1,
            colorIndex: 1
        )
        let sent = try XCTUnwrap(client.sent.last)
        XCTAssertNil(sent.recipients)
        let envelope = try JSONDecoder().decode(
            MultiplayerPacketEnvelope.self,
            from: sent.data
        )
        XCTAssertEqual(envelope.version, 1)
        XCTAssertEqual(envelope.matchId, Self.matchID)
        XCTAssertEqual(envelope.packetSequence, 1)
        guard case .hello(let hello) = envelope.payload else {
            return XCTFail("Expected hello packet.")
        }
        XCTAssertEqual(hello.gamePlayerId, "G:beta")
        XCTAssertEqual(hello.participantId, Self.localParticipantID)
        XCTAssertEqual(hello.seat, 1)
    }

    func testCoordinatorEventsRequireContiguousSequencesAndAcknowledgements() async throws {
        let client = MultiplayerGameKitClientFake(
            localGamePlayerID: "G:alpha",
            remotePlayers: [
                MultiplayerGameKitPlayer(gamePlayerID: "G:beta", displayName: "Beta")
            ]
        )
        let transport = MultiplayerGameKitTransport(client: client)
        try await transport.connect(
            matchID: Self.matchID,
            playerGroup: 9,
            participantCount: 2
        )
        XCTAssertTrue(transport.isCoordinator)

        try transport.broadcastEvents(
            [[0, 1, 250, 0, 1, 0, 0]],
            logicalMatchMilliseconds: 250
        )
        XCTAssertEqual(transport.highestAppliedEventSequence, 1)
        XCTAssertEqual(transport.unacknowledgedPacketSequences, [1])
        let eventEnvelope = try JSONDecoder().decode(
            MultiplayerPacketEnvelope.self,
            from: try XCTUnwrap(client.sent.last).data
        )
        XCTAssertEqual(eventEnvelope.lane, .canonical)
        XCTAssertEqual(client.sent.last?.mode, .reliable)

        XCTAssertThrowsError(
            try transport.broadcastEvents(
                [[0, 3, 500, 1, 2, 1, 1]],
                logicalMatchMilliseconds: 500
            )
        )

        let acknowledgement = MultiplayerPacketEnvelope(
            version: 1,
            matchId: Self.matchID,
            packetSequence: 1,
            eventSequence: 1,
            logicalMatchMilliseconds: 260,
            payload: .acknowledgement(
                MultiplayerAcknowledgementPacket(
                    acknowledgedPacketSequence: 1,
                    acknowledgedLane: .canonical,
                    appliedEventSequence: 1
                )
            )
        )
        client.receive(
            try JSONEncoder().encode(acknowledgement),
            from: "G:beta"
        )
        XCTAssertTrue(transport.unacknowledgedPacketSequences.isEmpty)

        // A duplicate packet sequence is ignored.
        client.receive(
            try JSONEncoder().encode(acknowledgement),
            from: "G:beta"
        )
        XCTAssertTrue(transport.unacknowledgedPacketSequences.isEmpty)
    }

    func testClockPingPongMapsLocalTouchTimeToCoordinatorTimeline() async throws {
        let clock = MultiplayerTestClock(value: 100)
        let client = MultiplayerGameKitClientFake(
            localGamePlayerID: "G:beta",
            remotePlayers: [
                MultiplayerGameKitPlayer(gamePlayerID: "G:alpha", displayName: "Alpha")
            ]
        )
        let transport = MultiplayerGameKitTransport(
            client: client,
            monotonicMilliseconds: { clock.value }
        )
        try await makeCompatible(transport, client: client, localSeat: 1)

        for index in 0..<4 {
            let sentAt = 100 + index * 100
            clock.value = sentAt
            try transport.sendClockPing(localMonotonicMilliseconds: sentAt)
            let pingSend = try XCTUnwrap(client.sent.last)
            XCTAssertEqual(pingSend.recipients, ["G:alpha"])
            let pingEnvelope = try JSONDecoder().decode(
                MultiplayerPacketEnvelope.self,
                from: pingSend.data
            )
            guard case .clockPing(let ping) = pingEnvelope.payload else {
                return XCTFail("Expected clock ping.")
            }
            clock.value = sentAt + 50
            let pongEnvelope = MultiplayerPacketEnvelope(
                version: 1,
                matchId: Self.matchID,
                packetSequence: index + 2,
                eventSequence: 0,
                logicalMatchMilliseconds: 0,
                payload: .clockPong(
                    MultiplayerClockPongPacket(
                        nonce: ping.nonce,
                        requesterSendMonotonicMilliseconds: sentAt,
                        coordinatorReceiveMonotonicMilliseconds: sentAt + 70,
                        coordinatorSendMonotonicMilliseconds: sentAt + 75
                    )
                )
            )
            client.receive(try JSONEncoder().encode(pongEnvelope), from: "G:alpha")
        }

        XCTAssertEqual(transport.clockEstimator.roundTripMilliseconds, 45)
        XCTAssertEqual(
            transport.clockEstimator.coordinatorOffsetMilliseconds,
            47.5,
            accuracy: 0.001
        )
        let measurement = try XCTUnwrap(
            transport.clockEstimator.networkMeasurement(seat: 1)
        )
        let proposal = MultiplayerNetworkPolicyProposal(
            measurements: [measurement],
            policy: MultiplayerFrozenNetworkPolicy(
                frontierStalenessMilliseconds: 40,
                evidenceRecoveryMilliseconds: 120
            )
        )
        client.receive(
            try encodedEnvelope(
                sequence: 6,
                lane: .control,
                payload: .networkPolicyVote(
                    MultiplayerNetworkPolicyVote(seat: 0, proposal: proposal)
                )
            ),
            from: "G:alpha"
        )
        XCTAssertEqual(transport.frozenNetworkPolicy, proposal.policy)

        let manifest = Self.manifest
        let startEnvelope = MultiplayerPacketEnvelope(
            version: 1,
            matchId: Self.matchID,
            packetSequence: 7,
            eventSequence: 0,
            logicalMatchMilliseconds: 0,
            payload: .startManifest(
                MultiplayerStartSignalPacket(
                    manifest: manifest,
                    coordinatorStartMonotonicMilliseconds: 1_000,
                    presentationLeadMilliseconds:
                        MultiplayerGameKitTransport.defaultPresentationLeadMilliseconds
                )
            )
        )
        client.receive(try JSONEncoder().encode(startEnvelope), from: "G:alpha")

        let localPresentation = try transport.localMonotonicMilliseconds(
            forCoordinatorLogicalMilliseconds: 250
        )
        XCTAssertEqual(localPresentation, 1_203)
        XCTAssertEqual(
            try transport.coordinatorLogicalMilliseconds(
                forLocalMonotonicMilliseconds: localPresentation
            ),
            251
        )
    }

    func testClockEstimatorUsesFourSamplesAndP95RoundTripVariationForNetworkPolicy() {
        var estimator = MultiplayerClockEstimator()
        for (index, roundTrip) in [10, 20, 40].enumerated() {
            let t1 = index * 100
            estimator.register(
                requesterSendMilliseconds: t1,
                coordinatorReceiveMilliseconds: t1 + roundTrip / 2,
                coordinatorSendMilliseconds: t1 + roundTrip / 2,
                requesterReceiveMilliseconds: t1 + roundTrip
            )
        }
        XCTAssertFalse(estimator.hasNetworkMeasurement)
        estimator.register(
            requesterSendMilliseconds: 300,
            coordinatorReceiveMilliseconds: 312,
            coordinatorSendMilliseconds: 312,
            requesterReceiveMilliseconds: 325
        )
        XCTAssertTrue(estimator.hasNetworkMeasurement)

        XCTAssertEqual(
            estimator.networkMeasurement(seat: 1),
            MultiplayerSeatNetworkMeasurement(
                seat: 1,
                attemptedSampleCount: 4,
                completedSampleCount: 4,
                reorderedSampleCount: 0,
                p95RoundTripMilliseconds: 40,
                p95RoundTripVariationMilliseconds: 20
            )
        )
    }

    func testOutstandingClockPingsStayBoundedWhileResponsesAreLost() async throws {
        let client = MultiplayerGameKitClientFake(
            localGamePlayerID: "G:beta",
            remotePlayers: [
                MultiplayerGameKitPlayer(gamePlayerID: "G:alpha", displayName: "Alpha")
            ]
        )
        let transport = MultiplayerGameKitTransport(client: client)
        try await makeCompatible(transport, client: client, localSeat: 1)

        for milliseconds in 0..<32 {
            try transport.sendClockPing(localMonotonicMilliseconds: milliseconds)
        }

        XCTAssertLessThanOrEqual(
            transport.outstandingClockPingCount,
            MultiplayerGameKitTransport.maximumOutstandingClockPings
        )
    }

    func testClockMeasurementCountsLossAndReorderAndFreezesAfterFourthPong() async throws {
        let clock = MultiplayerTestClock(value: 100)
        let client = MultiplayerGameKitClientFake(
            localGamePlayerID: "G:beta",
            remotePlayers: [
                MultiplayerGameKitPlayer(gamePlayerID: "G:alpha", displayName: "Alpha")
            ]
        )
        let transport = MultiplayerGameKitTransport(
            client: client,
            monotonicMilliseconds: { clock.value }
        )
        try await makeCompatible(transport, client: client, localSeat: 1)

        var pings: [MultiplayerClockPingPacket] = []
        for index in 0..<6 {
            let sentAt = 100 + index * 100
            clock.value = sentAt
            try transport.sendClockPing(localMonotonicMilliseconds: sentAt)
            let envelope = try JSONDecoder().decode(
                MultiplayerPacketEnvelope.self,
                from: try XCTUnwrap(client.sent.last?.data)
            )
            guard case .clockPing(let ping) = envelope.payload else {
                return XCTFail("Expected clock ping.")
            }
            pings.append(ping)
        }

        let offsets = [10, 20, 30, 40, -100, 50]
        func deliverPong(pingIndex: Int, packetSequence: Int) throws {
            let ping = pings[pingIndex]
            clock.value = ping.requesterSendMonotonicMilliseconds + 50
            let coordinatorTime =
                ping.requesterSendMonotonicMilliseconds + offsets[pingIndex] + 25
            client.receive(
                try encodedEnvelope(
                    sequence: packetSequence,
                    lane: .control,
                    payload: .clockPong(
                        MultiplayerClockPongPacket(
                            nonce: ping.nonce,
                            requesterSendMonotonicMilliseconds:
                                ping.requesterSendMonotonicMilliseconds,
                            coordinatorReceiveMonotonicMilliseconds: coordinatorTime,
                            coordinatorSendMonotonicMilliseconds: coordinatorTime
                        )
                    )
                ),
                from: "G:alpha"
            )
        }

        for (deliveryIndex, pingIndex) in [0, 2, 1, 3].enumerated() {
            try deliverPong(pingIndex: pingIndex, packetSequence: deliveryIndex + 2)
        }

        let frozenEstimator = transport.clockEstimator
        XCTAssertEqual(
            frozenEstimator.networkMeasurement(seat: 1),
            MultiplayerSeatNetworkMeasurement(
                seat: 1,
                attemptedSampleCount: 6,
                completedSampleCount: 4,
                reorderedSampleCount: 1,
                p95RoundTripMilliseconds: 50,
                p95RoundTripVariationMilliseconds: 0
            )
        )
        XCTAssertEqual(transport.outstandingClockPingCount, 0)

        try deliverPong(pingIndex: 4, packetSequence: 6)

        XCTAssertEqual(transport.clockEstimator, frozenEstimator)
        XCTAssertEqual(transport.outstandingClockPingCount, 0)
    }

    func testReconnectRequestsSnapshotFromCoordinator() async throws {
        let client = MultiplayerGameKitClientFake(
            localGamePlayerID: "G:beta",
            remotePlayers: [
                MultiplayerGameKitPlayer(gamePlayerID: "G:alpha", displayName: "Alpha")
            ]
        )
        let transport = MultiplayerGameKitTransport(client: client)
        try await transport.connect(
            matchID: Self.matchID,
            playerGroup: 11,
            participantCount: 2
        )

        client.changeConnection("G:alpha", status: .disconnected)
        XCTAssertEqual(
            transport.state,
            .recovering(disconnectedGamePlayerIDs: ["G:alpha"])
        )
        client.changeConnection("G:alpha", status: .connected)

        XCTAssertEqual(transport.state, .connected)
        let snapshotRequestSend = try XCTUnwrap(client.sent.last)
        XCTAssertEqual(snapshotRequestSend.recipients, ["G:alpha"])
        let envelope = try JSONDecoder().decode(
            MultiplayerPacketEnvelope.self,
            from: snapshotRequestSend.data
        )
        guard case .snapshotRequest(let request) = envelope.payload else {
            return XCTFail("Expected snapshot request after coordinator reconnect.")
        }
        XCTAssertEqual(request.afterEventSequence, 0)
    }

    func testEveryInputIsBroadcastSoAllPeersCanVerifyItsSeatEvidence() async throws {
        let client = MultiplayerGameKitClientFake(
            localGamePlayerID: "G:beta",
            remotePlayers: [
                MultiplayerGameKitPlayer(gamePlayerID: "G:alpha", displayName: "Alpha")
            ]
        )
        let transport = MultiplayerGameKitTransport(client: client)
        try await transport.connect(
            matchID: Self.matchID,
            playerGroup: 12,
            participantCount: 2
        )
        try transport.sendHello(
            participantID: Self.localParticipantID,
            seat: 1,
            colorIndex: 1
        )
        let remoteHello = MultiplayerPacketEnvelope(
            version: 1,
            matchId: Self.matchID,
            packetSequence: 1,
            eventSequence: 0,
            logicalMatchMilliseconds: 0,
            payload: .hello(
                MultiplayerHelloPacket(
                    participantId: Self.remoteParticipantID,
                    seat: 0,
                    colorIndex: 0,
                    gamePlayerId: "G:alpha",
                    liveWireVersion: MultiplayerLiveWire.version,
                    capabilities: MultiplayerLiveWire.requiredCapabilities.sorted()
                )
            )
        )
        client.receive(try JSONEncoder().encode(remoteHello), from: "G:alpha")

        try transport.sendInput(
            MultiplayerInputPacket(
                inputSequence: 1,
                seat: 1,
                cell: 7,
                coordinatorInputMilliseconds: 420
            ),
            logicalMatchMilliseconds: 420
        )

        let fast = try XCTUnwrap(client.sent.dropLast().last)
        let sent = try XCTUnwrap(client.sent.last)
        XCTAssertEqual(fast.mode, .unreliable)
        XCTAssertEqual(sent.mode, .reliable)
        XCTAssertNil(sent.recipients)
        let envelope = try JSONDecoder().decode(
            MultiplayerPacketEnvelope.self,
            from: sent.data
        )
        guard case .input(let input) = envelope.payload else {
            return XCTFail("Expected peer input evidence.")
        }
        XCTAssertEqual(input.seat, 1)
        XCTAssertEqual(input.cell, 7)
        XCTAssertEqual(input.coordinatorInputMilliseconds, 420)
        XCTAssertEqual(envelope.lane, .evidence)
    }

    func testReliableEvidenceStillSendsWhenBestEffortFastLaneThrows() async throws {
        let client = MultiplayerGameKitClientFake(
            localGamePlayerID: "G:alpha",
            remotePlayers: [
                MultiplayerGameKitPlayer(gamePlayerID: "G:beta", displayName: "Beta")
            ]
        )
        let transport = MultiplayerGameKitTransport(client: client)
        try await makeCompatible(transport, client: client, localSeat: 0)
        client.failNextSendModes = [.unreliable]
        let sentBefore = client.sent.count

        XCTAssertNoThrow(
            try transport.sendInput(
                MultiplayerInputPacket(
                    inputSequence: 1,
                    seat: 0,
                    cell: 4,
                    coordinatorInputMilliseconds: 90
                ),
                logicalMatchMilliseconds: 90
            )
        )

        let sends = Array(client.sent.dropFirst(sentBefore))
        XCTAssertEqual(sends.map(\.mode), [.reliable])
        let envelope = try JSONDecoder().decode(
            MultiplayerPacketEnvelope.self,
            from: try XCTUnwrap(sends.first).data
        )
        XCTAssertEqual(envelope.lane, .evidence)
    }

    func testSealsUseFastAndReliableCheckpointLanesAndResolutionIsCanonical() async throws {
        let client = MultiplayerGameKitClientFake(
            localGamePlayerID: "G:alpha",
            remotePlayers: [
                MultiplayerGameKitPlayer(gamePlayerID: "G:beta", displayName: "Beta")
            ]
        )
        let transport = MultiplayerGameKitTransport(client: client)
        try await makeCompatible(transport, client: client, localSeat: 0)
        let sentBefore = client.sent.count
        let seal = MultiplayerInputSeal(
            seat: 0,
            throughInputAt: 99,
            highestInputSequence: 1
        )

        try transport.sendInputSeal(
            seal,
            logicalMatchMilliseconds: 100,
            includesReliableCheckpoint: true
        )
        try transport.sendInputResolution(
            MultiplayerInputResolution(
                inputID: MultiplayerInputID(seat: 0, inputSequence: 1),
                disposition: .ignored(.staleTarget)
            ),
            logicalMatchMilliseconds: 100
        )

        let sends = Array(client.sent.dropFirst(sentBefore))
        XCTAssertEqual(sends.map(\.mode), [.unreliable, .reliable, .reliable])
        let envelopes = try sends.map {
            try JSONDecoder().decode(MultiplayerPacketEnvelope.self, from: $0.data)
        }
        XCTAssertEqual(envelopes.map(\.lane), [.fastInput, .evidence, .canonical])
        XCTAssertEqual(envelopes.map(\.packetSequence), [1, 1, 1])
        guard case .inputSeal(let decodedSeal) = envelopes[1].payload else {
            return XCTFail("Expected reliable input-seal checkpoint.")
        }
        XCTAssertEqual(decodedSeal, seal)
        guard case .inputResolution(let decodedResolution) = envelopes[2].payload else {
            return XCTFail("Expected canonical input resolution.")
        }
        XCTAssertEqual(
            decodedResolution.inputID,
            MultiplayerInputID(seat: 0, inputSequence: 1)
        )
    }

    func testTerminalSealAndCoordinatorCancellationUseReliableLiveOnlyLanes() async throws {
        let peerClient = MultiplayerGameKitClientFake(
            localGamePlayerID: "G:beta",
            remotePlayers: [
                MultiplayerGameKitPlayer(gamePlayerID: "G:alpha", displayName: "Alpha")
            ]
        )
        let peerTransport = MultiplayerGameKitTransport(client: peerClient)
        try await makeCompatible(peerTransport, client: peerClient, localSeat: 1)
        peerClient.receive(
            try JSONEncoder().encode(
                MultiplayerPacketEnvelope(
                    version: 1,
                    matchId: Self.matchID,
                    packetSequence: 1,
                    eventSequence: 1,
                    logicalMatchMilliseconds: 100,
                    lane: .canonical,
                    payload: .events(MultiplayerEventBatchPacket(events: [[0, 1]]))
                )
            ),
            from: "G:alpha"
        )
        let peerSentBefore = peerClient.sent.count
        let seal = MultiplayerInputSeal(
            seat: 1,
            throughInputAt: 100,
            highestInputSequence: 1
        )

        try peerTransport.sendTerminalInputSeal(
            seal,
            logicalMatchMilliseconds: 100
        )

        let terminalSealSend = try XCTUnwrap(peerClient.sent.dropFirst(peerSentBefore).first)
        XCTAssertEqual(terminalSealSend.mode, .reliable)
        XCTAssertEqual(terminalSealSend.recipients, ["G:alpha"])
        let terminalSealEnvelope = try JSONDecoder().decode(
            MultiplayerPacketEnvelope.self,
            from: terminalSealSend.data
        )
        XCTAssertEqual(terminalSealEnvelope.lane, .evidence)
        guard case .terminalInputSeal(let terminalSeal) = terminalSealEnvelope.payload else {
            return XCTFail("Expected a terminal input seal.")
        }
        XCTAssertEqual(terminalSeal.version, 1)
        XCTAssertEqual(terminalSeal.finishEventSequence, 1)
        XCTAssertEqual(terminalSeal.seal, seal)

        let coordinatorClient = MultiplayerGameKitClientFake(
            localGamePlayerID: "G:alpha",
            remotePlayers: [
                MultiplayerGameKitPlayer(gamePlayerID: "G:beta", displayName: "Beta")
            ]
        )
        let coordinatorTransport = MultiplayerGameKitTransport(client: coordinatorClient)
        try await makeCompatible(coordinatorTransport, client: coordinatorClient, localSeat: 0)
        let coordinatorSentBefore = coordinatorClient.sent.count
        try coordinatorTransport.sendTerminalCancel(
            reason: .terminalDrainExceeded,
            throughEventSequence: 0,
            logicalMatchMilliseconds: 100
        )

        let cancelSend = try XCTUnwrap(
            coordinatorClient.sent.dropFirst(coordinatorSentBefore).first
        )
        XCTAssertEqual(cancelSend.mode, .reliable)
        let cancelEnvelope = try JSONDecoder().decode(
            MultiplayerPacketEnvelope.self,
            from: cancelSend.data
        )
        XCTAssertEqual(cancelEnvelope.lane, .control)
        guard case .terminalCancel(let cancellation) = cancelEnvelope.payload else {
            return XCTFail("Expected a terminal cancellation.")
        }
        XCTAssertEqual(cancellation.reason, .terminalDrainExceeded)
        XCTAssertEqual(cancellation.throughEventSequence, 0)
    }

    func testFastPayloadsAndResolutionsStayBlockedBeforeCapabilityUnanimity() async throws {
        let client = MultiplayerGameKitClientFake(
            localGamePlayerID: "G:alpha",
            remotePlayers: [
                MultiplayerGameKitPlayer(gamePlayerID: "G:beta", displayName: "Beta")
            ]
        )
        let transport = MultiplayerGameKitTransport(client: client)
        try await transport.connect(
            matchID: Self.matchID,
            playerGroup: 14,
            participantCount: 2
        )

        XCTAssertThrowsError(
            try transport.sendInputSeal(
                MultiplayerInputSeal(
                    seat: 0,
                    throughInputAt: 10,
                    highestInputSequence: 0
                ),
                logicalMatchMilliseconds: 11,
                includesReliableCheckpoint: true
            )
        )
        XCTAssertThrowsError(
            try transport.sendInputResolution(
                MultiplayerInputResolution(
                    inputID: MultiplayerInputID(seat: 0, inputSequence: 1),
                    disposition: .ignored(.prePresentation)
                ),
                logicalMatchMilliseconds: 11
            )
        )
        XCTAssertTrue(client.sent.isEmpty)
    }

    func testCumulativeEvidenceAcknowledgementClearsTheBoundedJournal() async throws {
        let client = MultiplayerGameKitClientFake(
            localGamePlayerID: "G:alpha",
            remotePlayers: [
                MultiplayerGameKitPlayer(gamePlayerID: "G:beta", displayName: "Beta")
            ]
        )
        let transport = MultiplayerGameKitTransport(client: client)
        try await makeCompatible(transport, client: client, localSeat: 0)
        for sequence in 1...2 {
            try transport.sendInput(
                MultiplayerInputPacket(
                    inputSequence: sequence,
                    seat: 0,
                    cell: sequence,
                    coordinatorInputMilliseconds: 90 + sequence
                ),
                logicalMatchMilliseconds: 90 + sequence
            )
        }
        XCTAssertEqual(
            transport.unacknowledgedEvidenceInputIDs,
            [
                MultiplayerInputID(seat: 0, inputSequence: 1),
                MultiplayerInputID(seat: 0, inputSequence: 2),
            ]
        )

        let acknowledgement = MultiplayerPacketEnvelope(
            version: 1,
            matchId: Self.matchID,
            packetSequence: 2,
            eventSequence: 0,
            logicalMatchMilliseconds: 100,
            payload: .acknowledgement(
                MultiplayerAcknowledgementPacket(
                    acknowledgedPacketSequence: 2,
                    acknowledgedLane: .evidence,
                    appliedEventSequence: 0
                )
            )
        )
        client.receive(try JSONEncoder().encode(acknowledgement), from: "G:beta")

        XCTAssertTrue(transport.unacknowledgedEvidenceInputIDs.isEmpty)
    }

    func testReconnectReplaysOnlyUnacknowledgedReliableEvidence() async throws {
        let client = MultiplayerGameKitClientFake(
            localGamePlayerID: "G:alpha",
            remotePlayers: [
                MultiplayerGameKitPlayer(gamePlayerID: "G:beta", displayName: "Beta")
            ]
        )
        let transport = MultiplayerGameKitTransport(client: client)
        try await makeCompatible(transport, client: client, localSeat: 0)
        try transport.sendInput(
            MultiplayerInputPacket(
                inputSequence: 1,
                seat: 0,
                cell: 4,
                coordinatorInputMilliseconds: 90
            ),
            logicalMatchMilliseconds: 90
        )
        let sentBeforeReconnect = client.sent.count

        client.changeConnection("G:beta", status: .disconnected)
        client.changeConnection("G:beta", status: .connected)

        let replay = try XCTUnwrap(client.sent.dropFirst(sentBeforeReconnect).last)
        XCTAssertEqual(replay.recipients, ["G:beta"])
        XCTAssertEqual(replay.mode, .reliable)
        let envelope = try JSONDecoder().decode(
            MultiplayerPacketEnvelope.self,
            from: replay.data
        )
        XCTAssertEqual(envelope.lane, .evidence)
        guard case .input(let input) = envelope.payload else {
            return XCTFail("Expected reliable evidence replay.")
        }
        XCTAssertEqual(input.inputSequence, 1)
    }

    func testReconnectReplaysLatestSealAfterEvidenceAndUnacknowledgedResolution() async throws {
        let client = MultiplayerGameKitClientFake(
            localGamePlayerID: "G:alpha",
            remotePlayers: [
                MultiplayerGameKitPlayer(gamePlayerID: "G:beta", displayName: "Beta")
            ]
        )
        let transport = MultiplayerGameKitTransport(client: client)
        try await makeCompatible(transport, client: client, localSeat: 0)
        try transport.sendInput(
            MultiplayerInputPacket(
                inputSequence: 1,
                seat: 0,
                cell: 4,
                coordinatorInputMilliseconds: 90
            ),
            logicalMatchMilliseconds: 90
        )
        try transport.sendInputSeal(
            MultiplayerInputSeal(
                seat: 0,
                throughInputAt: 99,
                highestInputSequence: 1
            ),
            logicalMatchMilliseconds: 100,
            includesReliableCheckpoint: true
        )
        try transport.sendInputResolution(
            MultiplayerInputResolution(
                inputID: MultiplayerInputID(seat: 0, inputSequence: 1),
                disposition: .ignored(.staleTarget)
            ),
            logicalMatchMilliseconds: 100
        )
        let sentBeforeReconnect = client.sent.count

        client.changeConnection("G:beta", status: .disconnected)
        client.changeConnection("G:beta", status: .connected)

        let replayed = try client.sent.dropFirst(sentBeforeReconnect).map {
            try JSONDecoder().decode(MultiplayerPacketEnvelope.self, from: $0.data)
        }
        XCTAssertEqual(replayed.map(\.lane), [.evidence, .evidence, .canonical])
        guard case .input = replayed[0].payload else {
            return XCTFail("Evidence must replay first.")
        }
        guard case .inputSeal = replayed[1].payload else {
            return XCTFail("The latest seal must replay after evidence.")
        }
        guard case .inputResolution = replayed[2].payload else {
            return XCTFail("Unresolved canonical disposition must replay last.")
        }
    }

    func testUnacknowledgedEvidenceRetriesWithoutDisconnectAndStopsAfterCumulativeAck()
        async throws
    {
        let clock = MultiplayerTestClock(value: 100)
        let client = MultiplayerGameKitClientFake(
            localGamePlayerID: "G:alpha",
            remotePlayers: [
                MultiplayerGameKitPlayer(gamePlayerID: "G:beta", displayName: "Beta")
            ]
        )
        let transport = MultiplayerGameKitTransport(
            client: client,
            monotonicMilliseconds: { clock.value }
        )
        try await makeCompatible(transport, client: client, localSeat: 0)
        try transport.serviceRecovery()
        let input = MultiplayerInputPacket(
            inputSequence: 1,
            seat: 0,
            cell: 4,
            coordinatorInputMilliseconds: 90
        )
        try transport.sendInput(input, logicalMatchMilliseconds: 90)
        let sendsBeforeRetry = client.sent.count

        clock.value =
            100 + MultiplayerGameKitTransport.recoveryRetryIntervalMilliseconds - 1
        try transport.serviceRecovery()
        XCTAssertEqual(client.sent.count, sendsBeforeRetry)

        clock.value += 1
        try transport.serviceRecovery()
        let retry = try XCTUnwrap(client.sent.dropFirst(sendsBeforeRetry).last)
        XCTAssertEqual(retry.recipients, ["G:beta"])
        let retryEnvelope = try JSONDecoder().decode(
            MultiplayerPacketEnvelope.self,
            from: retry.data
        )
        XCTAssertEqual(retryEnvelope.lane, .evidence)
        guard case .input(let retriedInput) = retryEnvelope.payload else {
            return XCTFail("Expected reliable input evidence retry.")
        }
        XCTAssertEqual(retriedInput, input)

        clock.value += MultiplayerGameKitTransport.recoveryRetryIntervalMilliseconds
        try transport.serviceRecovery()
        let newerRetry = try XCTUnwrap(client.sent.last)
        let newerRetryEnvelope = try JSONDecoder().decode(
            MultiplayerPacketEnvelope.self,
            from: newerRetry.data
        )
        XCTAssertGreaterThan(
            newerRetryEnvelope.packetSequence,
            retryEnvelope.packetSequence
        )

        client.receive(
            try encodedEnvelope(
                sequence: 2,
                lane: .control,
                payload: .acknowledgement(
                    MultiplayerAcknowledgementPacket(
                        acknowledgedPacketSequence: retryEnvelope.packetSequence,
                        acknowledgedLane: .evidence,
                        appliedEventSequence: 0
                    )
                )
            ),
            from: "G:beta"
        )
        let sendsAfterAck = client.sent.count
        clock.value += MultiplayerGameKitTransport.recoveryRetryIntervalMilliseconds
        try transport.serviceRecovery()
        XCTAssertEqual(client.sent.count, sendsAfterAck)
        XCTAssertNil(transport.pendingEvidenceRecipientsByInputID[input.id])
    }

    func testUnacknowledgedResolutionRetriesWithoutDisconnectAndStopsAfterAcknowledgement()
        async throws
    {
        let clock = MultiplayerTestClock(value: 500)
        let client = MultiplayerGameKitClientFake(
            localGamePlayerID: "G:alpha",
            remotePlayers: [
                MultiplayerGameKitPlayer(gamePlayerID: "G:beta", displayName: "Beta")
            ]
        )
        let transport = MultiplayerGameKitTransport(
            client: client,
            monotonicMilliseconds: { clock.value }
        )
        try await makeCompatible(transport, client: client, localSeat: 0)
        try transport.serviceRecovery()
        let resolution = MultiplayerInputResolution(
            inputID: MultiplayerInputID(seat: 1, inputSequence: 2),
            disposition: .ignored(.staleTarget)
        )
        try transport.sendInputResolution(resolution, logicalMatchMilliseconds: 90)
        let sendsBeforeRetry = client.sent.count

        clock.value += MultiplayerGameKitTransport.recoveryRetryIntervalMilliseconds
        try transport.serviceRecovery()
        let retry = try XCTUnwrap(client.sent.dropFirst(sendsBeforeRetry).last)
        XCTAssertEqual(retry.recipients, ["G:beta"])
        let retryEnvelope = try JSONDecoder().decode(
            MultiplayerPacketEnvelope.self,
            from: retry.data
        )
        XCTAssertEqual(retryEnvelope.lane, .canonical)
        guard case .inputResolution(let retriedResolution) = retryEnvelope.payload else {
            return XCTFail("Expected canonical input-resolution retry.")
        }
        XCTAssertEqual(retriedResolution, resolution)

        clock.value += MultiplayerGameKitTransport.recoveryRetryIntervalMilliseconds
        try transport.serviceRecovery()
        let newerRetry = try XCTUnwrap(client.sent.last)
        let newerRetryEnvelope = try JSONDecoder().decode(
            MultiplayerPacketEnvelope.self,
            from: newerRetry.data
        )
        XCTAssertGreaterThan(
            newerRetryEnvelope.packetSequence,
            retryEnvelope.packetSequence
        )

        client.receive(
            try encodedEnvelope(
                sequence: 2,
                lane: .control,
                payload: .acknowledgement(
                    MultiplayerAcknowledgementPacket(
                        acknowledgedPacketSequence: retryEnvelope.packetSequence,
                        acknowledgedLane: .canonical,
                        appliedEventSequence: 0
                    )
                )
            ),
            from: "G:beta"
        )
        let sendsAfterAck = client.sent.count
        clock.value += MultiplayerGameKitTransport.recoveryRetryIntervalMilliseconds
        try transport.serviceRecovery()
        XCTAssertEqual(client.sent.count, sendsAfterAck)
        XCTAssertNil(
            transport.pendingResolutionRecipientsByInputID[resolution.inputID]
        )
    }

    func testFailedFourSeatEvidenceBroadcastRemainsPendingForEveryRecipientUntilAck()
        async throws
    {
        let remoteIDs = ["G:beta", "G:gamma", "G:delta"]
        let client = MultiplayerGameKitClientFake(
            localGamePlayerID: "G:alpha",
            remotePlayers: remoteIDs.map {
                MultiplayerGameKitPlayer(gamePlayerID: $0, displayName: $0)
            }
        )
        let transport = MultiplayerGameKitTransport(client: client)
        try await makeFourSeatCompatible(transport, client: client)
        let input = MultiplayerInputPacket(
            inputSequence: 1,
            seat: 0,
            cell: 4,
            coordinatorInputMilliseconds: 90
        )
        client.failNextSendModes = [.reliable]

        XCTAssertThrowsError(
            try transport.sendInput(input, logicalMatchMilliseconds: 90)
        )
        XCTAssertEqual(
            transport.pendingEvidenceRecipientsByInputID[input.id],
            Set(remoteIDs)
        )

        var targetedSequence: [String: Int] = [:]
        for remoteID in remoteIDs {
            client.changeConnection(remoteID, status: .disconnected)
            let sentBefore = client.sent.count
            client.changeConnection(remoteID, status: .connected)
            let replay = try XCTUnwrap(
                client.sent.dropFirst(sentBefore).first(where: {
                    $0.recipients == [remoteID]
                })
            )
            let envelope = try JSONDecoder().decode(
                MultiplayerPacketEnvelope.self,
                from: replay.data
            )
            XCTAssertEqual(envelope.lane, .evidence)
            guard case .input = envelope.payload else {
                return XCTFail("Expected targeted evidence replay.")
            }
            targetedSequence[remoteID] = envelope.packetSequence
        }
        XCTAssertEqual(
            transport.pendingEvidenceRecipientsByInputID[input.id],
            Set(remoteIDs),
            "A targeted send is not delivery proof; every peer stays pending until ACK."
        )

        var remaining = Set(remoteIDs)
        for remoteID in ["G:delta", "G:beta", "G:gamma"] {
            client.receive(
                try encodedEnvelope(
                    sequence: 2,
                    lane: .control,
                    payload: .acknowledgement(
                        MultiplayerAcknowledgementPacket(
                            acknowledgedPacketSequence: try XCTUnwrap(
                                targetedSequence[remoteID]
                            ),
                            acknowledgedLane: .evidence,
                            appliedEventSequence: 0
                        )
                    )
                ),
                from: remoteID
            )
            remaining.remove(remoteID)
            XCTAssertEqual(
                transport.pendingEvidenceRecipientsByInputID[input.id]
                    ?? [],
                remaining
            )
        }
        XCTAssertNil(transport.pendingEvidenceRecipientsByInputID[input.id])
    }

    func testFailedFourSeatResolutionBroadcastRemainsPendingForEveryRecipientUntilAck()
        async throws
    {
        let remoteIDs = ["G:beta", "G:gamma", "G:delta"]
        let client = MultiplayerGameKitClientFake(
            localGamePlayerID: "G:alpha",
            remotePlayers: remoteIDs.map {
                MultiplayerGameKitPlayer(gamePlayerID: $0, displayName: $0)
            }
        )
        let transport = MultiplayerGameKitTransport(client: client)
        try await makeFourSeatCompatible(transport, client: client)
        let resolution = MultiplayerInputResolution(
            inputID: MultiplayerInputID(seat: 2, inputSequence: 1),
            disposition: .ignored(.finished)
        )
        client.failNextSendModes = [.reliable]

        XCTAssertThrowsError(
            try transport.sendInputResolution(
                resolution,
                logicalMatchMilliseconds: 90
            )
        )
        XCTAssertEqual(
            transport.pendingResolutionRecipientsByInputID[resolution.inputID],
            Set(remoteIDs)
        )

        var targetedSequence: [String: Int] = [:]
        for remoteID in remoteIDs {
            client.changeConnection(remoteID, status: .disconnected)
            let sentBefore = client.sent.count
            client.changeConnection(remoteID, status: .connected)
            let replay = try XCTUnwrap(
                client.sent.dropFirst(sentBefore).first(where: {
                    $0.recipients == [remoteID]
                })
            )
            let envelope = try JSONDecoder().decode(
                MultiplayerPacketEnvelope.self,
                from: replay.data
            )
            XCTAssertEqual(envelope.lane, .canonical)
            guard case .inputResolution = envelope.payload else {
                return XCTFail("Expected targeted resolution replay.")
            }
            targetedSequence[remoteID] = envelope.packetSequence
        }
        XCTAssertEqual(
            transport.pendingResolutionRecipientsByInputID[resolution.inputID],
            Set(remoteIDs),
            "A targeted send is not delivery proof; every peer stays pending until ACK."
        )

        var remaining = Set(remoteIDs)
        for remoteID in ["G:gamma", "G:delta", "G:beta"] {
            client.receive(
                try encodedEnvelope(
                    sequence: 2,
                    lane: .control,
                    payload: .acknowledgement(
                        MultiplayerAcknowledgementPacket(
                            acknowledgedPacketSequence: try XCTUnwrap(
                                targetedSequence[remoteID]
                            ),
                            acknowledgedLane: .canonical,
                            appliedEventSequence: 0
                        )
                    )
                ),
                from: remoteID
            )
            remaining.remove(remoteID)
            XCTAssertEqual(
                transport.pendingResolutionRecipientsByInputID[resolution.inputID]
                    ?? [],
                remaining
            )
        }
        XCTAssertNil(transport.pendingResolutionRecipientsByInputID[resolution.inputID])
    }

    func testEvidenceJournalRejectsOverflowBeforeSendingAnotherFastCopy() async throws {
        let client = MultiplayerGameKitClientFake(
            localGamePlayerID: "G:alpha",
            remotePlayers: [
                MultiplayerGameKitPlayer(gamePlayerID: "G:beta", displayName: "Beta")
            ]
        )
        let transport = MultiplayerGameKitTransport(
            client: client,
            maximumEvidenceJournalEntries: 1
        )
        try await makeCompatible(transport, client: client, localSeat: 0)
        try transport.sendInput(
            MultiplayerInputPacket(
                inputSequence: 1,
                seat: 0,
                cell: 4,
                coordinatorInputMilliseconds: 90
            ),
            logicalMatchMilliseconds: 90
        )
        let sentBeforeOverflow = client.sent.count

        XCTAssertThrowsError(
            try transport.sendInput(
                MultiplayerInputPacket(
                    inputSequence: 2,
                    seat: 0,
                    cell: 5,
                    coordinatorInputMilliseconds: 91
                ),
                logicalMatchMilliseconds: 91
            )
        ) { error in
            XCTAssertEqual(error as? MultiplayerGameKitError, .evidenceJournalFull)
        }
        XCTAssertEqual(client.sent.count, sentBeforeOverflow)
    }

    func testRecoverySnapshotCarriesPlansAndResumeShiftsTheSharedClock() async throws {
        let clock = MultiplayerTestClock(value: 100)
        let client = MultiplayerGameKitClientFake(
            localGamePlayerID: "G:alpha",
            remotePlayers: [
                MultiplayerGameKitPlayer(gamePlayerID: "G:beta", displayName: "Beta")
            ]
        )
        let transport = MultiplayerGameKitTransport(
            client: client,
            monotonicMilliseconds: { clock.value }
        )
        try await makeCompatible(transport, client: client, localSeat: 0)
        try freezeCoordinatorNetworkPolicy(transport, client: client)
        try transport.sendStartManifest(
            Self.manifest,
            coordinatorStartMonotonicMilliseconds: 1_000,
            presentationLeadMilliseconds: 180
        )
        try transport.sendPause(pauseID: 1, logicalMatchMilliseconds: 250)
        let plan = MultiplayerWireActivationPlan(
            planId: 3,
            kind: .target,
            at: 600,
            ownerSeat: 1,
            entityId: 2,
            cell: 9,
            colorIndex: 1,
            lifetimeMs: nil
        )
        try transport.sendSnapshot(
            events: [],
            pendingPlans: [plan],
            afterEventSequence: 0,
            logicalMatchMilliseconds: 250,
            to: "G:beta"
        )
        let snapshotEnvelope = try JSONDecoder().decode(
            MultiplayerPacketEnvelope.self,
            from: try XCTUnwrap(client.sent.last).data
        )
        guard case .snapshot(let snapshot) = snapshotEnvelope.payload else {
            return XCTFail("Expected recovery snapshot.")
        }
        XCTAssertEqual(snapshot.pendingPlans, [plan])
        XCTAssertEqual(snapshot.pauseId, 1)
        XCTAssertEqual(snapshot.pausedAtLogicalMilliseconds, 250)
        XCTAssertEqual(snapshot.coordinatorMatchStartMonotonicMilliseconds, 1_000)

        clock.value = 400
        try transport.sendResume(pauseID: 1, logicalMatchMilliseconds: 250)
        let resumeEnvelope = try JSONDecoder().decode(
            MultiplayerPacketEnvelope.self,
            from: try XCTUnwrap(client.sent.last).data
        )
        guard case .resume(let resume) = resumeEnvelope.payload else {
            return XCTFail("Expected shared-clock resume.")
        }
        XCTAssertEqual(resume.coordinatorMatchStartMonotonicMilliseconds, 1_300)
    }

    func testPacketPayloadRoundTripsEveryRecoveryAndControlCase() throws {
        let cases: [MultiplayerPacketPayload] = [
            .hello(
                MultiplayerHelloPacket(
                    participantId: Self.localParticipantID,
                    seat: 0,
                    colorIndex: 0,
                    gamePlayerId: "G:alpha"
                )
            ),
            .rosterConfirmed(
                MultiplayerRosterConfirmedPacket(confirmedCount: 2, participantCount: 2)
            ),
            .clockPing(
                MultiplayerClockPingPacket(
                    nonce: 1,
                    requesterSendMonotonicMilliseconds: 100
                )
            ),
            .clockPong(
                MultiplayerClockPongPacket(
                    nonce: 1,
                    requesterSendMonotonicMilliseconds: 100,
                    coordinatorReceiveMonotonicMilliseconds: 120,
                    coordinatorSendMonotonicMilliseconds: 121
                )
            ),
            .startManifest(
                MultiplayerStartSignalPacket(
                    manifest: Self.manifest,
                    coordinatorStartMonotonicMilliseconds: 1_000,
                    presentationLeadMilliseconds: 180
                )
            ),
            .input(
                MultiplayerInputPacket(
                    inputSequence: 1,
                    seat: 0,
                    cell: 4,
                    coordinatorInputMilliseconds: 300
                )
            ),
            .inputSeal(
                MultiplayerInputSeal(
                    seat: 0,
                    throughInputAt: 300,
                    highestInputSequence: 1
                )
            ),
            .inputResolution(
                MultiplayerInputResolution(
                    inputID: MultiplayerInputID(seat: 0, inputSequence: 1),
                    disposition: .committed(eventSequence: 1)
                )
            ),
            .terminalInputSeal(
                MultiplayerTerminalInputSealPacket(
                    version: 1,
                    finishEventSequence: 1,
                    seal: MultiplayerInputSeal(
                        seat: 0,
                        throughInputAt: 300,
                        highestInputSequence: 1
                    )
                )
            ),
            .activationPlans(
                MultiplayerActivationPlansPacket(
                    plans: [
                        MultiplayerWireActivationPlan(
                            planId: 1,
                            kind: .target,
                            at: 500,
                            ownerSeat: 0,
                            entityId: 1,
                            cell: 4,
                            colorIndex: 0,
                            lifetimeMs: nil
                        )
                    ]
                )
            ),
            .cancelActivationPlans(
                MultiplayerCancelActivationPlansPacket(planIds: [1])
            ),
            .events(MultiplayerEventBatchPacket(events: [[6, 1, 500]])),
            .acknowledgement(
                MultiplayerAcknowledgementPacket(
                    acknowledgedPacketSequence: 1,
                    appliedEventSequence: 1
                )
            ),
            .snapshot(
                MultiplayerSnapshotPacket(
                    afterEventSequence: 0,
                    throughEventSequence: 1,
                    chunkIndex: 0,
                    chunkCount: 1,
                    events: [[6, 1, 500]],
                    pendingPlans: [],
                    coordinatorMatchStartMonotonicMilliseconds: 10_000,
                    pauseId: nil,
                    pausedAtLogicalMilliseconds: nil
                )
            ),
            .snapshotRequest(MultiplayerSnapshotRequestPacket(afterEventSequence: 0)),
            .pause(
                MultiplayerPausePacket(
                    pauseId: 1,
                    pausedAtLogicalMilliseconds: 500
                )
            ),
            .resume(
                MultiplayerResumePacket(
                    pauseId: 1,
                    coordinatorMatchStartMonotonicMilliseconds: 12_000
                )
            ),
            .finish(
                MultiplayerFinishPacket(
                    finalEventSequence: 1,
                    manifestHash: Self.hash,
                    transcriptDigest: Self.hash
                )
            ),
            .terminalCancel(
                MultiplayerTerminalCancelPacket(
                    version: 1,
                    throughEventSequence: 1,
                    reason: .terminalDrainExceeded
                )
            ),
        ]
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        for payload in cases {
            XCTAssertEqual(
                try decoder.decode(
                    MultiplayerPacketPayload.self,
                    from: encoder.encode(payload)
                ),
                payload
            )
        }
    }

    private static let matchID = "11111111-1111-4111-8111-111111111111"
    private static let localParticipantID = "22222222-2222-4222-8222-222222222222"
    private static let remoteParticipantID = "33333333-3333-4333-8333-333333333333"
    private static let hash = String(repeating: "A", count: 43)
    private static let manifest = MultiplayerStartManifest(
        protocolVersion: 1,
        ruleset: MultiplayerAPIContract.ruleset,
        proofVersion: 1,
        matchId: matchID,
        buildId: MultiplayerAPIContract.buildID,
        seed: hash,
        startingLives: 3,
        participants: [
            MultiplayerManifestParticipant(
                participantId: localParticipantID,
                seat: 0,
                colorIndex: 0
            ),
            MultiplayerManifestParticipant(
                participantId: remoteParticipantID,
                seat: 1,
                colorIndex: 1
            ),
        ],
        manifestHash: hash
    )

    private func encodedEnvelope(
        sequence: Int,
        lane: MultiplayerTransportLane,
        payload: MultiplayerPacketPayload
    ) throws -> Data {
        try JSONEncoder().encode(
            MultiplayerPacketEnvelope(
                version: 1,
                matchId: Self.matchID,
                packetSequence: sequence,
                eventSequence: 0,
                logicalMatchMilliseconds: 0,
                lane: lane,
                payload: payload
            )
        )
    }

    private func makeCompatible(
        _ transport: MultiplayerGameKitTransport,
        client: MultiplayerGameKitClientFake,
        localSeat: Int
    ) async throws {
        try await transport.connect(
            matchID: Self.matchID,
            playerGroup: 99,
            participantCount: 2
        )
        try transport.sendHello(
            participantID: Self.localParticipantID,
            seat: localSeat,
            colorIndex: localSeat
        )
        let remoteSeat = localSeat == 0 ? 1 : 0
        let remoteID = client.remotePlayers[0].gamePlayerID
        let remoteHello = MultiplayerHelloPacket(
            participantId: Self.remoteParticipantID,
            seat: remoteSeat,
            colorIndex: remoteSeat,
            gamePlayerId: remoteID,
            liveWireVersion: MultiplayerLiveWire.version,
            capabilities: MultiplayerLiveWire.requiredCapabilities.sorted()
        )
        client.receive(
            try encodedEnvelope(
                sequence: 1,
                lane: .control,
                payload: .hello(remoteHello)
            ),
            from: remoteID
        )
        XCTAssertEqual(transport.liveCompatibility, .unanimous)
    }

    private func makeFourSeatCompatible(
        _ transport: MultiplayerGameKitTransport,
        client: MultiplayerGameKitClientFake
    ) async throws {
        try await transport.connect(
            matchID: Self.matchID,
            playerGroup: 99,
            participantCount: 4
        )
        try transport.sendHello(
            participantID: Self.localParticipantID,
            seat: 0,
            colorIndex: 0
        )
        let participantIDs = [
            "33333333-3333-4333-8333-333333333333",
            "44444444-4444-4444-8444-444444444444",
            "55555555-5555-4555-8555-555555555555",
        ]
        for (index, player) in client.remotePlayers.enumerated() {
            let seat = index + 1
            let hello = MultiplayerHelloPacket(
                participantId: participantIDs[index],
                seat: seat,
                colorIndex: seat,
                gamePlayerId: player.gamePlayerID,
                liveWireVersion: MultiplayerLiveWire.version,
                capabilities: MultiplayerLiveWire.requiredCapabilities.sorted()
            )
            client.receive(
                try encodedEnvelope(
                    sequence: 1,
                    lane: .control,
                    payload: .hello(hello)
                ),
                from: player.gamePlayerID
            )
        }
        XCTAssertEqual(transport.liveCompatibility, .unanimous)
    }

    private func freezeCoordinatorNetworkPolicy(
        _ transport: MultiplayerGameKitTransport,
        client: MultiplayerGameKitClientFake
    ) throws {
        let measurement = MultiplayerSeatNetworkMeasurement(
            seat: 1,
            attemptedSampleCount: 4,
            completedSampleCount: 4,
            reorderedSampleCount: 0,
            p95RoundTripMilliseconds: 10,
            p95RoundTripVariationMilliseconds: 2
        )
        let proposal = MultiplayerNetworkPolicyProposal(
            measurements: [measurement],
            policy: MultiplayerFrozenNetworkPolicy(
                frontierStalenessMilliseconds: 40,
                evidenceRecoveryMilliseconds: 120
            )
        )
        client.receive(
            try encodedEnvelope(
                sequence: 2,
                lane: .control,
                payload: .networkMeasurement(measurement)
            ),
            from: "G:beta"
        )
        client.receive(
            try encodedEnvelope(
                sequence: 3,
                lane: .control,
                payload: .networkPolicyVote(
                    MultiplayerNetworkPolicyVote(seat: 1, proposal: proposal)
                )
            ),
            from: "G:beta"
        )
        XCTAssertEqual(transport.frozenNetworkPolicy, proposal.policy)
    }
}

@MainActor
private final class MultiplayerGameKitClientFake: MultiplayerGameKitClientProtocol {
    struct Send: Equatable {
        let data: Data
        let recipients: [String]?
        let mode: MultiplayerGameKitSendMode
    }

    var eventHandler: ((MultiplayerGameKitClientEvent) -> Void)?
    var isAuthenticated = true
    var scopedIDsArePersistent = true
    let localGamePlayerID: String
    var remotePlayers: [MultiplayerGameKitPlayer]
    var expectedPlayerCount = 0
    private(set) var configuration: MultiplayerMatchmakingConfiguration?
    private(set) var sent: [Send] = []
    private(set) var cancelCount = 0
    var failNextSendModes: [MultiplayerGameKitSendMode] = []

    init(
        localGamePlayerID: String,
        remotePlayers: [MultiplayerGameKitPlayer]
    ) {
        self.localGamePlayerID = localGamePlayerID
        self.remotePlayers = remotePlayers
    }

    func findMatch(configuration: MultiplayerMatchmakingConfiguration) async throws {
        self.configuration = configuration
        eventHandler?(.rosterChanged)
    }

    func send(
        _ data: Data,
        to gamePlayerIDs: [String]?,
        mode: MultiplayerGameKitSendMode
    ) throws {
        if failNextSendModes.first == mode {
            failNextSendModes.removeFirst()
            throw MultiplayerGameKitError.playerUnavailable
        }
        sent.append(Send(data: data, recipients: gamePlayerIDs, mode: mode))
    }

    func cancel() {
        cancelCount += 1
    }

    func receive(_ data: Data, from gamePlayerID: String) {
        eventHandler?(.received(data, fromGamePlayerID: gamePlayerID))
    }

    func changeConnection(
        _ gamePlayerID: String,
        status: MultiplayerGameKitConnectionStatus
    ) {
        eventHandler?(.connectionChanged(gamePlayerID, status))
    }
}

@MainActor
private final class MultiplayerTestClock {
    var value: Int

    init(value: Int) {
        self.value = value
    }
}
