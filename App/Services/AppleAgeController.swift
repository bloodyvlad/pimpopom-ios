import Foundation
import OSLog

@MainActor
final class AppleAgeController: ObservableObject {
    enum State: Equatable {
        case checking
        case manual
        case ready
        case under13
        case sharingRequired
        case failed
    }

    @Published private(set) var state = State.checking
    @Published private(set) var isWorking = false
    @Published private(set) var sharedRange: AppleSharedAgeRange?
    @Published private(set) var diagnostic: AppleAgeDiagnostic?
    private let service: any AppleAgeServing
    private let store: any AppleAgeLockStoring
    private let ads: AdsController
    private let isEnabled: Bool
    private var generation = 0
    private var work: Task<Void, Never>?
    private var isInBackground = false
    private var hasStarted = false
    private var requirement: AppleAgeRequirement?
    private var authorizationWaiters: [UUID: CheckedContinuation<Void, Error>] = [:]
    private let logger = Logger(subsystem: "com.otcsoftware.pimpopom", category: "AppleAge")

    init(
        ads: AdsController,
        service: any AppleAgeServing = AppleAgeService(),
        store: any AppleAgeLockStoring = UserDefaultsAppleAgeLockStore(),
        isEnabled: Bool = true
    ) {
        self.ads = ads
        self.service = service
        self.store = store
        self.isEnabled = isEnabled
        if store.hasSharedAppleRange, store.lastKnownProtection == nil, let band = ads.ageBand {
            // Migration preserves an existing Apple-derived band without inventing exact bounds.
            store.lastKnownProtection = AppleAgeProtection(band: band, range: nil)
        }
        if isEnabled {
            ads.beginSystemAgeRefresh()
            ads.onAgeConfirmationRequired = { [weak self] in
                self?.scheduleRefresh()
            }
            ads.onAppleAgeRefresh = { [weak self] in self?.scheduleRefresh() }
        } else {
            state = .manual
        }
    }

    /// Called only once the scene is active; the service waits for its attached window.
    func startIfNeeded() {
        guard !hasStarted else { return }
        scheduleRefresh()
    }

    func setInBackground(_ background: Bool) {
        guard isEnabled, background != isInBackground else { return }
        isInBackground = background
        if background {
            generation += 1
            if requirement != .optional && requirement != .legacy {
                closeAccess()
            }
        } else {
            scheduleRefresh()
        }
    }

    func scheduleRefresh() {
        guard isEnabled, !isInBackground else { return }
        hasStarted = true
        generation += 1
        let expected = generation
        // A known optional region gets a quiet foreground probe without hiding the game.
        if requirement != .optional && requirement != .legacy {
            closeAccess()
        }
        let previous = work
        isWorking = true
        work = Task { @MainActor [weak self] in
            await previous?.value
            guard let self, isCurrent(expected) else { return }
            await performRefresh(expected)
            if isCurrent(expected) { isWorking = false }
        }
    }

    func refresh() async {
        guard isEnabled else { return }
        scheduleRefresh()
        await work?.value
    }

    func waitUntilIdle() async { await work?.value }

    /// Identity callbacks remain held while required-region age authorization is unresolved.
    func waitForAuthorization() async throws {
        try Task.checkCancellation()
        if ads.allowsApp { return }
        guard state == .checking else { throw CancellationError() }
        let id = UUID()
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                if Task.isCancelled {
                    continuation.resume(throwing: CancellationError())
                } else {
                    authorizationWaiters[id] = continuation
                }
            }
        } onCancel: {
            Task { @MainActor [weak self] in
                self?.authorizationWaiters.removeValue(forKey: id)?.resume(throwing: CancellationError())
            }
        }
        try Task.checkCancellation()
        guard ads.allowsApp else { throw CancellationError() }
    }

    private func settleAuthorizationWaiters() {
        guard state != .checking else { return }
        let waiting = authorizationWaiters.values
        authorizationWaiters.removeAll()
        for continuation in waiting {
            if ads.allowsApp { continuation.resume() } else { continuation.resume(throwing: CancellationError()) }
        }
    }

    private func isCurrent(_ expected: Int) -> Bool {
        expected == generation && !isInBackground
    }

    private func closeAccess() {
        ads.beginSystemAgeRefresh()
        state = .checking
    }

    private func readRequirement() async throws -> AppleAgeRequirement {
        do {
            return try await service.regulatoryRequirement()
        } catch {
            record(error, stage: "regional-requirement")
            throw error
        }
    }

    private func performRefresh(_ expected: Int) async {
        defer { if isCurrent(expected) { settleAuthorizationWaiters() } }
        do {
            let currentRequirement = try await readRequirement()
            guard isCurrent(expected) else { return }
            requirement = currentRequirement
            diagnostic = nil
            if currentRequirement != .required {
                allowUnspecifiedAgeAccess()
                return
            }
            closeAccess()
            await ads.waitForConsentPresentation()
            guard isCurrent(expected) else { return }
            let response = try await requestSharing()
            retainSharedLock(response, expected: expected)
            guard isCurrent(expected) else { return }
            applyRequiredResponse(response)
        } catch {
            guard isCurrent(expected) else { return }
            // A failed regulatory query is unknown, never evidence of an optional region.
            requirement = nil
            closeAccess()
            state = .failed
        }
    }

    private func requestSharing() async throws -> AppleAgeResponse {
        do { return try await service.requestAgeRange() } catch {
            record(error, stage: "sharing-request")
            throw error
        }
    }

    private func retainSharedLock(_ response: AppleAgeResponse, expected: Int) {
        guard case .shared(let range) = response, range.isValid else { return }
        store.hasSharedAppleRange = true
        let received = AppleAgeProtection(band: range.adBand, range: range)
        if isCurrent(expected) {
            store.lastKnownProtection = received
        } else {
            // A stale result cannot authorize another player. Keep any stricter evidence
            // so a later eligibility=false result cannot lose a known child restriction.
            let existing =
                store.lastKnownProtection
                ?? ads.ageBand.flatMap { band in
                    band == .adult ? nil : AppleAgeProtection(band: band, range: nil)
                }
            if let existing, protectionRank(existing.band) <= protectionRank(received.band) {
                store.lastKnownProtection = existing
            } else if received.band != .adult {
                store.lastKnownProtection = received
            }
            closeAccess()
        }
    }

    private func protectionRank(_ band: AdAgeBand) -> Int {
        switch band {
        case .under13: 0
        case .youngTeen: 1
        case .olderTeen: 2
        case .adult: 3
        }
    }

    private func applyRequiredResponse(_ response: AppleAgeResponse) {
        switch response {
        case .unsupported, .declined:
            state = .sharingRequired
        case .shared(let range):
            guard range.isValid else {
                state = .failed
                return
            }
            sharedRange = range
            ads.applySystemAge(range)
            state = range.adBand.allowsApp ? .ready : .under13
        }
    }

    private func allowUnspecifiedAgeAccess() {
        sharedRange = store.lastKnownProtection?.range
        ads.allowUnspecifiedAgeAccess(
            protection: store.lastKnownProtection, appleLocked: store.hasSharedAppleRange
        )
        if ads.needsManualAgeChoice {
            ads.waitForManualAgeChoice()
            state = .manual
        } else {
            state = ads.ageBand == .under13 ? .under13 : .ready
        }
    }

    func chooseManualAge(_ band: AdAgeBand?) async {
        guard state == .manual, ads.canManuallyChangeAge else { return }
        if let band { await ads.setAgeBand(band) } else { ads.skipManualAgeChoice() }
        state = ads.ageBand == .under13 ? .under13 : .ready
        settleAuthorizationWaiters()
    }

    private func record(_ error: Error, stage: String) {
        guard !(error is CancellationError) else { return }
        let nsError = error as NSError
        diagnostic = AppleAgeDiagnostic(stage: stage, domain: nsError.domain, code: nsError.code)
        logger.error(
            "Age check failed stage=\(stage, privacy: .public) domain=\(nsError.domain, privacy: .public) code=\(nsError.code, privacy: .public)"
        )
    }
}
