import SwiftUI
import Charts
#if canImport(UIKit)
import UIKit
#endif

struct ContentView: View {
    @EnvironmentObject private var waterLog: WaterLogModel
    @AppStorage("onboarding.completed") private var onboardingCompleted = false

    var body: some View {
        Group {
            if onboardingCompleted {
                MainAppView(onboardingCompleted: $onboardingCompleted)
            } else {
                OnboardingFlow {
                    onboardingCompleted = true
                }
            }
        }
        .task {
            waterLog.refreshForToday()
        }
    }
}

private struct OnboardingFlow: View {
    @EnvironmentObject private var waterLog: WaterLogModel

    @State private var step = 0
    @State private var selectedUnit: MeasurementUnit = .ml
    @State private var goalML = 2000
    @State private var connectHealthKit = true
    @State private var isSaving = false

    let onComplete: () -> Void

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color.sipBackground, Color.sipCloud], startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    ForEach(0..<4, id: \.self) { index in
                        Capsule()
                            .fill(index <= step ? Color.sipTeal : Color.sipStroke)
                            .frame(width: index == step ? 34 : 8, height: 8)
                    }
                }
                .padding(.top, 18)

                Spacer()

                Group {
                    if step == 0 {
                        welcomeStep
                    } else if step == 1 {
                        unitStep
                    } else if step == 2 {
                        goalStep
                    } else {
                        healthKitStep
                    }
                }
                .padding(.horizontal, 24)

                Spacer()

                VStack(spacing: 12) {
                    Button(step == 3 ? "Get Started" : "Continue") {
                        if step < 3 {
                            step += 1
                        } else {
                            isSaving = true
                            waterLog.setUnit(selectedUnit)
                            waterLog.setDailyGoal(goalML)

                            Task {
                                await waterLog.completeOnboarding(connectHealthKit: connectHealthKit)
                                await MainActor.run {
                                    isSaving = false
                                    onComplete()
                                }
                            }
                        }
                    }
                    .buttonStyle(SipPrimaryButtonStyle())
                    .disabled(isSaving)

                    if step > 0 {
                        Button("Back") {
                            step -= 1
                        }
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 28)
            }
        }
        .animation(.spring(duration: 0.35), value: step)
    }

    private var welcomeStep: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(Color.sipTeal.opacity(0.12))
                    .frame(width: 148, height: 148)
                    .blur(radius: 8)

                RoundedRectangle(cornerRadius: 34)
                    .fill(.white)
                    .frame(width: 124, height: 124)
                    .shadow(color: .black.opacity(0.06), radius: 16, y: 8)
                    .overlay {
                        Image(systemName: "drop.fill")
                            .font(.system(size: 62))
                            .foregroundStyle(Color.sipTeal)
                    }
            }

            Text("Sip")
                .font(.system(size: 44, weight: .heavy, design: .rounded))

            Text("Track hydration effortlessly")
                .font(.title3.weight(.medium))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private var unitStep: some View {
        VStack(spacing: 18) {
            Text("Choose your units")
                .font(.largeTitle.bold())

            Text("You can switch this anytime in Settings")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 14) {
                unitCard(.ml, title: "Metric", subtitle: "Milliliters")
                unitCard(.oz, title: "Imperial", subtitle: "Fluid ounces")
            }
        }
    }

    private func unitCard(_ unit: MeasurementUnit, title: String, subtitle: String) -> some View {
        Button {
            selectedUnit = unit
        } label: {
            VStack(spacing: 10) {
                Text(unit.title.uppercased())
                    .font(.title2.weight(.black))
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 152)
            .background(selectedUnit == unit ? Color.sipTeal.opacity(0.14) : .white)
            .overlay {
                RoundedRectangle(cornerRadius: 24)
                    .stroke(selectedUnit == unit ? Color.sipTeal : Color.sipStroke, lineWidth: selectedUnit == unit ? 2 : 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 24))
        }
        .buttonStyle(.plain)
    }

    private var goalStep: some View {
        VStack(spacing: 20) {
            Text("Set your daily goal")
                .font(.largeTitle.bold())

            Text(displayGoal(goalML))
                .font(.system(size: 56, weight: .black, design: .rounded))
                .contentTransition(.numericText())

            Text("Recommended based on average adult intake")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                goalChip(1500)
                goalChip(2000)
                goalChip(2500)
            }

            HStack(spacing: 14) {
                Button {
                    goalML = max(500, goalML - 100)
                } label: {
                    Image(systemName: "minus")
                        .font(.title3.bold())
                        .frame(width: 52, height: 52)
                        .background(Color.sipCardBackground)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.sipStroke, lineWidth: 1))
                }

                Slider(value: Binding(
                    get: { Double(goalML) },
                    set: { goalML = Int($0.rounded()) }
                ), in: 500...6000, step: 100)
                .tint(.sipTeal)

                Button {
                    goalML = min(6000, goalML + 100)
                } label: {
                    Image(systemName: "plus")
                        .font(.title3.bold())
                        .frame(width: 52, height: 52)
                        .background(Color.sipTeal)
                        .foregroundStyle(.white)
                        .clipShape(Circle())
                }
            }
        }
    }

    private func goalChip(_ amountML: Int) -> some View {
        Button {
            goalML = amountML
        } label: {
            Text(displayGoal(amountML))
                .font(.subheadline.bold())
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(goalML == amountML ? Color.sipTeal : Color.sipCardBackground)
                .foregroundStyle(goalML == amountML ? .white : .primary)
                .clipShape(Capsule())
                .overlay {
                    Capsule().stroke(goalML == amountML ? Color.sipTeal : Color.sipStroke, lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
    }

    private var healthKitStep: some View {
        VStack(spacing: 20) {
            Text("Sync with Apple Health")
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)

            Text("Keep hydration data in one place. You can change this in Settings anytime.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 22) {
                iconBadge(system: "drop.fill", background: .sipTeal)
                Image(systemName: "arrow.left.and.right")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(Color.sipTeal)
                iconBadge(system: "heart.fill", background: .pink)
            }
            .padding(.vertical, 10)

            Toggle("Connect Apple Health", isOn: $connectHealthKit)
                .toggleStyle(.switch)
                .padding()
                .background(Color.sipCardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .overlay {
                    RoundedRectangle(cornerRadius: 18).stroke(Color.sipStroke, lineWidth: 1)
                }
        }
    }

    private func iconBadge(system: String, background: Color) -> some View {
        RoundedRectangle(cornerRadius: 20)
            .fill(background)
            .frame(width: 82, height: 82)
            .overlay {
                Image(systemName: system)
                    .font(.system(size: 36))
                    .foregroundStyle(.white)
            }
            .shadow(color: background.opacity(0.24), radius: 12, y: 7)
    }

    private func displayGoal(_ amountML: Int) -> String {
        selectedUnit == .ml ? "\(amountML) ml" : String(format: "%.1f oz", Double(amountML) / 29.5735)
    }
}

private struct MainAppView: View {
    @EnvironmentObject private var waterLog: WaterLogModel
    @Binding var onboardingCompleted: Bool

    private let adVerticalSpacing: CGFloat = 2
    private let adReservedHeight: CGFloat = 10
    private let tabBarContentHeight: CGFloat = 49

    var body: some View {
        TabView {
            TodayScreen()
                .tabItem {
                    Label("Today", systemImage: "drop.fill")
                }

            HistoryScreen()
                .tabItem {
                    Label("History", systemImage: "chart.bar.fill")
                }

            RemindersScreen()
                .tabItem {
                    Label("Reminder", systemImage: "bell.badge.fill")
                }

            SettingsScreen(onboardingCompleted: $onboardingCompleted)
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Color.clear.frame(height: adReservedHeight + adVerticalSpacing)
        }
        .overlay(alignment: .bottom) {
            GeometryReader { proxy in
                GlobalAdBanner()
                    .frame(height: adReservedHeight)
                    .padding(.horizontal, 10)
                    .padding(.bottom, proxy.safeAreaInsets.bottom + tabBarContentHeight + adVerticalSpacing)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            }
            .allowsHitTesting(false)
        }
    }
}

private struct TodayScreen: View {
    @EnvironmentObject private var waterLog: WaterLogModel
    @State private var isShowingCustomAmountAlert = false
    @State private var customAmountInput = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    progressCard
                    quickAddGrid
                    entriesCard
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 20)
            }
            .background(Color.sipBackground)
            .navigationTitle("Today")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Reset") {
                        waterLog.resetToday()
                    }
                }
            }
        }
    }

    private var progressCard: some View {
        VStack(spacing: 12) {
            Text(Date.now.formatted(.dateTime.weekday(.wide).month().day()))
                .font(.footnote.weight(.bold))
                .foregroundStyle(.secondary)

            ZStack {
                Circle()
                    .stroke(Color.sipStroke, lineWidth: 18)
                    .frame(width: 208, height: 208)

                Circle()
                    .trim(from: 0, to: waterLog.progress)
                    .stroke(
                        AngularGradient(colors: [.sipTeal, .sipMint], center: .center),
                        style: StrokeStyle(lineWidth: 18, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: 208, height: 208)

                VStack(spacing: 6) {
                    Image(systemName: "drop.fill")
                        .foregroundStyle(Color.sipTeal)
                    Text(waterLog.dailyIntakeDisplay)
                        .font(.system(size: 36, weight: .black, design: .rounded))
                    Text("Goal: \(waterLog.dailyGoalDisplay)")
                        .foregroundStyle(.secondary)
                        .font(.subheadline.weight(.medium))
                    Text(waterLog.remainingML == 0 ? "Goal reached" : "\(waterLog.remainingDisplay) left")
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(Color.sipTeal)
                }
            }
            .padding(.vertical, 6)
        }
        .frame(maxWidth: .infinity)
        .padding(18)
        .background(Color.sipCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 26))
        .overlay {
            RoundedRectangle(cornerRadius: 26)
                .stroke(Color.sipStroke, lineWidth: 1)
        }
    }

    private var quickAddGrid: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Quick Add")
                .font(.headline)

            LazyVGrid(columns: [.init(.flexible()), .init(.flexible())], spacing: 10) {
                quickAddButton("Small Glass", icon: "cup.and.saucer.fill", amountML: 150)
                quickAddButton("Regular Cup", icon: "waterbottle.fill", amountML: 250)
                quickAddButton("Bottle", icon: "drop.circle.fill", amountML: 500)
                customAddButton
            }
        }
    }

    private func quickAddButton(_ title: String, icon: String, amountML: Int) -> some View {
        Button {
            waterLog.addWater(amountML)
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(Color.sipTeal)
                Text("+\(waterLog.format(ml: amountML))")
                    .font(.title3.weight(.bold))
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(Color.sipCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .overlay {
                RoundedRectangle(cornerRadius: 18).stroke(Color.sipStroke, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    private var customAddButton: some View {
        Button {
            customAmountInput = ""
            isShowingCustomAmountAlert = true
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundStyle(Color.sipTeal)
                Text("Custom")
                    .font(.title3.weight(.bold))
                Text("Enter amount")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(Color.sipCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .overlay {
                RoundedRectangle(cornerRadius: 18).stroke(Color.sipStroke, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .alert("Custom Water Intake", isPresented: $isShowingCustomAmountAlert) {
            TextField("Amount (ml)", text: $customAmountInput)
                .keyboardType(.numberPad)
            Button("Cancel", role: .cancel) {}
            Button("Confirm") {
                if let amount = Int(customAmountInput), amount > 0 {
                    waterLog.addWater(amount)
                }
            }
        } message: {
            Text("Enter how much water you drank.")
        }
    }

    private var entriesCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Today Entries")
                .font(.headline)

            if waterLog.todayEntries.isEmpty {
                Text("No logs yet. Add your first drink above.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(Color.sipCardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .overlay {
                        RoundedRectangle(cornerRadius: 18).stroke(Color.sipStroke, lineWidth: 1)
                    }
            } else {
                VStack(spacing: 0) {
                    ForEach(waterLog.todayEntries) { entry in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("+\(waterLog.format(ml: entry.amountML))")
                                    .font(.subheadline.weight(.bold))
                                Text(entry.timestamp, style: .time)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button {
                                waterLog.removeEntry(entry.id)
                            } label: {
                                Image(systemName: "trash")
                                    .foregroundStyle(.red)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)

                        if entry.id != waterLog.todayEntries.last?.id {
                            Divider()
                                .padding(.leading, 14)
                        }
                    }
                }
                .background(Color.sipCardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .overlay {
                    RoundedRectangle(cornerRadius: 18).stroke(Color.sipStroke, lineWidth: 1)
                }
            }
        }
    }

}

private struct HistoryScreen: View {
    @EnvironmentObject private var waterLog: WaterLogModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    summaryCard
                    chartCard
                    recentCard
                }
                .padding(16)
                .padding(.bottom, 20)
            }
            .background(Color.sipBackground)
            .navigationTitle("History")
        }
    }

    private var totals: [DailyTotal] {
        waterLog.dailyTotals(lastDays: 7)
    }

    private var summaryCard: some View {
        let averageML = totals.isEmpty ? 0 : totals.map(\.totalML).reduce(0, +) / totals.count

        return VStack(alignment: .leading, spacing: 8) {
            Text("Daily Average")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
            Text(waterLog.format(ml: averageML))
                .font(.system(size: 34, weight: .black, design: .rounded))
            Text("Last 7 days")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Color.sipCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .overlay {
            RoundedRectangle(cornerRadius: 22).stroke(Color.sipStroke, lineWidth: 1)
        }
    }

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Weekly Trend")
                .font(.headline)

            Chart(totals) { item in
                BarMark(
                    x: .value("Day", item.date, unit: .day),
                    y: .value("Amount", waterLog.unit.convertFromML(item.totalML))
                )
                .foregroundStyle(Color.sipTeal.gradient)
                .cornerRadius(6)
            }
            .frame(height: 220)
            .chartYAxis {
                AxisMarks(position: .leading)
            }
        }
        .padding(18)
        .background(Color.sipCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .overlay {
            RoundedRectangle(cornerRadius: 22).stroke(Color.sipStroke, lineWidth: 1)
        }
    }

    private var recentCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Recent Days")
                .font(.headline)

            VStack(spacing: 0) {
                ForEach(Array(totals.reversed())) { item in
                    HStack {
                        Text(item.date, format: .dateTime.weekday(.abbreviated).day())
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        Text(waterLog.format(ml: item.totalML))
                            .font(.subheadline.weight(.bold))
                        Text(percentText(for: item.totalML))
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.secondary)
                            .frame(width: 46, alignment: .trailing)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)

                    if item.id != totals.first?.id {
                        Divider()
                            .padding(.leading, 14)
                    }
                }
            }
            .background(Color.sipCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .overlay {
                RoundedRectangle(cornerRadius: 18).stroke(Color.sipStroke, lineWidth: 1)
            }
        }
    }

    private func percentText(for totalML: Int) -> String {
        guard waterLog.dailyGoalML > 0 else { return "0%" }
        let value = min((Double(totalML) / Double(waterLog.dailyGoalML)) * 100, 999)
        return "\(Int(value.rounded()))%"
    }

}

private struct GlobalAdBanner: View {
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
                Text("Google Ad Placeholder")
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                Text("Fixed above tab bar on all pages")
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
        .background(Color.sipAdOrange)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.25), lineWidth: 1)
        }
    }
}

private struct RemindersScreen: View {
    @EnvironmentObject private var waterLog: WaterLogModel

    @State private var remindersEnabled = false
    @State private var wakeUpTime = Calendar.current.date(from: DateComponents(hour: 8, minute: 0)) ?? .now
    @State private var bedTime = Calendar.current.date(from: DateComponents(hour: 22, minute: 0)) ?? .now
    @State private var selectedFrequency: ReminderFrequency = .smart
    @State private var smartMinutes = 90
    @State private var isSaving = false
    @State private var saveMessage = ""
    @State private var isShowingSaveMessage = false

    private let calendar = Calendar.current

    private var hasUnsavedChanges: Bool {
        remindersEnabled != waterLog.remindersEnabled
            || minutesFromDate(wakeUpTime) != waterLog.reminderWakeMinutes
            || minutesFromDate(bedTime) != waterLog.reminderBedMinutes
            || selectedFrequency != waterLog.reminderFrequency
            || smartMinutes != waterLog.reminderSmartMinutes
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    enableCard
                    savedStateCard
                    scheduleCard
                    frequencyCard
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 20)
            }
            .background(Color.sipBackground)
            .navigationTitle("Reminders")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(hasUnsavedChanges ? "Save" : "Saved") {
                        isSaving = true
                        Task {
                            let success = await waterLog.applyReminderSettings(
                                enabled: remindersEnabled,
                                wakeMinutes: minutesFromDate(wakeUpTime),
                                bedMinutes: minutesFromDate(bedTime),
                                frequency: selectedFrequency,
                                smartMinutes: smartMinutes
                            )

                            await MainActor.run {
                                if success {
                                    saveMessage = "Reminder settings saved"
                                } else {
                                    saveMessage = "Notification permission is required. Enable it in iOS Settings."
                                    remindersEnabled = false
                                }
                                isSaving = false
                                isShowingSaveMessage = true
                            }
                        }
                    }
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.sipReminderBlue)
                        .disabled(isSaving || !hasUnsavedChanges)
                }
            }
            .task {
                remindersEnabled = waterLog.remindersEnabled
                wakeUpTime = dateFromMinutes(waterLog.reminderWakeMinutes)
                bedTime = dateFromMinutes(waterLog.reminderBedMinutes)
                selectedFrequency = waterLog.reminderFrequency
                smartMinutes = waterLog.reminderSmartMinutes
            }
            .alert("Reminders", isPresented: $isShowingSaveMessage) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(saveMessage)
            }
        }
    }

    private var enableCard: some View {
        HStack {
            Text("Enable Reminders")
                .font(.body.weight(.medium))
            Spacer()
            Toggle("", isOn: $remindersEnabled)
                .labelsHidden()
                .tint(.green)
        }
        .padding(16)
        .background(Color.sipCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12).stroke(Color.sipStroke, lineWidth: 1)
        }
    }

    private var savedStateCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("CURRENT SETTING")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(hasUnsavedChanges ? "Not Saved" : "Saved")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background((hasUnsavedChanges ? Color.orange : Color.green).opacity(0.15))
                    .foregroundStyle(hasUnsavedChanges ? Color.orange : Color.green)
                    .clipShape(Capsule())
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(remindersEnabled ? "Reminders On" : "Reminders Off")
                    .font(.subheadline.weight(.bold))
                Text("Window: \(formattedTime(wakeUpTime)) - \(formattedTime(bedTime))")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Text("Frequency: \(frequencyDescription)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(Color.sipCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay {
                RoundedRectangle(cornerRadius: 12).stroke(Color.sipStroke, lineWidth: 1)
            }
        }
    }

    private var scheduleCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SCHEDULE")
                .font(.caption)
                .foregroundStyle(.secondary)

            VStack(spacing: 0) {
                timeRow(
                    title: "Wake Up",
                    systemImage: "sun.max.fill",
                    iconBackground: .orange.opacity(0.16),
                    iconColor: .orange,
                    time: $wakeUpTime
                )

                Divider().padding(.leading, 52)

                timeRow(
                    title: "Bedtime",
                    systemImage: "moon.fill",
                    iconBackground: .indigo.opacity(0.16),
                    iconColor: .indigo,
                    time: $bedTime
                )
            }
            .background(Color.sipCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay {
                RoundedRectangle(cornerRadius: 12).stroke(Color.sipStroke, lineWidth: 1)
            }
        }
    }

    private func timeRow(
        title: String,
        systemImage: String,
        iconBackground: Color,
        iconColor: Color,
        time: Binding<Date>
    ) -> some View {
        HStack {
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 7)
                    .fill(iconBackground)
                    .frame(width: 28, height: 28)
                    .overlay {
                        Image(systemName: systemImage)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(iconColor)
                    }
                Text(title)
                    .font(.body)
            }

            Spacer()

            DatePicker(
                "",
                selection: time,
                displayedComponents: .hourAndMinute
            )
            .labelsHidden()
            .tint(Color.sipReminderBlue)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private var frequencyCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("FREQUENCY")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 6) {
                ForEach(ReminderFrequency.allCases, id: \.self) { value in
                    Button {
                        selectedFrequency = value
                    } label: {
                        Text(value.rawValue)
                            .font(.caption.weight(selectedFrequency == value ? .bold : .medium))
                            .frame(maxWidth: .infinity)
                            .frame(height: 30)
                            .background(selectedFrequency == value ? .white : .clear)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .foregroundStyle(.primary)
                    }
                }
            }
            .padding(4)
            .background(Color(red: 0.89, green: 0.89, blue: 0.91))
            .clipShape(RoundedRectangle(cornerRadius: 10))

            if selectedFrequency == .smart {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "sparkles")
                        .font(.title3)
                        .foregroundStyle(Color.sipReminderBlue)
                        .padding(8)
                        .background(Color.sipReminderBlue.opacity(0.14))
                        .clipShape(Circle())

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Smart interval")
                            .font(.subheadline.bold())
                        Stepper(value: $smartMinutes, in: 1...240, step: 1) {
                            Text("Every \(smartMinutes) minute\(smartMinutes == 1 ? "" : "s")")
                                .font(.footnote.weight(.semibold))
                        }
                        Text("For testing you can set very short intervals.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(12)
                .background(Color.sipCardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay {
                    RoundedRectangle(cornerRadius: 12).stroke(Color.sipStroke, lineWidth: 1)
                }
            }
        }
    }

    private var frequencyDescription: String {
        if selectedFrequency == .smart {
            return "Smart every \(smartMinutes)m"
        }
        return selectedFrequency.rawValue
    }

    private func minutesFromDate(_ date: Date) -> Int {
        let components = calendar.dateComponents([.hour, .minute], from: date)
        let hour = components.hour ?? 0
        let minute = components.minute ?? 0
        return (hour * 60) + minute
    }

    private func dateFromMinutes(_ minutes: Int) -> Date {
        let bounded = min(max(minutes, 0), 1439)
        var components = calendar.dateComponents([.year, .month, .day], from: Date())
        components.hour = bounded / 60
        components.minute = bounded % 60
        return calendar.date(from: components) ?? Date()
    }

    private func formattedTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }
}

private struct SettingsScreen: View {
    @EnvironmentObject private var waterLog: WaterLogModel
    @Binding var onboardingCompleted: Bool

    @State private var draftGoalML = 2000
    @State private var isUpdatingHealthSync = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    goalCard
                    unitCard
                    healthCard
                    appCard
                }
                .padding(16)
                .padding(.bottom, 20)
            }
            .background(Color.sipBackground)
            .navigationTitle("Settings")
            .onAppear {
                draftGoalML = waterLog.dailyGoalML
            }
        }
    }

    private var goalCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Hydration Goal")
                .font(.headline)

            Text(waterLog.format(ml: draftGoalML))
                .font(.system(size: 38, weight: .black, design: .rounded))

            Slider(value: Binding(
                get: { Double(draftGoalML) },
                set: { draftGoalML = Int($0.rounded()) }
            ), in: 500...6000, step: 100)
            .tint(.sipTeal)

            Button("Save Goal") {
                waterLog.setDailyGoal(draftGoalML)
            }
            .buttonStyle(SipPrimaryButtonStyle())
        }
        .padding(18)
        .background(Color.sipCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .overlay {
            RoundedRectangle(cornerRadius: 22).stroke(Color.sipStroke, lineWidth: 1)
        }
    }

    private var unitCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Units")
                .font(.headline)

            Picker("Units", selection: Binding(
                get: { waterLog.unit },
                set: { waterLog.setUnit($0) }
            )) {
                ForEach(MeasurementUnit.allCases, id: \.self) { unit in
                    Text(unit.title.uppercased()).tag(unit)
                }
            }
            .pickerStyle(.segmented)
        }
        .padding(18)
        .background(Color.sipCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .overlay {
            RoundedRectangle(cornerRadius: 22).stroke(Color.sipStroke, lineWidth: 1)
        }
    }

    private var healthCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Apple Health")
                .font(.headline)

            Text(healthStatusText)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Button(waterLog.healthSyncEnabled ? "Disable Health Sync" : "Enable Health Sync") {
                isUpdatingHealthSync = true
                Task {
                    await waterLog.setHealthSyncEnabled(!waterLog.healthSyncEnabled)
                    await MainActor.run {
                        isUpdatingHealthSync = false
                    }
                }
            }
            .font(.headline.bold())
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(waterLog.healthSyncEnabled ? Color.red : Color.sipTeal)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .disabled(isUpdatingHealthSync || waterLog.healthPermissionStatus == .unavailable)
            .opacity((isUpdatingHealthSync || waterLog.healthPermissionStatus == .unavailable) ? 0.55 : 1)
        }
        .padding(18)
        .background(Color.sipCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .overlay {
            RoundedRectangle(cornerRadius: 22).stroke(Color.sipStroke, lineWidth: 1)
        }
    }

    private var appCard: some View {
        VStack(spacing: 10) {
            Button("Reset Today", role: .destructive) {
                waterLog.resetToday()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(18)
        .background(Color.sipCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .overlay {
            RoundedRectangle(cornerRadius: 22).stroke(Color.sipStroke, lineWidth: 1)
        }
    }

    private var healthStatusText: String {
        switch waterLog.healthPermissionStatus {
        case .authorized:
            return "Connected and syncing hydration data"
        case .denied:
            return "Permission denied. You can enable it in iOS Settings."
        case .unavailable:
            return "HealthKit is unavailable on this device."
        case .unknown:
            return "Permission has not been requested yet."
        }
    }
}

private struct SipPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.bold())
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(Color.sipTeal)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

private extension Color {
    static let sipTeal = adaptive(light: Color(red: 0.05, green: 0.72, blue: 0.65), dark: Color(red: 0.07, green: 0.85, blue: 0.93))
    static let sipMint = adaptive(light: Color(red: 0.18, green: 0.84, blue: 0.75), dark: Color(red: 0.11, green: 0.70, blue: 0.82))
    static let sipCloud = adaptive(light: Color(red: 0.93, green: 0.98, blue: 0.97), dark: Color(red: 0.10, green: 0.10, blue: 0.12))
    static let sipBackground = adaptive(light: Color(red: 0.96, green: 0.97, blue: 0.98), dark: Color.black)
    static let sipCardBackground = adaptive(light: Color.white, dark: Color(red: 0.11, green: 0.11, blue: 0.12))
    static let sipStroke = adaptive(light: Color(red: 0.88, green: 0.91, blue: 0.93), dark: Color(red: 0.22, green: 0.22, blue: 0.23))
    static let sipAdOrange = Color(red: 0.96, green: 0.52, blue: 0.16)
    static let sipReminderBlue = adaptive(light: Color(red: 0.08, green: 0.50, blue: 0.93), dark: Color(red: 0.04, green: 0.52, blue: 1.00))

    static func adaptive(light: Color, dark: Color) -> Color {
#if canImport(UIKit)
        return Color(UIColor { trait in
            trait.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        })
#else
        return light
#endif
    }
}

//#Preview {
//    ContentView()
//        .environmentObject(WaterLogModel())
//}
