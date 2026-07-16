import 'package:flutter/material.dart';

/// Maps the schedule "icon" string key (admin's `_rounded` icon convention)
/// to the exact non-rounded icon constants this app's mock data originally
/// used, so ratiba_screen.dart's rendering stays pixel-identical even though
/// the data now comes from the server.
const Map<String, IconData> _iconsByKey = {
  'live_tv_rounded': Icons.live_tv,
  'child_care_rounded': Icons.child_care,
  'sports_soccer_rounded': Icons.sports_soccer,
  'movie_outlined': Icons.movie_outlined,
  'newspaper_rounded': Icons.newspaper,
  'waves_rounded': Icons.waves,
};

IconData iconFromKey(String? key) => _iconsByKey[key] ?? Icons.live_tv;
