import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'theme/app_theme.dart';
import 'theme/responsive.dart';
import 'state/app_state.dart';
import 'screens/splash_screen.dart';
import 'app_route_observer.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.white,
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
  ));
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
