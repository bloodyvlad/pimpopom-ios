#if DEBUG
    @MainActor
    final class UITestAppleAgeService: AppleAgeServing {
        let mode: String

        init(mode: String) { self.mode = mode }

        func regulatoryRequirement() async throws -> AppleAgeRequirement {
            mode == "optional" ? .optional : .required
        }

        func requestAgeRange() async throws -> AppleAgeResponse {
            if mode == "optional" { throw AgeServiceError.invalidRange }
            if mode == "required-declined" { return .declined }
            let under13 = mode == "under13"
            return .shared(
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
        var lastKnownProtection: AppleAgeProtection?
    }
#endif
