import SwiftUI
import UIKit

enum AdBannerPlacement: String, Sendable {
    case menu
    case activeGameplay
    case results
}

struct AdBannerSlot: View {
    @EnvironmentObject private var ads: AdsController

    let placement: AdBannerPlacement
    var isSurfaceVisible = true

    private var reservesHeight: Bool {
        isSurfaceVisible && ads.reservesBannerSlot
    }

    private var canHostAd: Bool {
        reservesHeight
    }

    var body: some View {
        GeometryReader { proxy in
            if canHostAd {
                BannerContainerRepresentable(
                    controller: ads,
                    availableWidth: proxy.size.width,
                    isEnabled: true
                )
            } else {
                Color.clear
                    .allowsHitTesting(false)
            }
        }
        .frame(
            maxWidth: .infinity,
            minHeight: reservesHeight ? GameplayLayoutMetrics.adBannerHeight : 0,
            maxHeight: reservesHeight ? GameplayLayoutMetrics.adBannerHeight : 0
        )
        .contentShape(Rectangle())
        .allowsHitTesting(canHostAd && ads.canAttachBanner)
        .accessibilityHidden(!reservesHeight)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Advertisement")
        .accessibilityValue(accessibilityValue)
        .accessibilityIdentifier("ad-slot-\(placement.rawValue)")
    }

    private var accessibilityValue: String {
        return switch ads.bannerState {
        case .loaded: "Loaded"
        case .loading: "Loading"
        case .failed: "Unavailable"
        case .unavailable: "Empty"
        }
    }
}

private struct BannerContainerRepresentable: UIViewRepresentable {
    @ObservedObject var controller: AdsController
    let availableWidth: CGFloat
    let isEnabled: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(controller: controller)
    }

    func makeUIView(context _: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        view.clipsToBounds = true
        view.accessibilityIdentifier = "ad-banner-container"
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.pendingAttachment?.cancel()
        uiView.isUserInteractionEnabled = isEnabled && controller.canAttachBanner
        guard isEnabled else {
            controller.detachBanner(from: uiView)
            return
        }
        let controller = controller
        let availableWidth = availableWidth
        context.coordinator.pendingAttachment = Task { @MainActor [weak uiView, weak controller] in
            await Task.yield()
            guard !Task.isCancelled, let uiView, let controller else { return }
            controller.attachBanner(to: uiView, availableWidth: availableWidth)
        }
    }

    static func dismantleUIView(_ uiView: UIView, coordinator: Coordinator) {
        coordinator.pendingAttachment?.cancel()
        coordinator.controller?.detachBanner(from: uiView)
    }

    final class Coordinator {
        weak var controller: AdsController?
        var pendingAttachment: Task<Void, Never>?

        init(controller: AdsController) {
            self.controller = controller
        }

        deinit {
            pendingAttachment?.cancel()
        }
    }
}
