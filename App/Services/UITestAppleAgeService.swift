#if DEBUG
    @MainActor
    final class UITestAppleAgeService: AppleAgeServing {
        let under13: Bool

        init(under13: Bool) { self.under13 = under13 }

        func requestAgeRange() async throws -> AppleAgeResponse {
            .shared(
                AppleSharedAgeRange(
                    lowerBound: under13 ? nil : 13, upperBound: under13 ? 12 : 15,
                    hasParentalControls: true
                )
            )
        }
    }

    @MainActor
    final class UITestAppleAgeLockStore: AppleAgeLockStoring {
        var hasSharedAppleRange = false
    }
#endif
