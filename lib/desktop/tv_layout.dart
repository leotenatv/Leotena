import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Android TV and Android smart TVs use the Windows desktop layout.
/// Phones stay on the phone screens.
class TvLayout {
  TvLayout._();

  static const _channel = MethodChannel('com.ghettodevelopers.leotena/device');

  static bool active = false;

  static Future<void> detect() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      active = await _channel.invokeMethod<bool>('isTelevision') == true;
    } catch (_) {
      active = false;
    }
  }
}
