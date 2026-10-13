import 'package:intl/intl.dart';
import 'package:flutter/services.dart';

final _formatter = NumberFormat.decimalPattern('en');

String formatAmount(double amount) => _formatter.format(amount);

/// Turns Arabic-Indic / Persian digits and the Arabic decimal/thousands marks into ASCII, so a
/// number typed on an Arabic keyboard ("١٢٫٥") parses like "12.5".
String asciiDigits(String s) {
  final b = StringBuffer();
  for (final r in s.runes) {
    if (r >= 0x0660 && r <= 0x0669) {
      b.writeCharCode(r - 0x0660 + 0x30);
    } else if (r >= 0x06F0 && r <= 0x06F9) {
      b.writeCharCode(r - 0x06F0 + 0x30);
    } else if (r == 0x066B) {
      b.write('.');
    } else if (r == 0x066C) {
      b.write(',');
    } else {
      b.writeCharCode(r);
    }
  }
  return b.toString();
}

/// Parses a typed amount (any digits, thousands commas) — 0 when empty or invalid.
double parseAmount(String s) => double.tryParse(asciiDigits(s).trim().replaceAll(',', '')) ?? 0;

/// Input formatter that converts Arabic digits to ASCII as they are typed. Put it before any
/// digits-only filter, which would otherwise drop them.
class AsciiDigitsFormatter extends TextInputFormatter {
  const AsciiDigitsFormatter();

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final text = asciiDigits(newValue.text);
    if (text == newValue.text) return newValue;
    // Every converted character is a single UTF-16 unit both before and after, so offsets hold.
    return newValue.copyWith(text: text);
  }
}
