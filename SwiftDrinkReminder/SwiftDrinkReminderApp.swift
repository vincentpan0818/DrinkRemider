import AppTrackingTransparency
import GoogleMobileAds
import SwiftUI

@main
struct SwiftDrinkReminderApp: App {
  @StateObject private var waterLog = WaterLogModel()

  var body: some Scene {
    WindowGroup {
      ContentView()
        .environmentObject(waterLog)
        .onReceive(
          NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
        ) { _ in
          requestAppTracking()
        }
    }
  }

  private func requestAppTracking() {
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
      ATTrackingManager.requestTrackingAuthorization { _ in
        DispatchQueue.main.async {
          if AdMobConfiguration.isConfigured {
            MobileAds.shared.start()
          }
        }
      }
    }
  }
}
