-- ============================================================================
-- LearnHub app — Supabase setup
-- Run this in the Supabase dashboard: SQL Editor → New query → Run.
--
-- Context: your tables were created by Django on this same Postgres database.
-- The Flutter app talks to them through Supabase/PostgREST using the `anon`
-- and `authenticated` roles. By default those roles have NO access, so we:
--   1. Grant SELECT on the content tables.
--   2. Enable Row-Level Security (RLS) and add read policies.
--   3. Create app-owned tables for auth-linked profiles, device tokens,
--      notifications, and (optionally) saved CGPA records.
--
-- IMPORTANT: This grants READ-ONLY access to learning content. All writes that
-- touch money or vote integrity stay on the Django side. Adjust table names if
-- your Django app_label differs from `learning`.
-- ============================================================================

-- ---------------------------------------------------------------------------
-- 1. READ access to learning content (public catalog: subjects & materials)
-- ---------------------------------------------------------------------------
grant usage on schema public to anon, authenticated;

grant select on table public.learning_subject       to anon, authenticated;
grant select on table public.learning_material       to anon, authenticated;
grant select on table public.learning_materialimage  to anon, authenticated;

alter table public.learning_subject       enable row level security;
alter table public.learning_material      enable row level security;
alter table public.learning_materialimage enable row level security;

-- Anyone (signed in or not) may read the catalog. Tighten later if you want to
-- gate full materials behind a subscription (see note at the bottom).
drop policy if exists "read subjects" on public.learning_subject;
create policy "read subjects" on public.learning_subject
  for select using (true);

drop policy if exists "read materials" on public.learning_material;
create policy "read materials" on public.learning_material
  for select using (true);

drop policy if exists "read material images" on public.learning_materialimage;
create policy "read material images" on public.learning_materialimage
  for select using (true);

-- ---------------------------------------------------------------------------
-- 2. App-owned profile linking Supabase Auth user -> LearnHub data
--    Auto-created on signup via the trigger below.
-- ---------------------------------------------------------------------------
create table if not exists public.app_profiles (
  user_id        uuid primary key references auth.users(id) on delete cascade,
  full_name      text,
  phone_number   text,
  -- Optional link back to the Django auth_user.id once you reconcile accounts.
  django_user_id integer,
  is_subscribed  boolean not null default false,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);

alter table public.app_profiles enable row level security;

drop policy if exists "own profile read" on public.app_profiles;
create policy "own profile read" on public.app_profiles
  for select using (auth.uid() = user_id);

drop policy if exists "own profile upsert" on public.app_profiles;
create policy "own profile upsert" on public.app_profiles
  for insert with check (auth.uid() = user_id);

drop policy if exists "own profile update" on public.app_profiles;
create policy "own profile update" on public.app_profiles
  for update using (auth.uid() = user_id);

grant select, insert, update on table public.app_profiles to authenticated;

-- Create a profile row automatically whenever a new auth user signs up.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.app_profiles (user_id, full_name, phone_number)
  values (
    new.id,
    new.raw_user_meta_data ->> 'full_name',
    new.raw_user_meta_data ->> 'phone_number'
  )
  on conflict (user_id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ---------------------------------------------------------------------------
-- 3. Device push tokens (for Firebase Cloud Messaging targeting)
-- ---------------------------------------------------------------------------
create table if not exists public.app_device_tokens (
  token      text primary key,
  user_id    uuid not null references auth.users(id) on delete cascade,
  platform   text,
  updated_at timestamptz not null default now()
);

alter table public.app_device_tokens enable row level security;

drop policy if exists "own tokens" on public.app_device_tokens;
create policy "own tokens" on public.app_device_tokens
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

grant select, insert, update, delete on table public.app_device_tokens to authenticated;

-- ---------------------------------------------------------------------------
-- 4. Notification history (the app reads this; your sender writes it)
-- ---------------------------------------------------------------------------
create table if not exists public.app_notifications (
  id         bigint generated by default as identity primary key,
  user_id    uuid not null references auth.users(id) on delete cascade,
  title      text not null,
  body       text,
  data       jsonb default '{}'::jsonb,
  read_at    timestamptz,
  created_at timestamptz not null default now()
);

alter table public.app_notifications enable row level security;

drop policy if exists "own notifications read" on public.app_notifications;
create policy "own notifications read" on public.app_notifications
  for select using (auth.uid() = user_id);

drop policy if exists "own notifications update" on public.app_notifications;
create policy "own notifications update" on public.app_notifications
  for update using (auth.uid() = user_id);

grant select, update on table public.app_notifications to authenticated;

-- ---------------------------------------------------------------------------
-- 5. (Optional) Cloud-synced CGPA records — the app currently stores CGPA
--    locally; enable this if you want it to follow the user across devices.
-- ---------------------------------------------------------------------------
create table if not exists public.app_cgpa_records (
  user_id    uuid primary key references auth.users(id) on delete cascade,
  payload    jsonb not null default '[]'::jsonb,
  updated_at timestamptz not null default now()
);

alter table public.app_cgpa_records enable row level security;

drop policy if exists "own cgpa" on public.app_cgpa_records;
create policy "own cgpa" on public.app_cgpa_records
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

grant select, insert, update, delete on table public.app_cgpa_records to authenticated;

-- ---------------------------------------------------------------------------
-- 6. App release log — drives the in-app "update available" prompt.
--    The app isn't on the Play Store yet, so it has no store auto-update;
--    instead it reads this table on launch and compares version_code
--    against its own build number (see lib/core/services/update_service.dart).
--    One row per shipped build (append-only — keeps history, easy rollback).
--    Rows are inserted by the GitHub Actions release workflow using the
--    service_role key, not by the app.
-- ---------------------------------------------------------------------------
create table if not exists public.app_release (
  id           bigint generated by default as identity primary key,
  version_code integer not null,          -- matches the APK's build number (flutter --build-number)
  version_name text not null,             -- e.g. '1.1.0' — shown to the user
  apk_url      text not null,             -- direct download link (Cloudflare R2)
  mandatory    boolean not null default false, -- true = blocking/non-dismissible update
  notes        text,                      -- "what's new", shown in the dialog
  created_at   timestamptz not null default now()
);

alter table public.app_release enable row level security;

drop policy if exists "read app release" on public.app_release;
create policy "read app release" on public.app_release
  for select using (true);

grant select on table public.app_release to anon, authenticated;
-- No insert/update/delete grants for anon/authenticated — only the
-- service_role key (used server-side by CI) can publish a release.

-- ---------------------------------------------------------------------------
-- 7. Phone-number sign-in + identity-verified password reset.
--    Mirrors the Django site's own auth UX: log in with phone + password,
--    register with email, and reset a forgotten password by confirming
--    email + phone together (no email link) — see learning/forms.py
--    StudentLoginForm / IdentityVerificationForm on the website.
--
--    Supabase Auth's client SDK only signs in by email or phone-OTP, not
--    "phone + password", so the app looks up the matching email for a given
--    phone number here, then signs in with that email normally. Both
--    functions are SECURITY DEFINER because anon/authenticated has no
--    direct access to auth.users; they only return/act on exactly the row
--    matched by the caller-supplied phone/email, nothing else.
-- ---------------------------------------------------------------------------
create or replace function public.get_email_for_phone(p_phone text)
returns text
language plpgsql
security definer set search_path = public
as $$
declare
  v_email text;
begin
  select u.email into v_email
  from public.app_profiles p
  join auth.users u on u.id = p.user_id
  where p.phone_number = p_phone
  order by p.created_at asc
  limit 1;

  return v_email;
end;
$$;

revoke all on function public.get_email_for_phone(text) from public;
grant execute on function public.get_email_for_phone(text) to anon, authenticated;

create or replace function public.reset_password_with_identity(
  p_email text,
  p_phone text,
  p_new_password text
)
returns boolean
language plpgsql
security definer set search_path = public
as $$
declare
  v_user_id uuid;
begin
  if length(p_new_password) < 8 then
    raise exception 'Password must be at least 8 characters long.';
  end if;

  select u.id into v_user_id
  from auth.users u
  join public.app_profiles p on p.user_id = u.id
  where lower(u.email) = lower(p_email)
    and p.phone_number = p_phone;

  if v_user_id is null then
    return false;
  end if;

  update auth.users
  set encrypted_password = crypt(p_new_password, gen_salt('bf')),
      updated_at = now()
  where id = v_user_id;

  return true;
end;
$$;

revoke all on function public.reset_password_with_identity(text, text, text) from public;
grant execute on function public.reset_password_with_identity(text, text, text) to anon, authenticated;

-- ============================================================================
-- OPTIONAL: gate full material content behind a subscription
-- ----------------------------------------------------------------------------
-- If you later want only subscribers to read full materials, replace the
-- "read materials" policy with something like:
--
--   create policy "read materials" on public.learning_material
--     for select using (
--       exists (
--         select 1 from public.app_profiles p
--         where p.user_id = auth.uid() and p.is_subscribed = true
--       )
--     );
--
-- ...and keep subjects public so the catalog is still browsable.
-- You would set app_profiles.is_subscribed = true from your Paystack webhook
-- (server-side) using the Supabase service-role key.
-- ============================================================================
