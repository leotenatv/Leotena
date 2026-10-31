import 'package:flutter/services.dart';

/// Win32 window controls for the Leotena desktop shell.
///
/// The channel is registered only by the Windows runner. Calls are ignored
/// on every other platform, so this file is safe to compile into the
/// Android and iOS builds.
class DesktopWindow {
  DesktopWindow._();

  static const _channel = MethodChannel('com.ghettodevelopers.leotena/window');

  static Future<void> setFullScreen(bool enabled) async {
    try {
      await _channel.invokeMethod<void>('setFullScreen', enabled);
    } catch (_) {
      // Runner without the channel, or the window is already closing.
    }
  }
}
