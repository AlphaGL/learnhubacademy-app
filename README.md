# LearnHub — Flutter App

The mobile companion to the LearnHub learning platform. It reads your learning
content **directly from Supabase** (so it keeps working even if the Django web
site is down), uses **Supabase Auth** for accounts (incl. Google sign-in), and
**Firebase** for push notifications, analytics, and crash reporting.

> Status: **v1 foundation** — premium UI (splash, onboarding, dark mode,
> shimmer loading, gradient design system), Auth (email + Google), dashboard,
> course/material browsing, "Explain with AI", the CGPA calculator, push
> notifications, and Play-Store release config. Awards, study groups, CBT exams,
> ambassador, and in-app subscription are the next modules (architecture is
> built to scale into them).

## Premium design system
- **Typography:** Plus Jakarta Sans (`google_fonts`).
- **Brand:** indigo→violet gradient used sparingly for emphasis.
- **Components:** `PremiumCard`, `GradientButton`, `AppLogo`, `SectionHeader`,
  `EmptyState`, `Pill`, shimmer skeletons — all in `lib/shared/widgets/`.
- **Motion:** subtle entrance animations via `flutter_animate`.
- **Dark mode:** system / light / dark, persisted (Profile → Dark mode).
- **First-run:** branded splash + 3-slide onboarding.

---

## Architecture at a glance

```
Flutter app ──► Supabase (PostgREST + Auth)  ──►  your existing Supabase Postgres
     │                                              (same DB Django uses)
     └────────► Firebase (FCM push, Analytics, Crashlytics)
```

- **Data:** read directly from the Django-created tables (`learning_subject`,
  `learning_material`, …) via Supabase. Row-Level Security controls access — see
  [`sql/supabase_setup.sql`](sql/supabase_setup.sql).
- **Auth:** Supabase Auth (email/password + Google). Required so RLS can use
  `auth.uid()`.
- **Why not connect to the DB directly?** A mobile app can't safely hold DB
  credentials. Supabase gives a safe, RLS-guarded API over the *same* database.

### Login caveat for existing users
Your current passwords live in Django's `auth_user` table (PBKDF2 hashes), which
Supabase Auth can't read. So:
- **New users** sign up in the app (Supabase Auth).
- **Existing users** sign in with **Google**, or use **"Forgot password"** to
  set an app password (this creates their Supabase Auth identity).
- `app_profiles.django_user_id` is provided so you can reconcile the two
  identities later if needed.

---

## First-time setup (do this once)

### 0. Prerequisites
- Install Flutter SDK (stable channel) and run `flutter doctor`.
- Android Studio (for the Android SDK + an emulator or a real device).

### 1. Generate the native platform folders
This repo ships `lib/`, `pubspec.yaml`, config, SQL, and docs. Generate the
`android/`, `ios/`, etc. folders into it:

```bash
cd C:\Users\Ibeawuchi\Desktop\neky\learnhub_app
flutter create . --org com.neky --project-name learnhub --platforms=android,ios
flutter pub get
```

(`flutter create .` will NOT overwrite the existing `lib/` or `pubspec.yaml`.)

### 2. Supabase
Follow [`docs/SUPABASE_SETUP.md`](docs/SUPABASE_SETUP.md):
1. Get your **Project URL** and **anon key** (Project Settings → API).
2. Run [`sql/supabase_setup.sql`](sql/supabase_setup.sql) in the SQL Editor.
3. Enable the **Google** auth provider.

### 3. Firebase
Follow [`docs/FIREBASE_SETUP.md`](docs/FIREBASE_SETUP.md):
1. Create a Firebase project, add an Android app with id `com.neky.learnhub`.
2. Download `google-services.json` → `android/app/google-services.json`.
3. Add the Google Services Gradle plugin (exact lines in the doc).
4. Copy the **Web client ID** for Google sign-in.

### 4. Run
Keys live in **`dart_define.json`** (git-ignored). It's already pre-filled with
your **Supabase URL** (`https://wtakxswpardxmkdupeqn.supabase.co`, derived from
your Django `.env` DB host), Cloudinary cloud name, and Paystack public key.
You only need to paste two values:

- `SUPABASE_ANON_KEY` — from Supabase Dashboard → Project Settings → API.
- `GOOGLE_WEB_CLIENT_ID` — from Firebase / Google Cloud (for Google sign-in).

Then run:

```bash
flutter run --dart-define-from-file=dart_define.json
```

> Only **public** keys belong here. The DB password, Cloudinary secret, Paystack
> secret, and Brevo key from your `.env` must NEVER ship in the app — they stay
> on the Django server. `dart_define.json` is git-ignored for safety.

> First launch downloads the Plus Jakarta Sans font (google_fonts) — needs
> internet once, then it's cached. To fully offline-proof it, bundle the font
> files and switch `GoogleFonts` to a bundled `TextTheme`.

---

## Building for the Play Store
See [`docs/PLAYSTORE_CHECKLIST.md`](docs/PLAYSTORE_CHECKLIST.md). Short version:

```bash
flutter build appbundle --release \
  --dart-define=SUPABASE_URL=... \
  --dart-define=SUPABASE_ANON_KEY=... \
  --dart-define=GOOGLE_WEB_CLIENT_ID=...
```

You must set up an upload keystore + signing config first (in the doc), publish
a privacy policy ([`docs/PRIVACY_POLICY_TEMPLATE.md`](docs/PRIVACY_POLICY_TEMPLATE.md)),
and complete the **Data safety** form.

---

## Project layout

```
lib/
  main.dart                 # bootstrap: Firebase + Supabase init
  app.dart                  # MaterialApp + theme + AuthGate
  core/
    config/app_config.dart  # keys (via --dart-define) + table names
    theme/app_theme.dart
    services/               # supabase, auth, notifications (FCM), analytics
  features/
    auth/                   # login, signup, Google, auth gate
    home/                   # bottom-nav shell + dashboard
    subjects/               # course catalog (reads learning_subject)
    materials/              # topics + detail + "Explain with AI"
    cgpa/                   # CGPA calculator (local storage)
    notifications/          # notification history
    profile/                # account, sign out, privacy
sql/supabase_setup.sql      # grants + RLS + app tables (run in Supabase)
docs/                       # setup + store guides
```

## Roadmap (scale-from-here)
- CBT exams (`learning_exam*`) with timer + scoring
- Awards leaderboard + Paystack in-app voting
- Study groups & ambassador
- In-app subscription (Paystack) + subscriber-gated materials via RLS
- Offline caching of materials
