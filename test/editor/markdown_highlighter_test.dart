import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pero/core/theme/pero_theme.dart';
import 'package:pero/editor/focus_mode.dart';
import 'package:pero/editor/markdown_highlighter.dart';

String _visibleText(TextSpan span, Color dim) {
  final buffer = StringBuffer();
  void walk(InlineSpan node) {
    if (node is! TextSpan) {
      return;
    }
    if (node.text != null && node.style?.color != dim) {
      buffer.write(node.text);
    }
    final children = node.children;
    if (children != null) {
      for (final child in children) {
        walk(child);
      }
    }
  }

  final children = span.children;
  if (children != null) {
    for (final child in children) {
      walk(child);
    }
  }
  return buffer.toString();
}

void main() {
  testWidgets('highlighting preserves the source text', (tester) async {
    const source =
        '# Заголовок\n\nТекст **жирный**, *курсив*, _ещё_, `код` и [ссылка](https://example.com).\n\n- пункт\n\n```\ncode\n```';
    final controller = MarkdownEditingController(text: source);
    TextSpan? span;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            span = controller.buildTextSpan(
              context: context,
              style: const TextStyle(fontSize: 19),
              withComposing: false,
            );
            return const SizedBox();
          },
        ),
      ),
    );

    expect(span, isNotNull);
    expect(span!.toPlainText(), source);
    controller.dispose();
  });

  testWidgets('focus mode preserves text and does not change its length', (
    tester,
  ) async {
    const source = 'Первое предложение. Второе предложение!';
    final controller = MarkdownEditingController(text: source)
      ..focusMode = FocusMode.sentence
      ..selection = const TextSelection.collapsed(offset: 22);
    TextSpan? span;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            span = controller.buildTextSpan(
              context: context,
              style: const TextStyle(fontSize: 19),
              withComposing: false,
            );
            return const SizedBox();
          },
        ),
      ),
    );

    expect(span!.toPlainText(), source);
    controller.dispose();
  });

  testWidgets('sentence focus dims other sentences', (tester) async {
    const source = 'Первое предложение. Второе предложение! Третье.';
    final controller = MarkdownEditingController(text: source)
      ..focusMode = FocusMode.sentence
      ..selection = TextSelection.collapsed(
        offset: source.indexOf('Второе'),
      );
    TextSpan? span;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            span = controller.buildTextSpan(
              context: context,
              style: const TextStyle(fontSize: 19),
              withComposing: false,
            );
            return const SizedBox();
          },
        ),
      ),
    );

    final visible = _visibleText(span!, PeroPalette.light.dim);
    expect(visible, contains('Второе предложение!'));
    expect(visible, isNot(contains('Первое')));
    expect(visible, isNot(contains('Третье')));
    controller.dispose();
  });

  testWidgets('paragraph focus dims other paragraphs', (tester) async {
    const source = 'Первый абзац. Ещё фраза.\n\nВторой абзац.';
    final controller = MarkdownEditingController(text: source)
      ..focusMode = FocusMode.paragraph
      ..selection = TextSelection.collapsed(
        offset: source.indexOf('Ещё'),
      );
    TextSpan? span;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            span = controller.buildTextSpan(
              context: context,
              style: const TextStyle(fontSize: 19),
              withComposing: false,
            );
            return const SizedBox();
          },
        ),
      ),
    );

    final visible = _visibleText(span!, PeroPalette.light.dim);
    expect(visible, contains('Первый абзац. Ещё фраза.'));
    expect(visible, isNot(contains('Второй абзац')));
    controller.dispose();
  });
}
