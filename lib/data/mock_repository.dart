import 'package:flutter/material.dart';

/// Pure presentation helpers still used by fetched (non-mock) content.
/// The actual movies/channels/packages/schedule data now comes from the
/// backend via AppState.bootstrap() — see lib/data/content_repository.dart.
class MockRepository {
  static const List<List<Color>> _g = [
    [Color(0xFF1D4A82), Color(0xFF2C6DB5)],
    [Color(0xFF0F2748), Color(0xFF3A86C9)],
    [Color(0xFF143A6B), Color(0xFF19B26B)],
    [Color(0xFF2C6DB5), Color(0xFF7FC6F0)],
    [Color(0xFF0A1C36), Color(0xFF1D4A82)],
    [Color(0xFF1D4A82), Color(0xFF0A7D4A)],
    [Color(0xFF3A86C9), Color(0xFF143A6B)],
    [Color(0xFF0F2748), Color(0xFF2C6DB5)],
  ];

  static List<Color> gradient(int i) => _g[i % _g.length];

  static String aiImage(String prompt, {required int seed, int width = 960, int height = 540}) =>
      'https://image.pollinations.ai/prompt/${Uri.encodeComponent(prompt)}'
      '?width=$width&height=$height&nologo=true&seed=$seed';

  static String aiChannelImage(String prompt, {required int seed}) =>
      aiImage(prompt, seed: seed, width: 960, height: 540);

  static String aiMoviePoster(String prompt, {required int seed}) =>
      aiImage(prompt, seed: seed, width: 640, height: 960);
}
