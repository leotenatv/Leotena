import 'dart:async';

import 'package:audioplayers/audioplayers.dart';

/// Plays recorded Swahili guides from [assets/voices] during payment.
///
/// Files map to carousel steps:
/// - `1.wav` welcome
/// - `2.wav` details (name / phone)
/// - `3.wav` package pick
/// - `4.wav` waiting / success
class PaymentVoices {
  PaymentVoices._();

  static final AudioPlayer _player = AudioPlayer();
  static StreamSubscription<void>? _completeSub;
  static bool _ready = false;

  static const assets = <String>[
    'voices/1.wav',
    'voices/2.wav',
    'voices/3.wav',
    'voices/4.wav',
  ];

  static const welcomeAsset = 'voices/1.wav';
  static const detailsAsset = 'voices/2.wav';
  static const packageAsset = 'voices/3.wav';
  static const waitingAsset = 'voices/4.wav';
  static const successAsset = 'voices/4.wav';

  static Future<void> prepare() async {
    if (_ready) return;
    try {
      await _player.setReleaseMode(ReleaseMode.stop);
      await _player.setVolume(1.0);
      _ready = true;
    } catch (_) {
      _ready = true;
    }
  }

  static Future<void> playStep(
    int step, {
    void Function()? onStart,
    void Function()? onDone,
  }) async {
    final i = step.clamp(0, assets.length - 1);
    await playAsset(assets[i], onStart: onStart, onDone: onDone);
  }

  static Future<void> playAsset(
    String asset, {
    void Function()? onStart,
    void Function()? onDone,
  }) async {
    await prepare();
    try {
      await _completeSub?.cancel();
      await _player.stop();
      _completeSub = _player.onPlayerComplete.listen((_) {
        onDone?.call();
      });
      onStart?.call();
      await _player.play(AssetSource(asset));
    } catch (_) {
      onDone?.call();
    }
  }

  static Future<void> stop() async {
    try {
      await _completeSub?.cancel();
      _completeSub = null;
      await _player.stop();
    } catch (_) {}
  }
}
