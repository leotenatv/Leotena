import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

const _channel = MethodChannel('com.ghettodevelopers.leotena/integrity');

const integrityBlockMessage =
    'Programu imegundua kisomaji cha mtandao au zana ya kubadili programu. '
    'Ondoa programu kama HTTP Canary na Reqable, zima proxy, kisha ufungue Leotena tena.';

/// True when a sniffer, a system proxy, or a tamper tool is present.
Future<bool> clientIntegrityBlocked() async {
  if (kIsWeb) return false;
  try {
    if (!Platform.isAndroid && !Platform.isWindows) return false;
  } catch (_) {
    return false;
  }
  if (_environmentProxy()) return true;
  try {
    final raw = await _channel.invokeMethod<Object?>('inspect');
    if (raw is Map && raw['blocked'] == true) return true;
  } on MissingPluginException {
    return false;
  } catch (_) {
    return false;
  }
  return false;
}

bool _environmentProxy() {
  // Windows hotspot and shared Wi-Fi often set a proxy variable. That is a
  // network setting, not a sniffer, and must not block playback.
  try {
    if (Platform.isWindows) return false;
  } catch (_) {
    return false;
  }
  const keys = [
    'HTTP_PROXY',
    'HTTPS_PROXY',
    'ALL_PROXY',
    'http_proxy',
    'https_proxy',
    'all_proxy',
  ];
  for (final key in keys) {
    final value = Platform.environment[key];
    if (value != null && value.trim().isNotEmpty) return true;
  }
  return false;
}
