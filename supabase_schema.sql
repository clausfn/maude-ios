-- Liviqa Supabase schema — Phase 1
-- Run in Supabase SQL editor. All tables use RLS; only the signed-in user touches their own rows.

-- ─────────────────────────────────────────────
-- profiles
-- ─────────────────────────────────────────────
create table if not exists profiles (
  id              uuid primary key references auth.users on delete cascade,
  display_name    text,
  avatar_url      text,
  created_at      timestamptz default now()
);

alter table profiles enable row level security;

create policy "Own profile only"
  on profiles for all
  using (auth.uid() = id)
  with check (auth.uid() = id);

-- Auto-create profile on sign-up
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles (id) values (new.id);
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- ─────────────────────────────────────────────
-- wallet_grants
-- ─────────────────────────────────────────────
create table if not exists wallet_grants (
  id                uuid primary key default gen_random_uuid(),
  user_id           uuid not null references auth.users on delete cascade,
  recipient_name    text not null,
  recipient_type    text not null,           -- research | clinical | employer | insurance | public_good
  scope_keys        text[] not null,
  is_active         boolean not null default true,
  expires_at        timestamptz,
  created_at        timestamptz default now()
);

alter table wallet_grants enable row level security;

create policy "Own grants only"
  on wallet_grants for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- ─────────────────────────────────────────────
-- wallet_events
-- ─────────────────────────────────────────────
create table if not exists wallet_events (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references auth.users on delete cascade,
  event_type    text not null,              -- access_request | consent_granted | consent_revoked | data_accessed
  actor_name    text not null,
  scope_keys    text[] not null,
  decision      text not null default 'pending',
  occurred_at   timestamptz default now()
);

alter table wallet_events enable row level security;

create policy "Own events only"
  on wallet_events for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- ─────────────────────────────────────────────
-- journal_entries  (opt-in sync only — HealthKit data never stored here)
-- ─────────────────────────────────────────────
create table if not exists journal_entries (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references auth.users on delete cascade,
  body          text not null,
  mood          int check (mood between 1 and 5),
  metrics       jsonb,                      -- MetricSnapshot (no raw HealthKit data)
  tags          text[] default '{}',
  sync_enabled  boolean not null default false,
  created_at    timestamptz default now(),
  updated_at    timestamptz default now()
);

alter table journal_entries enable row level security;

create policy "Own journal only"
  on journal_entries for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);
