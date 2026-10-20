import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pero/core/theme/pero_theme.dart';
import 'package:pero/editor/focus_mode.dart';
import 'package:pero/editor/markdown_highlighter.dart';

const String _block = '''
# Раздел

Абзац с **жирным**, *курсивом*, [ссылкой](https://example.com) и `кодом`.

- первый пункт списка
- второй пункт списка

> Цитата с текстом.

''';

String _document(int length) {
  final buffer = StringBuffer();
  while (buffer.length < length) {
    buffer.write(_block);
  }
  return buffer.toString().substring(0, length);
}

double _median(List<double> values) {
  final sorted = List<double>.from(values)..sort();
  return sorted[sorted.length ~/ 2];
}

String _format(int length) {
  if (length >= 1000) {
    return '${length ~/ 1000}k';
  }
  return '$length';
}

void main() {
  testWidgets(
    'highlight, layout and paint cost by document size',
    (tester) async {
      late BuildContext context;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (value) {
              context = value;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      final controller = MarkdownEditingController()
        ..palette = PeroPalette.light
        ..font = EditorFont.mono
        ..fontSize = 19
        ..focusMode = FocusMode.off;

      addTearDown(controller.dispose);

      // ignore: avoid_print
      print('Editor benchmark: highlight + layout + paint per keystroke');
      // ignore: avoid_print
      print('----------------------------------------------------------');

      for (final entry in <int, int>{
        10000: 5,
        100000: 3,
        500000: 1,
      }.entries) {
        final size = entry.key;
        final iterations = entry.value;
        final base = _document(size);

        // Warm-up: populate internal caches and let the font load.
        // ignore: use_build_context_synchronously
        _measure(context, controller, base, -1);

        final highlight = <double>[];
        final layout = <double>[];
        final paint = <double>[];
        for (var index = 0; index < iterations; index++) {
          // ignore: use_build_context_synchronously
          final sample = _measure(context, controller, base, index);
          highlight.add(sample.highlight);
          layout.add(sample.layout);
          paint.add(sample.paint);
        }

        final highlightMs = _median(highlight);
        final layoutMs = _median(layout);
        final paintMs = _median(paint);
        // ignore: avoid_print
        print(
          '${_format(size).padLeft(5)} chars: '
          'highlight ${highlightMs.toStringAsFixed(1)} ms | '
          'layout ${layoutMs.toStringAsFixed(1)} ms | '
          'paint ${paintMs.toStringAsFixed(1)} ms | '
          'total ${(highlightMs + layoutMs + paintMs).toStringAsFixed(1)} ms',
        );

        expect(highlightMs, greaterThan(0));
        expect(layoutMs, greaterThan(0));
      }
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );
}

_Measurement _measure(
  BuildContext context,
  MarkdownEditingController controller,
  String base,
  int index,
) {
  // Alternate the last character so the highlight cache is invalidated,
  // imitating a keystroke without growing the document.
  final text = '${base.substring(0, base.length - 1)}'
      '${index.isEven ? 'a' : 'b'}';
  controller.value = TextEditingValue(
    text: text,
    selection: TextSelection.collapsed(offset: text.length),
  );

  final highlightWatch = Stopwatch()..start();
  final span = controller.buildTextSpan(
    context: context,
    withComposing: false,
  );
  highlightWatch.stop();

  final painter = TextPainter(
    text: span,
    textDirection: TextDirection.ltr,
  );
  final layoutWatch = Stopwatch()..start();
  painter.layout(maxWidth: 720);
  layoutWatch.stop();

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final paintWatch = Stopwatch()..start();
  painter.paint(canvas, Offset.zero);
  paintWatch.stop();
  final picture = recorder.endRecording();
  picture.dispose();
  painter.dispose();

  return _Measurement(
    highlight: highlightWatch.elapsedMicroseconds / 1000,
    layout: layoutWatch.elapsedMicroseconds / 1000,
    paint: paintWatch.elapsedMicroseconds / 1000,
  );
}

class _Measurement {
  const _Measurement({
    required this.highlight,
    required this.layout,
    required this.paint,
  });

  final double highlight;
  final double layout;
  final double paint;
}
