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
| Live calorie tracking (HKWorkoutSession) | ✅ | Active energy via HealthKit — Apple optimizes energy estimation per workout type |
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

### 2a · Internal (you only) ✅ Complete — Build 2 (2026-06-18)
- [x] Added iOS stub target (`com.burnrewardapp.app`) so ASC accepted the upload
- [x] Archived and uploaded Build 2 via Xcode → Product → Archive → Distribute
- [x] Installed via TestFlight on Apple Watch SE (watchOS 10.6.2) — confirmed working end-to-end
- [x] Export compliance answered (no non-exempt encryption)

### 2b · Trusted circle (3–5 people)
- [x] External tester group "Trusted Circle" created in App Store Connect
      (2026-06-20 — full record: `TESTFLIGHT_2b.md`)
- [x] Beta App Review **approved** same-day (2026-06-20); public link live:
      https://testflight.apple.com/join/CrWXhAya
- [x] Tester onboarding note drafted — `TESTER_GUIDE.md` (covers install on
      both devices, first quest on Watch, companion checks, extras to try,
      feedback path). Supersedes the watch-only invite text in
      `TESTFLIGHT_2b.md`, which predates the companion.
- [x] **Send the link + guide to 3–5 trusted testers** — ✅ 2026-07-14: build 29
      cleared Beta App Review and the trusted circle is installed and testing
      ("up and running", Xavier). Feedback triage happens here as it lands.

### 2c · Wider beta
- [ ] Expand group once core loop is confirmed bug-free by 2b testers
- [ ] Monitor TestFlight feedback in App Store Connect (built-in: testers can send feedback + screenshots directly from TestFlight)

### Feedback pipeline (when volume justifies it)
- [ ] Wire burnrewardapp@gmail.com Gmail filter → label all app feedback
- [ ] Add Gmail MCP integration to Claude Code session for triage
- [ ] Graduate to GitHub Issues with labels: `bug`, `feature`, `question`, `severity:high/med/low`

---

## Phase 3 — App Store Submission

> **Expanded 2026-07-09** for the iOS companion — the earlier list was watch-only.
> Listing copy + screenshot specs live in `APP_STORE_METADATA.md`; **that doc
> predates the companion — refresh it for the iOS app before submitting.**
> The app is now an **iPhone app with a bundled Apple Watch app**, not a
> watch-only title — plan screenshots, description, and privacy around both.

### 3a · Build readiness

- [ ] Submitted build carries all shipped work (character sheet + 30 badges,
      C6 alerts bell + local notifications, all five retention loops, XP v2.1,
      **watch pause button** — W4, built 2026-07-14, needs its internal-
      TestFlight device pass before the submission archive)
- [x] Version + build numbers **aligned across every target** — **2026-07-11:**
      all three targets set to **1.1 (build 29)** in the project file (was iOS 9 /
      watch 2 / complication 2). Root cause of the drift found: Xcode Organizer's
      *"Automatically manage version and build number"* was checked, silently
      stamping the uploaded build (ASC was at 28) without writing it back to the
      project — so the file lagged. 29 clears the 28 floor. **Xavier to UNCHECK
      that box on the next Distribute** so the project file is the single source
      of truth. Build-verified clean (zero warnings).
- [~] Release-configuration archive builds clean (zero warnings) — **Release
      *compile* verified clean in the simulator 2026-07-11** (optimized `-O`
      path, zero warnings/errors; catches Release-only issues Debug hides). The
      final signed **device archive** still has to be done on Xavier's Mac.
- [x] No debug/QA affordances leak into Release — **audited 2026-07-11.** Zero
      `#if DEBUG` blocks anywhere; all 11 `-BR*` flags read via
      `ProcessInfo…arguments.contains` (inert without the arg, which an App Store
      install never passes); `-BRSampleData` verified unable to inject demo data
      in Release (`refresh()` always hits real HealthKit without it); every
      `DashboardViewModel(sample: true)` sits inside a `#Preview` (compiler-
      stripped). Zero `try!`/`fatalError`/`preconditionFailure`/`as!`, zero
      TODO/FIXME markers, zero hardcoded secrets, zero `http://` URLs, and the
      old `simulateBurn`/`+50 CAL` affordances are confirmed gone. Only trace:
      two error-path `print()`s in watch `WorkoutManager` (lines 120, 460) —
      harmless, optional to wrap in `#if DEBUG`.
- [ ] Real-device end-to-end smoke test: watch quest → earns → iOS Home / History
      / records / badges / weekly challenge / alerts all update; achievement +
      streak + challenge notifications fire; live quest mirroring works

### 3b · App Store Connect record & metadata

- [ ] App record exists for bundle ID `com.burnrewardapp.app` (created for
      TestFlight) — confirm it's set up as the **primary iPhone app** with the
      watch app bundled, not a standalone watchOS listing
- [ ] Category: **Health & Fitness** (primary; pick a secondary)
- [ ] Listing copy pasted — name, subtitle, description, keywords, promo text
      (see §4 in metadata; rewrite for the companion: RPG progression, quests,
      badges, weekly challenges, on-device privacy)
- [ ] Support URL + Marketing URL (GitHub Pages site) set
- [ ] Age rating questionnaire → **4+**
- [ ] Pricing = **Free** (IAP / subscription is post-launch, see C8)

### 3c · Screenshots (both platforms now)

- [x] **iPhone** — raw functional set captured 2026-07-11 (`Screenshots/iPhone/`,
      verified 1320×2868, Home/character/history/receipt/forge/alerts + 1 dark).
      **Superseded by Xavier's own polished marketing set** (device-framed,
      headline copy, retro art embellishments) covering Home, Alerts, quest
      receipt, Reward Forge, and the trophy case.
- [x] **Apple Watch** — Xavier's marketing set includes real Watch UI (live
      mid-workout stats: calories/BPM/steps, plus the weekly-challenge view),
      clearing the simulator's sensor-data blocker.
- [x] Full 8-shot marketing set saved to `Screenshots/Marketing/`, verified
      1320×2868 (2026-07-11). Two fixes needed before final upload:
      **`08_your_quest_on_your_wrist.png`** shows "1,450/3,500 XP to LVL 7" —
      wrong (should read 1,468/1,500, per `01`/`03` and the real app);
      **`02_see_every_run_walk_and_ride.png`** shows the Cheeseburger row
      tagged both 🏆 RECORD and UNFINISHED — that's the bug fixed in `686efcc`
      today, so this screenshot predates the fix and no longer matches the
      shipped app. Regenerate both from a current build. Other 6 shots
      verified accurate against real app data/math.
- [ ] App preview video — optional

### 3d · Privacy & compliance (updated for the iOS app)

- [ ] **App Privacy questionnaire → "Data Not Collected."** Nothing leaves the
      device: HealthKit is read on-device, the profile photo is a local JPEG in
      UserDefaults, notifications are scheduled locally, no analytics/SDKs. This
      is a genuine selling point — answer it honestly and simply.
- [ ] Health usage strings present: `NSHealthShareUsageDescription` on **both**
      targets (iOS needed both HK strings + the HealthKit entitlement — error
      90683 if missing); `PrivacyInfo.xcprivacy` on each (UserDefaults reason
      CA92.1)
- [ ] No stray usage strings needed — PHPicker requires no `NSPhotoLibrary*`
      string; confirm no location/contacts/mic usage crept in
- [ ] Export compliance — no non-exempt encryption (already answered for TestFlight)
- [ ] Privacy Policy URL set; Data Compliance + Terms pages current on the site

### 3e · Submit

- [ ] Attach the build to the version, write "What's New"
- [ ] App Review notes: state it **requires an iPhone + Apple Watch (watchOS 10+)**,
      and how to exercise the loop (pick reward → workout → earn). HealthKit apps
      sometimes draw a usage question — no demo account needed, it's all on-device
- [ ] Submit for Review; respond to any reviewer follow-ups

### 3f · Post-approval

- [ ] Release (manual hold for a chosen date, or automatic)
- [ ] Verify the live listing and that the watch app still installs standalone
      (`WKRunsIndependentlyOfCompanionApp`)
- [ ] Record the shipped version/build number here

---

## v1.x — Post-Launch Watch Improvements

Items to build after the App Store launch, based on real usage and tester feedback.

| # | Item | Priority | Notes |
|---|---|---|---|
| W1 | Expanded reward library | High | Add more food options beyond the 20 launch rewards |
| W2 | Custom reward (user enters any food + calorie count) | High | Power-user feature, often requested |
| W3 | Streak / history screen on watch | Medium | "You've earned 7 rewards this week" |
| W4 | ✅ Pause workout mid-session | — | **Built 2026-07-14, pulled forward into the v1 submission** — see "Pause button (W4)" section |
| W5 | 📋 Expanded workout types (22-entry catalog) | **Designed 2026-07-14** | **See `WORKOUT_CATALOG.md`** — data model rides v1.1, live tracking + favorites picker = v1.15 |
| W6 | ✅ Workout type step accuracy | — | Subsumed by per-type Metrics Profiles (steps flag per type) — `WORKOUT_CATALOG.md` |

---

## v2.0 — iOS Companion App

**Design locked 2026-07-02** (dashboard-first, "experience over unlock"): Home = header
(profile avatar · wordmark · notification bell) + Level/XP card + Last Quest hero card +
weekly day strip + stat tiles + quest log. Tabs: Home / History / Settings. Light **and**
dark, arcade-but-accessible (pixel font for accents only, Dynamic Type + VoiceOver).

### Milestone 1 — ✅ Built 2026-07-02 (needs on-device verification)

- [x] Watch stamps quest metadata (reward names/emojis, goal, earned count) onto every
      saved `HKWorkout` — `QuestMetadata.swift`, shared with the iOS target. History
      accrues from the next watch build onward; pre-metadata workouts show as generic quests.
- [x] Watch marked `WKRunsIndependentlyOfCompanionApp` (stays standalone-installable)
- [x] iOS target: HealthKit read entitlement + usage string, Press Start 2P font
- [x] iOS app: HealthKit-backed Home (locked design), History (grouped log + quest detail),
      Settings, Alerts (empty-state stub), Profile (name + level + lifetime totals)
- [x] XP engine: 1 active cal in a BurnReward workout = 1 XP; level threshold
      `T(L) = 100·(L−1)² + 400·(L−1)`; pixel title ladder (SNACK ROOKIE → FEAST OVERLORD,
      finalized with Xavier 2026-07-08)
- [x] Both targets build clean; Home verified in simulator (light + dark) via
      `-BRSampleData` launch argument
- [x] Verify on real iPhone paired with the watch — confirmed 2026-07-02 (metadata quest
      rendered with emoji/name/goal/EARNED; legacy workouts show as generic entries as designed)
- [x] Ship watch metadata change in next TestFlight build so history starts accruing —
      Build 3 uploaded 2026-07-04 (also carries live mirroring + XP formula v2)

### Milestone 2 — ✅ Built 2026-07-02 (needs on-device verification): Live quest on iPhone

Uses HealthKit **workout session mirroring** (watchOS 10 / iOS 17) — no WatchConnectivity,
no servers. The watch mirrors its running `HKWorkoutSession` to the iPhone and streams
`LiveQuestSnapshot` JSON over `sendToRemoteWorkoutSession`.

- [x] Shared `LiveQuestSnapshot.swift` (compiled into both targets)
- [x] Watch: `startMirroringToCompanionDevice` on quest start **and** session recovery;
      snapshots sent on calorie/HR updates (throttled ~1/s), force-sent on milestones
      and the final earned state. Best-effort — the watch never depends on the phone.
- [x] iPhone: `LiveQuestManager` registers `workoutSessionMirroringStartHandler` at
      launch (the system background-launches the app when mirroring starts); Home hero
      card becomes a live CURRENT QUEST (pulsing dot, ticking timer, live EXP bar, HR,
      cals to go; pulse respects Reduce Motion). Dashboard auto-refreshes when the
      session ends so the finished quest appears in history.
- [x] Device test passed 2026-07-02 — live CURRENT QUEST card appeared on the iPhone
      during a real quest (Chocolate Chip Cookie, 150 cal walk)

> Note: mirroring attaches at quest start. Quests already running when the apps are
> installed/updated won't stream — only quests started after both builds are on.

### Milestone 3 — 🔧 XP Formula v2 (started 2026-07-03)

Replaces v1's flat "1 cal = 1 XP" with an effort-aware formula — still 100%
HealthKit-derived and recomputed on demand, so there is no XP store to migrate:

```
XP = round(activeCalories × typeFactor × intensityFactor)
     + quest-complete bonus (+25) + first-quest-of-the-day bonus (+20)
```

- typeFactor: LIFT ×1.4 (corrects the watch's undercounting of strength work); others ×1.0
- intensityFactor from avg HR: <100 ×1.0 · 100–119 ×1.05 · 120–139 ×1.10 · 140–159 ×1.20 · 160+ ×1.25
- Every factor ≥ 1 and every bonus ≥ 0 → no workout is worth less than under v1;
  when this ships, history re-scores automatically and levels can only go **up**

- [x] `XPEngine.swift` — per-quest breakdown scoring, order-independent daily bonus
- [x] Quest detail shows the itemized XP receipt (base / factors / bonuses / total)
- [x] Home quest log + level stats wired through the new engine (verified in
      simulator: sample data re-scores 4,303 → 5,483 XP, LV 5 → LV 6)
- 💡 Future levers (noted, not built): personal HR zones via HealthKit date of
      birth (HRmax ≈ 208 − 0.7·age), per-type factor table when the expanded
      workout catalog (C3) lands, rested/idle XP

### Milestone 4 — ✅ Built 2026-07-04: Custom rewards — the phone becomes the brain (C4 + C5)

The iPhone now owns the reward library; the watch renders it. Sync is
WatchConnectivity `updateApplicationContext` — last-writer-wins config that the
system delivers whenever the watch is next reachable. No servers, nothing queued.

- [x] Shared `RewardLibrary` model (`Reward` made Codable and shared to iOS).
      Names are the identity (the watch persists picks by name), so the editor
      enforces uniqueness. Custom rewards list first, hidden built-ins drop out.
- [x] iOS **REWARD FORGE** tab (4th tab): forge custom rewards (name, emoji with
      suggestion grid, calorie goal 10–5,000, optional flavor text), hide/show
      built-ins, reorder + swipe-delete customs
- [x] iPhone re-pushes the library at every launch, so a reset or re-paired
      watch always catches up
- [x] Watch `RewardLibraryStore`: receives + persists to the App Group; picker
      lists the synced library; quest recovery resolves from the *full* catalog
      so hiding a reward can't strand an in-flight quest
- [x] Standalone guarantee: a watch that has never synced uses the built-in 20
- [x] Also shipped alongside: WEEKLY BURN bar chart on History (last 8 weeks,
      current week gold) and version alignment — all targets now v1.1 (build 2)
      after the complication was found stranded at 1.0 (3)
- [x] Device test PASSED 2026-07-06: forged "Rosemary Bread" (125 cal) on
      iPhone → appeared in the watch picker → ran a 55-min walk quest → earned,
      and landed in iOS History with its emoji, 125 cal, 98 BPM, +150 XP

### v1.1 Feedback Round 1 — ✅ 2026-07-04 (Xavier's annotated PDF)

- [x] **Watch fix:** Health Access sheet re-prompted at every app open and after
      every finished quest — the picker's `.task` re-fires on each appearance and
      called `requestAuthorization` unconditionally. Now gated behind
      `statusForAuthorizationRequest` (same gate added to the iOS read path).
- [x] Home: "LV" → "LVL" (badge + XP line), bigger header avatar (36 → 44 pt),
      THIS WEEK card tappable → History (chevron + accessibility hint)
- [x] History: WEEKLY BURN card now spans the full grouped-list width; quest
      rows bigger (30 pt emoji, subheadline title) and show earned XP
- [x] Profile: 96 pt avatar with photo picker — stored on-device as a 256 px
      JPEG in UserDefaults, removable, shown in the Home header too
- [x] FORGE REWARD sheet themed to match the app (was system white)
- ✅ Open discussions from the PDF, both now resolved: the profile-as-character-sheet
      revamp (Milestone 5, built 2026-07-08) and the level-title ladder — Xavier
      finalized the names 2026-07-08 (SNACK ROOKIE → FEAST OVERLORD; he fixed the
      blurry LV3/5/7 rungs and recapped the apex as FEAST PHANTOM → FEAST OVERLORD)

### Milestone 5 — ✅ Built 2026-07-08: Profile → character sheet

Xavier commissioned the profile-as-character-sheet revamp (mockup approved
first, then built). Everything is derived live from the HealthKit quest list —
no new storage, so a reinstall rebuilds the exact same sheet. Engine lives in
`QuestModels.swift` (pure Foundation, next to `LevelEngine` / `DashboardStats`);
view is a full rewrite of `ProfileView.swift`.

- [x] **Identity plate** — avatar in a gold portrait ring (photo picker intact),
      inline editable name, level title, LVL badge, XP bar with "to next level".
- [x] **Class affinity** (`ClassAffinity`) — quests per class with the top one
      flagged MAIN. RPG class names (Xavier's pick): RUN→STRIDER, WALK→WAYFARER,
      BIKE→OUTRIDER, LIFT→JUGGERNAUT, OTHER→WILDCARD. The four core tiles always
      show; WILDCARD appears only if an "other" quest exists.
- [x] **Records** (`PersonalRecord`) — biggest burn, longest quest, most steps,
      highest avg HR, best all-time streak; each names the quest that set it and
      deep-links to its `QuestDetailView`. Added `bestStreak` (longest historical
      run, distinct from `DashboardStats.streakDays` = current).
- [x] **Trophy case** (`BadgeCatalog`) — 30 badges, earned-first, locked ones
      dashed with a padlock + the requirement (also the VoiceOver label). Every
      predicate is a pure function of quest history. Ladders: burn (Spark 250 →
      Inferno 500 → Titan 800 → Dragon Slayer 1000), duration (30/60/90 min),
      steps (5k/10k/15k), precision (within 10/5/2% of goal), grind (Decade 10 →
      Centurion 100 → Legend 250). Plus consistency (Week Warrior, Brick by Brick
      = rest-tolerant, Double Feature), comeback (7-day, 30-day gaps), variety
      (Multiclass, Class Master), time-of-day (Dawn Raid, Night Owl), rewards
      (Sweet Ten, Paid in Sweat, Combo King), Full Party, First Burn.
- [x] **Lifetime** tiles unchanged; **perk-tree teaser** (locked Canvas glyph)
      plants the PoE-progression flag as a future-update horizon.
- [x] Deliberately deferred (need data the model doesn't carry): all heart-rate
      **zone**/effort badges → wait for the personal-HR-zones feature (also the
      safe home for them — no flat-BPM badges that reward overexertion); and
      reward-**type** badges → need a reward category field (Forge + watch sync).
- [x] Accessibility: VoiceOver labels on every tile/row/badge (earned vs locked),
      Dynamic Type via `.pixel(_:relativeTo:)`, contrast via BRTheme FG colors,
      light + dark verified in the simulator with sample data. Zero warnings.
- Dev aid: `-BRStartOnProfile` launch flag auto-presents the sheet (screenshots).
- ✅ Approved by Xavier on device 2026-07-08 ("I love it!").
- 💡 Xavier's follow-up idea: **real pixel-art badge medallions** instead of
      emoji in the trophy case — matches the retro/Dungeon Meshi identity;
      pairs naturally with a badge-detail-on-tap view. Later.

### Full-code audit — 🔧 2026-07-08 (fix batch 1 of findings shipped)

Complete read of all 3 targets (~4,600 lines) while Xavier device-tested the
character sheet. Five real bugs found and fixed same day:

- [x] **`|` in custom reward names corrupted quest metadata** — the pipe is
      `QuestMetadata.separator`; a name containing it would split into phantom
      rewards on the phone, permanently (HKWorkout metadata is immutable).
      Builder now validates name + emoji; `RewardStore.addCustom` strips it as
      a backstop.
- [x] **iOS read-auth set was missing `stepCount`** — worked on Xavier's phone
      (grant predates), but a fresh install would show "—" in the Steps row
      forever. Added to the set; the once-per-install flag is wiped on
      reinstall so the sheet still shows exactly once.
- [x] **Watch victory screen ignored Reduce Motion** — the looping emoji pulse
      now skips when Reduce Motion is on (our own ADA rule).
- [x] **Haptic replay after mid-quest relaunch** — `restoreState` now resyncs
      `hapticQuarter` to restored progress so recovery doesn't re-buzz passed
      milestones.
- [x] **Watch BACK button tap target** grown to 52×32 pt with a full-rect
      content shape (was a bare 6 pt label — the only mid-workout escape hatch).

**Fix batch 2 — ✅ 2026-07-09 (four deferred findings cleared).** All build
clean (iOS scheme, which compiles the embedded watch app); simulator-verified
where visible:

- [x] **Watch timer past an hour** — `WorkoutView` live timer and `EarnedView`
      summary showed `75:00`, not `1:15:00`. Added `WatchFormat.duration` (in
      `Theme.swift`) mirroring iOS `BRFormat.duration`; both watch sites use it.
- [x] **Identity-plate name crowding** — a long display name (`.fixedSize`)
      overflowed into the LVL badge. Name `TextField` is now sized
      `min(text, 165)` — `.frame(maxWidth: 165)` resolved by an outer
      `.fixedSize` — so a short name still hugs the pencil and a long one
      truncates with an ellipsis. Verified both ("Xavier" hugs; "Maximilian
      Wellington III" → "Maximilian Welli…", badge intact).
- [x] **Silent empty history on a failed fetch** — `DashboardViewModel.refresh`
      swallowed a thrown read and showed the same "NO QUESTS YET" as a truly
      empty account. Added an operation-based `.failed` state (only when the
      fetch *throws* and there's nothing cached — a *denied* read returns []
      without throwing, so it can't false-trigger). History and Home empty
      states now show a distinct "COULDN'T LOAD · pull to try again" hint.
- [x] **`stats`/`scores` recomputed per render** — worse than noted: History
      rows read `model.scores[id]` in a loop, rebuilding `XPEngine.scoreAll`
      per row (O(n²)/render). Both are now cached and recomputed only when the
      quest list changes, via a single `setQuests` funnel (keeps them from ever
      going stale against `quests`).

**History class filter — ✅ 2026-07-09.** A pinned chip row under the QUEST
LOG title: `ALL` + one chip per class the player has logged, each with its
count. Chips reuse `ClassAffinity` (same bucketing as the character sheet, so
counts never disagree) and show the RPG class names (STRIDER / WAYFARER /
OUTRIDER / JUGGERNAUT / WILDCARD — Xavier's pick over plain RUN/WALK). Tapping
filters the month-grouped log; the selected chip goes solid green (the app's
"active" convention). The WEEKLY BURN chart hides while a filter is on (it's an
all-activity overview — showing it beside a filtered list would contradict it).
Class-only for now; an Earned/Unfinished dimension was offered and deferred.
VoiceOver labels + `.isSelected` trait on every chip; verified light + dark in
the simulator. Also folded in: the empty/failed-fetch state is now wrapped in a
`ScrollView` so the batch-2 "pull down to try again" copy actually triggers a
refresh (it previously sat on a non-scrolling view).

**Badge celebration + badge detail — ✅ 2026-07-09** (mockup-first; Xavier
approved the haptic + real-best overshoot via the option picker):

- [x] **Unlock detection** — badges stay 100% HealthKit-derived; the only new
      storage is a "seen badge IDs" list in UserDefaults (`br.ios.seenBadgeIDs`),
      diffed inside the `setQuests` funnel. First observation seeds silently, so
      the feature landing on an existing history (or a reinstall) never fires a
      back-dated toast barrage — only genuinely new unlocks celebrate. Safe from
      the empty-then-loaded race because `setQuests` only ever carries a real
      fetch result.
- [x] **Toast** (`BadgeToast` in RootView) — overlays the TabView so it shows on
      any tab: gold-bordered dark island, medallion, "BADGE EARNED!" + name.
      Auto-dismisses in 4 s (8 s + spoken announcement under VoiceOver; fade-only
      under Reduce Motion; success haptic on appear — the system setting can
      silence it). Tap → trophy case. Multi-unlocks queue one at a time in
      ladder order.
- [x] **Badge detail sheet** — every trophy-case tile is now a button → compact
      sheet: big medallion, EARNED/LOCKED pill, requirement, and for the 12
      quantifiable ladder badges a progress bar ("700 / 1,000 cal") — locked
      badges read as goals, not mysteries. Earned badges show the real best
      (overshoot kept, e.g. "700 / 500 cal") with a green bar; locked climb in
      gold. `Badge` gained an optional `Progress` (current/target/unit).
- [x] Verified in simulator: toast light + dark, sheet locked (dark) + earned
      (light). Zero warnings. Dev aids: `-BRDemoBadgeToast` (pins two demo
      toasts open), `-BRDemoBadgeSheet` / `-BRDemoBadgeSheetEarned`.
- 💡 Pairs with Xavier's pixel-art medallion idea later — the sheet's big
      medallion is where real art would land first.

No deferred audit findings remain — the 2026-07-08 audit list is fully cleared.

### C6 — Notification bell (in-app inbox) ✅ 2026-07-09

Mockup-first; Xavier chose **in-app inbox only** (no push yet — no permission
prompt, nothing leaves the device) and **all three alert types**.

- [x] **Feed engine** (`AlertFeed` in `QuestModels.swift`, pure Foundation) —
      two sections, all derived from quest history (no backend):
  - **NEXT UP** nudges from current state: XP to the next level (+ next rank
    title), the locked badge you're closest to ("100 cal from Titan", via
    `Badge.Progress`), and the current streak (≥2 days, gentle — never guilt
    about rest).
  - **RECENT** achievement events reconstructed by **replaying the log**:
    level-ups (accumulate XP chronologically, emit each threshold crossed),
    badges (walk the log, reuse `BadgeCatalog` so predicates can't drift, date
    each to the quest that first satisfied it), and current records (biggest
    burn / longest / most steps — **heart rate deliberately excluded**, never
    celebrate a high BPM). Real dates, not faked.
- [x] **Unread model** — `alertsLastSeen` (UserDefaults) drives the bell's red
      dot and the per-row "new" dots; marked seen on sheet *close* so new items
      stay highlighted while reading. Seeded to now on first real load so a
      pre-existing history never lights the bell for back-dated events.
- [x] `NotificationsView` rewritten from the empty stub to the real feed;
      `HomeView` bell now reads `model.hasUnreadAlerts`. VoiceOver labels per
      row, light + dark verified in simulator, zero warnings. Dev aid:
      `-BRStartOnAlerts` auto-presents the sheet.
- ~~📋 Deferred to a follow-up: real local notifications~~ → built same day, below.

### C6 (part 2) — Local notifications ✅ 2026-07-09

`NotificationService.swift` (new file — the project uses Xcode 16 synchronized
folders, so no pbxproj edit was needed). **Local notifications only**: scheduled
on the iPhone with `UNUserNotificationCenter`, no server, nothing leaves the
device. Two channels, individually toggleable in Settings:

- [x] **Badges & level-ups** — posted only when detected while the app is
      **backgrounded** (quest-end mirroring background-launches the app, which
      is exactly that moment); in the foreground the in-app toast owns the
      celebration, so nothing ever doubles up. Level-ups use the same
      seed-silently pattern as badges (`br.ios.notifiedLevel`) and resync
      quietly if history shrinks (Health edits).
- [x] **Streak reminder** — one nudge at a user-picked time (default 6 PM),
      scheduled **for today only** and only when: the streak is alive (≥ 2
      days), nothing is earned yet today, and the time is still ahead. Earned
      a quest? The reschedule (runs on every quest-list change) cancels it.
      It never rolls to tomorrow with stale copy and never fires after a
      streak already broke — encouragement, not guilt. Known trade-off,
      accepted: it's best-effort — the reminder is (re)planned when the app
      runs (open, or any quest-end background launch), so a day where the app
      never runs gets no reminder. The alternative (a repeating trigger) could
      fire stale/guilt-y copy on rest days, which violates the tone rule.
- [x] **Settings › NOTIFICATIONS section** — two toggles with captions, a
      compact time picker (shown only when the streak channel is on), a
      privacy footer, and an honest "off in iOS Settings" hint row that
      deep-links to the app's notification settings. Permission is requested
      on first toggle-on (never at launch); unlike HealthKit,
      `getNotificationSettings` reports truthfully, so the UI reflects the
      real state (re-checked when returning from the Settings app).
- [x] Verified in simulator: Settings UI light + dark, scheduling path runs
      clean (sample data's today-quest correctly suppresses the reminder).
      Zero warnings. The permission dialog and lock-screen banner can't be
      exercised in the sim (no tap automation) — **device test needed**:
      flip both toggles on, accept the prompt, then earn a badge with the
      phone locked. Dev aid: `-BRStartOnSettings` opens the tab.

### Device-test follow-up — 🔧 2026-07-06: silent live-data failure

First M4 device run: the forged reward ("Bread", 125 cal) synced to the watch
picker — the phone→watch half **passes**. But the quest ran 8+ minutes with
zero calories, no heart rate, and zero steps: HealthKit delivered nothing, and
every failure path was invisible (`beginCollection`'s error was ignored,
session errors only printed, and DEBUG builds faked the workout screen when
the session failed to start).

- [x] Session/collection start failures now bounce back to the picker with an
      alert; mid-session errors show a red banner on the workout screen
- [x] Orange "NO SENSOR DATA · CHECK HEALTH ACCESS" hint after 45 s with no
      samples — read access being off raises no error, so this is the only signal
- [x] Quest start awaits (gated) authorization before collection begins — types
      still undetermined at `beginCollection` are silently never collected
- [x] Removed the `#if DEBUG` fake-workout fallback
- [x] Re-prompt returned + dead SET GOAL button (2026-07-06): (a) the
      `statusForAuthorizationRequest` gate from the v1.1 round never worked —
      HealthKit hides read grants, so it returns `.shouldRequest` forever and
      re-prompted on every appearance; replaced with a persisted "already asked"
      flag on both platforms (sheet shows at most once per install). (b) awaiting
      `beginCollection(at:)` stalled the workout-screen transition on device;
      restored the optimistic transition + non-blocking collection start.
- [x] Confirmed fixed on device 2026-07-06 — quest earned with live calories +
      heart rate flowing (the earlier zero-data run was denied read access).
- [x] Steps added to the iOS quest detail (`Quest.steps` read from the saved
      workout's step-count statistic; "Steps" row in `QuestDetailView`, "—" when
      a workout carries no step data; sample data seeded with plausible cadence).
      Verified on device 2026-07-08 (cookie quest: 1,391 steps).
- [x] False "HEALTH ACCESS NEEDED" gate (2026-07-08): the watch showed the
      full-screen gate minutes after a quest saved with full live data —
      `authorizationStatus(for: workoutType)` returned `.sharingDenied`, which is
      impossible if access were really off (a denied app can't save a workout at
      all). Third HealthKit status API to lie to us. First pass downgraded it to
      an advisory banner but left it wired to the same lying signal, so it kept
      crying wolf even with everything granted (Xavier confirmed iPhone toggles
      all on). **Final fix: stop predicting denial entirely.** `HealthAccess`
      dropped its `.denied` case; `updateHealthAccess()` only reports
      `.unavailable` (no HealthKit) vs `.granted`; the picker banner is gone.
      The *only* health-access warning left is operation-based — the 45 s
      "NO SENSOR DATA" hint on the workout screen, shown when a live session
      collects nothing (the one signal HealthKit reports honestly). That hint now
      points to the correct path: iPhone Settings › Privacy & Security › Health ›
      BurnReward (the watch's "WATCH › PRIVACY › HEALTH" copy was wrong — no such
      section exists; that Privacy screen only has sensor toggles).

### UX round 1 — ✅ 2026-07-10 (Xavier's cosmetic/UX feedback board)

- [x] **Clickable cards (Home):** EXP/level card → opens the character sheet;
      LAST QUEST hero → pushes the quest detail + XP receipt; QUEST LOG rows →
      push their quest detail (chevrons added for affordance). Home is now
      wrapped in a NavigationStack (its custom header stays; nav bar hidden on
      the root only, pushed details keep back bars). Live quest card stays
      non-tappable (no detail exists for an in-flight quest yet).
- [x] **Retro tab bar** (`BRTabBarStyle` in BRTheme.swift): Press Start 2P
      labels via UITabBarAppearance (the only route to a tab-item font), theme
      colors mirrored from BRTheme (card bg, divider hairline, greenFG
      selected, textMuted normal), filled icons. Tabs renamed to game-menu
      voice: **HOME · LOG · FORGE · SYSTEM** — FORGE (hammer icon) was
      Xavier's explicit ask for REWARDS; LOG/SYSTEM are the same voice applied
      to History/Settings (one-word reverts if disliked).
- [x] **Dead-space purge:** every tab root now uses a compact `BRTabHeader`
      (Home's custom-header pattern) instead of a system nav bar, plus
      tightened list top margins — content starts immediately under the title
      on LOG / FORGE / SYSTEM / alerts sheet. Rewards' EditButton moved into
      the header (manual editMode binding). Pushed details keep system bars.
- [x] Verified in sim, light + dark, all four tabs. Zero warnings.

### UX round 2 — ✅ 2026-07-10 (Xavier's art lands: console tab bar + trophy medallions)

Mockup-first (approved live in the simulator; Xavier: "Love it"):

- [x] **Custom console tab bar** (`RetroTabBar.swift`) — the system tab bar is
      gone (`.toolbar(.hidden, for: .tabBar)` everywhere + `safeAreaInset`
      replacement): full-width, bleeds through the home-indicator area, dark
      island surface both themes, gold hairline, Xavier's 4 pixel icons
      (template-tinted, nearest-neighbor), green active state with a
      "cartridge slot" indicator. Tabs: **HOME · LOG · FORGE · CHARACTER**.
- [x] **CHARACTER is a tab** — the character sheet left its sheet: 4th tab,
      custom header, no Done. **Settings moved behind the gear** in the
      CHARACTER header (sheet with its own Done) — approved placement. Home's
      avatar + EXP card and badge-toast taps now switch to the tab.
- [x] **Trophy medallion art (30)** — Xavier's drawn medallions wired into the
      trophy grid (46 pt), badge detail sheet (130 pt), and celebration toast;
      loaded by convention (`Art/badge_<id>.png`, toast reuses celebration id).
      Earned shows art; locked keeps the padlock + progress-ring system.
      Asset pipeline: sources had the transparency checkerboard baked in as
      pixels — `strip_checker.swift` (scratchpad) flood-fills from the borders
      to real alpha, then downscale (badges 512 px, icons 256 px). Tab icons
      arrived black-on-transparent and are template-tinted in-app.
- [x] **Challenge bar recolor** (Xavier's one tweak): weekly-challenge progress
      is now orange (`BRTheme.challengeFill`) so the three Home bars read
      distinctly — blue = level XP, gold = quest EXP, orange = challenge.
- [x] **Gray-ghost locked badges** (approved 2026-07-10): locked badges show
      the medallion art desaturated + dimmed (grid 35% / sheet 40% opacity,
      saturation 0) instead of the padlock — the whole collection is visible,
      earning a badge "ignites" it into color. Gold progress arcs overlay the
      in-progress ghosts. The padlock/dashed-ring system remains only as the
      fallback for any future badge that ships before its art does.
- [x] QA flags: `-BRStartOnProfile`/`-BRStartOnSettings` → CHARACTER tab (the
      latter auto-opens the Settings sheet); new `-BRScrollToTrophies` jumps
      the character sheet to the trophy case. Verified light + dark, zero
      warnings. Art spec + filename table: `ART_ASSETS.md`.

### Pause button (W4) — ✅ 2026-07-14 (pulled forward into v1; device pass pending)

First build of the post-v1 vision list, promoted into the v1 submission by
Xavier's call ("launch a bit later, ships more complete"). Iteration happens
via **internal TestFlight** (no Beta App Review needed), so folding it in costs
no extra review cycle — only the final App Store review remains. Mockup-first:
two entry variants screenshotted on the watch sim; Xavier picked **B** (BACK
stays; bottom PAUSE button) recolored **orange** for visibility.

- [x] **Watch: pause engine** (`WorkoutManager`) — `togglePause()` calls
      `HKWorkoutSession.pause()/.resume()`; the previously-empty
      `didChangeTo` delegate is now the single state sink, so our button and
      any system-initiated pause take the same path. HealthKit's own pause
      events keep the *saved* workout's duration honest; `pausedAccumulated` +
      `pauseStartedAt` keep the on-screen timer honest (frozen while paused,
      paused spans never count). State persists (3 new UserDefaults keys) and
      restores across force-close; session recovery re-syncs from
      `session.state`. Haptics: `.stop` on pause, `.start` on resume (same
      language as Apple's Workout app). Milestone checks guard against
      straggler samples landing mid-pause.
- [x] **Watch: UI** — full-width orange PAUSE button (`PixelButtonStyle`
      gained `fill`/`shadow` params) at the bottom of the workout screen;
      BACK stays exactly as shipped. Tap → **pause menu takeover**: blinking
      "‖ PAUSED" marquee (steady under Reduce Motion), frozen clock, dimmed
      cal count, green RESUME, red-ghost END QUEST. Ending confirms via the
      (re-worded) dialog: "End this quest? It saves to history as unfinished"
      — shared with BACK. VoiceOver labels on every control.
- [x] **iPhone: live card PAUSED state** — LIVE pill → orange PAUSED pill,
      pulsing record-dot goes still + orange, timer freezes at the watch's
      exact second (muted). Fixed a real bug in the process: the card's timer
      was wall-clock from `startDate`, which would have silently drifted
      forever after any pause.
- [x] **Wire format** (`LiveQuestSnapshot`) — new `isPaused`,
      `pausedSeconds`, `pausedAt` + an `elapsedSeconds(at:)` helper both
      apps share; custom `decodeIfPresent` decode so old-build payloads
      still parse. Watch force-sends a snapshot on every pause/resume flip.
- [x] **QA flags** — watch: `-BRDemoWorkout` / `-BRDemoPaused` seed a
      live-looking quest with **no HK session** (solves the "watch sim has no
      tap automation or sensors" screenshot blocker for good; demo never
      persists, never touches the complication). iOS: `-BRDemoLiveQuest` /
      `-BRDemoLiveQuestPaused` seed the Home live card. All ProcessInfo-gated,
      inert in real installs.
- [x] Both targets build clean, zero warnings; verified in sim: watch running
      + paused states (Ultra 3), iPhone paused card light + dark.
- [ ] **Device pass (Xavier, internal TestFlight):** pause mid-quest with real
      sensors → phone card flips PAUSED → resume → finish → saved workout's
      duration excludes the paused stretch. Also eyeball the pause menu on the
      real SE (smallest screen). Then this rides the v1 submission archive.

### Retention direction — adopted 2026-07-09 (from Xavier's external spec, adapted)

Xavier brought a retention & subscription build spec (drafted with Claude chat).
Discussion outcome: adopt the *loops*, reject the parts that conflict with
shipped architecture. Decisions:

- **Architecture stays derivation-first.** No SwiftData `QuestCompletion` store —
  HealthKit remains the database; a small store only ever for genuinely
  non-derivable game state (perks, founder status, entitlements), later.
- **Formulas stay ours.** XP v2 + the FEAST OVERLORD ladder are canonical; the
  spec's class-based XP / new curve / new titles are superseded. Its precision
  idea survives as a future **additive precision XP bonus** (never a penalty).
- **Daily streak stays** (Xavier's call); all *pressure* (challenges, new
  reminders) is weekly. Watch complication stays free (already shipped).
- **Adapted build order:** ✅ 1. Weekly Challenge → ✅ 2. PR celebrations →
  ✅ 3. badge progress rings → ✅ 4. next-title on Home + `GameBalance` →
  ✅ 5. precision XP bonus (v2.1). **All five free-tier retention loops done.**
  Next: post-launch StoreKit 2 contextual paywall (free tier complete; founder
  pricing) → later: CloudKit social (after a privacy scoping pass).
- **Post-launch order (re-set 2026-07-14):** **v1.1 = Record Old Workouts +
  workout-catalog data model** (backfill tester-requested; both designed +
  adjudicated same day; the backfill form's type picker is built against the
  full 22-type catalog from day one — records: `RECORD_OLD_WORKOUTS.md`,
  `WORKOUT_CATALOG.md`) → **v1.15 = catalog UX** (live tracking for all 22
  types, phone catalog browser + favorites, watch picker rework via the M4
  sync channel) → **v1.2 = the Ember Tree** (perk tree, PoE-inspired ~32
  nodes, chosen 2026-07-11 over GPS routes; the subscription attaches here —
  **decision record: `PERK_TREE.md`**). Nothing builds before the App Store
  submission ships.

### Weekly Challenge — ✅ 2026-07-09 (retention loop 1)

- [x] `WeeklyChallenge` engine (QuestModels.swift, pure Foundation): one
      challenge per calendar week, **deterministically picked from the week
      start** (same all week, rotates weekly) with progress derived from that
      week's quests — zero stored state, reinstall rebuilds it. Pool of 5
      (Xavier approved): 🗡️ QUEST SPREE (4 quests) · 🎯 PRECISION WEEK (3
      within 10%, same math as the precision badges) · 🧭 DUNGEON MENU (3
      classes) · 🔥 BIG BURN (1,500 cal) · ⏳ LONG HAUL (120 min). All weekly
      aggregates — rest days never cost progress (health guardrail).
- [x] `WeeklyChallengeCard` on Home (between LAST QUEST and THIS WEEK):
      name/detail, progress bar, days-left countdown, green COMPLETE! pill.
- [x] Bell NEXT UP nudge ("611 cal from BIG BURN") — leads the nudge list,
      disappears when complete.
- [x] Third notification channel: **Challenge reminder** — one heads-up on the
      week's last full day at the shared reminder time, only when ≥ 50% done
      but not finished (no engagement = silence, not homework). Settings
      toggle added; time picker now serves both reminder channels.
- [x] Verified in sim (light + dark, in-progress + COMPLETE states), zero
      warnings. QA: `-br.demoChallengeIndex N` forces a specific challenge.

### PR celebrations — ✅ 2026-07-09 (retention loop 2)

Makes repeating a reward meaningful: breaking your own record is now an event.

- [x] **`Celebration` payload** (QuestModels.swift) — the toast generalized
      from badges-only to badge unlocks *and* record breaks; `BadgeToast` →
      `CelebrationToast` (same gold chrome, headline varies: "BADGE EARNED!" /
      "NEW RECORD!"). Queue/haptic/VoiceOver/Reduce-Motion behavior unchanged.
- [x] **Record-break detection** — burn / duration / steps bests persisted
      (`br.ios.prBurn/prDuration/prSteps`), diffed in `setQuests`; same rules
      as badges: first observation seeds silently (no back-dated toasts on
      install/reinstall), shrinks (Health deletions) resync silently, only a
      genuine beat celebrates ("BIGGEST BURN · 812 CAL · beats 700 cal").
      **Heart rate and streak deliberately excluded** — never cheer a high
      BPM, and a live streak would re-toast daily.
- [x] **Stamps** — the quest currently *holding* a record shows a gold
      "🏆 RECORD" tag in History rows and per-record pills (🔥 BIGGEST BURN /
      ⏱️ LONGEST QUEST / 👣 MOST STEPS) in the quest detail. Fully derived —
      stamps move automatically when a record falls.
- [x] Records list now cached in the model (`model.records`) like
      stats/scores; the character sheet reads the cache.
- [x] Notifications: record breaks ride the achievements channel (toggle
      re-captioned "Achievements — badges, level-ups, and new records").
- [x] Toast verified in sim (record + badge styles); stamps build-verified
      (record-holder rows sit below the scroll fold — confirm on device).
      Zero warnings. `-BRDemoBadgeToast` now demos a record toast first.

### Retention loops 3 + 4 — ✅ 2026-07-09 (rings · next title · GameBalance)

- [x] **Badge progress rings** (trophy grid) — locked badges with progress now
      wear a gold arc around the medallion (solid faint track replaces the
      dash); untouched badges stay dashed; "unfinished business" reads at a
      glance without opening the detail sheet. VoiceOver reads the numbers
      ("700 of 1,000 cal"). Verified in sim via a temporary locked-first sort
      (reverted).
- [x] **Next-title line on Home** — the level card's XP line now ends with
      "→ DUNGEON DINER" in green: the visible gap on the first screen. Shown
      only when the next level actually changes the rank (mid-band levels and
      FEAST OVERLORD at the top show nothing — the card never points at the
      rank you already hold).
- [x] **`GameBalance.swift`** (new file) — every systemic tunable in one
      place: XP bonuses + LIFT factor + HR intensity bands, the level-curve
      coefficients, all five challenge goals + the precision tolerance, and
      the nudge gates (streak min days, challenge min fraction, toast dwell).
      Challenge detail strings now interpolate the same constants, so tuning
      a number can't leave stale copy. Badge thresholds deliberately stay in
      `BadgeCatalog` beside their requirement strings; the title ladder stays
      in `LevelEngine` (Xavier-finalized). **Zero behavior change** —
      regression-verified in sim (sample data still 5,483 XP · LVL 6 · same
      challenge numbers).

### Precision XP bonus (v2.1) — ✅ 2026-07-09 (retention loop 5)

The healthy differentiator, wired into scoring: reward landing *near* the goal,
not raw overshoot. Precision is the skill.

- [x] **`XPEngine.precisionBonus`** — an *earned* quest earns up to
      `GameBalance.precisionBonusMax` (50) XP, full at (or under) the goal,
      tapering linearly to 0 once overshoot hits `precisionBonusFalloff` (30%).
      Unfinished and goal-less quests earn nothing. Added as a new
      `XPBreakdown.precisionBonus` field folded into `total`.
- [x] **Strictly additive** — a bonus ≥ 0, so it honors the v2 rule (factors
      ≥ 1, bonuses ≥ 0): no quest scores lower, re-derived history can only
      level **up**. Sample re-scored **5,483 → 5,968 XP** (still LVL 6, now
      right at LV7's door) — verified in sim; levels only rose.
- [x] **Receipt line** — quest detail shows "Precision landing +45" in gold,
      its own line in the XP breakdown (verified: Pizza Slice 412/400 →
      3% over → +45 of 50, total +564). `-BRDemoQuestReceipt` presents a
      receipt for screenshots.
- [x] Constants live in `GameBalance` (max + falloff), tunable in one place.
      Zero warnings. Formula doc bumped v2 → v2.1.

| # | Feature | Why companion, not watch |
|---|---|---|
| C1 | ✅ BurnReward source icon in iPhone Health app | Comes free with the real iOS app (Milestone 1) |
| C2 | ✅ Full workout history & stats (all-time rewards earned, calories burned, streaks) | Built in Milestone 1 — HealthKit is the source of truth, no sync code |
| C3 | 📋 Expanded workout type catalog + watch favorites config | **Designed 2026-07-14, `WORKOUT_CATALOG.md`** — 22 types, 9 metrics profiles, 7 classes + WILDCARD; phone = catalog + favorites, watch picker shows favorites (M4 sync pattern) |
| C4 | ✅ Custom reward builder (name + calorie count + emoji) | Built 2026-07-04 — Milestone 4 |
| C5 | ✅ Reward library editor (add / hide / reorder) | Built 2026-07-04 — Milestone 4 |
| C6 | ✅ Complete 2026-07-09 — in-app alerts inbox (bell) + local notifications (achievements when backgrounded, today-only streak reminder, Settings toggles). All on-device, no server. | Phone handles notification scheduling, watch displays |
| C7 | Social / share card ("I earned it 🔥") | Shareable graphic of earned reward + stats |
| C8 | In-app purchases (premium reward packs, themes) | IAP requires iOS app; planned for a later version |
| C9 | 📋 Record old workouts (manual backfill, 7-day window) | **v1.1 headliner — designed 2026-07-14, see `RECORD_OLD_WORKOUTS.md`.** Phone form → real HKWorkout write; watch untouched |

---

## v3+ — Platform Vision (reshaped 2026-07-03)

Direction validated by watch-app tester feedback and the idea backlog (Apple
Reminders). BurnReward grows from a watch game into a **social fitness RPG**.

**Privacy promise, re-scoped:** *your health data never leaves your device.*
Community features will be optional, account-based, and additive — never
required for the core earn-your-treat loop, which stays fully on-device.

**Aesthetic north star:** *Delicious in Dungeon* — fight the workout, earn the meal.

| # | Idea | Notes |
|---|---|---|
| P1 | XP formula v2 (type / intensity / bonus aware) | 🔧 Milestone 3 — in progress |
| P2 | Full nutrition tracking (calories + macros) | Replace MyFitnessPal-type apps outright, integrated with the RPG |
| P3 | Community events | Competitive (who burns more) + collaborative (shared goal); global first, city/region later |
| P4 | Persistent leaderboards & campaigns | "Give people something to grind for" |
| P5 | Community recipe library with macros | User-generated; Letterboxd-style rating/review flow |
| P6 | RPG class badges for contributions | TANK strength · HEALER/MAGE recovery · SUPPORT nutrition · DPS HIIT; badge titles shown next to usernames |
| P7 | Maps & GPS workout routes | Personal capture stays local (HKWorkoutRoute); social sharing private-by-default |
| P8 | Idle-game mechanics | Progress between sessions (e.g. PoE-style rested XP) |

---

## Deferred / Won't Do

| Item | Status |
|---|---|
| Manual calorie adjustment by user | Won't do — BurnReward earns rewards honestly |
| Android / Wear OS | Won't do — Apple Watch + HealthKit is the core tech dependency |
| Food/meal logging | **Reprioritized 2026-07-03** → P2: testers asked for a full calorie/macro tracker, not a complement |
| Social leaderboards | **Reprioritized 2026-07-03** → P3/P4, under the re-scoped privacy promise above |

---

*Last updated: 2026-07-14 (trusted circle live on build 29 · pause W4 built + pulled into v1 · Record Old Workouts designed → v1.1 · workout catalog designed → data model v1.1, UX v1.15 · Ember Tree → v1.2)*
