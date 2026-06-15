# BurnReward — App Store Connect Metadata Pack

Everything you paste into App Store Connect lives here. Copy/paste field by field.
Pricing: **Free** at launch (in-app purchases planned for a later version).
Support email: **burnrewardapp@gmail.com**

---

## 1. App Information (App Store Connect → App Information)

| Field | Value |
|---|---|
| **App Name** (30 char max) | `BurnReward` |
| **Subtitle** (30 char max) | `Earn your treats` |
| **Bundle ID** | `com.burnrewardapp.watch` |
| **SKU** | `BURNREWARD001` (any unique internal string) |
| **Primary Category** | Health & Fitness |
| **Secondary Category** | Games (optional — reinforces the RPG angle) |
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

> Support URL technically must be a webpage, not a `mailto:`. Your GitHub Pages site works, and it links to the support email in the footer. If you'd rather have a dedicated support page, say the word and I'll add `support.html`.

---

## 4. Listing Copy

### Promotional Text (170 char max — editable any time without review)
```
Turn every workout into a quest. Pick a treat, burn the calories, earn it guilt-free. Your Apple Watch is now a fitness RPG.
```

### Description (4000 char max)
```
BURNREWARD — SWEAT NOW. FEAST LATER.

Every treat is a quest. Pick the reward you're craving — a burrito, a milkshake, a slice of pizza — and BurnReward turns its calories into an EXP bar on your wrist. Work out, fill the bar, and earn your treat the honest way.

It's a fitness tracker with the soul of a retro RPG.

HOW IT WORKS
• Pick your reward (or stack up to two for a combo quest)
• Choose your workout: walk, run, bike, lift, or anything
• Start the session — your Apple Watch tracks active calories live
• Watch the EXP bar climb with satisfying haptic milestones at 25%, 50%, and 75%
• Hit 100% and the victory screen fires — reward unlocked

BUILT FOR APPLE WATCH
• Live calorie and heart-rate tracking powered by HealthKit
• Real workout sessions — your effort counts toward your Activity rings
• A watch-face complication shows your quest progress at a glance
• A full workout summary when you finish: time, average heart rate, calories
• Pick up right where you left off if you close the app mid-workout

NO GUILT, JUST GAMEPLAY
BurnReward doesn't count what you eat or lecture you about it. It flips the script: do the work, earn the treat, enjoy it. Simple, motivating, and a little bit fun.

20 built-in rewards from a 150-calorie cookie to a 980-calorie burrito — pick your quest and get moving.

Your health data stays on your device. No accounts, no servers, no ads, no tracking. Ever.
```

### Keywords (100 char max, comma-separated, no spaces)
```
fitness,workout,calorie,reward,rpg,gamify,health,exercise,run,walk,motivation,treat,burn,goal,quest
```

### What's New in This Version (for v1.0)
```
First release. Pick a reward, burn the calories, earn your treat. Welcome to the quest.
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

Click path: "Get Started" → for each data type below.

**Do you collect data? → YES** (you collect Health data, even though it stays on-device and powers the app).

Add ONE data type:

| Question | Answer |
|---|---|
| Data type | **Health** (under "Health & Fitness") |
| Is this data used to track you? | **No** |
| Is this data linked to the user's identity? | **No** |
| Purpose | **App Functionality** |

Then for Fitness (heart rate / workouts), if prompted separately, same answers: **Fitness → not tracking, not linked, App Functionality.**

Everything else (Contact Info, Identifiers, Usage Data, Diagnostics, Location, etc.): **Not Collected.**

> This matches the declarations in `data-compliance.html` Section 5. Net result on your store page: "Data Not Linked to You: Health & Fitness."

---

## 7. Screenshots (required for submission)

watchOS App Store screenshots. You need at least one set. Capture on a 45mm-class watch (your SE 44mm is fine) or in the Simulator.

**Required size (Apple Watch):** 410 × 502 px (Series 4–9 / SE 44–45mm). App Store Connect accepts this size for all modern watches.

**Recommended shot list (capture 4–5):**
1. **Pick Reward screen** — the food list with one selected (shows the core hook)
2. **Workout screen mid-quest** — EXP bar ~60%, live HR and calories visible
3. **Earned/victory screen** — the celebration with the summary stats
4. **Watch-face complication** — your face showing the quest gauge
5. *(optional)* The combo pick (two rewards selected)

> How to capture: on the watch, press **Side button + Digital Crown** together; the screenshot saves to the paired iPhone's Photos. (Enable Settings → General → Screenshots on the watch first.) Or use the Simulator's screenshot button.

---

## 8. TestFlight — "What to Test" (Beta App Info)
```
Thanks for testing BurnReward!

Please grant Health access when prompted (active energy + heart rate),
then start a quest and go for a short walk or run to see the EXP bar fill.

What to check:
• Does the calorie count climb during a real workout?
• Do you feel the haptic pulses at 25/50/75%?
• Does the victory screen show your time, avg heart rate, and calories?
• If you close the app mid-workout and reopen it, does the quest resume?
• Does the watch-face complication update?

Report anything weird to burnrewardapp@gmail.com.
```

---

## 9. App Review Notes (Submit for Review → Notes)
```
BurnReward is a standalone watchOS fitness app (no iPhone app required).

TO TEST:
1. Launch on an Apple Watch (watchOS 10+).
2. Tap "Allow" on the HealthKit permission prompt (active energy, heart rate, workouts).
3. Pick a reward and tap SET GOAL to start a workout session.
4. Active calories from a real workout fill the EXP progress bar. Reaching the
   goal saves the workout to Apple Health and shows a summary.

NOTE ON SIMULATING DATA: HealthKit calorie data requires real movement, so a
brief walk is needed to see progress on a physical device.

HEALTH DATA: All health data is processed on-device only. There is no server,
no account, and no third-party SDK. HealthKit data is used solely to track the
user's calorie-burn goal. See Privacy Policy:
https://xcaraballo14.github.io/Apple-Watch---Calories-Burn/privacy-policy.html

No login credentials are required to review the app.
```

---

## 10. Pre-Submission Checklist

- [ ] Phase 1 done: app runs on your physical watch via Xcode, real calories tracked
- [ ] Apple ID added to Xcode with the paid Developer Program active
- [ ] "Automatically manage signing" on for both targets (app + complication)
- [ ] Archive validates clean (Product → Archive → Validate App)
- [ ] App record created in App Store Connect with bundle ID `com.burnrewardapp.watch`
- [ ] Build uploaded and processed (appears in TestFlight)
- [ ] Tested via TestFlight on your own watch
- [ ] Screenshots captured (Section 7)
- [ ] All listing copy pasted (Section 4)
- [ ] App Privacy questionnaire completed (Section 6)
- [ ] Age rating completed (Section 5)
- [ ] Privacy Policy + Support URLs set (Section 3)
- [ ] Submit for Review

---

*Generated as a submission aid. Pricing, IAP, and tax/banking decisions are yours to finalize in App Store Connect.*
