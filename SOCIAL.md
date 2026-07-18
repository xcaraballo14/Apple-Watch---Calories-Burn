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
- **P1 — Accounts + profiles + friends. ✅ COMPLETE 2026-07-17 — first real
  account landed in the `profiles` table.**
  - ✅ **Schema + RLS** — `supabase/p1_schema.sql`: profiles (username
    regex-constrained, avatar kind/ref, level/title/badge_ids with sanity
    caps) + friendships (pending/accepted/blocked, unordered-pair unique
    index). Policies: profiles readable by any *signed-in* player (game
    identity is the public layer — enables friend search; health data can't
    exist here), writes self-only; friendship inserts requester-only +
    pending-only + blocked-pair-proof, addressee answers (accept/block),
    either side severs. ⚠️ Xavier must run it in the SQL editor.
  - ✅ **`SupabaseAPI.swift`** — dependency-free client (deliberate: no
    third-party SDK in the binary, keeps the audited privacy story; revisit
    at P2 if realtime justifies supabase-swift). GoTrue native-SIWA id_token
    exchange + auto-refresh, session in **Keychain** (never UserDefaults),
    PostgREST CRUD generics, Apple-nonce helpers (raw + SHA-256), row models.
    @MainActor like every app manager. Zero warnings.
  - ✅ **Sign in with Apple entitlement** added to the iOS target.
  - ✅ **Backend live — Xavier ran the SQL + enabled the Apple provider
    2026-07-17.** Verified from the outside: both tables exist (a control
    table 404s, so the schema cache is real), **RLS bites** (anonymous insert
    → `42501 new row violates row-level security policy` — nothing written),
    and the Apple provider parses id_tokens (`Unable to detect issuer` on a
    bogus token, which only happens once the provider is found; a disabled
    provider errors differently).
  - ✅ **Wiring landed 2026-07-17** (`GuildManager.swift`): SIWA with
    per-request nonce, Keychain session + auto-refresh, username claim via
    DB unique index (no check-then-write race), friend
    request/accept/decline/remove, exact-username search, friend profile with
    their trophy case, level/title/badge sync on quest-list change.
  - ✅ **First real sign-in 2026-07-17** — signed in with Apple on device,
    claimed a username, row confirmed in the `profiles` Table Editor. Full
    chain proven: SIWA → Supabase auth → RLS-protected write → cloud identity.
  - ⚠️ **The -7003 ghost (write it down so it never eats another night):**
    adding the Sign in with Apple capability by hand-editing the entitlements
    file put the key in the binary and the profile, but Apple's **auth server**
    never got a valid client registration — Xcode's auto-registration during
    an archive (3:08 AM) half-wrote it. Symptom: sheet renders fully, then
    "Sign Up Not Completed"; device console shows
    `AKAuthenticationError Code=-7003` with `AKClientBundleID=com.burnrewardapp.app`.
    NOT 2FA, restrictions, network, or the device account (Strava SIWA worked
    fine — the isolation test). **Cure:** developer.apple.com → Identifiers →
    the App ID → **uncheck** Sign in with Apple → Save → **re-check** →
    Configure as **primary App ID** → Save → **wait ~10 min for the auth fleet
    to propagate** → Clean Build Folder → run. The off/on forces Apple to
    delete + recreate the client registration. (The `-54`/LaunchServices lines
    and the trailing `1001` in the log are unrelated noise.)
  - 🧹 Pre-submission cleanup: the `print("SIWA failure …")` diagnostic in
    `GuildManager` (added to catch -7003) — remove or `#if DEBUG`-gate it in
    the Phase 3a hygiene pass.
  - **Next: P1.5** (Xavier's pixel avatar set replacing initial-circles) or
    straight to **P2 — the activity feed**.
  - ✅ **Placement ruled (Xavier 2026-07-16): social lives on a 5th tab —
    GUILD** (HOME · LOG · FORGE · GUILD · CHARACTER; icon: `Art/tab_guild.png`
    by Xavier, SF-symbol fallback until drawn). **Sign-in moment: one-time
    skippable prompt at app launch** (Xavier's call over my lazy-gate rec —
    more sign-ups; the prompt shows once per install, NOT NOW is permanent
    until the user opens GUILD, and the core loop stays account-free).
  - ⏳ Next: UI round (mockup-first) — launch prompt, GUILD signed-out /
    username claim / friends home states, add-friend search, friend profile
    view; then wiring to SupabaseAPI.
- **P2 — Feed. 🔨 BUILT 2026-07-18, awaiting the SQL run + device pass.**
  - **Placement ruled:** the GUILD tab gained a `FEED | PARTY` switch rather
    than a sixth tab. Feed leads (it's why people open the tab); PARTY carries
    a gold count badge when requests are waiting.
  - **Card layout (Xavier's mockup, 2026-07-18):** header → headline/caption →
    photos → **stats console** → **reaction console**. The two consoles share a
    frame, dividers, and colour language so the card reads as one machine. The
    stats redesign was Xavier's explicit ask: icon + full word + a 16pt value,
    one panel instead of three loose chips.
  - **Reactions, not comments (Xavier, 2026-07-18).** Closed palette: 🔥 BURN ·
    💪 STRONG · 👑 LEGEND · ⚔️ RESPECT, one per player per post (the DB primary
    key enforces it). A fixed set has **no abuse surface and no moderation
    queue** — which is exactly what free-text comments would have cost. Xavier
    asked for comments mid-session, heard the cost, and kept the ruling.
    Comments revisit post-launch with a real moderation budget; **⚔️ CHALLENGE
    from his mockup is deferred to P3** (it needs its own design).
  - **Photos: up to 3 per post, swipeable** (Xavier upgraded from my
    one-photo rec), on all three post kinds. Single photos skip the carousel
    chrome entirely.
  - ⚠️ **EXIF is the load-bearing safety step.** `PostPhotoPipeline` never
    uploads the picked file — it re-renders through a bitmap context and writes
    fresh JPEG bytes with empty EXIF/GPS/TIFF dictionaries. A raw camera photo
    carries the coordinates it was taken at; uploading one would publish a
    tester's home address *invisibly*. Downscale to 1440px long edge / q0.75
    (~200KB) happens in the same pass. **Never "optimize" the redraw away for
    already-small images — the redraw is the strip.**
  - **Posting is explicit only** (Xavier's dial): POST TO GUILD lives in P0's
    ShareCardSheet, gated on being signed in. Nothing auto-publishes.
  - **Realtime deferred to P3** (Xavier's call after the explainer): a
    friends-only feed updates a few times a day, so pull-to-refresh loses
    nothing, and posts arriving mid-scroll would shift content under the thumb.
    The hand-rolled websocket earns its keep when notifications exist. The
    dependency-free client survives P2 intact — **`supabase-swift` still not
    needed**, correcting the original plan above.
  - **Caption filter is a wordlist + URL stripper, and is documented as such.**
    Verified against 8 cases incl. the Scunthorpe problem (whole-word matching,
    no substring false positives). It is *not* moderation — report/block +
    the `hidden` kill switch in P4 are.
  - ⏳ **Blocked on Xavier:** (1) run `supabase/p2_schema.sql`; (2) add the
    **Sensitive Content Analysis** capability in Xcode → Signing &
    Capabilities. Without (2) the on-device nudity screen silently no-ops
    (`analysisPolicy == .disabled`) — the code degrades gracefully but the
    safety net is simply absent. Do it through Xcode's UI so the App ID
    auto-registers; hand-editing the entitlements file is what caused the
    -7003 ghost below.
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
