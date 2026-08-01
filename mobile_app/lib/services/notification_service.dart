import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

/// ============================================================================
/// NotificationService
///
/// HOW IT WORKS NOW: real push notifications via Firebase Cloud Messaging
/// (FCM). The backend (code.gs) sends a push the instant a form is
/// submitted, and Android/iOS deliver it even if the app is fully closed —
/// the OS shows it directly from the system tray, no Dart code needs to be
/// running. This requires a Firebase project; see FIREBASE_SETUP.md.
///
/// This still also polls /dashboard every [pollInterval] while the app is
/// open, but ONLY to keep the in-app unread badge (bottom nav / dashboard
/// card) live — it no longer fires notifications itself, so you don't get
/// a duplicate on top of the push notification.
/// ============================================================================
class NotificationService {
  NotificationService._internal();
  static final NotificationService instance = NotificationService._internal();

  final _plugin = FlutterLocalNotificationsPlugin();
  Timer? _pollTimer;
  final _unreadCountController = StreamController<int>.broadcast();

  /// Listen to this for a live unread count (e.g. to badge the bottom nav).
  Stream<int> get unreadCountStream => _unreadCountController.stream;

  static const _prefsKey = 'last_seen_unread_count';
  static const _lastRegisteredTokenKey = 'last_registered_fcm_token';
  static const String channelId = 'contact_submissions';
  static const String channelName = 'New Submissions';
  static const String channelDescription =
      'Alerts when someone submits a contact form on your website';

  bool _initialized = false;
  StreamSubscription<RemoteMessage>? _onMessageSub;
  StreamSubscription<String>? _onTokenRefreshSub;

  /// Call once at app startup, before login (doesn't need auth).
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    // Firebase must be initialized before touching FirebaseMessaging.
    // Safe to call even if main.dart already did it (it's idempotent by
    // app name), but we guard with a try/catch just in case.
    try {
      await Firebase.initializeApp();
    } catch (e) {
      // Already initialized elsewhere, or google-services.json is missing.
      // We don't want a missing Firebase config to crash the whole app —
      // local notifications / polling still work either way.
      debugPrint('🔔 [Push] Firebase.initializeApp() in NotificationService: $e');
    }

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    await _plugin.initialize(
        const InitializationSettings(android: androidInit, iOS: iosInit));

    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    // Create the channel up front (not lazily on first show()) so that a
    // push notification arriving while the app has NEVER been opened still
    // lands in a properly-configured high-importance channel.
    await androidPlugin?.createNotificationChannel(const AndroidNotificationChannel(
      channelId,
      channelName,
      description: channelDescription,
      importance: Importance.high,
    ));

    // Android 13+ and iOS both require explicit runtime permission.
    await androidPlugin?.requestNotificationsPermission();
    await _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);

    // FCM's own permission prompt (covers iOS properly; on Android 13+ this
    // is the same permission as above, so it's a harmless no-op there).
    try {
      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      debugPrint('🔔 [Push] Notification permission: ${settings.authorizationStatus}');
      // Show alerts while the app is in the foreground on iOS too.
      await FirebaseMessaging.instance
          .setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
    } catch (e) {
      // Firebase not configured (google-services.json missing) — ignore so
      // the rest of the app still works while push isn't set up yet.
      debugPrint('🔔 [Push] requestPermission failed: $e');
    }

    // FOREGROUND messages: Android/iOS do NOT auto-display the system
    // notification while the app is open, so we show it ourselves. This is
    // the one case where we still call flutter_local_notifications.
    _onMessageSub = FirebaseMessaging.onMessage.listen((message) {
      debugPrint('🔔 [Push] Foreground message received: '
          '${message.notification?.title} / ${message.notification?.body}');
      final notification = message.notification;
      if (notification != null) {
        _showNotification(
          title: notification.title ?? 'New notification',
          body: notification.body ?? '',
        );
      }
      // Keep the in-app badge in sync immediately instead of waiting for
      // the next poll tick.
      unawaited(refreshNow());
    });

    final prefs = await SharedPreferences.getInstance();
    // Kept for backward compatibility / potential future use; the badge
    // count itself now always comes fresh from the server.
    prefs.getInt(_prefsKey);
  }

  /// Call after a successful login. Registers this device for push
  /// notifications, checks the badge count immediately, then re-checks
  /// every [pollInterval] for as long as the app stays open (foreground
  /// badge only — actual notifications come from FCM push, not this timer).
  void startPolling({Duration pollInterval = const Duration(seconds: 25)}) {
    stopPolling();
    _checkNow();
    _pollTimer = Timer.periodic(pollInterval, (_) => _checkNow());
    unawaited(_registerDeviceToken());
  }

  /// Call on logout so it stops hitting the backend with no valid session.
  void stopPolling({bool unregisterDevice = false}) {
    _pollTimer?.cancel();
    _pollTimer = null;
    if (unregisterDevice) {
      unawaited(_unregisterDeviceToken());
    }
  }

  /// Call right after marking notifications read in the app itself, so the
  /// badge updates immediately instead of waiting for the next poll tick.
  Future<void> refreshNow() => _checkNow();

  /// Sends this device's current FCM token to the backend so it knows
  /// where to push new-submission alerts. Also listens for token refreshes
  /// (FCM rotates tokens occasionally) and re-registers automatically.
  Future<void> _registerDeviceToken() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) {
        debugPrint('🔔 [Push] getToken() returned null — Firebase not '
            'configured (check google-services.json is in android/app/).');
        return;
      }
      debugPrint('🔔 [Push] Got FCM token: $token');

      final prefs = await SharedPreferences.getInstance();
      if (prefs.getString(_lastRegisteredTokenKey) != token) {
        final result = await ApiService.instance.registerDevice(token);
        debugPrint('🔔 [Push] registerDevice API result: $result');
        if (result['success'] == true) {
          await prefs.setString(_lastRegisteredTokenKey, token);
        }
      } else {
        debugPrint('🔔 [Push] Token unchanged since last registration, skipping API call.');
      }

      _onTokenRefreshSub?.cancel();
      _onTokenRefreshSub =
          FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
        debugPrint('🔔 [Push] Token refreshed: $newToken');
        final result = await ApiService.instance.registerDevice(newToken);
        if (result['success'] == true) {
          final p = await SharedPreferences.getInstance();
          await p.setString(_lastRegisteredTokenKey, newToken);
        }
      });
    } catch (e) {
      // No Firebase config yet, or offline — safe to skip, push just won't
      // arrive until the next successful registration attempt.
      debugPrint('🔔 [Push] _registerDeviceToken failed: $e');
    }
  }

  Future<void> _unregisterDeviceToken() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await ApiService.instance.unregisterDevice(token);
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_lastRegisteredTokenKey);
    } catch (_) {
      // Fine to ignore on logout.
    }
  }

  Future<void> _checkNow() async {
    final result = await ApiService.instance.getDashboard();
    if (result['success'] != true) return;

    final data = result['data'] as Map<String, dynamic>?;
    final count = (data?['unreadNotifications'] as num?)?.toInt() ?? 0;
    _unreadCountController.add(count);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefsKey, count);
  }

  Future<void> _showNotification(
      {required String title, required String body}) async {
    const androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
      importance: Importance.high,
      priority: Priority.high,
    );
    const details = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(
          presentAlert: true, presentBadge: true, presentSound: true),
    );
    await _plugin.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000, title, body, details);
  }
}
