-- BurnReward Social P3 — the weekly XP leaderboard / ⚔️ WEEKLY CHALLENGE
-- (run once in the Supabase SQL editor, after p2_schema.sql). Adds one table:
-- weekly_scores, holding each opted-in player's XP for a given week.
--
-- Summary-only wire, load-bearing: the ONLY thing posted is an integer XP
-- total and which week it's for. No workouts, no calories, no heart rate, no
-- timestamps. XP already bakes in precision + type factor (v2.1), so the board
-- ranks skill, not raw burn — the health guardrail lives in *what* is stored.
--
-- Opt-in: a row only exists once the player turns on "Join the weekly
-- challenge". Leaving deletes their rows, so they vanish from every board.

create table public.weekly_scores (
  user_id    uuid not null references public.profiles (id) on delete cascade,
  -- The Monday that starts the week, computed identically on every device
  -- (fixed Monday-start calendar) so friends in different locales still land
  -- in the same bucket.
  week_start date not null,
  xp         integer not null default 0 check (xp >= 0 and xp <= 1000000),
  updated_at timestamptz not null default now(),
  -- One score per player per week; the upsert from the client merges on this.
  primary key (user_id, week_start)
);

-- Ranking read: this week's rows, highest first.
create index weekly_scores_week_idx on public.weekly_scores (week_start, xp desc);

alter table public.weekly_scores enable row level security;

-- Same friends-only boundary as the feed: you see your own scores and those of
-- accepted friends, nobody else's. are_friends() already excludes blocked
-- pairs (p4a), so a block hides scores in both directions for free.
create policy "scores readable by author and accepted friends"
  on public.weekly_scores for select
  to authenticated
  using (user_id = auth.uid() or public.are_friends(auth.uid(), user_id));

-- You post, update, and delete only your own score. The client upserts, which
-- PostgREST runs as INSERT ... ON CONFLICT DO UPDATE — so it needs both the
-- insert and the update policy to pass.
create policy "post your own score"
  on public.weekly_scores for insert
  to authenticated
  with check (user_id = auth.uid());

create policy "update your own score"
  on public.weekly_scores for update
  to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

-- Leaving the challenge (opt-out) deletes your rows so you drop off every
-- friend's board immediately.
create policy "delete your own score"
  on public.weekly_scores for delete
  to authenticated
  using (user_id = auth.uid());
