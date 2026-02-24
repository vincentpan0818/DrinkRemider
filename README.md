# SwiftDrinkReminder

A minimal SwiftUI iOS app project for tracking daily water intake.

## Requirements

- Xcode 15+
- iOS 17.0+
- Swift 5

## Project Structure

- `SwiftDrinkReminder.xcodeproj`: Xcode project file.
- `SwiftDrinkReminder/SwiftDrinkReminderApp.swift`: App entry point.
- `SwiftDrinkReminder/ContentView.swift`: Main screen showing today's water intake.
- `SwiftDrinkReminder/WaterLogModel.swift`: Data model for water logging.
- `SwiftDrinkReminder/Assets.xcassets`: Asset catalog.
- `SwiftDrinkReminder/Info.plist`: App metadata and runtime settings.

## Features

- Visual flow redesigned based on `design/stitch_onboarding_welcome/*` references.
- First-run onboarding flow:
  - Welcome screen
  - Unit selection (`ml` / `oz`)
  - Daily goal setup
  - Optional HealthKit sync setup
- Today dashboard:
  - Circular progress ring with intake + goal state
  - Quick add cards (`+150`, `+250`, `+500`, `+750`)
  - Today's entries list with delete support
- History tab:
  - Last 7 days bar chart
  - Per-day progress rows and average summary
- Settings tab:
  - Update daily goal (500 to 6000 ml)
  - Unit switching (`ml` / `oz`)
  - Enable/disable HealthKit sync
  - Reset today's intake
  - Re-run onboarding
- Local persistence via `UserDefaults` for goal, entries, onboarding status, and HealthKit preference.
- Automatic daily rollover (new day starts from 0 ml intake).

## Open the Project

1. Open `SwiftDrinkReminder.xcodeproj` in Xcode.
2. Select an iOS simulator or a connected device.
3. Run the app.

## Notes

- No build/test command was executed during project creation.
- App icon slots are preconfigured in `AppIcon.appiconset` and ready for image files.
