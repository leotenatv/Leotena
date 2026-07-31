import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// New channel id — Android never updates sound/importance on an existing
/// channel, so a fresh id is required for WhatsApp-style audible alerts.
const kAndroidAlertChannelId = 'leotena_alerts';

const _androidChannel = AndroidNotificationChannel(
  kAndroidAlertChannelId,
  'Arifa za Leotena',
  description: 'Arifa za sauti kuhusu vituo vipya, mechi na matangazo muhimu.',
  importance: Importance.max,
  playSound: true,
  enableVibration: true,
  showBadge: true,
);

final _localNotifications = FlutterLocalNotificationsPlugin();

/// Must be a top-level (or static) function, invoked in its own isolate when
/// a push arrives while the app is backgrounded/terminated. FCM already
/// renders the system-tray notification for these automatically — this hook
/// exists for future data-message handling, not display.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {}

/// Creates the Android notification channel and readies the local-display
/// plugin used for foreground pushes (FCM does not auto-display those).
/// Call once at startup, after `Firebase.initializeApp()`.
Future<void> setupLocalNotifications() async {
  final android = _localNotifications
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
  await android?.createNotificationChannel(_androidChannel);
  // Android 13+ runtime permission (also covered by FCM requestPermission).
  await android?.requestNotificationsPermission();

  await _localNotifications.initialize(
    const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')),
  );

  // iOS / macOS: show banner + sound even while app is in foreground.
  await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
    alert: true,
    badge: true,
    sound: true,
  );
}

/// Asks for alert + sound (not silent/provisional) and returns the FCM token.
Future<String?> requestPushPermissionAndToken() async {
  final settings = await FirebaseMessaging.instance.requestPermission(
    alert: true,
    announcement: false,
    badge: true,
    carPlay: false,
    criticalAlert: false,
    provisional: false, // provisional = quiet / no sound on iOS
    sound: true,
  );
  if (settings.authorizationStatus == AuthorizationStatus.denied) {
    return null;
  }
  return FirebaseMessaging.instance.getToken();
}

/// Shows a system-tray notification for a push received while the app is in
/// the foreground (FCM only auto-displays background/terminated pushes).
void showForegroundNotification(RemoteMessage message) {
  final notification = message.notification;
  if (notification == null) return;
  _localNotifications.show(
    notification.hashCode,
    notification.title,
    notification.body,
    NotificationDetails(
      android: AndroidNotificationDetails(
        _androidChannel.id,
        _androidChannel.name,
        channelDescription: _androidChannel.description,
        importance: Importance.max,
        priority: Priority.max,
        playSound: true,
        enableVibration: true,
        icon: '@mipmap/ic_launcher',
        category: AndroidNotificationCategory.message,
      ),
    ),
  );
}
