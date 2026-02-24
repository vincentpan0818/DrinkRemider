import Foundation
import Combine
import HealthKit
import UserNotifications

struct DrinkEntry: Identifiable, Codable, Hashable {
    let id: UUID
    let amountML: Int
    let timestamp: Date

    init(id: UUID = UUID(), amountML: Int, timestamp: Date = Date()) {
        self.id = id
        self.amountML = amountML
        self.timestamp = timestamp
    }
}

struct DailyTotal: Identifiable, Hashable {
    let date: Date
    let totalML: Int

    var id: Date { date }
}

enum HealthPermissionStatus: String {
    case unknown
    case authorized
    case denied
    case unavailable
}

enum MeasurementUnit: String, CaseIterable, Codable {
    case ml
    case oz

    var title: String {
        switch self {
        case .ml: return "ml"
        case .oz: return "oz"
        }
    }

    func convertFromML(_ value: Int) -> Double {
        switch self {
        case .ml:
            return Double(value)
        case .oz:
            return Double(value) / 29.5735
        }
    }

    func convertToML(_ value: Double) -> Int {
        switch self {
        case .ml:
            return Int(value.rounded())
        case .oz:
            return Int((value * 29.5735).rounded())
        }
    }
}

enum ReminderFrequency: String, CaseIterable, Codable {
    case oneHour = "1h"
    case twoHours = "2h"
    case threeHours = "3h"
    case smart = "Smart"

    func intervalMinutes(smartMinutes: Int) -> Int {
        switch self {
        case .oneHour:
            return 60
        case .twoHours:
            return 120
        case .threeHours:
            return 180
        case .smart:
            return min(max(smartMinutes, 1), 240)
        }
    }
}

enum NotificationPermissionStatus: String {
    case unknown
    case authorized
    case denied
}

@MainActor
final class WaterLogModel: ObservableObject {
    @Published private(set) var dailyIntakeML: Int
    @Published private(set) var dailyGoalML: Int
    @Published private(set) var entries: [DrinkEntry]
    @Published private(set) var healthSyncEnabled: Bool
    @Published private(set) var healthPermissionStatus: HealthPermissionStatus = .unknown
    @Published private(set) var unit: MeasurementUnit
    @Published private(set) var remindersEnabled: Bool
    @Published private(set) var reminderWakeMinutes: Int
    @Published private(set) var reminderBedMinutes: Int
    @Published private(set) var reminderFrequency: ReminderFrequency
    @Published private(set) var reminderSmartMinutes: Int
    @Published private(set) var notificationPermissionStatus: NotificationPermissionStatus = .unknown

    private let defaults: UserDefaults
    private let calendar: Calendar
    private let healthStore = HKHealthStore()
    private let notificationCenter = UNUserNotificationCenter.current()

    private let intakeKey = "water.intakeML"
    private let goalKey = "water.goalML"
    private let logDateKey = "water.logDate"
    private let entriesKey = "water.entries"
    private let healthSyncEnabledKey = "health.sync.enabled"
    private let unitKey = "water.unit"
    private let remindersEnabledKey = "reminders.enabled"
    private let reminderWakeMinutesKey = "reminders.wakeMinutes"
    private let reminderBedMinutesKey = "reminders.bedMinutes"
    private let reminderFrequencyKey = "reminders.frequency"
    private let reminderSmartMinutesKey = "reminders.smartMinutes"

    private let reminderIdentifierPrefix = "hydration.reminder."

    init(defaults: UserDefaults = .standard, calendar: Calendar = .current) {
        self.defaults = defaults
        self.calendar = calendar

        let storedGoal = defaults.integer(forKey: goalKey)
        dailyGoalML = storedGoal > 0 ? storedGoal : 2000
        dailyIntakeML = max(0, defaults.integer(forKey: intakeKey))
        healthSyncEnabled = defaults.bool(forKey: healthSyncEnabledKey)
        unit = MeasurementUnit(rawValue: defaults.string(forKey: unitKey) ?? "ml") ?? .ml
        remindersEnabled = defaults.bool(forKey: remindersEnabledKey)

        let wakeValue = defaults.object(forKey: reminderWakeMinutesKey) as? Int
        reminderWakeMinutes = wakeValue ?? (8 * 60)

        let bedValue = defaults.object(forKey: reminderBedMinutesKey) as? Int
        reminderBedMinutes = bedValue ?? (22 * 60)

        reminderFrequency = ReminderFrequency(rawValue: defaults.string(forKey: reminderFrequencyKey) ?? ReminderFrequency.smart.rawValue) ?? .smart
        let smartValue = defaults.object(forKey: reminderSmartMinutesKey) as? Int
        reminderSmartMinutes = min(max(smartValue ?? 90, 1), 240)

        if let data = defaults.data(forKey: entriesKey),
           let decoded = try? JSONDecoder().decode([DrinkEntry].self, from: data) {
            entries = decoded.sorted { $0.timestamp > $1.timestamp }
        } else {
            entries = []
        }

        refreshHealthPermissionStatus()
        refreshNotificationPermissionStatus()

        rolloverIfNeeded(referenceDate: Date())
        recalculateTodayIntake()
        persist()
    }

    func addWater(_ amountML: Int) {
        guard amountML > 0 else { return }
        rolloverIfNeeded(referenceDate: Date())

        let newEntry = DrinkEntry(amountML: amountML)
        entries.insert(newEntry, at: 0)
        recalculateTodayIntake()
        persist()

        if healthSyncEnabled, healthPermissionStatus == .authorized {
            Task { [weak self] in
                await self?.saveToHealthKit(entry: newEntry)
            }
        }
    }

    func resetToday() {
        rolloverIfNeeded(referenceDate: Date())
        entries.removeAll { calendar.isDateInToday($0.timestamp) }
        recalculateTodayIntake()
        persist()
    }

    func setDailyGoal(_ goalML: Int) {
        let boundedGoal = min(max(goalML, 500), 6000)
        dailyGoalML = boundedGoal
        persist()
    }

    func setUnit(_ newUnit: MeasurementUnit) {
        unit = newUnit
        persist()
    }

    func refreshForToday() {
        rolloverIfNeeded(referenceDate: Date())
        recalculateTodayIntake()
        refreshHealthPermissionStatus()
        persist()
    }

    func removeEntry(_ entryID: UUID) {
        entries.removeAll { $0.id == entryID }
        recalculateTodayIntake()
        persist()
    }

    func dailyTotals(lastDays days: Int) -> [DailyTotal] {
        guard days > 0 else { return [] }

        let today = calendar.startOfDay(for: Date())
        let startDate = calendar.date(byAdding: .day, value: -(days - 1), to: today) ?? today

        let grouped = Dictionary(grouping: entries.filter { $0.timestamp >= startDate }) {
            calendar.startOfDay(for: $0.timestamp)
        }

        return Array((0..<days).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            let total = grouped[day, default: []].reduce(0) { $0 + $1.amountML }
            return DailyTotal(date: day, totalML: total)
        }
        .reversed())
    }

    var todayEntries: [DrinkEntry] {
        entries.filter { calendar.isDateInToday($0.timestamp) }
    }

    func setHealthSyncEnabled(_ enabled: Bool) async {
        if enabled {
            let granted = await requestHealthKitAuthorization()
            healthSyncEnabled = granted
        } else {
            healthSyncEnabled = false
        }
        persist()
    }

    func completeOnboarding(connectHealthKit: Bool) async {
        if connectHealthKit {
            let granted = await requestHealthKitAuthorization()
            healthSyncEnabled = granted
        } else {
            healthSyncEnabled = false
        }
        persist()
    }

    func applyReminderSettings(
        enabled: Bool,
        wakeMinutes: Int,
        bedMinutes: Int,
        frequency: ReminderFrequency,
        smartMinutes: Int
    ) async -> Bool {
        remindersEnabled = enabled
        reminderWakeMinutes = min(max(wakeMinutes, 0), 1439)
        reminderBedMinutes = min(max(bedMinutes, 0), 1439)
        reminderFrequency = frequency
        reminderSmartMinutes = min(max(smartMinutes, 1), 240)
        persist()

        if !enabled {
            await clearScheduledReminders()
            return true
        }

        let granted = await requestNotificationAuthorization()
        guard granted else {
            remindersEnabled = false
            persist()
            return false
        }

        await scheduleReminderNotifications()
        return true
    }

    var progress: Double {
        guard dailyGoalML > 0 else { return 0 }
        return min(Double(dailyIntakeML) / Double(dailyGoalML), 1.0)
    }

    var remainingML: Int {
        max(dailyGoalML - dailyIntakeML, 0)
    }

    var dailyIntakeDisplay: String {
        format(ml: dailyIntakeML)
    }

    var dailyGoalDisplay: String {
        format(ml: dailyGoalML)
    }

    var remainingDisplay: String {
        format(ml: remainingML)
    }

    func format(ml value: Int) -> String {
        switch unit {
        case .ml:
            return "\(value) ml"
        case .oz:
            let ounces = unit.convertFromML(value)
            return String(format: "%.1f oz", ounces)
        }
    }

    private func rolloverIfNeeded(referenceDate: Date) {
        let todayStart = calendar.startOfDay(for: referenceDate)
        let storedDate = defaults.object(forKey: logDateKey) as? Date

        guard let storedDate else {
            defaults.set(todayStart, forKey: logDateKey)
            return
        }

        if !calendar.isDate(storedDate, inSameDayAs: todayStart) {
            defaults.set(todayStart, forKey: logDateKey)
        }
    }

    private func recalculateTodayIntake() {
        dailyIntakeML = todayEntries.reduce(0) { $0 + $1.amountML }
    }

    private func refreshHealthPermissionStatus() {
        guard HKHealthStore.isHealthDataAvailable(),
              let waterType = HKObjectType.quantityType(forIdentifier: .dietaryWater) else {
            healthPermissionStatus = .unavailable
            return
        }

        let status = healthStore.authorizationStatus(for: waterType)
        switch status {
        case .sharingAuthorized:
            healthPermissionStatus = .authorized
        case .sharingDenied:
            healthPermissionStatus = .denied
        case .notDetermined:
            healthPermissionStatus = .unknown
        @unknown default:
            healthPermissionStatus = .unknown
        }
    }

    private func refreshNotificationPermissionStatus() {
        notificationCenter.getNotificationSettings { [weak self] settings in
            Task { @MainActor in
                guard let self else { return }
                switch settings.authorizationStatus {
                case .authorized, .provisional, .ephemeral:
                    self.notificationPermissionStatus = .authorized
                case .denied:
                    self.notificationPermissionStatus = .denied
                case .notDetermined:
                    self.notificationPermissionStatus = .unknown
                @unknown default:
                    self.notificationPermissionStatus = .unknown
                }
            }
        }
    }

    private func requestNotificationAuthorization() async -> Bool {
        let granted = await withCheckedContinuation { continuation in
            notificationCenter.requestAuthorization(options: [.alert, .sound, .badge]) { success, _ in
                continuation.resume(returning: success)
            }
        }
        refreshNotificationPermissionStatus()
        return granted
    }

    private func scheduleReminderNotifications() async {
        await clearScheduledReminders()

        let dates = upcomingReminderDates(
            wakeMinutes: reminderWakeMinutes,
            bedMinutes: reminderBedMinutes,
            intervalMinutes: reminderFrequency.intervalMinutes(smartMinutes: reminderSmartMinutes)
        )

        for fireDate in dates {
            let content = UNMutableNotificationContent()
            content.title = "Time to drink water"
            content.body = "Stay on track with your hydration goal."
            content.sound = .default

            let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let identifier = reminderIdentifierPrefix + String(Int(fireDate.timeIntervalSince1970))
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
            try? await notificationCenter.add(request)
        }
    }

    private func clearScheduledReminders() async {
        let pending = await notificationCenter.pendingNotificationRequests()
        let reminderIDs = pending
            .map(\.identifier)
            .filter { $0.hasPrefix(reminderIdentifierPrefix) }
        notificationCenter.removePendingNotificationRequests(withIdentifiers: reminderIDs)
    }

    private func upcomingReminderDates(
        wakeMinutes: Int,
        bedMinutes: Int,
        intervalMinutes: Int,
        from now: Date = Date(),
        maxCount: Int = 64
    ) -> [Date] {
        guard intervalMinutes > 0 else { return [] }

        var dates: [Date] = []
        let dayStart = calendar.startOfDay(for: now)

        // Generate reminders for the next few days and keep only upcoming ones.
        for dayOffset in 0..<7 {
            guard dates.count < maxCount,
                  let currentDayStart = calendar.date(byAdding: .day, value: dayOffset, to: dayStart) else {
                break
            }

            let dayTimes = reminderTimesForDay(
                wakeMinutes: wakeMinutes,
                bedMinutes: bedMinutes,
                intervalMinutes: intervalMinutes
            )

            for minuteOfDay in dayTimes {
                guard dates.count < maxCount else { break }
                guard let fireDate = calendar.date(byAdding: .minute, value: minuteOfDay, to: currentDayStart) else {
                    continue
                }
                if fireDate > now {
                    dates.append(fireDate)
                }
            }
        }

        return dates.sorted()
    }

    private func reminderTimesForDay(wakeMinutes: Int, bedMinutes: Int, intervalMinutes: Int) -> [Int] {
        guard intervalMinutes > 0 else { return [] }

        var start = wakeMinutes
        var end = bedMinutes

        if start < 0 { start = 0 }
        if start > 1439 { start = 1439 }
        if end < 0 { end = 0 }
        if end > 1439 { end = 1439 }

        var ranges: [(Int, Int)] = []
        if end > start {
            ranges = [(start, end)]
        } else if end < start {
            ranges = [(start, 24 * 60), (0, end)]
        } else {
            ranges = [(0, 24 * 60)]
        }

        var result: [Int] = []
        for (rangeStart, rangeEnd) in ranges {
            var cursor = rangeStart
            while cursor < rangeEnd {
                result.append(cursor)
                cursor += intervalMinutes
            }
        }

        return result
    }

    private func requestHealthKitAuthorization() async -> Bool {
        guard HKHealthStore.isHealthDataAvailable(),
              let waterType = HKObjectType.quantityType(forIdentifier: .dietaryWater) else {
            healthPermissionStatus = .unavailable
            return false
        }

        let granted = await withCheckedContinuation { continuation in
            healthStore.requestAuthorization(toShare: [waterType], read: [waterType]) { success, _ in
                continuation.resume(returning: success)
            }
        }

        refreshHealthPermissionStatus()
        return granted && healthPermissionStatus == .authorized
    }

    private func saveToHealthKit(entry: DrinkEntry) async {
        guard let waterType = HKObjectType.quantityType(forIdentifier: .dietaryWater) else { return }

        let quantity = HKQuantity(unit: .literUnit(with: .milli), doubleValue: Double(entry.amountML))
        let sample = HKQuantitySample(type: waterType, quantity: quantity, start: entry.timestamp, end: entry.timestamp)

        _ = await withCheckedContinuation { continuation in
            healthStore.save(sample) { success, _ in
                continuation.resume(returning: success)
            }
        }
    }

    private func encodedEntries() -> Data? {
        let recentEntries = entries
            .sorted { $0.timestamp > $1.timestamp }
            .prefix(1000)

        return try? JSONEncoder().encode(Array(recentEntries))
    }

    private func persist() {
        defaults.set(dailyIntakeML, forKey: intakeKey)
        defaults.set(dailyGoalML, forKey: goalKey)
        defaults.set(healthSyncEnabled, forKey: healthSyncEnabledKey)
        defaults.set(unit.rawValue, forKey: unitKey)
        defaults.set(remindersEnabled, forKey: remindersEnabledKey)
        defaults.set(reminderWakeMinutes, forKey: reminderWakeMinutesKey)
        defaults.set(reminderBedMinutes, forKey: reminderBedMinutesKey)
        defaults.set(reminderFrequency.rawValue, forKey: reminderFrequencyKey)
        defaults.set(reminderSmartMinutes, forKey: reminderSmartMinutesKey)
        defaults.set(encodedEntries(), forKey: entriesKey)
        defaults.set(calendar.startOfDay(for: Date()), forKey: logDateKey)
    }
}
