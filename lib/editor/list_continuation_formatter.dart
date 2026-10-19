import 'package:flutter/services.dart';

final RegExp _listLine = RegExp(r'^(\s*)([-*+]|\d+\.)\s+(.*)$');

class ListContinuationFormatter extends TextInputFormatter {
  const ListContinuationFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.composing.isValid) {
      return newValue;
    }

    final oldText = oldValue.text;
    final newText = newValue.text;
    final selection = newValue.selection;

    if (!selection.isCollapsed) {
      return newValue;
    }
    if (newText.length != oldText.length + 1) {
      return newValue;
    }

    final caret = selection.baseOffset;
    if (caret <= 0 || caret > newText.length) {
      return newValue;
    }
    if (newText[caret - 1] != '\n') {
      return newValue;
    }
    if (newText.replaceRange(caret - 1, caret, '') != oldText) {
      return newValue;
    }

    final lineStart =
        caret < 2 ? 0 : oldText.lastIndexOf('\n', caret - 2) + 1;
    if (lineStart > oldText.length) {
      return newValue;
    }
    final line = oldText.substring(lineStart, caret - 1);
    final match = _listLine.firstMatch(line);
    if (match == null) {
      return newValue;
    }

    final indent = match.group(1)!;
    final marker = match.group(2)!;
    final content = match.group(3)!;

    if (content.trim().isEmpty) {
      final rest = newText.substring(caret);
      final result = '${oldText.substring(0, lineStart)}$rest';
      return TextEditingValue(
        text: result,
        selection: TextSelection.collapsed(offset: lineStart),
      );
    }

    String nextMarker;
    if (RegExp(r'\d').hasMatch(marker)) {
      final number = int.tryParse(
        marker.substring(0, marker.length - 1),
      );
      nextMarker = number == null ? marker : '${number + 1}.';
    } else {
      nextMarker = marker;
    }

    final insertion = '$indent$nextMarker ';
    final result = newText.replaceRange(caret, caret, insertion);
    return TextEditingValue(
      text: result,
      selection: TextSelection.collapsed(
        offset: caret + insertion.length,
      ),
    );
  }
}
