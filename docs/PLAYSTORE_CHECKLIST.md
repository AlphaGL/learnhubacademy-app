# Play Store release checklist

Everything required to ship LearnHub to Google Play, in order.

## A. App identity
- [ ] **Application ID**: `com.neky.learnhub` (set via `flutter create --org com.neky`).
      This is permanent once published — choose carefully.
- [ ] **App name**: LearnHub (in `android/app/src/main/AndroidManifest.xml`,
      `android:label`).
- [ ] **App icon**: replace the default. Use
      [`flutter_launcher_icons`](https://pub.dev/packages/flutter_launcher_icons)
      or Android Studio's Image Asset tool. Provide a 512×512 PNG for the store
      listing too.
- [ ] **Version**: `pubspec.yaml` `version: 1.0.0+1`. Bump the build number
      (`+N`) on **every** upload.

## B. Required permissions (AndroidManifest.xml)
`flutter create` adds INTERNET. For notifications, ensure these are present in
`android/app/src/main/AndroidManifest.xml` (inside `<manifest>`, above
`<application>`):

```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
```

Only request what you use — Play reviews permissions. We do **not** use location,
contacts, SMS, or camera in v1, so don't add those.

## C. Target API level
- [ ] `targetSdkVersion 34` (Android 14) or newer — Google Play requires a
      recent target API for new apps/updates. Set in `android/app/build.gradle`.
- [ ] `minSdkVersion 23`.

## D. Signing (upload key)
1. Create a keystore (keep it safe and backed up — losing it blocks updates):
   ```bash
   keytool -genkey -v -keystore C:\Users\Ibeawuchi\learnhub-upload.jks ^
     -keyalg RSA -keysize 2048 -validity 10000 -alias upload
   ```
2. Create `android/key.properties` (git-ignored):
   ```
   storePassword=********
   keyPassword=********
   keyAlias=upload
   storeFile=C:\\Users\\Ibeawuchi\\learnhub-upload.jks
   ```
3. In `android/app/build.gradle`, load it and wire `signingConfigs.release`:
   ```gradle
   def keystoreProperties = new Properties()
   def keystorePropertiesFile = rootProject.file('key.properties')
   if (keystorePropertiesFile.exists()) {
       keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
   }
   android {
       signingConfigs {
           release {
               keyAlias keystoreProperties['keyAlias']
               keyPassword keystoreProperties['keyPassword']
               storeFile keystoreProperties['storeFile'] ? file(keystoreProperties['storeFile']) : null
               storePassword keystoreProperties['storePassword']
           }
       }
       buildTypes {
           release {
               signingConfig signingConfigs.release
               // Optional: enable code shrinking. If you turn this on, create an
               // empty android/app/proguard-rules.pro first, then add:
               //   minifyEnabled true
               //   shrinkResources true
               //   proguardFiles getDefaultProguardFile('proguard-android-optimize.txt'), 'proguard-rules.pro'
           }
       }
   }
   ```
4. Enroll in **Play App Signing** (default for new apps) when you create the app
   in Play Console.

## E. Build the release bundle (AAB — Play requires .aab, not .apk)
```bash
flutter build appbundle --release ^
  --dart-define=SUPABASE_URL=... ^
  --dart-define=SUPABASE_ANON_KEY=... ^
  --dart-define=GOOGLE_WEB_CLIENT_ID=...
```
Output: `build/app/outputs/bundle/release/app-release.aab`.

Test the release build on a device first:
```bash
flutter build apk --release --dart-define=...   # for sideload testing only
```

## F. Play Console store listing
- [ ] App name, short description (80 chars), full description (4000 chars).
- [ ] **Screenshots**: at least 2 phone screenshots (min 320px). Add a feature
      graphic (1024×500).
- [ ] App category: **Education**.
- [ ] Contact email.
- [ ] **Privacy policy URL** (required — host the one in
      `PRIVACY_POLICY_TEMPLATE.md`, e.g. at `https://best-learnhub.vercel.app/privacy`).

## G. Data safety form (required, must be accurate)
Declare what the app collects/shares. For v1:
| Data | Collected | Why | Shared |
|------|-----------|-----|--------|
| Email address | Yes | Account creation (Supabase Auth) | No |
| Name | Yes | Personalisation | No |
| Phone number | Yes (optional) | Account/profile | No |
| App activity / analytics | Yes | Firebase Analytics | No (Google as processor) |
| Crash logs | Yes | Firebase Crashlytics | No (Google as processor) |
| Device/FCM token | Yes | Push notifications | No |

- [ ] Mark data **encrypted in transit** (Supabase/Firebase use HTTPS).
- [ ] Provide a way to **request account deletion** (see below).

## H. Account deletion (required for apps with sign-in)
Google requires an in-app and/or web path to delete an account + data.
- Add a "Delete account" action (calls Supabase to delete the user + cascade
  rows). Ask me to wire this — it needs a small Edge Function or backend
  endpoint using the service-role key (can't be done safely from the client).
- Also provide a public web URL describing the deletion process.

## I. Content rating & compliance
- [ ] Complete the **content rating questionnaire** (Education → likely Everyone).
- [ ] **Target audience**: if you target under-13s, extra Families policy rules
      apply. For university students, set 13+ / 18+ appropriately.
- [ ] Ads: none in v1 → declare "No ads". (The web `ads` app is not in the app.)
- [ ] Payments: no in-app purchases in v1. **Note:** if you later add the
      subscription via **Paystack** for *digital* content, Google Play policy
      generally requires **Google Play Billing** for in-app digital goods —
      review this before adding paid subscriptions in-app.

## J. Pre-launch
- [ ] Test on a physical device (sign-in, courses load, push notification).
- [ ] Use Play Console **Internal testing** track first, then Closed, then
      Production.
- [ ] Verify Crashlytics receives a forced test crash.

## Quick reference — files you'll edit
- `android/app/build.gradle` — applicationId, sdk versions, signing, plugins
- `android/app/src/main/AndroidManifest.xml` — label, permissions
- `android/key.properties` — signing secrets (git-ignored)
- `pubspec.yaml` — version bump per upload
