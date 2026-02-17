import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

class ThousandsFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue;
    }

    // Remove all non-digits
    final String newText = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');

    // If empty or just zeros, handle appropriately?
    // Usually we let it be parsed.
    if (newText.isEmpty) {
      return newValue.copyWith(text: '');
    }

    // Format
    final number = int.parse(newText);
    final formatted = NumberFormat('#,###').format(number);

    // Calculate cursor position
    // Simple heuristic: count digits before cursor, find position of that many digits in new string

    int initialCursor = newValue.selection.end;
    int digitsBeforeCursor = 0;

    for (int i = 0; i < initialCursor && i < newValue.text.length; i++) {
      if (RegExp(r'[0-9]').hasMatch(newValue.text[i])) {
        digitsBeforeCursor++;
      }
    }

    int newCursor = 0;
    int digitsEncountered = 0;

    for (int i = 0; i < formatted.length; i++) {
      if (RegExp(r'[0-9]').hasMatch(formatted[i])) {
        digitsEncountered++;
      }
      if (digitsEncountered == digitsBeforeCursor) {
        newCursor = i + 1;
        break;
      }
    }

    // Handle edge case where no digits were before cursor (start of line)
    if (digitsBeforeCursor == 0) {
      newCursor = 0;
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: newCursor),
    );
  }
}
