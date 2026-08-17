import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'theme/app_theme.dart';
import 'theme/responsive.dart';
import 'state/app_state.dart';
import 'data/push_notifications.dart';
import 'screens/splash_screen.dart';
import 'app_route_observer.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Android 16 (targetSdk 36) enforces edge-to-edge with no opt-out.
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.dark,
    systemNavigationBarDividerColor: Colors.transparent,
  ));

  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    await setupLocalNotifications();
    FirebaseMessaging.onMessage.listen(showForegroundNotification);
    await attachNotificationOpenHandlers();
  } catch (_) {
    // No google-services config for this build target, no Play services on
    // the device, etc. — push notifications just won't work; nothing else
    // in the app depends on Firebase being present.
  }

  runApp(const LeotenaApp());
}

class LeotenaApp extends StatelessWidget {
  const LeotenaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppState(),
      child: MaterialApp(
        title: 'Leotena',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        navigatorObservers: [appRouteObserver],
        builder: (context, child) {
          final mq = MediaQuery.of(context);
          return MediaQuery(
            data: clampTextScale(mq),
            child: child ?? const SizedBox.shrink(),
          );
        },
        home: const SplashScreen(),
      ),
    );
  }
}
