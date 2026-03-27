import SwiftUI
#if canImport(GoogleMobileAds)
import GoogleMobileAds
#endif

@main
struct SwiftDrinkReminderApp: App {
    @StateObject private var waterLog = WaterLogModel()

    init() {
#if canImport(GoogleMobileAds)
        if AdMobConfiguration.isConfigured {
            MobileAds.shared.start()
        }
#endif
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(waterLog)
        }
    }
}
