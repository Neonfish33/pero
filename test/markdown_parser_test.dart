import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pero/editor/markdown_parser.dart';

void main() {
  group('deriveTitle', () {
    test('takes the first non-empty line without heading markers', () {
      expect(deriveTitle('# Привет\n\nМир'), 'Привет');
      expect(deriveTitle('\n\n  ## Заголовок  \nтекст'), 'Заголовок');
    });

    test('falls back for an empty document', () {
      expect(deriveTitle(''), 'Без названия');
      expect(deriveTitle(' \n\t\n'), 'Без названия');
    });

    test('truncates a long title', () {
      final title = deriveTitle('a' * 100);
      expect(title.length, 61);
      expect(title.endsWith('…'), isTrue);
    });
  });

  group('focus ranges', () {
    const text = 'Первое предложение. Второе предложение!\n\nНовый абзац.';

    test('sentence range contains only the current sentence', () {
      final range = sentenceRange(text, text.indexOf('Второе'));
      expect(text.substring(range.start, range.end).trim(), 'Второе предложение!');
    });

    test('paragraph range contains the current paragraph', () {
      final range = paragraphRange(text, text.indexOf('Второе'));
      expect(
        text.substring(range.start, range.end),
        'Первое предложение. Второе предложение!',
      );
    });

    test('caret at the start of the document is safe', () {
      final range = sentenceRange('Привет. Пока.', 0);
      expect(range.start, 0);
      expect(range.end, greaterThan(0));
    });

    test('sentence range uses the current list line', () {
      const list = '- один\n- два\n- три';
      final range = sentenceRange(list, list.indexOf('два'));
      expect(list.substring(range.start, range.end), '- два');
    });
  });

  group('markdown blocks', () {
    test('parses headings, lists, quotes, code and rules', () {
      const source = '''
# Заголовок

Текст **жирный** и *курсив*.

- один
- два

1. первый
2. второй

> цитата
> вторая строка

```dart
final x = 1;
```

---
''';
      final blocks = parseMarkdownBlocks(source);

      expect(blocks.whereType<MarkdownHeading>().length, 1);
      expect(blocks.whereType<MarkdownParagraph>().length, 1);
      expect(blocks.whereType<MarkdownList>().length, 2);
      expect(blocks.whereType<MarkdownQuote>().length, 1);
      expect(blocks.whereType<MarkdownCode>().length, 1);
      expect(blocks.whereType<MarkdownRule>().length, 1);

      final firstList = blocks.whereType<MarkdownList>().first;
      expect(firstList.ordered, isFalse);
      expect(firstList.items, <String>['один', 'два']);

      final secondList = blocks.whereType<MarkdownList>().last;
      expect(secondList.ordered, isTrue);
      expect(secondList.items, <String>['первый', 'второй']);
    });
  });

  group('inline spans', () {
    test('covers the source text without losing characters', () {
      const source =
          'Текст **жирный**, *курсив*, _ещё курсив_, `код` и [ссылка](https://example.com).';
      final spans = buildInlineSpans(
        source,
        base: const TextStyle(),
        strong: const TextStyle(),
        emphasis: const TextStyle(),
        code: const TextStyle(),
        link: const TextStyle(),
        mark: const TextStyle(),
      );
      final buffer = StringBuffer();
      for (final span in spans) {
        if (span is TextSpan) {
          buffer.write(span.text ?? '');
        }
      }
      expect(buffer.toString(), source);
    });
  });

  test('exports standalone HTML with a title and content', () {
    final html = markdownToStandaloneHtml(
      '# Привет\n\nМир',
      title: 'Тест <Перо>',
    );
    expect(html, contains('<title>Тест &lt;Перо&gt;</title>'));
    expect(html, contains('<h1>Привет</h1>'));
    expect(html, contains('<p>Мир</p>'));
    expect(html, contains('charset="utf-8"'));
  });
}
