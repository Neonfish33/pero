import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:markdown/markdown.dart' as md;

class MarkdownRange {
  const MarkdownRange(this.start, this.end);

  final int start;
  final int end;

  bool contains(int offset) => offset >= start && offset <= end;
}

final RegExp _inlinePattern = RegExp(
  r'(\*\*|__)(?=\S)(.+?)(?<=\S)\1'
  r'|\*(?=\S)(.+?)(?<=\S)\*'
  r'|(?<!\w)_(?=\S)(.+?)(?<=\S)_(?!\w)'
  r'|`[^`]+`'
  r'|\[([^\]]+)\]\(([^)]+)\)',
);

final RegExp _headingPattern = RegExp(r'^(#{1,6})\s+(.*)$');
final RegExp _listPattern = RegExp(r'^\s*([-*+]|\d+\.)\s+(.*)$');
final RegExp _rulePattern = RegExp(r'^\s*(?:-{3,}|\*{3,}|_{3,})\s*$');
final RegExp _lineBlockPattern = RegExp(
  r'^\s*(?:#{1,6}\s|>|[-*+]\s|\d+\.\s)',
);

String normalizeNewlines(String text) =>
    text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');

String deriveTitle(String markdown, {String fallback = 'Без названия'}) {
  for (final line in markdown.split('\n')) {
    var value = line.trim();
    if (value.isEmpty) {
      continue;
    }
    value = value.replaceFirst(RegExp(r'^#{1,6}\s*'), '').trim();
    if (value.isEmpty) {
      continue;
    }
    if (value.length > 60) {
      return '${value.substring(0, 60)}…';
    }
    return value;
  }
  return fallback;
}

MarkdownRange paragraphRange(String text, int caret) {
  final offset = caret.clamp(0, text.length);
  var start = offset > 0 ? text.lastIndexOf('\n\n', offset - 1) : -1;
  start = start < 0 ? 0 : start + 2;
  var end = text.indexOf('\n\n', offset);
  if (end < 0) {
    end = text.length;
  }
  if (start > end) {
    start = end;
  }
  return MarkdownRange(start, end);
}

MarkdownRange sentenceRange(String text, int caret) {
  final safeCaret = caret.clamp(0, text.length);
  var lineStart = safeCaret > 0
      ? text.lastIndexOf('\n', safeCaret - 1) + 1
      : 0;
  if (lineStart < 0) {
    lineStart = 0;
  }
  var lineEnd = text.indexOf('\n', safeCaret);
  if (lineEnd < 0) {
    lineEnd = text.length;
  }
  if (lineStart <= lineEnd) {
    final line = text.substring(lineStart, lineEnd);
    if (_lineBlockPattern.hasMatch(line)) {
      return MarkdownRange(lineStart, lineEnd);
    }
  }

  final paragraph = paragraphRange(text, caret);
  final content = text.substring(paragraph.start, paragraph.end);
  final offset = (caret - paragraph.start).clamp(0, content.length);
  final pattern = RegExp(r'''[.!?…]+["'»”)\]]*(\s+|$)''');

  var previousEnd = 0;
  for (final match in pattern.allMatches(content)) {
    final end = match.end;
    if (offset < end || end >= content.length) {
      return MarkdownRange(paragraph.start + previousEnd, paragraph.start + end);
    }
    previousEnd = end;
  }
  return MarkdownRange(paragraph.start + previousEnd, paragraph.end);
}

MarkdownRange focusRangeFor(String text, int caret, FocusRangeMode mode) {
  switch (mode) {
    case FocusRangeMode.off:
      return MarkdownRange(0, text.length);
    case FocusRangeMode.sentence:
      return sentenceRange(text, caret);
    case FocusRangeMode.paragraph:
      return paragraphRange(text, caret);
  }
}

enum FocusRangeMode { off, sentence, paragraph }

List<InlineSpan> buildInlineSpans(
  String text, {
  required TextStyle base,
  required TextStyle strong,
  required TextStyle emphasis,
  required TextStyle code,
  required TextStyle link,
  required TextStyle mark,
  GestureRecognizer? Function(String url)? linkRecognizer,
}) {
  final spans = <InlineSpan>[];

  void addText(String value, TextStyle style, {GestureRecognizer? recognizer}) {
    if (value.isEmpty) {
      return;
    }
    spans.add(TextSpan(text: value, style: style, recognizer: recognizer));
  }

  var position = 0;
  for (final match in _inlinePattern.allMatches(text)) {
    if (match.start > position) {
      addText(text.substring(position, match.start), base);
    }

    final boldMarker = match.group(1);
    final boldText = match.group(2);
    final italicStar = match.group(3);
    final italicUnderscore = match.group(4);
    final linkText = match.group(5);
    final linkUrl = match.group(6);

    if (boldMarker != null && boldText != null) {
      addText(boldMarker, mark);
      addText(boldText, strong);
      addText(boldMarker, mark);
    } else if (italicStar != null) {
      addText('*', mark);
      addText(italicStar, emphasis);
      addText('*', mark);
    } else if (italicUnderscore != null) {
      addText('_', mark);
      addText(italicUnderscore, emphasis);
      addText('_', mark);
    } else if (linkText != null && linkUrl != null) {
      addText('[', mark);
      addText(
        linkText,
        link,
        recognizer: linkRecognizer?.call(linkUrl),
      );
      addText('](', mark);
      addText(linkUrl, code);
      addText(')', mark);
    } else if (match.group(0)!.startsWith('`')) {
      addText(match.group(0)!, code);
    }

    position = match.end;
  }

  if (position < text.length) {
    addText(text.substring(position), base);
  }
  return spans;
}

sealed class MarkdownBlock {
  const MarkdownBlock();
}

class MarkdownHeading extends MarkdownBlock {
  const MarkdownHeading(this.level, this.text);

  final int level;
  final String text;
}

class MarkdownParagraph extends MarkdownBlock {
  const MarkdownParagraph(this.text);

  final String text;
}

class MarkdownQuote extends MarkdownBlock {
  const MarkdownQuote(this.text);

  final String text;
}

class MarkdownList extends MarkdownBlock {
  const MarkdownList({required this.ordered, required this.items});

  final bool ordered;
  final List<String> items;
}

class MarkdownCode extends MarkdownBlock {
  const MarkdownCode(this.code);

  final String code;
}

class MarkdownRule extends MarkdownBlock {
  const MarkdownRule();
}

List<MarkdownBlock> parseMarkdownBlocks(String markdown) {
  final lines = markdown.split('\n');
  final blocks = <MarkdownBlock>[];
  var index = 0;

  while (index < lines.length) {
    final line = lines[index];
    final trimmed = line.trim();
    if (trimmed.isEmpty) {
      index++;
      continue;
    }

    if (trimmed.startsWith('```') || trimmed.startsWith('~~~')) {
      final fence = trimmed.substring(0, 3);
      index++;
      final code = <String>[];
      while (index < lines.length && !lines[index].trimLeft().startsWith(fence)) {
        code.add(lines[index]);
        index++;
      }
      if (index < lines.length) {
        index++;
      }
      blocks.add(MarkdownCode(code.join('\n')));
      continue;
    }

    final heading = _headingPattern.firstMatch(line);
    if (heading != null) {
      blocks.add(MarkdownHeading(heading.group(1)!.length, heading.group(2)!));
      index++;
      continue;
    }

    if (_rulePattern.hasMatch(line)) {
      blocks.add(const MarkdownRule());
      index++;
      continue;
    }

    if (line.trimLeft().startsWith('>')) {
      final quote = <String>[];
      while (index < lines.length && lines[index].trimLeft().startsWith('>')) {
        quote.add(
          lines[index].replaceFirst(RegExp(r'^\s*>\s?'), ''),
        );
        index++;
      }
      blocks.add(MarkdownQuote(quote.join('\n')));
      continue;
    }

    final listMatch = _listPattern.firstMatch(line);
    if (listMatch != null) {
      final ordered = RegExp(r'\d').hasMatch(listMatch.group(1)!);
      final items = <String>[];
      while (index < lines.length) {
        final match = _listPattern.firstMatch(lines[index]);
        if (match == null) {
          break;
        }
        final itemOrdered = RegExp(r'\d').hasMatch(match.group(1)!);
        if (itemOrdered != ordered) {
          break;
        }
        items.add(match.group(2)!);
        index++;
      }
      blocks.add(MarkdownList(ordered: ordered, items: items));
      continue;
    }

    final paragraph = <String>[];
    while (index < lines.length) {
      final current = lines[index];
      if (current.trim().isEmpty) {
        break;
      }
      if (_headingPattern.hasMatch(current)) {
        break;
      }
      if (current.trimLeft().startsWith('```') ||
          current.trimLeft().startsWith('~~~')) {
        break;
      }
      if (current.trimLeft().startsWith('>')) {
        break;
      }
      if (_listPattern.hasMatch(current)) {
        break;
      }
      if (_rulePattern.hasMatch(current)) {
        break;
      }
      paragraph.add(current.trim());
      index++;
    }
    if (paragraph.isNotEmpty) {
      blocks.add(MarkdownParagraph(paragraph.join(' ')));
    }
  }

  return blocks;
}

String markdownToStandaloneHtml(String markdown, {required String title}) {
  final body = md.markdownToHtml(
    markdown,
    extensionSet: md.ExtensionSet.gitHubFlavored,
  );
  final safeTitle = _escapeHtml(title);

  return '''<!DOCTYPE html>
<html lang="ru">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>$safeTitle</title>
<style>
:root{color-scheme:light dark;--bg:#f6f7f8;--fg:#1c1f24;--ui:#7b838c;--line:#e3e6e9;--acc:#1a8cff;--hl:#0b6bcb}
@media (prefers-color-scheme:dark){:root{--bg:#15181c;--fg:#cfd5db;--ui:#838b94;--line:#262a30;--acc:#4db2ff;--hl:#7cc4ff}}
*{box-sizing:border-box}
body{margin:0;background:var(--bg);color:var(--fg);font:19px/1.72 "Source Serif 4",Georgia,"Times New Roman",serif}
main{max-width:40rem;margin:0 auto;padding:10vh 28px 30vh}
h1,h2,h3,h4,h5,h6{line-height:1.3;margin:1.6em 0 .5em;color:var(--hl)}
h1{font-size:1.7em}h2{font-size:1.35em}h3{font-size:1.15em}
p{margin:.8em 0}
a{color:var(--acc)}
code{background:var(--line);padding:1px 5px;border-radius:4px;font:0.9em "IBM Plex Mono",Consolas,monospace}
pre{background:var(--line);padding:12px 14px;border-radius:6px;overflow-x:auto}
pre code{background:none;padding:0}
blockquote{margin:1em 0;padding-left:1em;border-left:3px solid var(--acc);color:var(--ui)}
hr{border:0;border-top:1px solid var(--line);margin:2em 0}
table{border-collapse:collapse;margin:1em 0;width:100%}
th,td{border:1px solid var(--line);padding:6px 8px;text-align:left}
th{background:var(--line)}
img{max-width:100%}
</style>
</head>
<body>
<main>
$body
</main>
</body>
</html>
''';
}

String _escapeHtml(String value) {
  return value
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');
}
