import 'package:firebase_core/firebase_core.dart';
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
/// exists so the background isolate has Firebase ready, not for custom UI.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp();
  } catch (_) {
    // Isolate without google-services / Play services — nothing to display.
  }
}

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
    // Tap just resumes MainActivity (singleTop) → splash/home as a normal launch.
    onDidReceiveNotificationResponse: (_) {},
  );

  // iOS / macOS: show banner + sound even while app is in foreground.
  await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
    alert: true,
    badge: true,
    sound: true,
  );
}

/// Cold-start and background-tap: do not route to a special screen. The
/// existing splash → AppGate → home path already runs.
Future<void> attachNotificationOpenHandlers() async {
  FirebaseMessaging.onMessageOpenedApp.listen((_) {});
  try {
    await FirebaseMessaging.instance.getInitialMessage();
  } catch (_) {}
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

String? _titleOf(RemoteMessage message) {
  final fromNotification = message.notification?.title?.trim();
  if (fromNotification != null && fromNotification.isNotEmpty) return fromNotification;
  final fromData = (message.data['title'] ?? '').toString().trim();
  return fromData.isEmpty ? null : fromData;
}

String? _bodyOf(RemoteMessage message) {
  final fromNotification = message.notification?.body?.trim();
  if (fromNotification != null && fromNotification.isNotEmpty) return fromNotification;
  final fromData = (message.data['body'] ?? message.data['message'] ?? '').toString().trim();
  return fromData.isEmpty ? null : fromData;
}

/// Shows a system-tray notification for a push received while the app is in
/// the foreground (FCM only auto-displays background/terminated pushes).
void showForegroundNotification(RemoteMessage message) {
  final title = _titleOf(message);
  final body = _bodyOf(message);
  if (title == null && body == null) return;
  _localNotifications.show(
    message.messageId?.hashCode ?? message.hashCode,
    title ?? 'Leotena',
    body ?? '',
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
