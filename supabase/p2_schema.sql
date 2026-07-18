-- BurnReward Social P2 — the activity feed (run once in the Supabase SQL editor,
-- after p1_schema.sql). Adds: share_events (posts), reactions (the closed
-- palette), and the post-photos storage bucket.
--
-- RLS is the security boundary: the app ships only the publishable key, so the
-- rules below are what actually keep a post inside its author's party.
-- Summary-only wire holds — payload carries reward name/emoji/calories/
-- duration/XP, never raw HealthKit samples, heart rate, routes, or exact
-- workout timestamps.

-- ============================================================ friendship helper
-- Used by every policy below. SECURITY DEFINER so a reader can test "are these
-- two accepted friends?" without needing read access to the whole friendships
-- table, and so the check can't be tricked by a partial view of it.
-- search_path is pinned: a definer function with a loose search_path is a
-- privilege-escalation hole.
create or replace function public.are_friends(a uuid, b uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.friendships f
    where f.status = 'accepted'
      and least(f.requester, f.addressee)    = least(a, b)
      and greatest(f.requester, f.addressee) = greatest(a, b)
  );
$$;

revoke all on function public.are_friends(uuid, uuid) from public;
grant execute on function public.are_friends(uuid, uuid) to authenticated;

-- ============================================================ share_events
create table public.share_events (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references public.profiles (id) on delete cascade,
  kind        text not null check (kind in ('quest', 'badge', 'levelup')),
  -- Summary fields only. Shape by kind:
  --   quest   { reward, emoji, calories, seconds, xp }
  --   badge   { badge_id, name }
  --   levelup { level, title }
  payload     jsonb not null,
  -- Player-written, filtered client-side before it ever gets here. The length
  -- cap is enforced again in the database so a modified client can't post a
  -- wall of text.
  caption     text check (caption is null or char_length(caption) <= 100),
  -- Storage paths under the post-photos bucket: '<user_id>/<event_id>/<n>.jpg'.
  photo_paths text[] not null default '{}'
              check (array_length(photo_paths, 1) is null
                     or array_length(photo_paths, 1) <= 3),
  -- Moderation kill switch (Guideline 1.2). Hidden posts disappear from every
  -- feed including the author's; only the dashboard can flip it back.
  hidden      boolean not null default false,
  created_at  timestamptz not null default now()
);

create index share_events_feed_idx on public.share_events (created_at desc);
create index share_events_author_idx on public.share_events (user_id, created_at desc);

alter table public.share_events enable row level security;

-- The friends-only boundary, enforced in the database rather than the app.
create policy "feed readable by author and accepted friends"
  on public.share_events for select
  to authenticated
  using (
    not hidden
    and (user_id = auth.uid() or public.are_friends(auth.uid(), user_id))
  );

-- You post only as yourself, and never pre-hidden.
create policy "post as yourself"
  on public.share_events for insert
  to authenticated
  with check (user_id = auth.uid() and hidden = false);

-- Authors can take their own post down. Deliberately no UPDATE policy: a post
-- is immutable once shared, so what your party reacted to can't be swapped out
-- from under them.
create policy "authors can delete their posts"
  on public.share_events for delete
  to authenticated
  using (user_id = auth.uid());

-- ============================================================ reactions
create table public.reactions (
  event_id   uuid not null references public.share_events (id) on delete cascade,
  user_id    uuid not null references public.profiles (id) on delete cascade,
  reaction   text not null check (reaction in ('burn', 'strong', 'legend', 'respect')),
  created_at timestamptz not null default now(),
  -- One reaction per player per post: the counts mean "how many people felt
  -- this way", and the database is what guarantees it.
  primary key (event_id, user_id)
);

create index reactions_event_idx on public.reactions (event_id);

alter table public.reactions enable row level security;

-- You can see reactions exactly on the posts you can see. The EXISTS runs
-- under the reader's own RLS on share_events, so visibility can't widen here.
create policy "reactions visible with their post"
  on public.reactions for select
  to authenticated
  using (exists (select 1 from public.share_events e where e.id = event_id));

create policy "react as yourself"
  on public.reactions for insert
  to authenticated
  with check (
    user_id = auth.uid()
    and exists (select 1 from public.share_events e where e.id = event_id)
  );

-- Changing your mind moves your reaction rather than adding one.
create policy "change your own reaction"
  on public.reactions for update
  to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

create policy "take back your own reaction"
  on public.reactions for delete
  to authenticated
  using (user_id = auth.uid());

-- ============================================================ post photos
-- Private bucket. Paths are '<user_id>/<event_id>/<n>.jpg', so the first path
-- segment identifies the owner and drives the policies below.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('post-photos', 'post-photos', false, 5242880, array['image/jpeg'])
on conflict (id) do nothing;

-- Upload only into your own folder.
create policy "upload own post photos"
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'post-photos'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

-- Same friends-only boundary as the posts themselves — otherwise the photos
-- would be the leak the row-level rules were written to prevent.
create policy "post photos readable by author and accepted friends"
  on storage.objects for select
  to authenticated
  using (
    bucket_id = 'post-photos'
    and (
      (storage.foldername(name))[1] = auth.uid()::text
      or public.are_friends(auth.uid(), ((storage.foldername(name))[1])::uuid)
    )
  );

create policy "delete own post photos"
  on storage.objects for delete
  to authenticated
  using (
    bucket_id = 'post-photos'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

-- ⚠️ Deleting an auth user cascades the ROWS above but NOT the storage objects
-- — Postgres foreign keys don't reach into the storage backend. The in-app
-- account deletion flow (P4, Guideline 5.1.1(v)) must list and delete the
-- user's post-photos folder explicitly before deleting the account, or photos
-- outlive the account that owned them.
