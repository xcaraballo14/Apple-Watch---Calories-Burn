# BurnReward — App Store Connect Metadata Pack

Everything you paste into App Store Connect lives here. Copy/paste field by field.
Pricing: **Free** at launch (in-app purchases planned for a later version).
Support email: **burnrewardapp@gmail.com**

> **Refreshed 2026-07-09 for the iOS companion; brought current for the
> submission candidate build 1.1 (30) on 2026-07-14** (adds the watch pause
> button, medallion art, live quest card). BurnReward is an **iPhone app with
> a bundled Apple Watch app** — the listing, screenshots, and review notes
> below cover both. The full staged build/submit checklist lives in
> `ROADMAP.md → Phase 3`; this doc is the copy-paste pack.

---

## 1. App Information (App Store Connect → App Information)

| Field | Value |
|---|---|
| **App Name** (30 char max) | `BurnReward` |
| **Subtitle** (30 char max) | `Earn your treats` |
| **Bundle ID** | `com.burnrewardapp.app` |
| **SKU** | `BURNREWARD001` (any unique internal string) |
| **Primary Category** | Health & Fitness |
| **Secondary Category** | Games (reinforces the RPG angle) |
| **Content Rights** | Does not contain third-party content |
| **Age Rating** | 4+ (see Section 5 for the questionnaire answers) |

---

## 2. Pricing & Availability

| Field | Value |
|---|---|
| **Price** | Free (Tier 0) |
| **Availability** | All countries/regions (or restrict if you prefer) |

> **IAP note:** Because you plan in-app purchases later, you'll eventually need to sign the **Paid Applications Agreement** and add tax/banking info in App Store Connect → Agreements. You do **not** need this for a free launch — only when you add your first IAP.

---

## 3. URLs

| Field | Value |
|---|---|
| **Privacy Policy URL** (required) | `https://xcaraballo14.github.io/Apple-Watch---Calories-Burn/privacy-policy.html` |
| **Support URL** (required) | `https://xcaraballo14.github.io/Apple-Watch---Calories-Burn/` |
| **Marketing URL** (optional) | `https://xcaraballo14.github.io/Apple-Watch---Calories-Burn/` |
| **Support email** (in App Review contact + listing) | `burnrewardapp@gmail.com` |

> Support URL must be a webpage, not a `mailto:`. Your GitHub Pages site works and links to the support email in the footer.

---

## 4. Listing Copy

### Promotional Text (170 char max — editable any time without review)
```
Turn every workout into a quest. Pick a treat, burn the calories, earn it guilt-free. Then level up: your Apple Watch and iPhone are now a fitness RPG.
```

### Description (4000 char max)
```
BURNREWARD: SWEAT NOW. FEAST LATER.

Every treat is a quest. Pick the reward you're craving (a burrito, a milkshake, a slice of pizza) and BurnReward turns its calories into an EXP bar. Work out, fill the bar, and earn your treat the honest way.

It's a fitness tracker with the soul of a retro RPG, on your wrist and in your pocket.

HOW IT WORKS
• Pick your reward, or stack two for a combo quest
• Choose your workout: walk, run, bike, lift, or anything
• Start the session and your Apple Watch tracks active calories live
• Feel the haptic milestones at 25%, 50%, and 75%
• Need a breather? Pause the quest and resume right where you left off
• Hit 100% and the victory screen fires. Reward unlocked.

LEVEL UP YOUR EFFORT (iPhone companion)
Every quest earns XP and climbs a title ladder from SNACK ROOKIE to FEAST OVERLORD. The iPhone app is your character sheet:
• A living profile: your level, class affinity, and lifetime totals
• 30 hand-drawn pixel-art badges to earn, each showing its progress so your next goal is always in sight
• Personal records to chase and beat: biggest burn, longest quest, most steps
• A fresh weekly challenge every week, built around precision, not raw burn
• A live quest card: your wrist's workout streams to your phone in real time
• Full quest history with an itemized XP receipt for every workout
• Optional nudges when you're one quest from a level, a badge, or your weekly challenge

PRECISION IS THE SKILL
BurnReward rewards landing close to your goal, not overshooting it. The tighter your finish, the bigger the bonus. Control beats chaos.

BUILT ON HEALTHKIT
• Live calorie and heart-rate tracking from real Apple Watch workout sessions
• Your effort counts toward your Activity rings
• A watch-face complication shows quest progress at a glance
• Forge your own rewards on iPhone. They sync straight to your wrist.

NO GUILT, JUST GAMEPLAY
BurnReward doesn't count what you eat or lecture you about it. Do the work, earn the treat, enjoy it. Rest days never break your progress, and it never pushes you to overdo it.

YOUR DATA STAYS YOURS
Everything is processed on your device. No accounts, no servers, no ads, no tracking. Ever. Your health data never leaves your iPhone and Apple Watch.
```

### Keywords (100 char max, comma-separated, no spaces)
```
fitness,workout,calorie,reward,rpg,badge,level,streak,challenge,exercise,run,walk,quest,treat,game
```
> 98/100 chars. Tune freely — the app name and subtitle already index, so keywords are for the long tail (progression terms like badge/level/streak/challenge are the companion's hooks).

### What's New in This Version (v1.1 — first App Store release)
```
BurnReward arrives on the App Store. Pick a treat, earn it with a real Apple Watch workout, and level up a full RPG on your iPhone: titles, 30 pixel-art badges, personal records, weekly challenges, and an XP receipt for every quest. Pause mid-workout when life interrupts. Everything stays on your device. Sweat now, feast later.
```

---

## 5. Age Rating Questionnaire (answers → results in 4+)

Answer **None / No** to every content category:
- Cartoon or Fantasy Violence: None
- Realistic Violence: None
- Sexual Content or Nudity: None
- Profanity or Crude Humor: None
- Alcohol, Tobacco, or Drug Use: None
- Mature/Suggestive Themes: None
- Horror/Fear Themes: None
- Medical/Treatment Information: **None** (BurnReward is a motivation tool, not medical info — see Terms disclaimer)
- Gambling: No
- Contests: No
- Unrestricted Web Access: No

→ Result: **4+**

---

## 6. App Privacy Questionnaire (App Store Connect → App Privacy)

> ⚠️ **CHANGED — confirm before submitting.** The earlier version of this pack
> declared *Data Collected → Health (not linked)*. That was the conservative
> reading. Apple defines "collect" as **transmitting data off the device** for
> access beyond the real-time request. BurnReward reads HealthKit **on-device
> only**, stores the profile photo locally, and schedules notifications
> locally — **nothing is ever transmitted, and there are no third-party SDKs or
> analytics.** So the accurate answer is **"Data Not Collected."** This is both
> correct under Apple's definition and the strongest version of your privacy
> promise. **Action:** confirm you're comfortable with this, and align
> `data-compliance.html` Section 5 to say the same (it currently mirrors the old
> "collected" declaration).

**Recommended answer — "Data Not Collected":**

- Click path: App Privacy → "Get Started" → **"We do not collect data from this app."**
- Result on your store page: **"Data Not Collected."**

Why it's justified, point by point:
- **Health & workouts** — read from HealthKit, computed and displayed on-device, never sent anywhere. Not collected.
- **Profile photo** — a small JPEG saved in local `UserDefaults`, never uploaded. Not collected.
- **Notifications** — scheduled locally with `UNUserNotificationCenter`. No push server, no token collection.
- **No** identifiers, usage data, diagnostics, location, or contacts are gathered.

> If you'd rather keep the previous conservative declaration (Health → not
> tracking, not linked, App Functionality), that's still *defensible* — but then
> revert the ROADMAP Phase 3 note too, so all three docs agree. Pick one and
> keep them consistent.

### 📅 When social features ship — update this label

The privacy label describes **the version you ship**, not future plans, and you
can edit it anytime with no penalty — so "Data Not Collected" is correct for the
v1 companion even though social is on the roadmap. **Don't pre-declare data you
don't collect yet** (claiming to collect email while the app has no account
misrepresents the current binary).

When the social milestone lands (accounts, friend feed, guilds — CloudKit first;
see the v3 platform vision in ROADMAP.md), update App Privacy for that version to
declare what it *then* actually collects — likely:

- **Contact Info → Email address** (account sign-in). Consider **Sign in with
  Apple** so users can hide their email behind Apple's private relay.
- **User Content** (anything shared to a friend feed / guild).
- **Identifiers** (a user/account ID).
- Purpose: **App Functionality** (and possibly Product Personalization); tracking
  **No** as long as there's no cross-app ad tracking.

**What does NOT change:** the core promise holds — raw HealthKit data still never
leaves the device. Social features are opt-in and account-based, and share
*derived* stats or social content, not workout data. So the label goes from
"Data Not Collected" to "collects Contact Info + User Content **for optional
social, not linked to health data**" — never "uploads your health data." Keep the
description and `privacy-policy.html` in step with the label at that time.

---

## 7. Screenshots (required for submission)

You now need **iPhone** screenshots (primary listing) **and** Apple Watch
screenshots. Capture the iPhone set in the Simulator with sample data:
`-BRSampleData` plus a start flag (`-BRStartOnProfile`, `-BRStartOnHistory`,
`-BRStartOnRewards`, `-BRStartOnAlerts`). Toggle theme with
`xcrun simctl ui <udid> appearance dark|light`.

**iPhone — required size:** one set at 6.9" (1320 × 2868) or 6.7" (1290 × 2796).
Recommended shot list (4–6):
1. **Home** — level card with the "→ next title" gap, weekly challenge card, last-quest hero
2. **Character sheet** — avatar, class affinity, records, trophy case with badge rings
3. **History** — quest log with a 🏆 RECORD stamp and the weekly burn chart
4. **Quest receipt** — the itemized XP breakdown (Base → Intensity → Precision → Total)
5. **Reward Forge** — building a custom reward
6. *(optional)* **Alerts** — the achievement feed behind the bell

**Apple Watch — required size:** 410 × 502 px (Series 4–9 / SE 44–45mm).
Recommended shot list (3–5):
1. **Pick Reward** — food list with one selected
2. **Workout mid-quest** — EXP bar ~60%, live HR + calories
3. **Earned / victory** — celebration with summary stats
4. **Watch-face complication** — the quest gauge
5. *(optional)* combo pick (two rewards)

> Watch capture: **Side button + Digital Crown** together (enable Settings →
> General → Screenshots first); the shot lands in the paired iPhone's Photos.
> Or use the Simulator screenshot button.

---

## 8. TestFlight — "What to Test" (Beta App Info)
```
Thanks for testing BurnReward!

ON YOUR APPLE WATCH: grant Health access when prompted (active energy + heart
rate), then pick a reward and go for a short walk or run to fill the EXP bar and
earn it.

THEN OPEN THE iPHONE APP and check:
• Does your finished quest appear in History with the right calories and XP?
• Do your level / title and the weekly challenge update?
• Do badges show progress, and did any unlock with a celebration?
• Turn on notifications in Settings — do you get an achievement or challenge ping?

BACK ON THE WATCH:
• Does the calorie count climb during a real workout?
• Do you feel the haptic pulses at 25/50/75%?
• Scroll down mid-quest and tap the orange PAUSE button. Does the timer freeze,
  and does RESUME pick up exactly where it stopped? (Check the iPhone too —
  the live quest card should read PAUSED.)
• Does the victory screen show time, avg heart rate, and calories?
• If you close the app mid-workout and reopen it, does the quest resume?
• Does the watch-face complication update?

Report anything weird to burnrewardapp@gmail.com.
```

---

## 9. App Review Notes (Submit for Review → Notes)
```
BurnReward is an iPhone app with a bundled Apple Watch app.

WHAT IT DOES: The user picks a food reward, then burns the matching calories in a
real Apple Watch workout to "earn" it. The iPhone app is the RPG progression
layer (level, titles, badges, personal records, a weekly challenge, and full
quest history), all derived from the workouts the watch saves to Apple Health.

TO TEST:
1. Install on an iPhone paired with an Apple Watch (watchOS 10+).
2. On the watch, tap Allow on the HealthKit prompt (active energy, heart rate,
   workouts, steps), pick a reward, and start a workout. Active calories fill the
   EXP bar; reaching the goal saves the workout to Apple Health and shows a summary.
3. Optional: scroll down on the workout screen and tap the orange PAUSE button.
   The quest freezes (timer stops, session pauses); RESUME continues it, and
   END QUEST abandons it after a confirmation.
4. Open the iPhone app to see that quest in History with its XP, plus your level,
   badges, records, and the weekly challenge updating from it. If the iPhone app
   is open during a watch workout, Home shows a live CURRENT QUEST card
   (it reads PAUSED while the watch is paused).

NOTES:
• The Apple Watch app also runs standalone. Real HealthKit calorie data requires
  actual movement, so a brief walk is needed to see progress on a device.
• HEALTH DATA is processed entirely on-device: no server, no account, no
  third-party SDK, no analytics. HealthKit is read only to compute the user's own
  progress; notifications are scheduled locally. Nothing is transmitted off device.
• No login credentials are required to review the app.

Privacy Policy: https://xcaraballo14.github.io/Apple-Watch---Calories-Burn/privacy-policy.html
```

---

## 10. Pre-Submission Checklist (ASC-paste quick list)

- [ ] Full loop verified on a real iPhone + paired watch (see `ROADMAP.md` → Phase 3a)
- [ ] Apple ID in Xcode with the paid Developer Program active
- [ ] "Automatically manage signing" on for **all** targets (iOS app, watch app, complication)
- [x] Version + build numbers **aligned across all targets** — all three at 1.1 (30), 2026-07-14
- [x] Archive validates clean — build 30 archived + device-verified (pause works) 2026-07-14
- [ ] Bundle IDs correct: app `com.burnrewardapp.app`, complication `com.burnrewardapp.app.widget` (confirm current)
- [x] Build uploaded and processed — 1.1 (30) on internal TestFlight, the submission candidate
- [x] iPhone **and** watch screenshots — Xavier's 8-shot marketing set final (02/08 fixes confirmed 2026-07-14)
- [ ] Listing copy pasted (Section 4)
- [ ] App Privacy completed — "Data Not Collected", confirmed + consistent with `data-compliance.html` (Section 6)
- [ ] Age rating completed (Section 5)
- [ ] Privacy Policy + Support URLs set (Section 3)
- [ ] Submit for Review with the notes in Section 9

> The full staged build → submit → post-approval checklist lives in
> `ROADMAP.md → Phase 3`. This section is the App Store Connect paste companion.

---

*Generated as a submission aid. Pricing, IAP, and tax/banking decisions are yours to finalize in App Store Connect.*
