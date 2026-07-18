import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

const _androidChannel = AndroidNotificationChannel(
  'leotena_default',
  'Arifa za Leotena',
  description: 'Arifa kuhusu vituo vipya, mechi na matangazo muhimu.',
  importance: Importance.high,
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
  await _localNotifications
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(_androidChannel);
  await _localNotifications.initialize(
    const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')),
  );
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
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      ),
    ),
  );
}
