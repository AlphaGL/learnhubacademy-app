# Supabase setup

Your data already lives in a Supabase Postgres database (the same one Django
uses via `DATABASE_URL`). The app talks to it through Supabase's API.

## 1. Find your project keys
Supabase dashboard → **Project Settings → API**:
- **Project URL** → use as `SUPABASE_URL`
- **anon public** key → use as `SUPABASE_ANON_KEY`

> These two are safe to ship in a mobile app. Access is controlled by
> Row-Level Security, **not** by hiding the anon key. NEVER ship the
> `service_role` key in the app.

## 2. Run the SQL setup
Dashboard → **SQL Editor → New query**, paste the contents of
[`../sql/supabase_setup.sql`](../sql/supabase_setup.sql), and **Run**.

This:
- grants the app read access to `learning_subject` / `learning_material` /
  `learning_materialimage`,
- enables RLS with safe read policies,
- creates `app_profiles`, `app_device_tokens`, `app_notifications`,
  `app_cgpa_records`,
- adds a trigger that auto-creates a profile row on signup.

If your Django `app_label` is not `learning`, edit the table names first.
(Confirm names in Supabase → **Table Editor**, or run:
`select tablename from pg_tables where schemaname='public';`)

## 3. Enable Google sign-in
Dashboard → **Authentication → Providers → Google → Enable**.
- Paste the **Client ID** and **Client Secret** from your Google Cloud OAuth
  consent screen / credentials (the same Google Cloud project Firebase uses).
- Authorized redirect URL is shown on that page — add it in Google Cloud.

Also under **Authentication → URL Configuration**, the default works for the
native PKCE flow used by the app.

## 4. Email confirmation (optional but recommended)
**Authentication → Providers → Email** — keep "Confirm email" on for production.
New users will get a confirmation email before they can sign in.

## 5. Test
Run the app with your keys (see README) and:
- Sign up with email → check the `app_profiles` row was created.
- Open **Courses** → you should see rows from `learning_subject`.

### Troubleshooting
- **Courses screen shows a permission error** → the SQL grants/policies didn't
  run, or table names differ. Re-run `supabase_setup.sql`.
- **Empty courses but no error** → `learning_subject` is genuinely empty in this
  project, or RLS policy filtered everything.
- **Google sign-in fails** → `GOOGLE_WEB_CLIENT_ID` missing/wrong, or the Google
  provider isn't enabled in Supabase.
