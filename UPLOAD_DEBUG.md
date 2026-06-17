# TestFlight Upload — Debug Log & Morning Plan

**Status as of 2026-06-17 ~2:10 AM:** Upload still failing. Read this first when you wake up.

The new iOS-stub project **builds, runs on the watch simulator perfectly, and now reaches
real App Store Connect validation** — but every upload is rejected with the same core error:

> `Invalid Info.plist value. The value for the key 'DTPlatformName' in bundle
> BurnReward Watch App.app is invalid.` (code 90508)

…plus the cascade it causes: armv7 required (90092), UIDeviceFamily [4] unsupported (90100),
and bundle-id-locked (90055).

---

## What we CONFIRMED tonight (facts, not guesses)

- The new project compiles clean and runs on watchOS 26.5 simulator. The app itself is fine.
- The iOS stub target exists, is `com.burnrewardapp.app`, iPhone-only (`UIDeviceFamily [1]`).
- The watch app is `com.burnrewardapp.app.watchkitapp`, device family 4, `WKApplication = true`,
  `WKCompanionAppBundleIdentifier = com.burnrewardapp.app`, `DTPlatformName = watchos`.
- The "Embed Watch Content" build phase is present and correctly configured.
- Background-mode key was mangled (`"item 0 (String) = workout-processing"`) → **fixed** to
  `workout-processing`.

## What we RULED OUT (things that were NOT the cause)

- **`MinimumOSVersion~ipad = 9.0`** — looked like the smoking gun. We stripped it from the
  archive, re-uploaded, and got the **exact same errors**. It was a red herring.
- **iPad device family on the iOS stub** — set the stub to iPhone-only. No change.
- **The "Embed Watch Content" phase** — present and correct.
- **Deployment targets** — all on watchOS/iOS 26.5, which is fine.

So the real, invariant problem is: **Apple's servers reject `DTPlatformName = watchos`** for
this bundle. The watch binary itself is correct; ASC refuses to classify it as watchOS.

---

## Leading hypothesis (test this first)

**We may have over-corrected.** The ORIGINAL project (this repo) was already a correctly-formed
**standalone watch app**:

| | Original (repo) | New (Desktop/BurnReward-new) |
|---|---|---|
| Watch app bundle ID | `com.burnrewardapp.app` ← matches ASC record | `com.burnrewardapp.app.watchkitapp` |
| Structure | standalone watchOS app | iOS stub + embedded watch app |
| iOS target | none | `com.burnrewardapp.app` stub |

The original watch app's bundle ID **already equaled the ASC record** `com.burnrewardapp.app`.
The reason "App Store Connect" didn't appear in Distribute back then was diagnosed as "missing
iOS stub" — but at that time the **DSA / Apple agreements were not yet accepted** (you accepted
them later). Unaccepted agreements ALSO remove the App Store Connect distribution method. So the
original blocker might have simply been the agreements, not the stub.

If so, the whole iOS-stub migration was a detour, and the clean fix is to archive the original
standalone project now that agreements are active.

---

## Morning plan — do these IN ORDER, stop at the first that works

### Test 1 — Does the ORIGINAL standalone project upload now? (most promising)
1. Open the original project: `~/Desktop/Apple Watch App/Apple-Watch---Calories-Burn/BurnReward/BurnReward.xcodeproj`
2. Confirm Signing & Capabilities is clean (auto-signing, your paid team).
3. Scheme = **BurnReward Watch App**, destination = **Any watchOS Device (arm64)**.
4. Product → Archive.
5. Organizer → Distribute App → **does "App Store Connect" now appear?**
   - If YES → upload. The watch app's bundle ID already matches the ASC record. This is likely the fix.
   - If it uploads cleanly → **done.** The stub was never needed.

### Test 2 — If the standalone upload ALSO says "DTPlatformName invalid"
Then it's an **Xcode 26.5 ↔ App Store Connect SDK-acceptance problem**, not our project:
- Try **Transporter** (already installed) with an exported `.ipa` — sometimes clearer/different.
- If Transporter rejects the same way, ASC simply isn't accepting `watchos26.5`-SDK builds yet.
  Options: install an Xcode version with an older watchOS SDK (e.g. watchOS 11) and archive with
  that, or wait for ASC to update, or open a ticket with Apple Developer Support.

### Test 3 — If you want to keep the iOS-stub project instead
Inspect the exported IPA to see whether the iOS stub is actually the primary payload:
```bash
# After Distribute → App Store Connect → EXPORT (not upload), point this at the exported folder:
find ~/Desktop -name "*.ipa" -newermt "-12 hours" 2>/dev/null
# unzip it and check: Payload/ should contain BurnReward.app with Watch/ inside it,
# NOT "BurnReward Watch App.app" sitting at the Payload root.
```
If the watch app is at the Payload root, the stub isn't being delivered as primary — check
`SKIP_INSTALL` (iOS stub must be NO, watch app YES) and the embed.

---

## Important notes
- The ASC record `com.burnrewardapp.app` (Apple ID 6781003526) is fine — don't delete it.
- All agreements are active. Paid team `334V6U8V7S`. Apple Distribution cert in place.
- The new project lives at `~/Desktop/BurnReward-new` (not yet in git).
- Nothing here requires touching the app's Swift code — it's 100% packaging/distribution.

**Recommendation:** start with Test 1. It's the least work and, in hindsight, the most likely
to just work now that agreements are accepted.
