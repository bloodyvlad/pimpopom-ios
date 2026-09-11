import SwiftUI

enum GameplayStampKind: Equatable, Sendable {
    case missed, extraLife, slowingDown

    var text: String {
        switch self {
        case .missed: "Missed"
        case .extraLife: "+1UP"
        case .slowingDown: "Slowing down"
        }
    }

    func tone(theme: ThemePalette) -> Color {
        switch self {
        case .missed: Color(hex: theme.tileColors[1])
        case .extraLife: Color(hex: GameHUDMetrics.livesColorHex)
        case .slowingDown: Color(hex: theme.chromeAccent)
        }
    }
}

struct GameplayStampEvent: Equatable, Identifiable, Sendable {
    let id: Int
    let kind: GameplayStampKind
}

/// A short-lived presentation event, never a gameplay timer or input blocker.
struct GameplayStampFeedback: View {
    let event: GameplayStampEvent?
    let theme: ThemePalette
    var identifier = "game-pickup-stamp"
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var visible = false

    var body: some View {
        Group {
            if let event, visible {
                GlowStampView(
                    text: event.kind.text, tone: event.kind.tone(theme: theme),
                    theme: theme, tilt: reduceMotion ? 0 : -4,
                    size: event.kind == .slowingDown ? 22 : 30,
                    horizontalPadding: 18, verticalPadding: 12
                )
                .accessibilityLabel(event.kind.text)
                .accessibilityIdentifier(identifier)
            }
        }
        .allowsHitTesting(false)
        .task(id: event?.id) {
            visible = event != nil
            do { try await Task.sleep(for: .milliseconds(1_500)) } catch { return }
            visible = false
        }
    }
}

struct GameplayLivesHighlight: ViewModifier {
    let event: GameplayStampEvent?
    let theme: ThemePalette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var highlighted = false

    func body(content: Content) -> some View {
        content
            .overlay {
                RoundedRectangle(cornerRadius: theme.isPixel ? 0 : 11)
                    .fill(Color(hex: GameHUDMetrics.livesColorHex).opacity(highlighted ? 0.20 : 0))
                    .overlay {
                        RoundedRectangle(cornerRadius: theme.isPixel ? 0 : 11)
                            .stroke(Color(hex: GameHUDMetrics.livesColorHex).opacity(highlighted ? 1 : 0), lineWidth: 3)
                    }
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
            .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: highlighted)
            .task(id: event?.id) {
                highlighted = event?.kind == .extraLife
                do { try await Task.sleep(for: .milliseconds(1_500)) } catch { return }
                highlighted = false
            }
    }
}
