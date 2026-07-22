-- BurnReward Social P3.5 — the shared character sheet (run once in the Supabase
-- SQL editor, after p3_schema.sql). One table: shared_characters, holding the
-- snapshot a friend sees on your open profile.
--
-- ⚠️ WHY A SEPARATE TABLE, NOT A profiles COLUMN: the profiles table is
-- readable by ANY signed-in player (it powers friend search — p1_schema.sql).
-- After the 2026-07-21 privacy pivot this snapshot carries real metrics
-- (calories, heart rate, steps), so it must be scoped to accepted friends, not
-- the whole user base. Same are_friends() boundary as the feed and scores.
--
-- Visibility model: a row exists only while you share ("party"). Turning the
-- "Show my character to my party" toggle off DELETES the row ("private"), so a
-- friend instantly falls back to your name / level / trophies. The two hard
-- lines from the pivot still hold: this data is never sold or handed to
-- sponsors/advertisers, and never used for ad targeting (Apple 5.1.3).

create table public.shared_characters (
  -- One snapshot per player; the client upserts on this key.
  user_id    uuid primary key references public.profiles (id) on delete cascade,
  -- The whole SharedCharacter struct (XP, class spread, lifetime, records).
  -- A blob rather than columns because the shape evolves with the character
  -- page and no policy or query ever needs to read inside it.
  character  jsonb not null,
  updated_at timestamptz not null default now()
);

alter table public.shared_characters enable row level security;

-- Readable by you and your accepted friends only. are_friends() already
-- excludes blocked pairs (p4a), so a block hides your character both ways.
create policy "character readable by author and accepted friends"
  on public.shared_characters for select
  to authenticated
  using (user_id = auth.uid() or public.are_friends(auth.uid(), user_id));

-- You write only your own. The client upserts, which PostgREST runs as
-- INSERT ... ON CONFLICT DO UPDATE, so it needs both insert and update to pass.
create policy "post your own character"
  on public.shared_characters for insert
  to authenticated
  with check (user_id = auth.uid());

create policy "update your own character"
  on public.shared_characters for update
  to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

-- Going private (toggle off) deletes your row.
create policy "delete your own character"
  on public.shared_characters for delete
  to authenticated
  using (user_id = auth.uid());
