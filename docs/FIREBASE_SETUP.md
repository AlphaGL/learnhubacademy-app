# Firebase setup (notifications, analytics, crashlytics + Google sign-in id)

Firebase powers push notifications (FCM), Analytics, and Crashlytics. It also
provides the **Web client ID** we use for Google sign-in (which is exchanged for
a Supabase session).

## 1. Create the Firebase project
1. Go to <https://console.firebase.google.com> → **Add project**.
2. Name it e.g. `LearnHub`. Enable Google Analytics when prompted.

## 2. Add the Android app
1. In the project, **Add app → Android**.
2. **Android package name:** `com.neky.learnhub`
   (must match `applicationId` in `android/app/build.gradle` — set by
   `flutter create --org com.neky --project-name learnhub`).
3. (Recommended) add your **debug SHA-1** and later your **release SHA-1** —
   required for Google sign-in. Get them with:
   ```bash
   cd android
   ./gradlew signingReport
   ```
   Copy the SHA-1 lines into Firebase → Project Settings → your Android app.
4. **Download `google-services.json`** and place it at:
   ```
   android/app/google-services.json
   ```
   (Already git-ignored — keep it out of source control.)

## 3. Wire up the Gradle plugins
Flutter's newer template uses the **declarative plugins block**. Open
`android/settings.gradle` (or `settings.gradle.kts`) and add the Google services
plugin to the `plugins { }` block:

```gradle
plugins {
    id "dev.flutter.flutter-plugin-loader" version "1.0.0"
    id "com.android.application" version "8.1.0" apply false
    id "org.jetbrains.kotlin.android" version "1.9.0" apply false
    // add these two:
    id "com.google.gms.google-services" version "4.4.2" apply false
    id "com.google.firebase.crashlytics" version "3.0.2" apply false
}
```

Then in `android/app/build.gradle`, inside the top `plugins { }` block:

```gradle
plugins {
    id "com.android.application"
    id "kotlin-android"
    id "dev.flutter.flutter-gradle-plugin"
    // add these two:
    id "com.google.gms.google-services"
    id "com.google.firebase.crashlytics"
}
```

> If your project uses the older `apply plugin:` style instead, add
> `apply plugin: 'com.google.gms.google-services'` at the bottom of
> `android/app/build.gradle` and the classpath in `android/build.gradle`.

### minSdk
FCM + Firebase need `minSdkVersion 21`+. In `android/app/build.gradle` set:
```gradle
defaultConfig {
    minSdkVersion 23   // safe modern floor; >= 21 required
    targetSdkVersion 34
}
```

## 4. Get the Web client ID (for Google sign-in)
Firebase → **Project Settings → General → Your apps**, or Google Cloud Console →
**APIs & Services → Credentials**. Copy the **Web application** OAuth client ID
(looks like `xxxx.apps.googleusercontent.com`). Pass it as
`--dart-define=GOOGLE_WEB_CLIENT_ID=...`. Put the **same** client ID + secret
into Supabase's Google provider (see SUPABASE_SETUP.md).

## 5. (iOS, when you add it)
- Add an iOS app in Firebase, download `GoogleService-Info.plist` into
  `ios/Runner/`.
- Enable Push Notifications + Background Modes (Remote notifications) in Xcode.
- Add an APNs key in Firebase → Cloud Messaging.

## 6. Test push notifications
1. Run the app on a device, sign in.
2. Firebase Console → **Messaging → Create campaign / Send test message**.
3. Grab the device's FCM token from the `app_device_tokens` table (the app
   registers it on sign-in) and send a test to that token.

## Sending notifications from your backend
Your Django backend (or any server) can send to a user by:
1. Looking up their token(s) in `app_device_tokens` (by `user_id`).
2. Calling the **FCM HTTP v1 API** with a service-account credential.
3. Inserting a row into `app_notifications` so it shows in the in-app history.

(That sender is a backend task — not part of this app. Ask and I'll add a small
Django management command / endpoint for it.)
