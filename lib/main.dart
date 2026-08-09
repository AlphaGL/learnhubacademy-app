import 'dart:async';
import 'dart:ui' show PlatformDispatcher;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'core/services/notification_service.dart';
import 'core/services/supabase_service.dart';
import 'core/theme/theme_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // --- Firebase (optional during early dev; required for release) ---
  // Uses native google-services.json / GoogleService-Info.plist.
  try {
    await Firebase.initializeApp();

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // Route uncaught Flutter + Dart errors to Crashlytics.
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };

    await NotificationService.instance.init();
  } catch (e) {
    debugPrint('Firebase init skipped/failed: $e');
  }

  // --- Supabase (required: data + auth) ---
  await SupabaseService.init();

  // --- Theme preference ---
  final themeController = ThemeController();
  await themeController.load();

  runApp(LearnHubApp(themeController: themeController));
}
