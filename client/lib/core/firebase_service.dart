import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Handles Firebase Cloud Messaging and keep-alive (wakelock) for Lucky5 client.
/// Call [FirebaseService.init] once after app startup.
///
/// NOTE: google-services.json must be placed in android/app/ before build.
/// Until the Firebase project is linked, this service no-ops gracefully.
class FirebaseService {
  FirebaseService._();

  static final _notifications = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static Future<void> init() async {
    try {
      await Firebase.initializeApp();
      _initialized = true;
    } catch (e) {
      // Firebase not configured yet — no google-services.json
      return;
    }

    await _setupLocalNotifications();
    await _setupFcm();
    await _enableWakelock();
  }

  static Future<void> _setupLocalNotifications() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await _notifications.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
    );

    const channel = AndroidNotificationChannel(
      'lucky5_rewards',
      'Lucky5 Rewards',
      description: 'Notifications for daily rewards and bonuses',
      importance: Importance.high,
    );
    final androidPlugin = _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(channel);
  }

  static Future<void> _setupFcm() async {
    final messaging = FirebaseMessaging.instance;

    await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Background message handler must be a top-level function
    FirebaseMessaging.onBackgroundMessage(_bgMessageHandler);

    // Foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final notification = message.notification;
      if (notification == null) return;
      _notifications.show(
        notification.hashCode,
        notification.title,
        notification.body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'lucky5_rewards',
            'Lucky5 Rewards',
            icon: '@mipmap/ic_launcher',
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
      );
    });

    // Subscribe to user-specific topic (set after login)
    final token = await messaging.getToken();
    if (token != null) {
      // Token is registered with the Lucky5 backend via the /api/Notification/register-device endpoint
      _fcmToken = token;
    }
  }

  static String? _fcmToken;
  static String? get fcmToken => _fcmToken;

  static Future<void> subscribeToUserTopic(String userId) async {
    if (!_initialized) return;
    await FirebaseMessaging.instance.subscribeToTopic('Lucky5_user$userId');
  }

  static Future<void> unsubscribeFromUserTopic(String userId) async {
    if (!_initialized) return;
    await FirebaseMessaging.instance.unsubscribeFromTopic('Lucky5_user$userId');
  }

  static Future<void> _enableWakelock() async {
    try {
      await WakelockPlus.enable();
    } catch (_) {}
  }

  static Future<void> disableWakelock() async {
    try {
      await WakelockPlus.disable();
    } catch (_) {}
  }
}

@pragma('vm:entry-point')
Future<void> _bgMessageHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}
