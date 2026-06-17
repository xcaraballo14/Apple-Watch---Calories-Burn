# BurnReward — iOS-Stub Migration Guide

**Why we're doing this:** A watch-only app cannot be uploaded to the App Store / TestFlight
on its own. Apple ships it *inside a minimal iOS "stub" app*. Our current project was
created **without** that iOS stub target, which is why Xcode (and `xcodebuild`) only ever
offered `release-testing / enterprise / debugging` and never **App Store Connect**.

Modern Xcode (15.1+) auto-creates the iOS stub when you make a new watchOS app. So we
recreate the project shell from the current template (gets the stub + correct nested
bundle IDs for free) and migrate our existing source files in. **No code is rewritten** —
every Swift file moves over unchanged.

Nothing on Apple's side needs redoing:
- App Store Connect record `com.burnrewardapp.app` (iOS) is **correct** — it's the stub that registers there.
- Paid team, agreements, Apple Distribution cert: all already in place.

---

## Target structure after migration

| Target | Type | Bundle ID |
|---|---|---|
| **BurnReward** | iOS stub app | `com.burnrewardapp.app` *(must match the ASC record)* |
| **BurnReward Watch App** | watchOS app | `com.burnrewardapp.app.watchkitapp` |
| **BurnRewardComplication** | watchOS Widget Extension | `com.burnrewardapp.app.watchkitapp.complication` |

> The watch app + complication bundle IDs change (they become nested under the iOS stub).
> That's expected and required. The App Group ID does **not** change.

---

## Step 1 — Create the new project shell

1. Xcode → **File → New → Project**
2. **watchOS** tab → **App** → Next
3. Fill in:
   - Product Name: **BurnReward**
   - Team: your paid **Developer Team** (XAVIER OMAR CARABALLO RODRIGUEZ)
   - Organization Identifier: **com.burnrewardapp** (so the stub becomes `com.burnrewardapp.app`)
   - Interface: **SwiftUI**, Language: **Swift**
   - **Leave "Include Complication" unchecked** if offered — we add the widget target manually in Step 4 so it matches our existing code exactly.
4. Save it to a **new temporary folder** (e.g. `~/Desktop/BurnReward-new`). We'll reconcile it with git afterward together.
5. Confirm you got **two targets**: `BurnReward` (iOS) and `BurnReward Watch App` (watchOS). The presence of the iOS target is the whole point.

## Step 2 — Set bundle IDs

Project → each target → Signing & Capabilities → **Automatically manage signing ON**, Team = Developer Team.

- **BurnReward** (iOS): bundle ID = `com.burnrewardapp.app`
- **BurnReward Watch App**: bundle ID = `com.burnrewardapp.app.watchkitapp`

(If the template already used `.watchkitapp`, great — just make sure the iOS one is exactly `com.burnrewardapp.app`.)

## Step 3 — Migrate the Watch App source

Delete the template's placeholder Swift files in the **BurnReward Watch App** group, then
drag these in from the repo (**check "Copy items if needed"** and target = **BurnReward Watch App**):

**Swift (11 files)** — from `BurnReward/BurnReward Watch App/`:
- `BurnRewardApp.swift`  ← this is the `@main` for the watch app (replaces the template's App file)
- `ContentView.swift`
- `PickRewardView.swift`
- `WorkoutView.swift`
- `WorkoutManager.swift`
- `EarnedView.swift`
- `HealthAccessView.swift`
- `WorkoutType.swift`
- `Reward.swift`
- `Theme.swift`
- `PixelButtonStyle.swift`

**Resources:**
- `Assets.xcassets` (contains the AppIcon `icon-1024.png` + AccentColor) → replace the template's Assets
- `Fonts/PressStart2P-Regular.ttf` → add to watch target, confirm it appears in **Build Phases → Copy Bundle Resources**
- `PrivacyInfo.xcprivacy` → add to watch target

> ⚠️ Only **one** `@main` per target. After adding `BurnRewardApp.swift`, delete the template's
> generated `BurnRewardApp`/`...App.swift` if it's a separate file, or you'll get a "multiple @main" error.

## Step 4 — Add the Complication (Widget Extension) target

1. **File → New → Target → watchOS → Widget Extension**
2. Product Name: **BurnRewardComplication**, embed in the **Watch App**
3. **Uncheck** "Include Configuration App Intent" (our widget is a `StaticConfiguration`)
4. Delete the generated placeholder widget Swift file(s), then drag in from `BurnReward/BurnRewardComplication/`:
   - `BurnRewardComplication.swift`
   - `BurnRewardComplicationBundle.swift`  ← the `@main` `WidgetBundle`
5. Confirm bundle ID = `com.burnrewardapp.app.watchkitapp.complication`

## Step 5 — Shared file (both watch + complication)

Drag `BurnReward/Shared/SharedState.swift` in and **check BOTH** targets in the
"Add to targets" panel: **BurnReward Watch App** *and* **BurnRewardComplication**.
(The widget reads the App-Group snapshot this file defines.)

## Step 6 — Capabilities & Info.plist

### Watch App target
**Signing & Capabilities → + Capability:**
- **HealthKit**
- **App Groups** → add `group.com.burnreward.app`

**Info.plist** — add these keys (values from the originals):
- `WKApplication` = YES, `WKWatchOnly` = YES *(template usually sets these)*
- `WKBackgroundModes` = array → `workout-processing`
- `NSHealthShareUsageDescription` = `BurnReward reads your active calories burned, heart rate, and step count to track progress toward your reward goal.`
- `NSHealthUpdateUsageDescription` = `BurnReward saves your workouts to Apple Health.`
- `UIAppFonts` = array → `PressStart2P-Regular.ttf`
- `ITSAppUsesNonExemptEncryption` = NO  *(skips the export-compliance prompt every upload)*

### Complication target
**Signing & Capabilities → + Capability: App Groups** → `group.com.burnreward.app`

### iOS stub target
No special capabilities needed. Leave its default template ContentView — it's a minimal
carrier the user never really interacts with. Deployment target whatever the template set.

## Step 7 — Deployment targets

- Watch App + Complication: **watchOS 10.0** (matches original)
- iOS stub: leave the template default

## Step 8 — Build & verify locally

1. Scheme: **BurnReward Watch App**, destination: your watch (or Any watch Device)
2. **⌘B** — fix any "multiple @main" or missing-file errors (usually a leftover template file)
3. Run on the watch once to confirm it still works (HealthKit prompt, pick reward, etc.)

## Step 9 — Archive & upload (the payoff)

1. Destination: **Any watch Device (arm64)**
2. **Product → Archive**
3. In Organizer → **Distribute App** → **App Store Connect** should now appear ✅
4. Upload → it lands in TestFlight under the existing `com.burnrewardapp.app` record after processing

> If you'd rather use the command line again, the same `xcodebuild -exportArchive` with
> `method = app-store-connect` will now succeed, because the archive finally contains the iOS stub.

---

## Step 10 — Reconcile with git (do this WITH me)

Once it builds and archives, ping me. We'll move the new `.xcodeproj` + reorganized files
back into the repo and commit. The Swift source is byte-identical, so the diff will be
mostly the project file + the new iOS stub folder.

---

## Quick reference — what each file needs

| File / Resource | Watch App | Complication | iOS stub |
|---|:---:|:---:|:---:|
| 11 watch Swift files | ✅ | | |
| `SharedState.swift` | ✅ | ✅ | |
| 2 complication Swift files | | ✅ | |
| `Assets.xcassets` (AppIcon) | ✅ | | |
| `PressStart2P-Regular.ttf` | ✅ | | |
| `PrivacyInfo.xcprivacy` | ✅ | | |
| HealthKit capability | ✅ | | |
| App Group `group.com.burnreward.app` | ✅ | ✅ | |

**App Group ID (unchanged):** `group.com.burnreward.app`
**ASC record (unchanged):** `com.burnrewardapp.app` · Apple ID `6781003526`
