# BurnReward — Ember Tree (Perk Tree) Design Record

**Status:** Design locked 2026-07-11 · **post-launch project #1** (chosen over GPS
routes; nothing here builds before the App Store submission ships).
**Provenance:** Xavier's external spec (drafted with another agent), adjudicated
in-session and adopted **with four corrections** plus one product fork Xavier
decided. This document supersedes both the raw spec and the earlier in-session
strawman tree. Whoever builds Phase 1 starts *here* — do not re-litigate.

---

## 1. What it is

A PoE-*inspired* (not PoE-*sized*) passive tree, ~32–36 nodes, that lets players
shape **how they earn XP and specialize per fitness class**. It is the
centerpiece of the future subscription and the payoff that makes leveling *do*
something beyond changing your title.

**Naming (locked):** **Ember Tree** · **Ember Points** · **Reforge** (respec) ·
**Builds** (saved setups) · **Keystones** (major perks). "Reforge" deliberately
rhymes with the REWARD FORGE tab language. Subscription name TBD.

---

## 2. Non-negotiables — trust and health rules

Perks may modify: XP earned, class specialization, precision/combo bonuses,
planning tools (previews, loadouts), weekly-challenge options, streak
protection, cosmetics.

Perks may **never** modify:
- HealthKit calorie or heart-rate measurements
- The reward's calorie goal, or whether it's marked EARNED
- The workout saved to Apple Health

Additional guardrails (ours, beyond the spec):
- **No repeatable incentives for raw overshoot.** "Big burn" conditions are
  **goal-relative** — "complete a quest whose *goal* is ≥ X" rewards ambition
  chosen at pick time; it never pays for blowing past a small goal (that would
  be precision-hostile and push overexertion).
- No perks keyed to hitting heart-rate targets, GPS, or any new HealthKit
  permission. V1 lives entirely on existing metrics.
- Keystone trade-offs **gate bonuses**; they never penalize, and copy never
  shames a short workout.
- Unfinished quests earn no perk XP.

---

## 3. Decisions locked 2026-07-11

| Decision | Ruling |
|---|---|
| History model | **Frozen snapshots** (see §4) — not retroactive re-derivation |
| Free vs. paid | **Free-core hybrid** (Xavier's pick, see §5) |
| Branch access | All branches open to everyone; class affinity is a *suggested-path highlight* only |
| Respec | Unlimited Reforge while no quest is active; allocation changes take effect **next quest** |
| Keystones | Exactly one active per build |
| Hybrids | Each triggers at most once per quest; two hybrids never stack on the same quest |
| Percentage math | Percentage bonuses apply to **base calorie XP only** (matches XP v2 architecture) |
| Watch | Never renders the tree; shows build name pre-quest + triggered perks on Earned |
| Navigation | **No fifth tab.** EMBER TREE card on CHARACTER, between Class Affinity and Records |
| Subscription shape | Bundle, not tree-only: tree + 3 build slots + premium weekly-challenge variants + themes + complication styles + build statistics |
| Products | One subscription group, monthly + yearly (`com.burnrewardapp.<name>.monthly` / `.yearly`); pricing experiment $3.99 / $24.99, optional 7-day trial; prices always from `Product.displayPrice`, never hard-coded |
| Cancellation | Nothing is destroyed: premium allocations go **dormant** (saved, inactive; watch shows BUILD DORMANT), historical XP untouched, re-subscribe reactivates instantly. Free-core allocations (§5) stay active |

---

## 4. Why frozen history (the big architecture call)

The earlier idea — perks as retroactive re-derivation ("buy a perk, your whole
history re-scores up") — **fails under unlimited respec**: moving points *out*
of a perk would lower past XP, so levels could drop, violating the oldest
invariant (re-derived history can only level up).

Adopted instead: **freeze the build at quest start, evaluate at quest end, stamp
the perk result into the workout's HealthKit metadata** — final at the moment
it's earned, exactly like calories.

- **HealthKit stays the database.** Perk XP rides in the same immutable metadata
  as reward names; a reinstall still rebuilds all historical XP.
- Base XP (calories × factors + standard bonuses) stays re-derived as today;
  only the **perk line** is a stored fact. Pre-perk and unsubscribed quests have
  no perk metadata → deterministically zero.
- Balance patches to the tree never rewrite anyone's history.

**Metadata keys** (values are controlled IDs/numbers ONLY — never user text;
the `|` separator corruption bug taught us this):

```
br.perkTreeVersion      1
br.activePerkIDs        kindling|fleet_footed|quick_burn|single_strike
br.activeKeystoneID     single_strike
br.perkBonusXP          114
br.perkBreakdown        fleet_footed:21|quick_burn:33|sharp_landing:60
```

**Engineering corrections folded in (the four):**
1. **Snapshot carries *resolved effects*** (condition + amount), not node IDs —
   the watch never needs the tree JSON or version sync; a stale watch cannot
   mis-evaluate. `ActiveBuildSnapshot` is self-contained and includes
   `entitlementWasActive` (a sub expiring mid-quest still honors that quest).
2. **Metadata is immutable — perk-engine bugs are permanent.** `PerkEngine` is
   pure Foundation (no SwiftUI/HealthKit/StoreKit/WatchConnectivity imports),
   with a unit test per node, before any watch build ships it.
3. **Builds must survive reinstall.** Allocations live in
   `NSUbiquitousKeyValueStore` (iCloud KVS — no backend, no account) with a
   local mirror. Points *earned* stay derived from level, so only choices are
   stored.
4. Tree definition ships as bundled `PerkTree-v1.json` (ids, branch, cost,
   prereqs, coordinates, effect definitions, icon names, version).

Flow: iPhone allocation → build saved (iCloud KVS + local) → WatchConnectivity
application context → watch stores resolved snapshot → quest starts (snapshot
frozen) → quest ends → watch evaluates → result stamped into workout metadata →
iPhone reads it forever after.

---

## 5. Free-core hybrid (the fork, decided)

- **Everyone** accumulates Ember Points (derived from level — free forever).
- **Free users** may allocate up to **3 points, inside Ember Core only**, and
  can Reforge them like anyone else.
- **Subscribers** unlock the branches, keystones, hybrids, and 3 build slots.
- **The paywall is contextual, not a splash screen:** the tree screen and
  CHARACTER card surface *"You have 9 unspent Ember Points"* — unspent points
  are the pitch. Additionally, **Quest Sense** (free-allocatable, see §7) shows
  which locked perks *would have triggered* on a quest — that preview is the
  conversion moment. Keep its copy gentle; it must inform, never nag.
- On lapse: premium allocations dormant; the free-core 3 stay active.

Accepted trade-off, eyes open: perk XP means subscribers level somewhat faster —
titles become partially accelerated by paying. Calories/EARNED are untouchable,
and the caps (§6) keep magnitudes modest so FEAST OVERLORD still means the work
was done.

---

## 6. Point economy and balance — ⚠️ both flagged TUNE

**Pacing problem found:** the spec's pacing wasn't tested against our curve
`T(L) = 100(L−1)² + 400(L−1)`:

| Spec's pacing | Level needed | XP needed | Realistic time* |
|---|---|---|---|
| 14 points | 15 | 25,200 | ~3–4 months |
| 20 points (cap) | 27 | 78,000 | a year+ |

*at ~1,500–2,500 XP/week (3–5 quests). A new subscriber's first week yields
4–6 points — one notable and change. Too slow for a paid centerpiece.

**Provisional re-pace** (final numbers from real TestFlight XP velocity):
unlock at level 5 with **6** starter points, **+1 per level through 20**, then
+1 every 2 levels, cap **26**. Node costs adopted: minor 1 · notable 2 ·
keystone 3.

**Balance bug found:** a focused Strider build sums 3+5+8+8+18 = **42% in
percentage nodes against the spec's 25% cap** — nearly half the flagship
build's points would do nothing. **Rule adopted:** *the maximum reachable
stackable-percentage sum on any legal single-class path must equal the cap* (no
dead allocations). Resolve in the balancing pass by raising the cap toward
~40% or shrinking node percentages — pick one, verify per branch.

Caps adopted: perk XP per quest ≤ min(percentage cap × base XP, **150 XP**);
receipt shows ≤ 3 perk lines (+ rollup line if more triggered).

---

## 7. Node blueprint v1 (24 named + 8–12 small connectors)

Layout: four class branches radiating from a shared core, hybrids between
adjacent branches. Class affinity highlights (never locks) a suggested path.

**Renames from the spec (canon collisions):**
- ~~Long Haul~~ → **Long Ride** (LONG HAUL is a live weekly challenge)
- ~~Berserker~~ → **Spearhead** (BURRITO BERSERKER is a title-ladder rung)
- Soft overlaps reviewed and accepted: *Long Road* vs the Long Walk / Long
  March badges; *Feastbreaker* vs the FEAST title vocabulary — different
  surfaces, no player-facing ambiguity.

### Ember Core (free-allocatable up to 3 points)
| Node | Cost | Effect |
|---|---:|---|
| Kindling | 1 | Completed quests gain +3% base XP |
| Quest Sense | 2 | Reward picker previews estimated XP + which perks could trigger (locked perks shown dimmed — the conversion surface) |
| Precision Rune | 2 | Finishing within 5% of goal grants +40 flat XP |
| Combo Socket | 2 | Save 3 favorite reward combos, synced to the watch picker |

### Strider (Run)
| Node | Cost | Effect |
|---|---:|---|
| Fleet Footed | 1 | Run quests +5% base XP |
| Quick Burn | 1 | Run quests 15–30 min +8% base XP |
| Sharp Landing | 2 | Run quests within 5% of goal +60 XP |
| Solo Hunt | 2 | Single-reward Run quests +8% base XP |
| **Single Strike** (keystone) | 3 | Single-reward Run quests +18% base XP; two-reward Runs get no Strider bonuses |

### Wayfarer (Walk)
| Node | Cost | Effect |
|---|---:|---|
| Trail Sense | 1 | Walk quests +5% base XP |
| Long Road | 1 | Walk quests ≥30 min +8% base XP |
| Five Thousand Strong | 2 | Walk quests reaching 5,000 steps +60 XP |
| Gentle Precision | 2 | Walks ≥30 min ending within 10% of goal +60 XP |
| **Pilgrim's Pact** (keystone) | 3 | Walks ≥45 min +18% base XP; walks under 30 min get no Wayfarer bonuses |

### Outrider (Bike)
| Node | Cost | Effect |
|---|---:|---|
| Rolling Start | 1 | Bike quests +5% base XP |
| Long Ride | 1 | Bike quests ≥45 min +8% base XP |
| Big Gear | 2 | Bike quests with a **goal ≥400 cal**, completed, +60 XP *(goal-relative — see §2)* |
| Clean Cadence | 2 | Bike quests within 5% of goal +60 XP |
| **Endless Road** (keystone) | 3 | +1% base XP per 10 min, up to +15%; flat Outrider bonuses disabled |

### Juggernaut (Lift / Other)
| Node | Cost | Effect |
|---|---:|---|
| Iron Core | 1 | Lift/Other quests +5% base XP |
| Heavy Load | 1 | Quests with a goal ≥400 cal +8% base XP *(already goal-relative)* |
| Time Under Tension | 2 | Lift/Other quests ≥45 min +8% base XP |
| Combo Crafter | 2 | Two-reward quests +60 XP |
| **Feastbreaker** (keystone) | 3 | Two-reward quests +18% base XP; single-reward quests get no Juggernaut bonuses |

### Hybrid notables (require nodes in both adjacent branches; once per quest; never two hybrids on one quest)
| Node | Between | Effect |
|---|---|---|
| Pathfinder | Strider + Wayfarer | Run/Walk ≥30 min within 5% of goal +100 XP |
| Voyager | Wayfarer + Outrider | Walk/Bike ≥45 min +100 XP |
| Siege Engine | Outrider + Juggernaut | Bike/Lift/Other with a **goal ≥500 cal**, completed, +100 XP *(goal-relative)* |
| Spearhead | Juggernaut + Strider | Run/Lift/Other, single reward, within 5% of goal +100 XP |

Connectors: 8–12 minor +2%-class-XP nodes shaping the paths. All percentages
above are **provisional pending the §6 balance pass.**

---

## 8. Surfaces

- **Receipt** gains a PERKS section (read from metadata breakdown):
  `Fleet Footed +21 · Quick Burn +33 · Sharp Landing +60 · PERK TOTAL +114`.
- **CHARACTER card** (between Class Affinity and Records): tree name, points
  spent/available, active build name, branch pips, OPEN TREE button.
- **Tree screen:** pan/zoom canvas, pinch zoom, branch-focus buttons; node
  states (allocated / available / locked / keystone / suggested-class glow /
  premium-dormant); tap → bottom card with description + cost + ALLOCATE.
  Pixel font for node names/costs/buttons only; system font for descriptions.
  VoiceOver on every node state, Dynamic Type, Reduce Motion honored, light +
  dark. **Mockup-first before any of this is built — house rule.**
- **Watch:** picker shows active build name; Earned screen lists triggered
  perks + perk XP. The watch never shows the tree.

---

## 9. Compliance updates required when this ships

- `data-compliance.html`: StoreKit wording ("BurnReward operates no backend and
  transmits no health data; StoreKit communicates with Apple to display,
  purchase, restore, and verify subscriptions") + storage inventory additions
  (perk allocations, build slots, entitlement cache, watch snapshot, perk
  workout metadata, iCloud KVS).
- `terms.html`: subscription section (auto-renewal, billing period, cancel via
  Apple, Restore Purchases, post-expiration behavior, refunds via Apple, price
  changes).
- Privacy label: likely still "Data Not Collected" (purchase data is Apple's
  collection, not ours) — re-verify against the questionnaire when that
  version submits.
- Hard rule: never use health data (calories, HR, weight, activity) to vary
  pricing or target purchase messaging.

---

## 10. Build order (phases) and acceptance gates

1. **Rules + data:** final pacing numbers → `PerkTree-v1.json` →
   `PerkBuildState` / `ActiveBuildSnapshot` → pure `PerkEngine` → a unit test
   per node. *(Pure Foundation — safe to start while the App Store build is in
   review.)*
2. **Quest integration:** freeze at start, evaluate at end, stamp metadata,
   PERKS receipt section; prove a Reforge never changes any historical XP.
3. **Tree UI:** CHARACTER card → canvas → allocation → build slots → Reforge →
   light/dark + accessibility. Mockups approved before build.
4. **Watch:** sync resolved snapshot, persist in App Group, Earned-screen
   perks, standalone test.
5. **Subscription:** products + `EntitlementManager`
   (`Transaction.currentEntitlements`, updates listener) → purchase/restore →
   gate *activation, not visibility* → expiration/revocation/grace states.
6. **TestFlight balancing:** watch for a dominant keystone/branch, whether
   receipts explain triggers, whether anyone trains unsafely for a perk.
   No analytics SDK — TestFlight feedback only.

**Do not launch until:** Reforge never rewrites history · watch works without
the iPhone · lapse erases nothing and free-core stays active · refund/revoke
disables future activation · the 150-XP cap is unbreachable · no node touches
the calorie goal · no node needs GPS or new permissions · unfinished quests
can't be farmed · tree navigable with VoiceOver and large text · every node
state legible in light and dark.

---

## 11. Explicitly open (not decided)

- Final pacing + percentage numbers (needs real tester XP velocity — §6)
- Subscription name and final pricing
- Node icon art (Xavier's pipeline — see `ART_ASSETS.md` conventions)
- Seasonal outer rings (deferred; `treeVersion` keeps the door open)
