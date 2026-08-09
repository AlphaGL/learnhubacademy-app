import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../config/app_config.dart';
import 'supabase_service.dart';

/// Top-level background handler — required by FCM to be a top-level function.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Keep light: the OS shows the notification tray entry automatically for
  // "notification" messages. Heavy work here is discouraged.
  debugPrint('BG message: ${message.messageId}');
}

/// Firebase Cloud Messaging + local notification presentation.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final _fln = FlutterLocalNotificationsPlugin();
  static const _channel = AndroidNotificationChannel(
    'learnhub_default',
    'LearnHub Notifications',
    description: 'Exam reminders, new materials, and award results.',
    importance: Importance.high,
  );

  Future<void> init() async {
    final messaging = FirebaseMessaging.instance;

    // Ask permission (required on Android 13+ and iOS).
    await messaging.requestPermission(alert: true, badge: true, sound: true);

    // Local notifications (to show FCM messages while app is foregrounded).
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    await _fln.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
    );
    await _fln
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);

    FirebaseMessaging.onMessage.listen(_showForeground);

    // Register/refresh the device token so the backend can target this device.
    final token = await messaging.getToken();
    if (token != null) await _saveToken(token);
    messaging.onTokenRefresh.listen(_saveToken);
  }

  void _showForeground(RemoteMessage message) {
    final n = message.notification;
    if (n == null) return;
    _fln.show(
      n.hashCode,
      n.title,
      n.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(),
      ),
    );
  }

  /// Persist the FCM token against the signed-in user so notifications can be
  /// targeted. No-op when signed out.
  Future<void> _saveToken(String token) async {
    final user = SupabaseService.currentUser;
    if (user == null) return;
    try {
      await SupabaseService.client.from(AppConfig.tblDeviceToken).upsert({
        'user_id': user.id,
        'token': token,
        'platform': defaultTargetPlatform.name,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'token');
    } catch (e) {
      debugPrint('Failed to save device token: $e');
    }
  }

  /// Call after a fresh sign-in to make sure the current token is linked.
  Future<void> syncTokenForCurrentUser() async {
    final token = await FirebaseMessaging.instance.getToken();
    if (token != null) await _saveToken(token);
  }
}
