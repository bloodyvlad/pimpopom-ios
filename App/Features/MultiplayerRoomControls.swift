import SwiftUI
import UIKit

struct MultiplayerRoomSearchView: View {
    let query: String
    let isSearching: Bool
    let theme: ThemePalette
    let onSearch: (String) -> Void

    @State private var text = ""

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Color(hex: theme.chromeAccent))
            TextField("Game code or creator nickname", text: $text)
                .font(theme.appFont(size: 12, weight: .bold, relativeTo: .subheadline))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .onSubmit { onSearch(text) }
                .accessibilityLabel("Search by game code or creator nickname")
                .accessibilityIdentifier("multiplayer-room-search")
            if isSearching {
                ProgressView().tint(Color(hex: theme.chromeAccent))
            }
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color(hex: theme.muted))
                .accessibilityLabel("Clear search")
                .accessibilityIdentifier("multiplayer-search-clear")
            }
        }
        .frame(minHeight: 44)
        .webCardStyle(theme: theme, padding: 10)
        .onAppear { text = query }
        .onChange(of: query) { _, value in
            if text.trimmingCharacters(in: .whitespacesAndNewlines) != value { text = value }
        }
        .onChange(of: text) { _, value in onSearch(value) }
    }
}

struct MultiplayerRoomCodeView: View {
    let code: String
    let isPrivate: Bool
    let theme: ThemePalette

    @State private var copied = false

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 3) {
                Text(isPrivate ? "PRIVATE GAME CODE" : "GAME CODE")
                    .font(theme.appFont(size: theme.legibleSmallCopySize(9), weight: .bold, relativeTo: .caption))
                    .foregroundStyle(Color(hex: theme.muted))
                Text(code)
                    .font(theme.appFont(size: 20, weight: .black, relativeTo: .title3))
                    .tracking(1.5)
                    .foregroundStyle(Color(hex: theme.chromeAccent))
                    .accessibilityIdentifier("multiplayer-room-code")
            }
            Spacer(minLength: 0)
            Button {
                UIPasteboard.general.string = code
                copied = true
            } label: {
                Image(systemName: copied ? "checkmark" : "doc.on.doc")
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(WebSecondaryButtonStyle(theme: theme, minimumHeight: 44))
            .frame(width: 44)
            .accessibilityLabel(copied ? "Game code copied" : "Copy game code")
            .accessibilityIdentifier("multiplayer-copy-code")
            ShareLink(item: "Join my PimPoPom game: \(code). Open Multiplayer and search for this code.") {
                Image(systemName: "square.and.arrow.up")
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(WebSecondaryButtonStyle(theme: theme, minimumHeight: 44))
            .frame(width: 44)
            .accessibilityLabel("Share game code")
        }
        .webCardStyle(theme: theme, padding: 10)
        .onChange(of: code) { copied = false }
    }
}
