# TestFlight Phase 2b — Trusted Circle

Reference doc for the external beta launch. Copy-paste ready.

---

## "What to Test" note
*Paste into App Store Connect → TestFlight → Trusted Circle → What to Test (4000 char limit)*

```
BurnReward is a watchOS fitness app that gamifies calorie burning.
Users pick a food reward (e.g. a cookie, a burrito), then complete
a workout on Apple Watch to earn it. The app tracks calories via
HKWorkoutSession (same engine as Apple's built-in Workout app),
shows a real-time EXP progress bar, fires haptic milestones at
25/50/75%, and displays a victory screen at 100%. Workouts are
saved to Apple Health. A watch-face complication shows quest progress.

WHAT TO TRY
• Pick a single reward, then try a combo of two rewards.
• Start each workout type at least once: Walk, Run, Bike, Lift, Other.
• Watch the EXP bar fill in real time as you burn calories.
• Feel for the haptic buzzes at 25%, 50%, and 75% progress.
• Push to 100% and confirm the victory screen fires.
• Check the post-workout summary (time, avg heart rate, calories).
• Confirm the workout shows up in the Apple Health app afterward.
• Add the BurnReward complication to a watch face and check it shows quest progress.
• Force-quit mid-workout, reopen — your quest should resume where you left off.

WHAT I MOST WANT TO KNOW
• Did the calorie count feel accurate vs. the built-in Workout app?
• Was anything confusing on first launch?
• Any crashes, freezes, or text that looked cut off?
• Did the rewards feel motivating, or fall flat?

HOW TO SEND FEEDBACK
In TestFlight, take a screenshot during the app, then tap
"Share Beta Feedback" — that's the fastest path. You can
also email burnrewardapp@gmail.com directly with any bugs,
crashes, or suggestions.

Thanks for testing! 🔥
```

---

## Tester invite message
*Send via iMessage / WhatsApp / email once the companion build clears review.
(The original watch-only invite this replaces predates the iPhone app.)*

```
Hey! I built a fitness game for Apple Watch + iPhone called BurnReward
and I'd love your help testing it 🔥

The idea: pick a food reward (a cookie, a burrito, whatever), then earn it
by burning the calories in a real workout. The iPhone app turns it into a
full RPG — you level up, earn badges, and chase a weekly challenge.

To try it you'll need:
• An iPhone (iOS 17.6 or newer)
• An Apple Watch (Series 4 or later, watchOS 10.6 or newer)
• The free "TestFlight" app from the App Store

Steps:
1. Install TestFlight on your iPhone (App Store, free).
2. Tap this link on your iPhone: https://testflight.apple.com/join/CrWXhAya
3. Accept the invite → install BurnReward on the iPhone → then open the
   Watch app and install it on your watch too (scroll down to find it).
4. Do a quick workout on the watch to earn your first reward — then open
   the iPhone app and watch your XP, level, and badges update.

It's an early beta so expect rough edges — that's exactly what I want to
find. If anything breaks or feels off, screenshot it and let me know (or
use "Share Beta Feedback" right in TestFlight). Takes ~15 min. 🙏
```

---

## Checklist

- [x] External group "Trusted Circle" created in App Store Connect
- [x] Build 2 added to Trusted Circle
- [x] Submitted for Beta App Review (2026-06-20)
- [x] "What to Test" note filled in App Store Connect
- [x] Test Information: contact info filled, Sign-in required unchecked
- [x] Beta App Review approved by Apple (2026-06-20, same day)
- [x] Enable public link in App Store Connect → copy URL
- [x] Public link live: https://testflight.apple.com/join/CrWXhAya
- [ ] **Companion build (29) in Beta App Review** — submitted 2026-07-11,
      pending (Build 2 above was watch-only; first review cleared same-day)
- [ ] Once approved: confirm the new build is assigned to the Trusted Circle
      group, and replace the watch-only "What to Test" with the companion
      version (`APP_STORE_METADATA.md` §8)
- [ ] Send to 3–5 trusted testers: invite message above + `TESTER_GUIDE.md`

---

## Tester requirements

Every tester must have:
- **iPhone** — any model, iOS 17.6 or newer
- **Apple Watch** — Series 4 or later, watchOS 10.6 or newer
- **TestFlight** — free, from the App Store on their iPhone

*Last updated: 2026-07-11 (companion era — invite + checklist refreshed)*
