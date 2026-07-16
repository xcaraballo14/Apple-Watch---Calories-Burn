# Workout Catalog — design record (expanded types, metrics profiles, classes)

**Status: designed & locked with Xavier 2026-07-14** (his third external spec,
adjudicated same-day — adoptions, one architectural rejection, one scope
push-back, one internal contradiction fixed). **Build: catalog data model
rides inside v1.1 (with Record Old Workouts); catalog UX + live tracking is
v1.15; Ember Tree stays v1.2. Nothing builds before the v1 App Store
submission ships.** Companions: `RECORD_OLD_WORKOUTS.md`, `PERK_TREE.md`.

## The law — three separate layers

> **Workout Type** records what the user did. **Metrics Profile** determines
> how it's measured and shown. **Class Affinity** determines who the user
> becomes in the game.

Two types may share a profile and differ in class; two types may share a
class and differ in profile. No layer drives another.

## Spec adjudication (2026-07-14)

**Adopted:** three-layer separation · set-based `Set<WorkoutMetric>` profiles
with explicit location/route policies (no boolean sprawl) · live/summary/
primary metric distinction · **PLAYMAKER** sports class (corrects my
WILDCARD-dumping proposal) · classes-are-identities-never-equipment (corrects
my rowing→OUTRIDER grouping) · HIIT-is-a-format · XP per *type* not per class,
×1.0 defaults, evidence before multipliers · steps per type via profile ·
curated catalog, swim as its own pass · careful language about Apple's calorie
engine ("HealthKit sensor collection and energy estimation that Apple
optimizes per workout type" — ROADMAP's "same engine as Workout app" line
fixed) · post-launch validation checklist (§13).

**Rejected — §8 stored class-at-completion.** `CompletedWorkout {
classAffinityAtCompletion, classMappingVersion }` is a stored *derived*
game-state record; a reinstall could no longer rebuild identical state.
Third spec in a row to propose a parallel store; same verdict.
**Counter-adoption that keeps §8's protection:** stamp the stable
**`workoutTypeID` into `QuestMetadata`** (a *fact* about the workout, which is
what metadata is for; also genuinely required — HK's activityType+location
can't distinguish two catalog entries sharing one HK type, e.g. any future
HIIT split). Class stays a pure function of typeID. **Mappings are canon**
(same governance as level titles and the XP curve): a remap is a rare,
deliberate, documented migration that knowingly re-derives history
*consistently* — never a silent side effect — and "it would un-earn someone's
badge" is a valid reason to refuse a remap.

**Pushed back — profiles must not smuggle in the GPS project.** The spec's
example profiles ship `route`/`elevation`/`pace`/`speed`/`power`/`cadence`;
BurnReward collects duration, active calories, HR, steps — plus `distance`,
which HealthKit provides in live sessions without any GPS work. Route capture
is **P7 (GPS/Map)**, its own project with its own permission surface. The
spec's own rule ("do not add metrics simply because they might be useful
someday") applies to its own examples. v1 profiles are built **only from
metrics we actually collect**; `WorkoutMetric` grows when the GPS project
lands. The architecture is designed for routes; it does not ship them.

**Contradiction fixed — BRAWLER launched thin.** The spec demands a class
earn its existence via "a meaningful group of activities," then gives BRAWLER
exactly one v1 discipline (Boxing). Kickboxing + Martial Arts pulled into the
v1 catalog (free labels on the same profile); BRAWLER launches as three.

## The five locked rulings

1. **HIIT → JUGGERNAUT, openly temporary.** Matches felt identity; WILDCARD
   would exile a top-popularity type; a mid-sweat taxonomy question serves
   nobody. typeID stamping makes a future remap/split clean. Post-launch
   review flagged.
2. **Indoor/outdoor are separate catalog entries** (Apple convention). Muscle
   memory; no per-quest-start toggle tax; entries map 1:1 onto distinct
   profiles. Favorites keep the watch picker short.
3. **v1 catalog = 22 entries** (table below).
4. **Class roster = 4 shipped core + MONK + BRAWLER + PLAYMAKER + intentional
   WILDCARD.** STRIDER/WAYFARER/OUTRIDER/JUGGERNAUT untouchable (Xavier's,
   shipped). **PLAYMAKER confirmed final by Xavier 2026-07-14** (GLADIATOR
   considered and passed on). All seven class names are now canon — same
   don't-rename status as the level-title ladder.
5. **Sequencing: data model in v1.1, UX in v1.15.** v1.1's backfill form
   offers all 22 types (coherent: backfill exists precisely for workouts done
   without the watch — a yoga class is the canonical case; it lands in MONK
   from day one). v1.15 ships live tracking, phone catalog browser +
   favorites, WatchConnectivity sync (M4's proven channel), watch picker
   rework. The type picker never gets built twice.

## v1 catalog — 22 entries

| # | Type (typeID) | Class | HK activity | Location | Profile | Steps | XP |
|---|---|---|---|---|---|---|---|
| 1 | Outdoor Run `run_outdoor` | STRIDER | .running | outdoor | outdoor_endurance | ✓ | 1.0 |
| 2 | Indoor Run `run_indoor` | STRIDER | .running | indoor | indoor_cardio | ✓ | 1.0 |
| 3 | Elliptical `elliptical` | STRIDER | .elliptical | indoor | indoor_cardio | ✓ | 1.0 |
| 4 | Outdoor Walk `walk_outdoor` | WAYFARER | .walking | outdoor | outdoor_endurance | ✓ | 1.0 |
| 5 | Indoor Walk `walk_indoor` | WAYFARER | .walking | indoor | indoor_cardio | ✓ | 1.0 |
| 6 | Hike `hike` | WAYFARER | .hiking | outdoor | outdoor_endurance | ✓ | 1.0 |
| 7 | Outdoor Cycle `cycle_outdoor` | OUTRIDER | .cycling | outdoor | outdoor_ride | ✗ | 1.0 |
| 8 | Indoor Cycle `cycle_indoor` | OUTRIDER | .cycling | indoor | stationary_cardio | ✗ | 1.0 |
| 9 | Strength (Traditional) `strength_traditional` | JUGGERNAUT | .traditionalStrengthTraining | n/a | strength_session | ✗ | **1.4** |
| 10 | Strength (Functional) `strength_functional` | JUGGERNAUT | .functionalStrengthTraining | n/a | strength_session | ✗ | **1.4** |
| 11 | Core Training `core` | JUGGERNAUT | .coreTraining | n/a | strength_session | ✗ | 1.0 |
| 12 | HIIT `hiit` | JUGGERNAUT ⚠️temp | .highIntensityIntervalTraining | n/a | stationary_cardio | ✗ | 1.0 ⚠️review |
| 13 | Yoga `yoga` | MONK | .yoga | indoor | mind_body | ✗ | 1.0 |
| 14 | Pilates `pilates` | MONK | .pilates | indoor | mind_body | ✗ | 1.0 |
| 15 | Boxing `boxing` | BRAWLER | .boxing | n/a | combat_conditioning | ✗ | 1.0 |
| 16 | Kickboxing `kickboxing` | BRAWLER | .kickboxing | n/a | combat_conditioning | ✗ | 1.0 |
| 17 | Martial Arts `martial_arts` | BRAWLER | .martialArts | n/a | combat_conditioning | ✗ | 1.0 |
| 18 | Soccer `soccer` | PLAYMAKER | .soccer | outdoor | court_sport | ✓ | 1.0 |
| 19 | Basketball `basketball` | PLAYMAKER | .basketball | n/a | court_sport | ✓ | 1.0 |
| 20 | Tennis `tennis` | PLAYMAKER | .tennis | n/a | court_sport | ✓ | 1.0 |
| 21 | Pickleball `pickleball` | PLAYMAKER | .pickleball | n/a | court_sport | ✓ | 1.0 |
| 22 | Other `other` | WILDCARD | .other | user | open | ✓ | 1.0 |

XP factors live in `GameBalance` keyed by typeID; ×1.4 on both strength types
(identical watch-undercount rationale that justified shipped LIFT ×1.4).
Every other change is post-launch, evidence-based only.

**Bench (later additions, each arrives with its own class question):**
Rowing (own endurance identity — NOT OUTRIDER), Dance/Cardio Dance (possible
rhythm class if demand shows), Jump Rope (STRIDER cardio vs BRAWLER fight
conditioning — product's call, not sensors'), Tai Chi + Barre + Flexibility
(→ MONK), Climbing (→ JUGGERNAUT), Volleyball/Racquetball (→ PLAYMAKER),
Skating. **Swimming is its own implementation pass** (pool/open-water config,
pool length, laps, strokes, water lock, wet-screen interaction) with its own
future class.

## v1 Metrics Profiles (only metrics we actually collect)

`WorkoutMetric` v1 cases: `duration, activeCalories, heartRate,
averageHeartRate, steps, distance`. (Route/pace/elevation/speed/laps/etc.
join with the GPS project and the swim pass.)

| Profile | Live | Summary adds | Primary | Location | Route policy |
|---|---|---|---|---|---|
| `outdoor_endurance` | duration, cals, HR, distance, steps | avgHR | duration, cals, distance | outdoorOnly | disabled (→ enabledForOutdoorSessions when P7 lands) |
| `indoor_cardio` | duration, cals, HR, distance, steps | avgHR | duration, cals | indoorOnly | disabled |
| `outdoor_ride` | duration, cals, HR, distance | avgHR | duration, cals, distance | outdoorOnly | disabled (→ P7) |
| `stationary_cardio` | duration, cals, HR | avgHR | duration, cals, HR | indoorOnly / n/a | disabled |
| `strength_session` | duration, cals, HR | avgHR | duration, cals, HR | notApplicable | disabled |
| `mind_body` | duration, cals, HR | avgHR | duration, cals | indoorOnly | disabled |
| `combat_conditioning` | duration, cals, HR | avgHR | duration, cals, HR | notApplicable | disabled |
| `court_sport` | duration, cals, HR, steps | avgHR | duration, cals | n/a | disabled |
| `open` | duration, cals, HR, steps | avgHR | duration, cals | userSelectable | disabled |

The EXP bar + reward progress are quest-level UI, not profile metrics — every
type keeps them (that's the game). Profiles shape the stat cells around them:
the watch live screen shows the profile's live set; the iOS quest detail shows
the summary set; primary picks what leads.

## Ripple effects (reviewed, decided)

- **Class Master pools families** — 3 yoga + 4 pilates = 7 toward MONK's 10.
  That pooling is the feature.
- **Full Party stays the four core classes** (run/walk/ride/lift), unchanged.
- **Multiclass (3 classes/week)** gets easier with 7 classes — ⚠️ TUNE review
  at v1.15 (consider 4).
- **Character sheet grid** — 4 core tiles always; any other class appears at
  its first quest (WILDCARD's existing rule generalizes).
- **Backfill MET table** keyed by typeID, all 22 rows, in `GameBalance`.
- **`QuestMetadata` additions:** `workoutTypeID` (+ `manual` from the backfill
  design). Parser verified forward-tolerant (reads keys individually, ignores
  schemaVersion) — old app versions render new-type quests via their HK
  activityType fallback bucketing.
- **Steps decided per type** (table), surfaced through profiles — subsumes
  roadmap W6.

## Build checklists

**v1.1 (rides with Record Old Workouts):**
- [ ] `WorkoutDefinition` + `WorkoutMetricsProfile` + `WorkoutMetric` models
      (shared file, both targets)
- [ ] 22 definitions + 9 profiles + class mapping as data
- [ ] `GameBalance`: per-typeID XP table + MET table
- [ ] `QuestMetadata.workoutTypeID` stamp (watch live quests keep stamping
      their 5; backfill stamps any of the 22)
- [ ] iOS class derivation reads typeID first, falls back to HK activityType
      for legacy workouts
- [ ] Backfill form type picker reads the catalog (grouped by class)

**v1.15 (catalog UX + live tracking):**
- [ ] Phone: catalog browser grouped by class, favorites (star) management
- [ ] Favorites sync via WatchConnectivity applicationContext (M4 pattern;
      fresh watch defaults to the original five)
- [ ] Watch: picker reads synced favorites; workout screen stat cells driven
      by the type's profile (live set)
- [ ] iOS quest detail driven by summary/primary sets
- [ ] Class affinity tiles + Multiclass TUNE review
- [ ] Mockups → approval → build; verify light/dark; device pass

**Post-launch validation (§13, adopted):** watch which types get picked/
favorited/backfilled, which classes level too fast/slow, what lands in Other,
whether HIIT's home and calorie/XP outcomes feel right, whether players feel
represented by their MAIN class. New classes require a meaningful activity
group + a real identity — never "HealthKit has more cases."
