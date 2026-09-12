import Foundation

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
    private let service: any AppleAgeServing
    private let store: any AppleAgeLockStoring
    private let ads: AdsController
    private let isEnabled: Bool
    private var generation = 0
    private var work: Task<Void, Never>?
    private var isInBackground = false
    private var authorizationWaiters: [UUID: CheckedContinuation<Void, Error>] = [:]

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
        if isEnabled {
            ads.beginSystemAgeRefresh()
            ads.onAgeConfirmationRequired = { [weak self] in self?.scheduleRefresh() }
            ads.onAppleAgeRefresh = { [weak self] in self?.scheduleRefresh() }
        } else {
            state = .manual
        }
    }

    func setInBackground(_ background: Bool) {
        guard isEnabled, background != isInBackground else { return }
        isInBackground = background
        if background {
            generation += 1
            ads.beginSystemAgeRefresh()
            state = .checking
        } else {
            scheduleRefresh()
        }
    }

    func scheduleRefresh() {
        guard isEnabled else { return }
        // This synchronous prefix closes ad and account eligibility before UI changes.
        generation += 1
        let expected = generation
        ads.beginSystemAgeRefresh()
        state = .checking
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

    /// Identity SDKs may finish directly while the app is returning from background.
    /// Hold their credentials in memory until age authorization is current again.
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

    private func performRefresh(_ expected: Int) async {
        defer { if isCurrent(expected) { settleAuthorizationWaiters() } }
        await ads.waitForConsentPresentation()
        guard isCurrent(expected) else { return }
        do {
            let response = try await service.requestAgeRange()
            // Sharing is a monotonic device lock even when the active result was
            // superseded; a later decline must not unlock manual age editing.
            if case .shared(let range) = response, range.isValid {
                store.hasSharedAppleRange = true
            }
            guard isCurrent(expected) else { return }
            switch response {
            case .unsupported:
                if store.hasSharedAppleRange { state = .sharingRequired } else { allowManualFallback() }
            case .declined(let isRequired):
                if !isRequired, !store.hasSharedAppleRange {
                    allowManualFallback()
                } else {
                    state = .sharingRequired
                }
            case .shared(let range):
                guard range.isValid else {
                    state = .failed
                    return
                }
                sharedRange = range
                store.hasSharedAppleRange = true
                guard range.adBand.allowsApp else {
                    state = .under13
                    return
                }
                ads.applySystemAge(range)
                state = .ready
            }
        } catch {
            guard isCurrent(expected) else { return }
            state = .failed
        }
    }

    private func allowManualFallback() {
        sharedRange = nil
        ads.allowManualAgeFallback()
        state = .manual
    }

}
