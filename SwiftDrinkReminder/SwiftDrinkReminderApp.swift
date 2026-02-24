import SwiftUI

@main
struct SwiftDrinkReminderApp: App {
    @StateObject private var waterLog = WaterLogModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(waterLog)
        }
    }
}
