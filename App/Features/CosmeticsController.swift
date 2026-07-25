import Combine
import Foundation

enum ThemeShopAction: Equatable, Sendable {
    case selected
    case select
    case buy
}

enum PetShopAction: Equatable, Sendable {
    case buy
    case select
    case hide
    case show
}

enum CosmeticCatalog {
    static let freeThemeIDs: Set<String> = ["classic", "disco"]

    static let themes = [
        CosmeticCatalogItem(id: "classic", name: "Default", priceCoins: 0),
        CosmeticCatalogItem(id: "disco", name: "Disco", priceCoins: 0),
        CosmeticCatalogItem(id: "light", name: "Light", priceCoins: 50),
        CosmeticCatalogItem(id: "pixel", name: "Pixel", priceCoins: 100),
    ]

    static let pets = [
        CosmeticCatalogItem(id: "foka", name: "Foka", priceCoins: 10),
        CosmeticCatalogItem(id: "kesha", name: "Kesha", priceCoins: 20),
        CosmeticCatalogItem(id: "tauta", name: "Tauta", priceCoins: 50),
        CosmeticCatalogItem(id: "misha", name: "Misha", priceCoins: 100),
        CosmeticCatalogItem(id: "pancake", name: "Pancake", priceCoins: 500),
    ]

    static func themeAction(themeID: String, owned: Set<String>, selectedID: String) -> ThemeShopAction {
        if themeID == selectedID { return .selected }
        return owned.contains(themeID) ? .select : .buy
    }

    static func petAction(
        petID: String,
        owned: Set<String>,
        selectedID: String?,
        visible: Bool
    ) -> PetShopAction {
        guard owned.contains(petID) else { return .buy }
        guard selectedID == petID else { return .select }
        return visible ? .hide : .show
    }

    static func displayedPetID(profile: PlayerProfile?) -> String? {
        guard let profile else { return nil }
        if let specialPetID = profile.specialPetId { return specialPetID }
        if let equippedPetID = profile.equippedPetId { return equippedPetID }
        return profile.petVisible ? profile.selectedPetId : nil
    }
}

@MainActor
final class CosmeticsController: ObservableObject {
    @Published private(set) var themes = CosmeticCatalog.themes
    @Published private(set) var pets = CosmeticCatalog.pets
    @Published private(set) var coinBalance = 0
    @Published private(set) var ownedThemeIDs = CosmeticCatalog.freeThemeIDs
    @Published private(set) var selectedThemeID = "classic"
    @Published private(set) var ownedPetIDs: Set<String> = []
    @Published private(set) var selectedPetID: String?
    @Published private(set) var petVisible = false
    @Published private(set) var displayedPetID: String?
    @Published private(set) var isLoading = false
    @Published private(set) var isEconomyMutationPending = false
    @Published private(set) var pendingThemeID: String?
    @Published private(set) var pendingPetID: String?
    @Published private(set) var themeMessage = ""
    @Published private(set) var petMessage = ""

    private let backend: BackendClient
    private let preferences: AppPreferences
    private let forcedUITestThemeID: String?
    private var sessionObservation: AnyCancellable?
    private var refreshGeneration = 0

    init(backend: BackendClient, preferences: AppPreferences) {
        self.backend = backend
        self.preferences = preferences
        forcedUITestThemeID = Self.forcedUITestThemeArgument()
        selectedThemeID =
            forcedUITestThemeID
            ?? (CosmeticCatalog.freeThemeIDs.contains(preferences.selectedThemeID)
                ? preferences.selectedThemeID
                : "classic")
        sessionObservation = backend.$sessionState.sink { [weak self] session in
            self?.applySession(session)
        }
    }

    var theme: ThemePalette { ThemePalette.resolve(selectedThemeID) }
    var isAuthenticated: Bool { backend.isAuthenticated }

    func refresh() async {
        guard !isEconomyMutationPending else { return }
        refreshGeneration += 1
        let generation = refreshGeneration
        isLoading = true
        defer {
            if generation == refreshGeneration { isLoading = false }
        }

        var catalogProfile: PlayerProfile?
        var loadedAnything = false
        var failures: [String] = []

        do {
            let response = try await backend.loadThemes()
            guard generation == refreshGeneration, !Task.isCancelled else { return }
            themes = validated(response.themes, fallback: CosmeticCatalog.themes)
            catalogProfile = response.profile
            coinBalance = response.coinBalance
            loadedAnything = true
        } catch {
            failures.append("themes")
        }

        do {
            let response = try await backend.loadPets()
            guard generation == refreshGeneration, !Task.isCancelled else { return }
            pets = validated(response.pets, fallback: CosmeticCatalog.pets)
            catalogProfile = response.profile
            coinBalance = response.coinBalance
            loadedAnything = true
        } catch {
            failures.append("pets")
        }

        guard generation == refreshGeneration, !Task.isCancelled else { return }
        if let catalogProfile {
            if backend.synchronizeProfileFromCatalog(catalogProfile) {
                applyProfile(catalogProfile)
            } else if let currentSession = backend.sessionState {
                applySession(currentSession)
            } else if let refreshedSession = try? await backend.loadSession() {
                guard generation == refreshGeneration, !Task.isCancelled else { return }
                applySession(refreshedSession)
            }
        } else if loadedAnything {
            if let refreshedSession = try? await backend.loadSession() {
                guard generation == refreshGeneration, !Task.isCancelled else { return }
                applySession(refreshedSession)
            } else {
                guard generation == refreshGeneration, !Task.isCancelled else { return }
                applyProfile(nil)
            }
        } else {
            applySession(backend.sessionState)
        }

        if loadedAnything, failures.isEmpty {
            themeMessage =
                backend.isAuthenticated
                ? "Select a theme you own, or spend verified coins on a new one."
                : "Default and Disco are free. Sign in to buy paid themes."
            petMessage =
                backend.isAuthenticated
                ? ""
                : "Sign in to buy and select pets."
        } else if !failures.isEmpty {
            let unavailable = failures.joined(separator: " and ")
            themeMessage = "Using the bundled catalog; live \(unavailable) are unavailable."
            petMessage = "Using the bundled catalog; purchases need the live service."
        }
    }

    func performThemeAction(_ theme: CosmeticCatalogItem) async {
        guard !isLoading, !isEconomyMutationPending else { return }
        let action = CosmeticCatalog.themeAction(
            themeID: theme.id,
            owned: ownedThemeIDs,
            selectedID: selectedThemeID
        )
        guard action != .selected else { return }

        if !backend.isAuthenticated {
            guard CosmeticCatalog.freeThemeIDs.contains(theme.id) else {
                themeMessage = "Sign in to buy paid themes."
                return
            }
            selectLocally(theme.id)
            themeMessage = "\(theme.name) is selected on this iPhone."
            return
        }

        if action == .buy, coinBalance < theme.priceCoins {
            themeMessage = ""
            return
        }

        isEconomyMutationPending = true
        pendingThemeID = theme.id
        themeMessage = action == .buy ? "Buying \(theme.name)…" : "Selecting \(theme.name)…"
        defer {
            pendingThemeID = nil
            isEconomyMutationPending = false
        }
        do {
            let response = try await backend.selectTheme(theme.id)
            applyProfile(response.profile)
            themeMessage =
                response.theme.purchased
                ? "\(theme.name) is yours and selected."
                : "\(theme.name) is selected."
        } catch {
            themeMessage = error.localizedDescription
        }
    }

    func performPetAction(_ pet: CosmeticCatalogItem) async {
        guard !isLoading, !isEconomyMutationPending else { return }
        guard backend.isAuthenticated else {
            petMessage = "Sign in to buy and select pets."
            return
        }

        let action = CosmeticCatalog.petAction(
            petID: pet.id,
            owned: ownedPetIDs,
            selectedID: selectedPetID,
            visible: petVisible
        )

        if action == .buy, coinBalance < pet.priceCoins {
            petMessage = ""
            return
        }

        isEconomyMutationPending = true
        pendingPetID = pet.id
        defer {
            pendingPetID = nil
            isEconomyMutationPending = false
        }
        do {
            switch action {
            case .hide, .show:
                let visible = action == .show
                petMessage = visible ? "Showing \(pet.name)…" : "Hiding \(pet.name)…"
                let response = try await backend.setPetVisibility(pet.id, visible: visible)
                applyProfile(response.profile)
                petMessage = withSpecialPetNotice(
                    "\(pet.name) is now \(visible ? "shown" : "hidden")."
                )
            case .buy, .select:
                petMessage = action == .buy ? "Buying \(pet.name)…" : "Selecting \(pet.name)…"
                let response = try await backend.selectPet(pet.id)
                applyProfile(response.profile)
                petMessage =
                    response.pet.purchased
                    ? ""
                    : withSpecialPetNotice("\(pet.name) is selected.")
            }
        } catch {
            petMessage = error.localizedDescription
        }
    }

    func canAfford(_ item: CosmeticCatalogItem) -> Bool {
        coinBalance >= item.priceCoins
    }

    private func applySession(_ session: SessionResponse?) {
        applyProfile(session?.profile)
    }

    private func applyProfile(_ profile: PlayerProfile?) {
        guard let profile else {
            coinBalance = 0
            ownedThemeIDs = CosmeticCatalog.freeThemeIDs
            if let forcedUITestThemeID {
                ownedThemeIDs.insert(forcedUITestThemeID)
            }
            let localID =
                forcedUITestThemeID
                ?? (CosmeticCatalog.freeThemeIDs.contains(preferences.selectedThemeID)
                    ? preferences.selectedThemeID
                    : "classic")
            selectedThemeID = localID
            ownedPetIDs = []
            selectedPetID = nil
            petVisible = false
            displayedPetID = nil
            return
        }

        coinBalance = profile.coins
        ownedThemeIDs = Set(profile.ownedThemeIds).union(CosmeticCatalog.freeThemeIDs)
        if let forcedUITestThemeID {
            ownedThemeIDs.insert(forcedUITestThemeID)
        }
        let serverThemeID = profile.selectedThemeId ?? "classic"
        selectedThemeID =
            forcedUITestThemeID
            ?? (ownedThemeIDs.contains(serverThemeID) ? serverThemeID : "classic")
        if forcedUITestThemeID == nil {
            preferences.selectedThemeID = selectedThemeID
        }
        ownedPetIDs = Set(profile.ownedPetIds)
        selectedPetID =
            profile.selectedPetId
            ?? profile.equippedPetId.flatMap { profile.ownedPetIds.contains($0) ? $0 : nil }
        petVisible = selectedPetID != nil && profile.petVisible
        displayedPetID = CosmeticCatalog.displayedPetID(profile: profile)
    }

    private func selectLocally(_ themeID: String) {
        guard CosmeticCatalog.freeThemeIDs.contains(themeID) else { return }
        selectedThemeID = themeID
        preferences.selectedThemeID = themeID
    }

    private func withSpecialPetNotice(_ message: String) -> String {
        guard displayedPetID != nil, displayedPetID != selectedPetID else { return message }
        return "\(message) Your special companion remains visible."
    }

    private func validated(
        _ catalog: [CosmeticCatalogItem],
        fallback: [CosmeticCatalogItem]
    ) -> [CosmeticCatalogItem] {
        let valid = catalog.filter { !$0.id.isEmpty && !$0.name.isEmpty && $0.priceCoins >= 0 }
        return valid.isEmpty ? fallback : valid
    }

    private static func forcedUITestThemeArgument() -> String? {
        #if DEBUG
            let arguments = ProcessInfo.processInfo.arguments
            guard arguments.contains("--uitesting") else { return nil }

            let value: String?
            if let fixture = ScreenshotFixture.resolve(arguments: arguments) {
                value = fixture.themeID
            } else if let argument = arguments.first(where: { $0.hasPrefix("--ui-test-theme=") }) {
                value = String(argument.dropFirst("--ui-test-theme=".count))
            } else if let index = arguments.firstIndex(of: "--ui-test-theme"),
                arguments.indices.contains(index + 1)
            {
                value = arguments[index + 1]
            } else {
                value = nil
            }

            guard let value, ThemePalette.all.contains(where: { $0.id == value }) else { return nil }
            return value
        #else
            return nil
        #endif
    }
}
