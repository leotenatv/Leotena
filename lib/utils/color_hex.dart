import 'package:flutter/material.dart';

/// Converts a 6-digit hex string (no `#`) to a [Color], as used by the
/// server's `gradientStart`/`gradientEnd` fields.
Color colorFromHex(String hex) {
  final clean = hex.replaceAll('#', '');
  return Color(int.parse('FF$clean', radix: 16));
}

List<Color> gradientFromJson(List<dynamic> json) {
  if (json.length < 2) return const [Color(0xFF1D4A82), Color(0xFF2C6DB5)];
  return [colorFromHex(json[0] as String), colorFromHex(json[1] as String)];
}
