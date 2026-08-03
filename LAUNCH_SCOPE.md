# Launch scope — locked 2026-07-28 for a **September 6, 2026** release

The scope contract for v1.0 on the App Store. `ROADMAP.md` is the history of what
was built; this is the frozen list of what still gets built *before submission*,
and what explicitly does not. Xavier locked both decisions below on 2026-07-28.

---

## The finding that set this scope

`HealthKitService.swift:44` filters every HealthKit workout down to
`bundleIdentifier.hasPrefix("com.burnrewardapp.app")` — **the app only counts
workouts its own watch app recorded.** Anything else in Apple Health is discarded
before it reaches the XP engine:

- a run recorded by Strava → nothing
- a Garmin watch or an Oura ring → nothing
- a phone-tracked workout → nothing
- **Apple's own Workout app on the Apple Watch the user is already wearing → nothing**

Four of the five launch-blocking tester complaints are this one line seen from
different angles — including the headline one, *"no real retention, I'd rather
use Strava."* The app never competed with Strava; it demanded the user abandon
Strava and paid them in a snack. Nobody makes that trade.

The architecture is not the problem. Derivation-first from `HKWorkout` is exactly
right for this, and `QuestModels.swift:71` already degrades gracefully on a
workout carrying no BurnReward metadata (`isLegacy = true`). The aperture is
simply closed.

---

## Decision 1 — scope (locked: **aperture fix first**)

Ships for Sept 6:

1. **Open the aperture.** Read all HealthKit workouts, not just BurnReward's.
2. **Dedup.** Strava + Apple Watch both write the same run; overlapping samples
   must not double-count. Time-window overlap, prefer the richer sample.
3. **Balance.** Non-BurnReward workouts score at the already-adjudicated
   **×0.8 `manualFactor`** (`RECORD_OLD_WORKOUTS.md`, 2026-07-14). Never below
   v1 for a quest the user actually ran — the "can only level up" invariant holds.
4. **Type breadth.** `brLabel` currently maps **4** types (WALK/RUN/BIKE/LIFT)
   and calls everything else OTHER. Expand to the common set — swim, row, HIIT,
   elliptical, yoga, hike, dance, stair, and so on.
5. **Data breadth.** Add `totalDistance` + the distance/energy quantity types to
   the read set and surface them. Covers most of tester item 1.
6. **Thin activity sharing.** A fourth `FeedEventKind` — post a workout, not just
   a completed quest. Reuses `ShareCardView` + `FeedManager.post`; no new backend.
7. **The paperwork.** `APP_STORE_METADATA.md` rewrite (done 2026-07-28), push the
   privacy-policy + data-compliance rewrite live, App Privacy label, age rating.
8. **Two-account device pass** over ARENA, open profiles, consent gate, deletion.

**Cut to post-launch:** full 22-type / 7-class catalog with class affinity
(`WORKOUT_CATALOG.md`) · GPS + routes · push notifications (APNs + Edge Function)
· in-app phone-side workout *recording* · manual/retroactive entry UI · character
creation · real-life "dungeons".

> Cutting the 22-type catalog does **not** cut type breadth — item 4 above is the
> shallow version (labels + XP factors). The catalog's 7-class affinity system is
> what waits.

### Why not the alternatives

- **Ship Sept 6 without the aperture fix** — launches into the exact flaw five
  testers independently named, and "doesn't count my Garmin" becomes a permanent
  1-star review. The launch was already held once for social; this is not the
  same kind of hold, because it is not a missing feature. It is the app being
  blind to its users' actual exercise.
- **Everything, move the date** — buys the full catalog + push + phone recording
  for roughly a month of slip. Rejected: none of those are why testers churn.

---

## Decision 2 — foreign workouts and the quest loop (locked: **full credit, no auto-claim**)

A workout from another source:

| | |
|---|---|
| Earns XP (at ×0.8) | ✅ |
| Counts toward streak, weekly challenge, records, badges | ✅ |
| Appears in quest history | ✅ |
| **Auto-completes a pending quest / claims the reward** | ❌ |

You still run a real quest to earn a snack. The blindness ends; the quest loop
keeps its meaning. This deliberately *departs* from `RECORD_OLD_WORKOUTS.md`'s
"full reward loop" ruling — that spec assumed a manual-entry UI the user invokes
deliberately, not a firehose of workouts arriving from every app on the phone.

---

## The calendar

```
Jul 28 – Aug 14   build: aperture, dedup, balance, types, data, thin sharing,
                  paperwork, review-access seeding
Aug 14            FEATURE FREEZE → TestFlight to the trusted circle
Aug 14 – Aug 28   two-week bake — real multiplayer, mixed devices, mixed sources
Aug 28            submit for review
Aug 28 – Sep 6    review + 9 days of buffer (one rejection round, no more)
Sep 6             release (manual hold)
```

Roughly 13 working days of build. There is no slack for a second rejection round.

---

## Open risks

1. **App Review cannot exercise social alone.** Feed, ARENA, and open profiles
   are all friends-only, so a reviewer signing in with their own Apple ID sees
   empty states everywhere — a classic "we were unable to locate the features
   described" rejection. Fix before submission: seed a `burnreward_demo` account
   that **auto-accepts** party requests (DB trigger or Edge Function) and carries
   sample posts, then tell the reviewer to add it in the notes. Costs ~half a day
   and adds no new auth surface. **This is a code item, not paperwork.**
2. **The iPhone HealthKit usage string goes stale the moment the aperture opens.**
   It currently reads *"reads the workouts it saved from your Apple Watch"* —
   false once it reads everything. Must change in the same commit, and
   `data-compliance.html` mirrors it.
3. **`ROADMAP.md` is stale** — nothing after 2026-07-19, so it does not know the
   pivot, pillars 4a/4b/4c, or this document. Reconcile before submission.
4. **The privacy-policy + data-compliance rewrite is committed but unpushed**
   (`77ed0cf`). GitHub Pages still serves the old *"nothing leaves your device"*
   text. Pushing it is what makes the App Privacy label truthful.
5. **Age rating moves off 4+.** Photos, captions, and usernames are user-generated
   content. See `APP_STORE_METADATA.md` §5.

---

## Tester feedback → disposition (2026-07-28 round)

| # | Feedback | Disposition |
|---|---|---|
| 1 | More workout data — GPS, distance, routes, cycling, cadence, power, energy, weight, swimming | **Partial ship.** Distance/energy/per-type stats ride the aperture fix. GPS + routes cut. |
| 2 | No real retention — "would rather use Strava" | **Ship.** This is the aperture fix. |
| 3 | Other hardware — Garmin, smart ring | **Mostly free.** These platforms write workouts into Apple Health; opening the aperture picks them up with no partner API. Verify per-vendor during the bake. |
| 4 | Track workouts on the phone without the watch | **Split.** *Counting* phone-tracked workouts ships free with the aperture. *Recording* one inside BurnReward is cut to v1.1. |
| 5 | More ways to share achievements/challenges/goals/workouts | **Thin ship** — activity posts. |

Future ideas parked (Xavier's own, same round): **character creation/interaction**
and **real-life "dungeons"** — encounter-style side objectives on a route. Both
are v2, both fit the design north star, and dungeons specifically need the GPS
project to exist first, so it sequences behind it naturally.

More feedback is expected over the coming days. Anything arriving after **Aug 14**
lands in v1.1 by default, not v1.0 — that is what the freeze means.
