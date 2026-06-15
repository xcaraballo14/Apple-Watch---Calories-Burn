# BurnReward — Earn Your Treats

> **The fitness RPG for Apple Watch.** Pick a junk-food reward as your quest, burn the matching calories, and actually earn it — guilt-free.

A standalone watchOS app built on HealthKit's live workout APIs. When you pick a reward (e.g. a Chipotle Burrito at 980 cal), the app creates an `HKWorkoutSession`, tracks your active energy in real time via `HKLiveWorkoutBuilder`, and fills an EXP bar against your goal. Hit 100% — the victory haptic fires, your workout saves to Apple Health, and the reward is yours.

---

## Requirements

| Tool | Version |
|---|---|
| Xcode | 15.0+ |
| watchOS deployment target | 10.0 |
| Swift | 5.9+ |
| Apple Watch (physical device) | Series 4 / SE or newer (watchOS 10+) |
| Apple Developer Program | Required to install on a real watch |

> The Watch Simulator does not generate real calorie data. A `#if DEBUG` button is included to simulate burns for UI testing.

---

## Project Structure

```
Apple-Watch---Calories-Burn/
├── index.html                        Landing page (GitHub Pages)
├── privacy-policy.html               Privacy Policy (App Store required URL)
├── terms.html                        Terms & Conditions
├── data-compliance.html              Full data-use & regulatory reference
│
└── BurnReward/
    ├── BurnReward.xcodeproj/
    │
    ├── BurnReward Watch App/         ← Main watchOS target
    │   ├── BurnRewardApp.swift       App entry point + EnvironmentObject injection
    │   ├── ContentView.swift         Phase router: picking → workout → earned
    │   ├── WorkoutManager.swift      HealthKit engine, state machine, persistence
    │   ├── Reward.swift              Reward model + 20-food allRewards list
    │   ├── WorkoutType.swift         Walk/Run/Bike/Strength/Other → HKWorkoutActivityType
    │   ├── PickRewardView.swift      Food picker (up to 2 combo rewards, workout type)
    │   ├── WorkoutView.swift         Live EXP bar, HR, elapsed time, calorie counter
    │   ├── EarnedView.swift          Victory screen with workout summary stats
    │   ├── HealthAccessView.swift    Error screen when HealthKit access is denied
    │   ├── Theme.swift               Color palette, pixel font, ScanlineOverlay
    │   ├── PixelButtonStyle.swift    Press-down pixel button style
    │   ├── Info.plist                WKWatchOnly=TRUE, HealthKit usage strings
    │   └── BurnReward_Watch_App.entitlements
    │
    ├── BurnRewardComplication/       ← WidgetKit watch-face complication target
    │   ├── BurnRewardComplication.swift      Complication view (emoji + calorie arc)
    │   ├── BurnRewardComplicationBundle.swift Widget configuration
    │   └── Info.plist
    │
    └── Shared/
        └── SharedState.swift         BurnRewardSnapshot + App Group helpers
```

---

## How to Build

1. **Clone the repo** and open `BurnReward/BurnReward.xcodeproj` in Xcode.
2. **Set your Team** — select your Apple Developer account in Signing & Capabilities for both targets (`BurnReward Watch App` and `BurnRewardComplication`).
3. **Check the App Group** — both targets share `group.com.burnreward.app`. If you use a different bundle ID prefix, update the App Group identifier in both entitlements files and in `SharedState.swift`.
4. **Select your Apple Watch** as the run destination.
5. **Build & Run** (`⌘R`). On first launch the HealthKit permission sheet appears — tap **Allow** to enable live calorie and heart rate tracking.

### Simulator testing

The Watch Simulator can't generate real HealthKit data. In debug builds a **+50 CAL** button appears on the workout screen to simulate calorie burns and test the full flow.

---

## App Flow

```
[Pick Reward Screen]
    • Choose up to 2 combo rewards (sorted by calories, sequential milestones)
    • Select workout type: Walk / Run / Bike / Lift / Other
    • Tap SET GOAL ▶
            │
            ▼
[Workout Screen]  ←── live HealthKit data
    • EXP bar fills as active calories accumulate
    • Haptic pulses at 25 / 50 / 75% progress
    • Intermediate milestone fires notification haptic + flash
    • HR and elapsed time shown live
            │  (100% reached)
            ▼
[Earned Screen]
    • Victory haptic + success sound
    • Workout saved to Apple Health
    • Summary: total time · avg heart rate · calories burned
    • Tap NEW QUEST to start over
```

---

## Key Technical Details

### HealthKit
- `HKWorkoutSession` + `HKLiveWorkoutBuilder` — the session keeps the watch sensors at full fidelity and appears as a live workout in the Control Center ring.
- `HKLiveWorkoutBuilderDelegate.workoutBuilder(_:didCollectDataOf:)` delivers calorie and HR updates; both are dispatched to `@MainActor` to update the UI.
- Completed workouts are saved to Apple Health via `builder.finishWorkout()` at the moment all rewards are earned.
- `healthStore.recoverActiveWorkoutSession` is called on launch to re-attach to a session still running after the app was backgrounded or killed.

### State Persistence
Everything is persisted to `UserDefaults` (standard) on every state change so a mid-workout relaunch lands right back where it left off. Keys:

| Key | What it stores |
|---|---|
| `br.activeRewardIDs` | Selected reward names (stable String IDs) |
| `br.phase` | `"workout"` or `"earned"` |
| `br.caloriesBurned` | Running calorie total |
| `br.earnedCount` | Combo milestones cleared |
| `br.startDate` | Workout start timestamp (for elapsed timer) |
| `br.summaryDuration` | Frozen workout length (seconds) |
| `br.summaryAvgHR` | Frozen average BPM |
| `br.summaryCalories` | Frozen total calories |

### Watch-Face Complication
A WidgetKit extension reads a `BurnRewardSnapshot` (isActive, emoji, caloriesBurned, totalGoal) from the shared App Group (`group.com.burnreward.app`) and renders a circular gauge on the watch face. The app calls `WidgetCenter.shared.reloadAllTimelines()` on every state change to keep it current.

### Design System
- **Font:** Press Start 2P (Google Fonts, SIL Open Font License)
- **Palette:** defined in `Theme.swift` — green `#00ff88`, yellow `#ffd700`, orange `#ff6b35`, red `#ff2244`, blue `#00aaff`
- **ScanlineOverlay:** Canvas-drawn CRT effect; intentionally scoped to the Earned screen only

---

## Reward List

20 foods sorted ascending by calories:

| Emoji | Reward | Calories |
|---|---|---|
| 🍪 | Chocolate Chip Cookie | 150 |
| 🌮 | Taco | 180 |
| 🍦 | Ice Cream Cone | 230 |
| 🥤 | Soda (20 oz) | 240 |
| 🍫 | Brownie | 250 |
| 🍩 | Donut | 270 |
| 🧁 | Cupcake | 300 |
| 🧋 | Bubble Tea (Boba) | 330 |
| 🍟 | French Fries | 365 |
| 🥐 | Cinnamon Roll | 380 |
| ☕ | Starbucks Frappuccino | 390 |
| 🍕 | Pizza Slice | 400 |
| 🧀 | Mac & Cheese Bowl | 420 |
| 🍗 | Chicken Wings | 440 |
| 🥪 | Chicken Sandwich | 490 |
| 🍜 | Ramen Bowl | 500 |
| 🥛 | Milkshake | 530 |
| 🍔 | Cheeseburger | 550 |
| 🌽 | Nachos | 590 |
| 🌯 | Chipotle Burrito | 980 |

---

## Legal

All three pages are hosted on GitHub Pages alongside the landing page.

- [Privacy Policy](privacy-policy.html) — Required URL for App Store submission
- [Terms & Conditions](terms.html)
- [Data & Compliance](data-compliance.html) — Full HealthKit data inventory and regulatory reference (GDPR, CCPA, COPPA, HIPAA, App Store nutrition label answers)

**Short version:** BurnReward processes health data (active energy, heart rate, workouts) entirely on-device. No servers. No analytics. No data sold. HealthKit data is used only to track the user's current quest.

---

## Roadmap

- [ ] iOS companion app (WatchConnectivity sync — design in progress)
- [ ] Custom reward creation (user-defined food name + calorie value)
- [ ] Workout history / earned log
- [ ] Friend challenges (share a quest link)
- [ ] Streak tracking

---

## License

© 2025 Xavier Caraballo. All rights reserved.

The app code in this repository is not open-source. The Press Start 2P font is used under the [SIL Open Font License 1.1](https://scripts.sil.org/OFL).
