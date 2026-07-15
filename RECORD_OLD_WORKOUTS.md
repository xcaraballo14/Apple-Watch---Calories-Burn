# Record Old Workouts — design record

**Status: designed & adjudicated with Xavier 2026-07-14. Build target: v1.1,
the first post-launch update — nothing here builds before the v1 App Store
submission ships.** Tester-requested ("I forgot my watch / it was dead"), item
2 of Xavier's six-item post-v1 vision. The Ember Tree (PERK_TREE.md) moves to
v1.2 behind this.

The feature: manually record a workout you actually did but didn't track,
up to **7 days back**, from the iPhone. It becomes a real quest everywhere.

---

## Why this is architecture-native

HealthKit is the database. The feature writes a **real `HKWorkout`** (via
`HKWorkoutBuilder`, dated in the past) with our `QuestMetadata` stamped on —
then history, XP, badges, challenges, streaks, and alerts all pick it up on
the next derivation pass with **zero new storage**. Reinstall rebuilds it
identically. The entire feature is: a themed form + validation + one
HealthKit write + a handful of pure-function filters.

## The four rulings (Xavier, 2026-07-14)

1. **Calorie input: Hybrid.** The app estimates calories from workout type +
   duration (MET table below, personalized by HealthKit body mass when
   available); the user can adjust within a plausibility band around the
   estimate. Honest default, tolerant of reality.
2. **Rewards: full loop.** A manual quest can attach a reward; entered
   calories ≥ goal earns it. You did the work, you get the treat — the core
   promise stays whole, MANUAL-tagged.
3. **Counting: Balanced.** Manual quests count toward **volume and
   consistency** (rewards, streaks, weekly challenges, grind/variety/
   consistency badges, reduced XP). They are **excluded from peak-performance
   claims** (records + PR toasts, the precision badge trio, and the
   single-quest superlative ladders: burn, duration, steps). Principle:
   *volume is self-reportable; peaks need sensors.*
4. **Timing: v1.1.** Designed now; built as the first post-launch update.
   Perk tree follows as v1.2.

## XP for manual quests (v2.1 formula, sensor terms zeroed)

| Component | Live | Manual | Why |
|---|---|---|---|
| Base calories | ✓ | ✓ (banded + capped) | The work happened |
| Intensity factor (HR bands) | ×1.0–1.25 | ×1.0 | No HR data exists |
| LIFT type factor | ×1.4 | ×1.0 | It corrects watch undercounting; no watch → no correction |
| Precision bonus | ≤ +50 | **0** | Precision is live control; typing the goal isn't skill |
| Quest-complete bonus | +25 | +25 | If a reward was attached and met |
| First-of-day bonus | +20 | +20 | They did work out that day (order-independent re-derivation handles the past date) |
| **`manualFactor`** ⚠️ TUNE | — | **×0.8** | Explicit "the watch is the best way to play" signal; lives in `GameBalance` |

Net: a manual quest earns roughly **55–75%** of its live equivalent.

**Invariant check:** "every factor ≥ 1 / levels only go up" protects re-scored
*history* across formula changes. `manualFactor` is fixed by the workout's own
metadata at creation and re-derives identically forever — no existing workout
ever re-scores downward. Compatible.

## Guardrails (all enforced in code)

- **7-day window** — `endDate ≤ now`, `startDate ≥ now − 7d`. No future entries.
- **Hybrid estimate + band** — estimate = MET × 3.5 × kg ÷ 200 × minutes,
  body mass read from HealthKit (⚠️ new read type; fallback 70 kg if absent).
  User-adjustable within ⚠️ TUNE ±40% of the estimate.
- **Hard cal/min ceilings per type** (⚠️ TUNE, `GameBalance`), sketch:
  WALK 8 · RUN 20 · BIKE 16 · LIFT 10 · OTHER 12 cal/min. MET sketch:
  WALK 3.5 · RUN 9.8 · BIKE 7.5 · LIFT 5.0 · OTHER 5.0.
- **Overlap warning** — if the entered time range intersects an existing
  quest, warn before saving (catches double-logging a workout the watch DID
  record). Warning, not a hard block — gym class + separate walk can touch.
- **`MANUAL` tag** — history row + quest detail wear it (same visual language
  as UNFINISHED). Honest bookkeeping, zero shame. XP receipt shows the manual
  factor as its own line, like every other factor.
- **Peak-performance exclusions** — see table below.

## Badge / record counting table (Balanced)

| Counts ✓ | Excluded ✗ |
|---|---|
| First Burn, Decade, Centurion, Legend (grind) | Records + PR toasts (biggest burn / longest / most steps) |
| Week Warrior, Brick by Brick, Double Feature (consistency) | Strategist, Sharpshooter, Needle Threader (precision) |
| Comeback, Back From the Dead | Spark → Dragon Slayer (single-quest burn ladder) |
| Multiclass, Class Master, Full Party (variety) | Long Walk → Endurance Tank (single-quest duration ladder) |
| Sweet Ten, Paid in Sweat, Combo King (rewards) | Foot Soldier → Long March (steps ladder — moot: manual quests carry no steps) |
| Weekly challenges (all five) | — |
| Streak (current + best) | — |

**⚠️ Open sub-call (one-liner, decide at build time):** Dawn Raid / Night Owl
(time-of-day pair) currently **count** per the approved "Balanced" wording,
but the start time is self-reported — a free badge for anyone who types 5 AM.
Excluding them would fit the "clock-verified peaks need sensors" principle.
Xavier to confirm.

## Engineering notes

- **iOS gains HealthKit WRITE (share) for workouts** — today only the watch
  writes. Adds `NSHealthUpdateUsageDescription` to the iOS target + workout
  share in the auth request (the persisted once-per-install ask-flag pattern
  stays; the sheet may re-show once after update since the request set
  changed — acceptable). App Privacy answer **stays "Data Not Collected"**:
  writing the user's own workout on-device is not collection.
- **`QuestMetadata` gains `manual` (Bool, optional key).** Verified
  2026-07-14: the iOS parser reads keys individually and never checks
  `schemaVersion`, so old app versions simply ignore the key (manual quests
  render as normal quests there — acceptable). Additive, no schema bump
  required; bump only if the format ever changes shape.
- **Write path:** `HKWorkoutBuilder` (non-live) on iPhone — begin/end with
  the past dates, add an `activeEnergyBurned` sample spanning the workout,
  stamp metadata (incl. `manual: true`), finish. No steps, no HR (Quest
  model already renders both as "—").
- **Deletes:** the iPhone app owns what it writes, so v1 of the feature can
  offer swipe-to-delete for MANUAL entries only (or defer to the Health app —
  the existing shrink-resync already handles external deletions cleanly).
  **No in-app editing** — HKWorkout metadata is immutable; editing =
  delete + re-record.
- **Watch is untouched.** No sync, no picker changes, no complication impact.

## UI sketch (mockup-first before build, as always)

- **Entry point:** "+" in the LOG tab's `BRTabHeader` → "RECORD PAST QUEST"
  sheet (FORGE-style theming).
- **Form:** class picker (5 chips, RPG names) → date (last-7-days) + start
  time → duration → calories (pre-filled with the estimate, stepper/slider
  within the band, cal/min cap enforced) → optional reward attach ("Did you
  earn a treat?" — picker shows eligible rewards ≤ entered calories) →
  MANUAL-tagged preview → save.
- **History:** row shows muted `MANUAL` tag beside the class/XP line; quest
  detail shows it near UNFINISHED's spot; XP receipt itemizes the ×0.8.

## Build checklist (v1.1)

- [ ] `GameBalance`: `manualFactor`, MET table, cal/min caps, band width
- [ ] `QuestMetadata.manual` + `Quest.isManual` parsing
- [ ] `XPEngine`: manual branch (factors 1.0, precision 0, ×manualFactor) +
      receipt line
- [ ] Predicate filters: records, precision trio, burn/duration ladders
      (+ time-of-day pair pending Xavier's call)
- [ ] iOS HealthKit write path + usage string + auth-set update
- [ ] RECORD PAST QUEST form (mockup → approval → build) + overlap warning
- [ ] MANUAL tags in history row / quest detail / receipt
- [ ] Sim verify: manual quest flows into history/XP/challenge/streak;
      exclusions hold; reinstall re-derives identically
- [ ] Device verify: workout visible in Apple Health, attributed to BurnReward
