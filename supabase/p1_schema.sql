-- BurnReward Social P1 — profiles + friendships (run once in Supabase SQL editor)
-- RLS is the security boundary: the app ships only the publishable key, so
-- every rule below is what actually protects user data. Summary-only wire:
-- nothing in these tables is (or can hold) raw health data.

-- ============================================================ profiles
create table public.profiles (
  id         uuid primary key references auth.users (id) on delete cascade,
  username   text unique not null
             check (username ~ '^[a-z0-9_]{3,16}$'),
  avatar_kind text not null default 'pixel'
             check (avatar_kind in ('pixel', 'photo')),
  avatar_ref text,                       -- pixel avatar id, or storage path (P1.5)
  level      int  not null default 1  check (level between 1 and 999),
  title      text not null default 'SNACK ROOKIE' check (char_length(title) <= 32),
  badge_ids  text[] not null default '{}' check (array_length(badge_ids, 1) is null
                                                 or array_length(badge_ids, 1) <= 64),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.profiles enable row level security;

-- Game identity (username, level, title, badges) is the public layer by
-- design — readable by any signed-in player so friend search works. Health
-- data never touches this table.
create policy "profiles readable by the signed-in"
  on public.profiles for select
  to authenticated
  using (true);

create policy "own profile insert"
  on public.profiles for insert
  to authenticated
  with check (id = auth.uid());

create policy "own profile update"
  on public.profiles for update
  to authenticated
  using (id = auth.uid())
  with check (id = auth.uid());

create policy "own profile delete"
  on public.profiles for delete
  to authenticated
  using (id = auth.uid());

-- ============================================================ friendships
create table public.friendships (
  requester  uuid not null references public.profiles (id) on delete cascade,
  addressee  uuid not null references public.profiles (id) on delete cascade,
  status     text not null default 'pending'
             check (status in ('pending', 'accepted', 'blocked')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (requester, addressee),
  check (requester <> addressee)
);

-- One relationship per pair regardless of direction.
create unique index friendships_unordered_pair
  on public.friendships (least(requester, addressee), greatest(requester, addressee));

alter table public.friendships enable row level security;

create policy "own friendships readable"
  on public.friendships for select
  to authenticated
  using (auth.uid() in (requester, addressee));

-- You can only ask on your own behalf, only as 'pending', and not toward
-- someone in an existing (incl. blocked) relationship with you.
create policy "request a friendship"
  on public.friendships for insert
  to authenticated
  with check (
    requester = auth.uid()
    and status = 'pending'
    and not exists (
      select 1 from public.friendships f
      where least(f.requester, f.addressee) = least(requester, addressee)
        and greatest(f.requester, f.addressee) = greatest(requester, addressee)
    )
  );

-- The addressee answers: accept or block. (Requesters can't flip their own
-- request to accepted — that's the whole point.)
create policy "addressee answers"
  on public.friendships for update
  to authenticated
  using (addressee = auth.uid())
  with check (addressee = auth.uid() and status in ('accepted', 'blocked'));

-- Either side can sever (cancel a pending request / unfriend / unblock).
create policy "either side can sever"
  on public.friendships for delete
  to authenticated
  using (auth.uid() in (requester, addressee));

-- ============================================================ housekeeping
create or replace function public.touch_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at := now();
  return new;
end $$;

create trigger profiles_touch before update on public.profiles
  for each row execute function public.touch_updated_at();
create trigger friendships_touch before update on public.friendships
  for each row execute function public.touch_updated_at();
