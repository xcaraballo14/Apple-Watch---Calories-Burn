# Social — design record (the launch-gating build)

**Status: adjudicated with Xavier 2026-07-14 — ACTIVE PROJECT #1.** Same
evening build 30 was verified, Xavier held the App Store submission on tester
consensus: *"what's the purpose of leveling your character and earning
trophies if you can't share it."* The launch now gates on the **full social
stack** (his call, all four dials answered maximal). Build 30 + the metadata
pack (`APP_STORE_METADATA.md`) stay ready; Phase 3e resumes when this ships.
Queue behind it (order TBD post-launch): v1.1 backfill + catalog model,
v1.15 catalog UX, v1.2 Ember Tree.

## The four rulings (Xavier, 2026-07-14)

1. **Launch gate: full competitive layer.** The store submission waits for
   share card + accounts + friends + feed + leaderboards, TestFlight-baked.
2. **First social build: everything.** Tiers 1–3 in one scope (engineered in
   phases below, each phase dropping to the trusted circle as it lands).
3. **Avatars: photo upload allowed** (plus the pixel-art picker as the
   default/fallback). Ships with the image-safety plumbing below.
4. **Feed: short captions allowed** (plus the auto-generated structured
   line). Ships with the text-safety plumbing below.

## Invariants (unchanged, load-bearing)

- **Core loop stays 100% on-device.** Social is an opt-in, account-based,
  additive layer. No account → the entire shipped app works exactly as today.
- **Summary-only wire.** What can ever leave the device, each item
  user-chosen: display name, avatar, level, title, badge IDs, per-quest
  summaries (reward name/emoji, calories, duration, class, earned/unfinished),
  weekly XP totals, captions the user types. **Never:** raw HealthKit samples,
  heart rate, steps streams, routes/location, workout timestamps beyond the
  share event's own date.
- Promise copy becomes: *"Your health data never leaves your device — you
  choose exactly what to share."* (Privacy policy + `data-compliance.html` +
  App Privacy label all update in P4; §6 of the metadata pack pre-wrote the
  label answer.)

## Stack

- **Supabase** (Postgres + Auth + Realtime + Storage), `supabase-swift` SDK.
  Free tier for the whole build (⚠️ free projects pause after ~7 idle days —
  fine in active dev); **Pro (~$25/mo) required at public launch.**
- **Sign in with Apple only** (email hidden via private relay by default —
  privacy-consistent, and one-tap).
- **Row-Level Security from day one:** profiles readable by friends (+
  username search), share events readable by accepted friends only, every
  write scoped to `auth.uid()`. RLS is the privacy promise enforced at the
  database layer.
- iPhone-only in v1 — **the watch app is untouched by this entire project.**

### Project config (Xavier created 2026-07-14 — P1 unblocked)

- **Project URL:** `https://djofkmbxtzxdljongnqu.supabase.co`
- **Publishable key:** `sb_publishable_2ZXntTG_lcclsg2t1z1Qdw_vGWxMC32`
  (client-safe by design — it ships inside the app binary; RLS is the actual
  security boundary)
- The `service_role` key stays in the Supabase dashboard only — never in the
  repo, the app, or chat.
- Verified live 2026-07-14: Auth healthy (GoTrue v2.193.0); REST root
  correctly refuses publishable-key introspection (new-key-system behavior).

## Data model (sketch — finalized in P1)

| Table | Shape | Notes |
|---|---|---|
| `profiles` | id (auth.uid), username (unique, filtered), avatar_kind (pixel/photo), avatar_ref, level, title, badge_ids[], updated_at | Client posts its own derived summary; server stores, never computes health data |
| `friendships` | requester, addressee, status (pending/accepted/blocked), created_at | Friend-request model; `blocked` doubles as the block list |
| `share_events` | id, user_id, kind (quest/badge/levelup), payload jsonb (summary fields only), caption (≤100 chars, filtered), created_at, hidden (moderation) | The feed. Auto-generated line + optional caption |
| `weekly_xp` | user_id, week_start, xp, quests | Client-posted opt-in summaries; leaderboard = a view over friends' rows |
| `reports` | reporter, target_kind (event/profile/avatar), target_id, reason, status, created_at | Feeds the admin review flow |

Known + accepted: client-posted XP/summaries are forgeable by a modified
client. For friends-only leaderboards that's a v1-acceptable trust model
(you're competing with people you added); revisit only if global boards ever
ship.

## Moderation & App Review compliance (the price of dials 3 + 4)

Required by Guideline 1.2 (UGC) + 5.1.1(v) (accounts) — all launch-gating:

- **Captions:** ≤100 chars, client-side profanity wordlist, URLs stripped
  (kills spam/phishing), server double-check in an edge function. No DMs, no
  comments in v1 — captions are the only free text.
- **Avatar photos:** pre-upload **on-device** screen via Apple's
  `SensitiveContentAnalysis` framework (iOS 17+ — our floor is 17.6 ✓), small
  fixed size, stored in a Supabase storage bucket. No third-party moderation
  API in v1 — keeps "no third parties touch your data" true.
- **Report** on any event, profile, or avatar → content auto-hides for the
  reporter immediately, lands in `reports` for admin action.
- **Block** → mutual invisibility, enforced in RLS (not just UI).
- **In-app account deletion** (Apple-required): deletes the Supabase account
  + all rows + storage objects. On-device data is untouched — the game keeps
  working; the promise ("core loop needs no account") makes deletion clean.
- **Admin duty (Xavier, ongoing):** review reports via the Supabase dashboard;
  published contact burnrewardapp@gmail.com; respond within 24h. Policy page
  gains a moderation/community section (P4).

## Build phases (each drops to the trusted circle; store waits for all)

- **P0 — Share card — ✅ BUILT 2026-07-16 (mockup-first, Xavier locked).**
  `ShareCardView.swift`: always-dark gold-chrome card, two variants — quest
  (emoji, full EXP bar, CAL/TIME/XP cells, conditional 🎯 precision flex line)
  and badge (medallion art, flavor, earned date) — both signed
  "NAME · LVL n · RANK". Entry points: green SHARE THIS WIN button on earned
  quest receipts (Home/LOG/CHARACTER paths) and earned badge sheets
  (detent 544→614); earned-only, no button on unfinished/locked. Export:
  `ImageRenderer` @3x (~990 px PNG, transparent corners), `ShareLink` +
  Save-to-Photos (`NSPhotoLibraryAddUsageDescription` added, add-only) with
  success haptic + "Saved ✓" feedback. No HR on the card (health rule). QA
  flags: `-BRDemoShareCard[Badge]`. Sim-verified; share-sheet/Photos taps are
  Xavier's hand-check. Rides the next TestFlight drop.
- **P1 — Accounts + profiles + friends.** Xavier creates the Supabase project
  (setup handoff below); SIWA; username claim (filtered); avatar (pixel picker
  + photo upload w/ SCA gate); friend request/accept; friend profile view
  (level, title, trophy case from badge_ids).
- **P2 — Feed.** share_events + captions; share-to-feed flow from the quest
  receipt / badge unlock moments; feed screen (new tab or bell-adjacent —
  mockup decides); Realtime for live updates.
- **P3 — Leaderboards.** weekly_xp posting (opt-in toggle); friends weekly
  XP board; ties into the existing weekly-challenge screen real estate
  (mockup decides). Guardrail: weekly aggregates only — rest days never shown,
  no daily pressure mechanics (health rule).
- **P4 — Compliance hardening.** Report/block flows, account deletion,
  caption/avatar filters verified, App Privacy label update (§6 pack),
  privacy-policy + data-compliance pages, moderation section, review notes
  update for the reviewer (test account needed? — SIWA means reviewer signs
  in with their own Apple ID; note it).
- **Bake:** ≥2 weeks of trusted-circle multiplayer use, then **Phase 3e
  submit** with social in the listing copy (description gains a SHARE/COMPETE
  section — drafted at P4).

Realistic wall-clock to submittable: **6–8 weeks** at current cadence.

## Explicitly not in v1

Guilds/community events + global boards (P3/P4 roadmap, post-launch) ·
community recipes (P5) · reactions/likes on feed items (open sub-call — cheap
table, decide during P2 mockups) · GPS route sharing (P7, after the GPS
project) · comments/DMs (never without a much bigger moderation budget).

## Xavier's setup handoff (P1 prerequisite, ~5 min)

1. supabase.com → sign up (GitHub login is fine) → **New project**
2. Org: personal · Project name: `burnreward` · Region: **East US (N.
   Virginia)** (closest to PR) · Generate a strong DB password (save it —
   needed rarely, but needed)
3. Wait ~2 min for provisioning
4. Project Settings → API: copy the **Project URL** and the **`anon` public
   key** and paste both to me (they're publishable-safe; they go in the app)
5. **Never share the `service_role` key** — that one bypasses RLS; it stays
   in the dashboard only

Then P1 starts: I take schema, RLS policies, and the Swift client from there.
