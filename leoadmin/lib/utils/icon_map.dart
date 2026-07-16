import 'package:flutter/material.dart';

/// Schedule item icons travel to/from the server as string keys. Only the
/// keys actually used by seeded/admin-entered data need an entry here;
/// `live_tv_rounded` is the fallback for anything unrecognized.
const Map<String, IconData> _iconsByKey = {
  'live_tv_rounded': Icons.live_tv_rounded,
  'child_care_rounded': Icons.child_care_rounded,
  'sports_soccer_rounded': Icons.sports_soccer_rounded,
  'movie_outlined': Icons.movie_outlined,
  'newspaper_rounded': Icons.newspaper_rounded,
  'waves_rounded': Icons.waves_rounded,
};

IconData iconFromKey(String? key) => _iconsByKey[key] ?? Icons.live_tv_rounded;

String keyFromIcon(IconData icon) {
  for (final entry in _iconsByKey.entries) {
    if (entry.value == icon) return entry.key;
  }
  return 'live_tv_rounded';
}
