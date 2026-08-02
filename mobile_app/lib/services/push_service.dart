import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'api_service.dart';

/// Handles messages that arrive while the app is fully backgrounded/killed.
/// Must be a TOP-LEVEL (or static) function — Flutter spawns a separate
/// isolate to run this, so it can't be a class method or closure.
/// For plain "notification" payloads (which is what our backend sends),
/// Android/iOS already show the system notification automatically without
/// this handler needing to do anything — it's here mainly so the app is
/// ready if you ever add data-only messages later.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Intentionally empty — see comment above.
}

/// ============================================================================
/// PushService — Firebase Cloud Messaging, used ONLY as a delivery
/// mechanism. Nothing else in this app touches Firebase; the backend
/// remains entirely Google Apps Script + Sheets + Drive.
///
/// This is what actually achieves "notify me even if the app is fully
/// closed" — unlike NotificationService's polling (which only runs while
/// the app process is alive), FCM messages are delivered and displayed by
/// the OS itself, independent of whether your app is running at all.
/// ============================================================================
class PushService {
  PushService._internal();
  static final PushService instance = PushService._internal();

  final _messaging = FirebaseMessaging.instance;
  final _localNotifications = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  /// Call once at app startup, after Firebase.initializeApp().
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    await _messaging.requestPermission(alert: true, badge: true, sound: true);
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // Android needs a notification channel to EXIST before it can be
    // referenced by ID — including for messages that arrive while the app
    // is backgrounded/killed. Creating it once here (not just when a
    // foreground message happens to show one) means a background/killed
    // delivery is never the first time Android hears about this channel.
    const channel = AndroidNotificationChannel(
      'contact_submissions',
      'New Submissions',
      description: 'Alerts when someone submits a contact form on your website',
      importance: Importance.high,
    );
    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    // While the app IS in the foreground, FCM does NOT auto-show a system
    // notification (so the app can decide how to react) — so we display it
    // ourselves here using the same local-notifications plugin already
    // used elsewhere in the app.
    FirebaseMessaging.onMessage.listen(_showForegroundNotification);
  }

  /// Call after a successful login — gets this device's push token and
  /// sends it to the backend so it knows where to deliver notifications.
  /// Also keeps it updated if the token ever rotates (FCM does this
  /// occasionally for security reasons).
  Future<void> registerToken() async {
    try {
      final token = await _messaging.getToken();
      if (token != null) {
        await ApiService.instance.registerDeviceToken(token, _platformName());
      }
      _messaging.onTokenRefresh.listen((newToken) {
        ApiService.instance.registerDeviceToken(newToken, _platformName());
      });
    } catch (e) {
      // Never let a push-registration hiccup block login/using the app.
      debugPrint('[push] Could not register device token: $e');
    }
  }

  String _platformName() {
    if (kIsWeb) return 'web';
    if (Platform.isIOS) return 'ios';
    return 'android';
  }

  Future<void> _showForegroundNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    const androidDetails = AndroidNotificationDetails(
      'contact_submissions',
      'New Submissions',
      channelDescription: 'Alerts when someone submits a contact form on your website',
      importance: Importance.high,
      priority: Priority.high,
    );
    const details = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(presentAlert: true, presentBadge: true, presentSound: true),
    );

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      notification.title,
      notification.body,
      details,
    );
  }
}