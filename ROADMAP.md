# BurnReward — Roadmap

Living document. Updated as features ship, bugs are filed, and the product evolves.
Legend: ✅ Done · 🔧 In progress · 📋 Planned · 💡 Idea/future

---

## Current State — v1.0 Core (watch-only, runs on device)

Everything below is **built and verified working** on Apple Watch SE (watchOS 10).

| Feature | Status | Notes |
|---|---|---|
| Reward picker (up to 2 rewards) | ✅ | Combo quest supported |
| 20 built-in rewards (150–980 cal) | ✅ | Cookie → Burrito |
| Workout type selector (Walk/Run/Bike/Lift/Other) | ✅ | Maps to correct HKWorkoutActivityType |
| Live calorie tracking (HKWorkoutSession) | ✅ | Active energy, same engine as built-in Workout app |
| Live heart rate tracking | ✅ | |
| Live step counter | ✅ | Via HKLiveWorkoutDataSource |
| EXP progress bar | ✅ | Yellow fill, climbs in real time |
| Haptic milestones at 25 / 50 / 75% | ✅ | |
| Victory screen at 100% | ✅ | Fires correctly |
| Post-workout summary (time, avg HR, calories) | ✅ | |
| Workout saved to Apple Health | ✅ | Attributed to BurnReward |
| Mid-workout relaunch recovery | ✅ | Quest resumes if app is force-closed |
| Watch-face complication | ✅ | Shows quest progress at a glance |
| Pixel-art flame app icon (1024×1024) | ✅ | |
| Privacy Policy / Terms / Data Compliance pages | ✅ | Hosted on GitHub Pages |
| PrivacyInfo.xcprivacy manifest | ✅ | UserDefaults reason CA92.1 |
| App Group (shared state) | ✅ | group.com.burnreward.app |

---

## v1.0.1 — Pre-TestFlight Fix Batch ✅ Shipped

Small polish pass before any external eyes see the app.

| # | Item | Type | Notes |
|---|---|---|---|
| 1 | Remove `+50 CAL` debug button | Bug / cleanup | ✅ Removed (`WorkoutView.swift`), plus the now-unused `simulateBurn()` helper in `WorkoutManager.swift`. It was already `#if DEBUG`-gated so it never shipped to TestFlight/App Store builds, but it's gone from the dev build too now. |
| 2 | Step counter overflows at 4 digits | Bug | ✅ Fixed in `WorkoutView.swift` — `stepsCell` now has `lineLimit(1)` + `minimumScaleFactor` (matching the other stat cells) and abbreviates to e.g. `12.3K` past 9999 steps. |
| 3 | "MAX REACHED · TAP ✓ TO SWAP" header wraps + illegible checkmark | UI | ✅ Fixed in `PickRewardView.swift` — the Unicode `✓` is replaced with an inline `checkmark.circle.fill` SF Symbol, and the header is forced single-line with `minimumScaleFactor` instead of wrapping. |

---

## Phase 2 — TestFlight

### 2a · Internal (you only)
- [ ] Archive and upload first build via Xcode → Product → Archive → Distribute
- [ ] Install via TestFlight on your own watch (proves the full archive→install pipeline)
- [ ] Answer export compliance (BurnReward uses zero encryption → Exempt)

### 2b · Trusted circle (3–5 people)
- [ ] Create external tester group in App Store Connect
- [ ] Generate TestFlight public link
- [ ] Send tester onboarding note (what to try, how to send feedback)
- [ ] Requirement to screen for: **iPhone + Apple Watch on watchOS 10+**

### 2c · Wider beta
- [ ] Expand group once core loop is confirmed bug-free by 2b testers
- [ ] Monitor TestFlight feedback in App Store Connect (built-in: testers can send feedback + screenshots directly from TestFlight)

### Feedback pipeline (when volume justifies it)
- [ ] Wire burnrewardapp@gmail.com Gmail filter → label all app feedback
- [ ] Add Gmail MCP integration to Claude Code session for triage
- [ ] Graduate to GitHub Issues with labels: `bug`, `feature`, `question`, `severity:high/med/low`

---

## Phase 3 — App Store Submission

Checklist (also in `APP_STORE_METADATA.md`):

- [ ] All v1.0.1 fixes shipped in the submitted build
- [ ] Screenshots captured from watch (410×502 px, 4–5 shots — see §7 in metadata)
- [ ] App record created in App Store Connect with bundle ID `com.burnrewardapp.app`
- [ ] All listing copy pasted (description, keywords, promo text — see §4 in metadata)
- [ ] Age rating questionnaire completed → 4+
- [ ] App Privacy questionnaire completed → Health data, not linked, App Functionality
- [ ] Privacy Policy + Support URLs set
- [ ] Submit for Review

---

## v1.x — Post-Launch Watch Improvements

Items to build after the App Store launch, based on real usage and tester feedback.

| # | Item | Priority | Notes |
|---|---|---|---|
| W1 | Expanded reward library | High | Add more food options beyond the 20 launch rewards |
| W2 | Custom reward (user enters any food + calorie count) | High | Power-user feature, often requested |
| W3 | Streak / history screen on watch | Medium | "You've earned 7 rewards this week" |
| W4 | Pause workout mid-session | Medium | Currently no pause, only stop |
| W5 | Expanded workout types (Yoga, HIIT, Swim, Row, etc.) | Low for watch | Better handled in companion app as a "favorites" config |
| W6 | Workout type step accuracy note | Low | Inform user that steps are less meaningful for Bike/Lift/Other |

---

## v2.0 — iOS Companion App

Xavier is designing the companion app. Features below are earmarked for that experience.
*Design handoff pending — no build work starts until designs are shared.*

| # | Feature | Why companion, not watch |
|---|---|---|
| C1 | BurnReward source icon in iPhone Health app | iPhone Health pulls icon from the iOS app bundle; watch-only apps show a blank tile |
| C2 | Full workout history & stats (all-time rewards earned, calories burned, streaks) | Too much data for a watch screen — natural phone territory |
| C3 | Expanded workout type catalog + watch favorites config | HealthKit has 100+ types; phone = config depth, watch = quick 5-chip picker |
| C4 | Custom reward builder (name + calorie count + emoji) | Text input is impractical on the watch |
| C5 | Reward library editor (add / hide / reorder) | Same reason as C4 |
| C6 | Push notifications ("You're 50 cal away from that burrito!") | Phone handles notification scheduling, watch displays |
| C7 | Social / share card ("I earned it 🔥") | Shareable graphic of earned reward + stats |
| C8 | In-app purchases (premium reward packs, themes) | IAP requires iOS app; planned for a later version |

---

## Deferred / Won't Do (v1)

| Item | Reason |
|---|---|
| Manual calorie adjustment by user | Defeats the purpose — BurnReward earns rewards honestly |
| Food/meal logging | Out of scope; BurnReward motivates output, not input |
| Social leaderboards | Privacy-first; adds server dependency |
| Android / Wear OS | Apple Watch + HealthKit is the core tech dependency |

---

*Last updated: 2026-06-16*
