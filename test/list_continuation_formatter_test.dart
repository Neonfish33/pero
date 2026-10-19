import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pero/editor/list_continuation_formatter.dart';

void main() {
  const formatter = ListContinuationFormatter();

  TextEditingValue pressEnter(String oldText) {
    final caret = oldText.length;
    final newText = '$oldText\n';
    return formatter.formatEditUpdate(
      TextEditingValue(
        text: oldText,
        selection: TextSelection.collapsed(offset: caret),
      ),
      TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: newText.length),
      ),
    );
  }

  test('continues an unordered list', () {
    final result = pressEnter('Пункт\n- один');
    expect(result.text, 'Пункт\n- один\n- ');
    expect(result.selection.baseOffset, result.text.length);
  });

  test('increments ordered list numbers', () {
    final result = pressEnter('1. один');
    expect(result.text, '1. один\n2. ');
    expect(result.selection.baseOffset, result.text.length);
  });

  test('keeps indentation', () {
    final result = pressEnter('  * пункт');
    expect(result.text, '  * пункт\n  * ');
  });

  test('exits the list from an empty item', () {
    final result = pressEnter('Пункт\n- ');
    expect(result.text, 'Пункт\n');
    expect(result.selection.baseOffset, 6);
  });

  test('does not touch ordinary lines', () {
    final result = pressEnter('Обычная строка');
    expect(result.text, 'Обычная строка\n');
  });

  test('does not touch an active composition', () {
    final value = formatter.formatEditUpdate(
      const TextEditingValue(
        text: '- один',
        selection: TextSelection.collapsed(offset: 6),
        composing: TextRange(start: 2, end: 6),
      ),
      const TextEditingValue(
        text: '- один\n',
        selection: TextSelection.collapsed(offset: 7),
        composing: TextRange(start: 2, end: 7),
      ),
    );
    expect(value.text, '- один\n');
  });
}
