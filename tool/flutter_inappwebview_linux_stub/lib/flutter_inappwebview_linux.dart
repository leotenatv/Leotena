import 'package:flutter_inappwebview_platform_interface/flutter_inappwebview_platform_interface.dart';

/// Registers a no-op platform implementation. Linux desktop never creates a WebView
/// (see [WebStreamPlayer]); this exists so plugin registration does not crash.
class LinuxInAppWebViewPlatform extends InAppWebViewPlatform {
  static void registerWith() {
    InAppWebViewPlatform.instance = LinuxInAppWebViewPlatform();
  }
}
