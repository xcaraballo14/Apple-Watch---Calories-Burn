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
*Send via iMessage / WhatsApp / email once public link is live*

```
Hey! I built a watchOS app called BurnReward and I'd love your help testing it 🔥

The idea: pick a reward (a cookie, a burrito, whatever), then earn it by burning
the calories in a workout. It's a fitness game for your wrist.

To try it you'll need:
• An iPhone (iOS 17.6 or newer)
• An Apple Watch (watchOS 10 or newer)
• The free "TestFlight" app from the App Store

Steps:
1. Install TestFlight on your iPhone (App Store, free).
2. Tap this link on your iPhone: https://testflight.apple.com/join/CrWXhAya
3. Accept the invite → install BurnReward → it'll appear on your watch.
4. Do a quick workout and see if you can earn your reward!

It's an early beta so expect rough edges — that's exactly what I want to find.
If anything breaks or feels off, screenshot it and let me know. Takes 10 min. 🙏
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
- [ ] Send to 3–5 trusted testers (iPhone + Apple Watch on watchOS 10+ required)

---

## Tester requirements

Every tester must have:
- **iPhone** — any model, iOS 17.6 or newer
- **Apple Watch** — Series 4 or later, watchOS 10.0 or newer
- **TestFlight** — free, from the App Store on their iPhone

*Last updated: 2026-06-20*
