import 'package:flutter/material.dart';

/// Converts a stored '#AARRGGBB' or '#RRGGBB' hex string back to a Color.
Color colorFromHex(String hex) {
  var value = hex.replaceFirst('#', '');
  if (value.length == 6) value = 'FF$value';
  return Color(int.parse(value, radix: 16));
}

String colorToHex(Color color) =>
    '#${color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}';
