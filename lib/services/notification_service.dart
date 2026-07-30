import 'dart:async';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

/// ============================================================================
/// NotificationService — Firebase-free "notify me" system.
///
/// HOW IT WORKS: while the app is open (or recently backgrounded — Android
/// generally keeps the process alive for a while after you leave it, until
/// the OS needs the memory back), this polls your /dashboard endpoint every
/// [pollInterval] and compares the unread-contacts count to what it saw
/// last time. If it went up, it fires a real local device notification and
/// updates a live badge count on the Notifications tab.
///
/// HONEST LIMITATION: this cannot wake the app up if it's been fully killed
/// (swiped away) for a long time, or notify you the instant a form is
/// submitted while your phone's screen is off and the app isn't running.
/// Genuinely instant "always-on" push — even with the app fully closed —
/// requires either Firebase Cloud Messaging or a third-party push relay
/// (e.g. OneSignal). Per the original "no Firebase" requirement, this is
/// the strongest alternative available without adding an external service.
/// ============================================================================
class NotificationService {
  NotificationService._internal();
  static final NotificationService instance = NotificationService._internal();

  final _plugin = FlutterLocalNotificationsPlugin();
  Timer? _pollTimer;
  final _unreadCountController = StreamController<int>.broadcast();

  /// Listen to this for a live unread count (e.g. to badge the bottom nav).
  Stream<int> get unreadCountStream => _unreadCountController.stream;

  int _lastKnownUnread = 0;
  static const _prefsKey = 'last_seen_unread_count';
  bool _initialized = false;

  /// Call once at app startup, before login (doesn't need auth).
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    await _plugin.initialize(
        const InitializationSettings(android: androidInit, iOS: iosInit));

    // Android 13+ and iOS both require explicit runtime permission.
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    await _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);

    final prefs = await SharedPreferences.getInstance();
    _lastKnownUnread = prefs.getInt(_prefsKey) ?? 0;
  }

  /// Call after a successful login. Checks immediately, then every
  /// [pollInterval] after that, for as long as the app stays alive.
  void startPolling({Duration pollInterval = const Duration(seconds: 25)}) {
    stopPolling();
    _checkNow();
    _pollTimer = Timer.periodic(pollInterval, (_) => _checkNow());
  }

  /// Call on logout so it stops hitting the backend with no valid session.
  void stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  /// Call right after marking notifications read in the app itself, so the
  /// badge updates immediately instead of waiting for the next poll tick.
  Future<void> refreshNow() => _checkNow();

  Future<void> _checkNow() async {
    final result = await ApiService.instance.getDashboard();
    if (result['success'] != true) return;

    final data = result['data'] as Map<String, dynamic>?;
    final count = (data?['unreadNotifications'] as num?)?.toInt() ?? 0;
    _unreadCountController.add(count);

    if (count > _lastKnownUnread) {
      final diff = count - _lastKnownUnread;
      await _showNotification(
        title: diff == 1 ? 'New form submission' : 'New form submissions',
        body: diff == 1
            ? 'You have a new contact form submission.'
            : 'You have $diff new contact form submissions.',
      );
    }

    _lastKnownUnread = count;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefsKey, count);
  }

  Future<void> _showNotification(
      {required String title, required String body}) async {
    const androidDetails = AndroidNotificationDetails(
      'contact_submissions',
      'New Submissions',
      channelDescription:
          'Alerts when someone submits a contact form on your website',
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
