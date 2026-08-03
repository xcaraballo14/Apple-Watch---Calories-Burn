# BurnReward — App Store Connect Metadata Pack

Everything you paste into App Store Connect lives here. Copy/paste field by field.
Pricing: **Free** at launch (in-app purchases planned for a later version).
Support email: **burnrewardapp@gmail.com**

> ## ⚠️ Rewritten 2026-07-28 for the social pivot + the aperture fix
>
> The previous version of this pack was written for a watch-only, account-free,
> nothing-leaves-the-device app. **Three of its answers were false and would have
> drawn a rejection or a misrepresentation problem:**
>
> 1. The description sold *"No accounts, no servers… your health data never leaves
>    your iPhone and Apple Watch."* The app now has accounts, a Supabase backend,
>    and consent-based sharing of calories and heart rate.
> 2. App Privacy was answered **"Data Not Collected."** It now collects Health &
>    Fitness, User Content, Identifiers, and Contact Info — all Linked to You.
> 3. Age rating was **4+** with a photo feed shipping. User-generated content
>    changes the questionnaire.
>
> All three are corrected below. Scope and dates: `LAUNCH_SCOPE.md`.
> Staged submit checklist: `ROADMAP.md → Phase 3` (⚠️ itself stale — reconcile
> before submitting). The label here mirrors `data-compliance.html` §5 exactly;
> if you edit one, edit both.

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
| **Age Rating** | ⚠️ **No longer 4+** — walk the questionnaire, see Section 5 |

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

> ⚠️ **The privacy policy at that URL is currently the OLD one.** The rewrite is
> committed (`77ed0cf`) but **unpushed**, so GitHub Pages still serves
> *"nothing leaves your device."* Submitting while that page is live means your
> stated policy contradicts your own privacy label. **Push before you submit.**

---

## 4. Listing Copy

### Promotional Text (170 char max — editable any time without review)
```
Turn every workout into a quest. Pick a treat, burn the calories, earn it guilt-free. Level up, and bring your party along for the ride.
```

### Description (4000 char max)
```
BURNREWARD: SWEAT NOW. FEAST LATER.

Every treat is a quest. Pick the reward you're craving (a burrito, a milkshake, a slice of pizza) and BurnReward turns its calories into an EXP bar. Work out, fill the bar, and earn your treat the honest way.

It's a fitness tracker with the soul of a retro RPG, on your wrist and in your pocket.

HOW IT WORKS
• Pick your reward, or stack two for a combo quest
• Start a quest on your Apple Watch and watch active calories fill the bar live
• Feel the haptic milestones at 25%, 50%, and 75%
• Need a breather? Pause the quest and resume right where you left off
• Hit 100% and the victory screen fires. Reward unlocked.

EVERY WORKOUT COUNTS
You don't have to change how you train. BurnReward reads your workout history from Apple Health, so sessions recorded by your Apple Watch, your iPhone, or the fitness apps and devices you already use all earn XP, feed your streak, and count toward your weekly challenge.

LEVEL UP YOUR EFFORT
Every workout earns XP and climbs a title ladder from SNACK ROOKIE to FEAST OVERLORD. The iPhone app is your character sheet:
• A living profile: your level, class affinity, and lifetime totals
• 30 hand-drawn pixel-art badges to earn, each showing its progress so your next goal is always in sight
• Personal records to chase and beat: biggest burn, longest quest, most steps
• A fresh weekly challenge every week, built around precision, not raw burn
• A live quest card: your wrist's workout streams to your phone in real time
• Full quest history with an itemized XP receipt for every workout

BRING YOUR PARTY
Sign in and the game opens up:
• Add friends and form a party
• Share quests, badges, level-ups, and workouts — with photos
• React with BURN, STRONG, LEGEND, and RESPECT
• Enter the ARENA: a weekly XP duel with your whole party
• Open character sheets — see a friend's level, records, and trophy case

Ranked by XP, never by raw calories or heart rate. The board rewards skill and consistency, not who pushed hardest.

PRECISION IS THE SKILL
BurnReward rewards landing close to your goal, not overshooting it. The tighter your finish, the bigger the bonus. Control beats chaos.

BUILT ON HEALTHKIT
• Live calorie and heart-rate tracking from real Apple Watch workout sessions
• Your effort counts toward your Activity rings
• A watch-face complication shows quest progress at a glance
• Forge your own rewards on iPhone. They sync straight to your wrist.

NO GUILT, JUST GAMEPLAY
BurnReward doesn't count what you eat or lecture you about it. Do the work, earn the treat, enjoy it. Rest days never break your progress, and it never pushes you to overdo it.

YOUR DATA, YOUR CALL
• Playing solo needs no account at all — the whole quest loop works offline
• Social is opt-in. You decide when to sign in and what your party can see
• Go private any time, block anyone, and delete your account from inside the app
• We never sell your health data, never hand it to sponsors or advertisers, and never use it for ad targeting
```

> **On naming other services:** the EVERY WORKOUT COUNTS section deliberately says
> *"the fitness apps and devices you already use"* rather than listing Strava,
> Garmin, or Oura by name. It's the same claim without stacking competitor
> trademarks into your listing, and it doesn't age badly if a vendor changes how
> they write to Health. Name them freely in marketing outside the App Store.

### Keywords (100 char max, comma-separated, no spaces)
```
fitness,workout,calorie,reward,rpg,badge,level,streak,challenge,friends,compete,quest,leaderboard
```
> 97/100 chars. Swapped `run,walk,treat,exercise` out for `friends,compete,leaderboard` — the app name and subtitle already index the treat/reward angle, and the social terms are the new long tail.

### What's New in This Version (v1.0 — first App Store release)
```
BurnReward arrives on the App Store. Pick a treat, earn it with a real workout, and level up a full RPG: titles, 30 pixel-art badges, personal records, weekly challenges, and an XP receipt for every quest. Every workout in Apple Health counts, whatever recorded it. Then bring your party — share your wins with photos, react to theirs, and duel them for weekly XP in the ARENA. Sweat now, feast later.
```

---

## 5. Age Rating Questionnaire

> ⚠️ **This changed. The old pack answered every category "None" and landed on
> 4+ — that was written before the app had a photo feed.** BurnReward now carries
> **user-generated content**: profile usernames, post captions, and up to three
> user-supplied photos per post, visible to other players.

**What you must declare:** the questionnaire asks whether the app contains or
allows user-generated content, and whether it includes social/interaction
features. Answer **yes** to both, then answer the moderation follow-ups. Do not
answer "None" across the board the way the old pack said.

**Your moderation story is genuinely strong — have it ready:**

- A closed reaction palette (BURN / STRONG / LEGEND / RESPECT) — **no free-text
  comments and no DMs**, so there is no open messaging surface at all
- Caption wordlist filter + URL stripper (`CaptionFilter.swift`)
- On-device Sensitive Content Analysis on picked photos
- In-app **report** on every post, with a written-off `reports` table
- In-app **block**, which darkens feed, photos, profile, and reactions both ways
- A `share_events.hidden` kill switch for take-downs
- Friends-only visibility — nothing is public, and party membership is mutual

That set is what Guideline 1.2 asks for (filter, report, block, act on reports,
publish a contact) and you have all of it.

**Expected result: 13+.** A social app with user-generated photos does not stay
at 4+. Treat that as the planning number, not gospel — Apple reworked the rating
tiers and questionnaire, App Store Connect recalculates the rating from your
answers automatically, and the live questionnaire is the authority. **Walk it in
ASC and record the actual result here.**

- [ ] Actual rating returned by the questionnaire: `________`

> **Answer honestly even though it costs you a tier.** An age rating that
> understates UGC is a rejection at review and a removal risk after launch. 13+
> costs you nothing real — the audience for a calorie-quest RPG isn't 8-year-olds.

---

## 6. App Privacy Questionnaire (App Store Connect → App Privacy)

> ⚠️ **REVERSED from the previous pack.** The old answer was *"Data Not
> Collected."* That was correct for a watch-only app that transmitted nothing.
> It is **false now** — signing in creates an account, and sharing transmits
> calories, heart rate, steps, photos, and captions to the backend.
>
> Apple treats data as *collected* when it leaves the device for anything beyond
> servicing the immediate request. In **solo mode** nothing does. In **social
> mode** it does. Apple requires you to declare what the app is *capable* of
> collecting — so the social-mode label is the label, even though sharing is
> opt-in and off by default.

**Declare exactly this** (mirrors `data-compliance.html` §5 — keep them identical):

| Data type | Collected | Linked to You | Tracking | Purpose |
|---|---|---|---|---|
| **Health & Fitness** — calories, heart rate, steps, workout data | ✓ | Yes | **No** | App Functionality |
| **User Content** — photos, captions, posts | ✓ | Yes | **No** | App Functionality |
| **Identifiers** — user ID / username | ✓ | Yes | **No** | App Functionality |
| **Contact Info** — email address (Apple private relay, if allowed) | ✓ | Yes | **No** | App Functionality |
| Location | ✗ | — | — | — |
| Financial Info | ✗ | — | — | — |
| Usage Data | ✗ | — | — | — |
| Diagnostics | ✗ | — | — | — |

**Click path for each collected type:** select the type → check **App
Functionality** only (do **not** check Third-Party Advertising, Developer's
Advertising, Analytics, or Product Personalization) → mark it **Linked to the
user's identity** → answer **No** to "used for tracking."

Where each lives in Apple's taxonomy: workout metrics under **Health & Fitness**;
photos and captions under **User Content**; the account id/username under
**Identifiers**; the Apple relay email under **Contact Info → Email Address**.

**Tracking is "No" and that is defensible:** no data broker, no cross-app or
cross-site advertising, no ad SDK, no IDFA, no ATT prompt. The two hard lines
from the pivot — never sold or handed to sponsors/advertisers, never used for ad
targeting — are what keep this answer true. They are also HealthKit rules
(Guideline 5.1.3), not just promises, so they are not negotiable later.

---

## 7. Screenshots (required for submission)

You now need **iPhone** screenshots (primary listing) **and** Apple Watch
screenshots. Capture the iPhone set in the Simulator with sample data:
`-BRSampleData` plus a start flag (`-BRStartOnProfile`, `-BRStartOnHistory`,
`-BRStartOnRewards`, `-BRStartOnAlerts`). Toggle theme with
`xcrun simctl ui <udid> appearance dark|light`.

**iPhone — required size:** one set at 6.9" (1320 × 2868) or 6.7" (1290 × 2796).

Your existing 8-shot marketing set is still valid for the solo screens. ⚠️ **It
predates social entirely** — the listing now promises a party, a feed, and an
ARENA, and a listing that promises features the screenshots never show is a weak
listing (and occasionally a review question). Add at least two:

1. **Home** — level card with the "→ next title" gap, weekly challenge, last-quest hero ✅ *have*
2. **Character sheet** — avatar, class affinity, records, trophy case ✅ *have*
3. **History** — quest log with a 🏆 RECORD stamp and the weekly burn chart ✅ *have*
4. **Quest receipt** — the itemized XP breakdown ✅ *have*
5. **Reward Forge** — building a custom reward ✅ *have*
6. **GUILD → FEED** — a couple of cards with photos and reactions 🆕 **needed**
7. **GUILD → ARENA** — the weekly XP board with the #1 crown 🆕 **needed**
8. *(optional)* **Friend's character sheet** — the open profile

**Apple Watch — required size:** 410 × 502 px (Series 4–9 / SE 44–45mm).
1. **Pick Reward** — food list with one selected
2. **Workout mid-quest** — EXP bar ~60%, live HR + calories
3. **Earned / victory** — celebration with summary stats
4. **Watch-face complication** — the quest gauge

> Watch capture: **Side button + Digital Crown** together (enable Settings →
> General → Screenshots first); the shot lands in the paired iPhone's Photos.

---

## 8. TestFlight — "What to Test" (Beta App Info)
```
Thanks for testing BurnReward!

NEW IN THIS BUILD: BurnReward now counts EVERY workout in Apple Health, not just
the ones its own watch app recorded. That's the big one — please hammer it.

WORKOUT SOURCES (the headline change):
• Work out however you normally do — Apple Watch, iPhone, Garmin, a ring,
  Strava, whatever writes to Apple Health.
• Open BurnReward. Does that workout appear in History with sensible calories,
  duration, and type?
• Does it earn XP, move your level, extend your streak, and count toward the
  weekly challenge?
• If you record the SAME session two ways (e.g. watch + a phone app), does it
  show up ONCE, or twice? Twice is a bug — tell us.
• Anything showing as "OTHER" that should have a real name? Send the workout type.

THE QUEST LOOP (unchanged, still needs a pass):
• Pick a reward, run a real quest on the watch, fill the EXP bar, earn it.
• Haptics at 25/50/75%? PAUSE freezes the timer, RESUME picks up exactly?
• Victory screen shows time, avg heart rate, calories?
• Note: an outside workout earns XP but does NOT auto-claim a pending reward.
  You still run a quest to earn a treat. Does that feel right, or annoying?

SOCIAL:
• Sign in, claim a username, add a friend, and post a win with a photo.
• Do their posts show up for you and yours for them? Do reactions land?
• ARENA: join the weekly challenge. Does your friend's score appear?
• Tap a friend's name — does their character sheet load?
• Try report, block, and unblock. Does blocking hide everything both ways?

Report anything weird to burnrewardapp@gmail.com.
```

---

## 9. App Review Notes (Submit for Review → Notes)

> ⚠️ **Read the reviewer-access problem below before pasting this.** The notes
> assume the demo-account seeding is in place.

```
BurnReward is an iPhone app with a bundled Apple Watch app.

WHAT IT DOES: The user picks a food reward, then burns the matching calories to
"earn" it. The iPhone app is the RPG progression layer (level, titles, badges,
personal records, weekly challenge, quest history), derived from the user's
Apple Health workout history. An optional social layer adds friends, a shared
activity feed, and a weekly XP leaderboard.

TO TEST THE CORE LOOP (no account needed):
1. Install on an iPhone. Tap Allow on the HealthKit prompt (workouts, active
   energy, heart rate, steps).
2. Any existing workouts in Apple Health appear immediately in the LOG tab with
   XP, level, badges, and records derived from them. If the test device has no
   workout history, record a short one with any app first.
3. For the full quest loop, pair an Apple Watch (watchOS 10+): on the watch, pick
   a reward and start a workout. Active calories fill the EXP bar; reaching the
   goal saves the workout to Apple Health and shows a summary. Scroll down for
   PAUSE / RESUME / END QUEST. With the iPhone app open, Home shows a live
   CURRENT QUEST card.

TO TEST THE SOCIAL LAYER (account required):
4. Open the GUILD tab and sign in. Sign in with Apple is the only sign-in method,
   so please use your own Apple ID — no demo credentials are needed or possible.
   Before the sign-in button, a consent screen discloses exactly what a party can
   see (including calories and heart rate) and links the privacy policy.
5. Claim any username.
6. Tap ADD, search for the username BURNREWARD_DEMO, and send a party request.
   This account accepts automatically within a few seconds and already has sample
   posts, a populated character sheet, and an ARENA score — it exists so a single
   reviewer can exercise the friends-only features. Pull to refresh the FEED.
7. FEED shows its posts; tap the reactions. Tap its name for its character sheet.
   The ARENA segment shows the weekly XP board once you tap ENTER THE CHALLENGE.
8. The ⋯ menu on any post offers Report and Block. Settings → GUILD lists blocked
   players and offers unblock. Settings → ACCOUNT → Delete account removes the
   account and all its content.

PRIVACY / DATA:
• Solo play requires no account and transmits nothing. HealthKit is read on-device
  to compute the user's own progress.
• Social is strictly opt-in. Signing in is gated behind a consent screen that
  discloses what is shared. Sharing a character sheet (which includes calories,
  heart rate, and steps) is a separate toggle, default ON but reversible any time,
  and visible only to accepted friends — enforced by row-level security, not by
  client code.
• Health data is never sold, never handed to sponsors or advertisers, and never
  used for advertising or tracking of any kind (Guideline 5.1.3).
• User-generated content is limited to usernames, short captions, and up to three
  photos per post. There is no free-text messaging: reactions are a closed set of
  four. Captions run through a wordlist filter and URL stripper; photos run
  through on-device Sensitive Content Analysis and are stripped of all EXIF/GPS
  metadata before upload. Every post can be reported and every player blocked, and
  we can hide any post server-side.
• In-app account deletion is available at Settings → ACCOUNT → Delete account
  (Guideline 5.1.1(v)).

Privacy Policy: https://xcaraballo14.github.io/Apple-Watch---Calories-Burn/privacy-policy.html
```

### ⚠️ The reviewer-access problem — fix before submitting

Feed, ARENA, and open profiles are **all friends-only**. A reviewer who signs in
with a fresh Apple ID has no friends, so every social screen renders an empty
state — and "we were unable to locate the features described in your metadata" is
one of the most common rejections there is.

**Recommended fix — a seeded demo party member.** Create a `BURNREWARD_DEMO`
account with a few posts, a character sheet, and an ARENA score, and add a
server-side rule (DB trigger on `friendships` insert, or a small Edge Function)
that **auto-accepts any party request addressed to it**. Then step 6 above just
works. Cost: about half a day. No new auth surface, no shipped password, and the
reviewer walks the real flow rather than a bypass.

**Alternative:** enable Supabase email/password auth for one review-only account
and hand ASC the credentials. Rejected — it means building a second sign-in path
into the app purely for review, and shipping a live password in your metadata.

**Do not** rely on a demo video alone. It sometimes satisfies a reviewer, and
sometimes gets you a request for working access anyway, which costs a full
review cycle you do not have in the September 6 schedule.

---

## 10. Pre-Submission Checklist (ASC-paste quick list)

**Code / build**
- [ ] Aperture fix shipped and device-verified across ≥3 workout sources
- [ ] `BURNREWARD_DEMO` account seeded + auto-accept rule live (Section 9)
- [ ] iPhone `NSHealthShareUsageDescription` updated — it still says *"reads the
      workouts it saved from your Apple Watch,"* which the aperture fix makes false
- [ ] `print("SIWA failure …")` diagnostic in `GuildManager` removed or `#if DEBUG`-gated
- [ ] Two-account device pass: ARENA, open profiles, consent gate, account deletion
- [ ] Version + build numbers aligned across all three targets, bumped past 1.1 (40)
- [ ] Archive validates clean, zero warnings
- [ ] "Automatically manage signing" on for all targets; **uncheck** Organizer's
      "Automatically manage version and build number" (it silently desyncs the project)

**Web**
- [ ] **Push `77ed0cf`** — the rewritten privacy policy + data-compliance go live
- [ ] Confirm both pages render on GitHub Pages and the policy URL resolves

**App Store Connect**
- [ ] Listing copy pasted (Section 4)
- [ ] App Privacy label set to the Section 6 table — **not** "Data Not Collected"
- [ ] Age rating questionnaire re-walked with UGC declared; result recorded (Section 5)
- [ ] Screenshots include the two new social shots (Section 7)
- [ ] Privacy Policy + Support URLs set (Section 3)
- [ ] Submit for Review with the Section 9 notes

> The full staged build → submit → post-approval checklist lives in
> `ROADMAP.md → Phase 3` (⚠️ stale — its Phase 3d still says "Data Not Collected").
> Scope and dates live in `LAUNCH_SCOPE.md`.

---

*Generated as a submission aid. Pricing, IAP, and tax/banking decisions are yours to finalize in App Store Connect.*
