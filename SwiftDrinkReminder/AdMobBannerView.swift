import SwiftUI
#if canImport(UIKit)
import UIKit
#endif
#if canImport(GoogleMobileAds)
import GoogleMobileAds
#endif

enum AdMobConfiguration {
    static let appID = Bundle.main.object(forInfoDictionaryKey: "GADApplicationIdentifier") as? String ?? ""
    static let bannerAdUnitID = Bundle.main.object(forInfoDictionaryKey: "AdMobBannerAdUnitID") as? String ?? ""

    static var isConfigured: Bool {
        !appID.isEmpty &&
        !bannerAdUnitID.isEmpty &&
        !appID.contains("YOUR_") &&
        !bannerAdUnitID.contains("YOUR_")
    }
}

struct AdMobBannerView: View {
    var body: some View {
        Group {
#if canImport(GoogleMobileAds)
            if AdMobConfiguration.isConfigured {
                AdMobBannerRepresentable(adUnitID: AdMobConfiguration.bannerAdUnitID)
            } else {
                AdBannerPlaceholder(message: "Set AdMob app ID and banner unit ID")
            }
#else
            AdBannerPlaceholder(message: "Add Google Mobile Ads SDK to enable AdMob")
#endif
        }
        .frame(maxWidth: .infinity)
        .frame(height: 50)
    }
}

private struct AdBannerPlaceholder: View {
    let message: String
    private let placeholderBackground = Color(red: 0.96, green: 0.52, blue: 0.16)

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 10)
                .fill(.white.opacity(0.22))
                .frame(width: 42, height: 42)
                .overlay {
                    Image(systemName: "megaphone.fill")
                        .foregroundStyle(.white)
                        .font(.subheadline)
                }

            VStack(alignment: .leading, spacing: 2) {
                Text("Google AdMob Banner")
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.9))
            }

            Spacer()

            Text("AD")
                .font(.caption2.weight(.black))
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(.white.opacity(0.2))
                .clipShape(Capsule())
                .foregroundStyle(.white)
        }
        .padding(12)
        .background(placeholderBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.25), lineWidth: 1)
        }
    }
}

#if canImport(GoogleMobileAds) && canImport(UIKit)
private struct AdMobBannerRepresentable: UIViewControllerRepresentable {
    let adUnitID: String

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIViewController(context: Context) -> BannerHostingController {
        let controller = BannerHostingController()
        controller.configure(adUnitID: adUnitID, delegate: context.coordinator)
        return controller
    }

    func updateUIViewController(_ uiViewController: BannerHostingController, context: Context) {
        uiViewController.updateBannerSize()
    }

    final class Coordinator: NSObject, BannerViewDelegate {
        func bannerViewDidReceiveAd(_ bannerView: BannerView) {
            print("[AdMob] Banner loaded: \(bannerView.adUnitID ?? "unknown")")
        }

        func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: any Error) {
            print("[AdMob] Banner failed: \(bannerView.adUnitID ?? "unknown") | \(error.localizedDescription)")
        }

        func bannerViewDidRecordImpression(_ bannerView: BannerView) {
            print("[AdMob] Banner impression: \(bannerView.adUnitID ?? "unknown")")
        }

        func bannerViewWillPresentScreen(_ bannerView: BannerView) {
            print("[AdMob] Banner click/open: \(bannerView.adUnitID ?? "unknown")")
        }
    }
}

private final class BannerHostingController: UIViewController {
    private var bannerView: BannerView?
    private var adUnitID = ""
    private weak var bannerDelegate: (any BannerViewDelegate)?

    func configure(adUnitID: String, delegate: any BannerViewDelegate) {
        self.adUnitID = adUnitID
        self.bannerDelegate = delegate
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        loadBannerIfNeeded()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
    }

    func updateBannerSize() {
        guard let bannerView else { return }
        let adSize = AdSizeBanner
        if bannerView.adSize.size.width != adSize.size.width || bannerView.adSize.size.height != adSize.size.height {
            bannerView.adSize = adSize
            bannerView.load(Request())
        }
    }

    private func loadBannerIfNeeded() {
        guard bannerView == nil, !adUnitID.isEmpty else { return }

        let banner = BannerView()
        banner.translatesAutoresizingMaskIntoConstraints = false
        banner.adUnitID = adUnitID
        banner.rootViewController = self
        banner.delegate = bannerDelegate
        view.addSubview(banner)

        NSLayoutConstraint.activate([
            banner.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            banner.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        bannerView = banner
        updateBannerSize()
    }
}
#endif
