-- BurnReward Social P4a — report + block (run once in the Supabase SQL editor,
-- after p2_schema.sql). Adds: the reports inbox, and real block semantics on
-- the existing friendships table.
--
-- Design note: blocking deliberately reuses friendships.status = 'blocked'
-- rather than a new table. are_friends() requires 'accepted', so the moment a
-- pair's row flips to 'blocked', every existing policy — feed rows, photos,
-- reactions — goes dark in BOTH directions with no further changes. The
-- p1 insert policy already refuses new requests toward any existing pair,
-- so a blocked player can't re-request either.

-- ============================================================ who blocked whom
-- Unblock is a right only the blocker holds, so the row has to say which side
-- that is. NULL on every non-blocked row (enforced below).
alter table public.friendships
  add column if not exists blocked_by uuid references public.profiles (id);

alter table public.friendships
  add constraint friendships_blocked_by_consistency
  check ((status = 'blocked') = (blocked_by is not null));

-- ============================================================ friendship policies
-- The p1 update/delete rules predate blocking and would let the *blocked*
-- person tamper with the row (flip it, or delete it and re-request). Replaced
-- wholesale with block-aware versions.

drop policy if exists "addressee answers" on public.friendships;
drop policy if exists "either side can sever" on public.friendships;

-- The addressee accepts a pending request. Only pending rows — otherwise a
-- blocked addressee could "accept" their own block away.
create policy "addressee accepts"
  on public.friendships for update
  to authenticated
  using (addressee = auth.uid() and status = 'pending')
  with check (addressee = auth.uid() and status = 'accepted' and blocked_by is null);

-- Either member can flip the pair to blocked — requester or addressee, from
-- pending or accepted. The using clause keeps the blocked person out: once
-- blocked_by names someone else, the row is untouchable to you.
create policy "either side can block"
  on public.friendships for update
  to authenticated
  using (
    auth.uid() in (requester, addressee)
    and (blocked_by is null or blocked_by = auth.uid())
  )
  with check (status = 'blocked' and blocked_by = auth.uid());

-- Severing (cancel / unfriend / unblock) — but a blocked row only by its
-- blocker. The blocked person severing would be self-unblocking.
create policy "sever unless blocked by the other side"
  on public.friendships for delete
  to authenticated
  using (
    auth.uid() in (requester, addressee)
    and (blocked_by is null or blocked_by = auth.uid())
  );

-- Blocking someone you have no row with (e.g. removed from the party first).
-- The p1 request policy only inserts 'pending'; this one only 'blocked'.
create policy "block without a prior row"
  on public.friendships for insert
  to authenticated
  with check (
    requester = auth.uid()
    and status = 'blocked'
    and blocked_by = auth.uid()
    and not exists (
      select 1 from public.friendships f
      where least(f.requester, f.addressee) = least(requester, addressee)
        and greatest(f.requester, f.addressee) = greatest(requester, addressee)
    )
  );

-- ============================================================ reports
-- The Guideline 1.2 inbox. Players can only file; reading, resolving, and
-- the hidden-flag kill switch happen in the dashboard (service role), so no
-- select/update/delete policies exist for the app at all.
create table public.reports (
  id          uuid primary key default gen_random_uuid(),
  reporter    uuid not null references public.profiles (id) on delete cascade,
  -- The player being reported — always present, so profile reports and
  -- post reports land in one inbox.
  target_user uuid not null references public.profiles (id) on delete cascade,
  -- Set when a specific post was reported. Survives the author taking the
  -- post down (set null) so the report itself isn't destroyed by the
  -- offender deleting the evidence — the dashboard still shows who and why.
  event_id    uuid references public.share_events (id) on delete set null,
  reason      text not null check (reason in ('inappropriate', 'spam', 'harassment', 'other')),
  note        text check (note is null or char_length(note) <= 200),
  created_at  timestamptz not null default now(),
  check (reporter <> target_user)
);

create index reports_inbox_idx on public.reports (created_at desc);

alter table public.reports enable row level security;

create policy "file a report as yourself"
  on public.reports for insert
  to authenticated
  with check (reporter = auth.uid());

-- ⚠️ Admin duty reminder (SOCIAL.md): reports are reviewed in the Supabase
-- dashboard within 24h — burnrewardapp@gmail.com is the published contact.
-- The kill switch for a reported post is share_events.hidden = true.
