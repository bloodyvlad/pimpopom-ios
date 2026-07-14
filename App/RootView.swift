import PimPoPomCore
import SwiftUI

struct RootView: View {
    let services: AlphaServices

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [Color(red: 0.03, green: 0.07, blue: 0.14), .black],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                VStack(spacing: 24) {
                    Spacer()

                    VStack(spacing: 8) {
                        Text("PimPoPom")
                            .font(.system(size: 48, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                            .minimumScaleFactor(0.75)

                        Text("Native iOS · Bootstrap Alpha")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.65))
                    }

                    VStack(spacing: 14) {
                        modeLink(.arcade, color: .cyan)
                        modeLink(.zen, color: .mint)
                    }

                    Text("Local only · no login · no ads · no purchases")
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.55))
                        .multilineTextAlignment(.center)

                    Spacer()

                    HStack {
                        Text("Build 1")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.white.opacity(0.45))

                        Spacer()

                        Button("Remove Ads") {}
                            .buttonStyle(.bordered)
                            .disabled(services.purchases.availability == .disabledForLocalAlpha)
                            .accessibilityHint("Unavailable in the local bootstrap alpha")
                    }
                }
                .padding(24)
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .tint(.white)
    }

    private func modeLink(_ mode: GameMode, color: Color) -> some View {
        NavigationLink {
            BootstrapGameView(mode: mode, ads: services.ads)
        } label: {
            HStack {
                Text(mode.displayName)
                    .font(.title3.weight(.bold))
                Spacer()
                Image(systemName: "arrow.right")
                    .font(.headline.weight(.bold))
            }
            .foregroundStyle(.black)
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity, minHeight: 58)
            .background(color, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .accessibilityHint("Opens the native gameplay bootstrap screen")
    }
}

private struct BootstrapGameView: View {
    let mode: GameMode
    let ads: any AdServing

    var body: some View {
        ZStack {
            Color(red: 0.03, green: 0.05, blue: 0.10)
                .ignoresSafeArea()

            VStack(spacing: 14) {
                HStack {
                    stat("Score", value: "0")
                    Spacer()
                    stat(mode == .arcade ? "Lives" : "Mode", value: mode == .arcade ? "● ● ●" : "∞")
                }

                VStack(spacing: 16) {
                    Image(systemName: "hammer.fill")
                        .font(.system(size: 42, weight: .bold))
                        .foregroundStyle(.cyan)

                    Text("Gameplay port is next")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.white)

                    Text("This first build proves the project, compact layout, signing, and device installation before the deterministic engine and SpriteKit board are connected.")
                        .font(.body)
                        .foregroundStyle(.white.opacity(0.68))
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(24)
                .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 24, style: .continuous))

                VStack(alignment: .leading, spacing: 7) {
                    HStack {
                        Text("Speed streak")
                        Spacer()
                        Text("1×")
                    }
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white.opacity(0.7))

                    ProgressView(value: 0, total: 5)
                        .tint(.cyan)
                }

                if ads.availability == .disabledForLocalAlpha {
                    Text("Ad service disabled · local alpha")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.48))
                        .frame(maxWidth: .infinity, minHeight: 28)
                        .background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 8))
                        .accessibilityLabel("Ads disabled for local alpha")
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
        .navigationTitle(mode.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color(red: 0.03, green: 0.05, blue: 0.10), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
    }

    private func stat(_ label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .font(.caption2.weight(.bold))
                .foregroundStyle(.white.opacity(0.5))
            Text(value)
                .font(.headline.monospacedDigit())
                .foregroundStyle(.white)
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    RootView(services: .localOnly)
}
