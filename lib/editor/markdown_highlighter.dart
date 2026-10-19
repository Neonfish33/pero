import 'package:flutter/material.dart';

import '../core/theme/pero_theme.dart';
import 'focus_mode.dart';
import 'markdown_parser.dart';

final RegExp _inlinePattern = RegExp(
  r'(\*\*|__)(?=\S)(.+?)(?<=\S)\1'
  r'|\*(?=\S)(.+?)(?<=\S)\*'
  r'|(?<!\w)_(?=\S)(.+?)(?<=\S)_(?!\w)'
  r'|`[^`]+`'
  r'|\[([^\]]+)\]\(([^)]+)\)',
);

final RegExp _headingLine = RegExp(r'^(#{1,6}\s)(.*)$');
final RegExp _prefixLine = RegExp(
  r'^(\s*)((?:>[ ]?)|(?:[-*+]\s)|(?:\d+\.\s))(.*)$',
);
final RegExp _ruleLine = RegExp(r'^\s*(?:-{3,}|\*{3,}|_{3,})\s*$');

class _StyledRange {
  _StyledRange(this.start, this.end, this.style);

  int start;
  int end;
  TextStyle style;
}

class MarkdownEditingController extends TextEditingController {
  MarkdownEditingController({super.text});

  EditorFont font = EditorFont.mono;
  double fontSize = 19;
  FocusMode focusMode = FocusMode.off;
  PeroPalette palette = PeroPalette.light;

  Object? _cacheKey;
  TextSpan? _cache;

  TextStyle get baseStyle => peroEditorStyle(font, fontSize, palette);

  void updateAppearance({
    EditorFont? font,
    double? fontSize,
    FocusMode? focusMode,
    PeroPalette? palette,
  }) {
    var changed = false;
    if (font != null && font != this.font) {
      this.font = font;
      changed = true;
    }
    if (fontSize != null && fontSize != this.fontSize) {
      this.fontSize = fontSize;
      changed = true;
    }
    if (focusMode != null && focusMode != this.focusMode) {
      this.focusMode = focusMode;
      changed = true;
    }
    if (palette != null && palette != this.palette) {
      this.palette = palette;
      changed = true;
    }
    if (changed) {
      _cache = null;
      _cacheKey = null;
    }
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final text = value.text;
    final selection = value.selection;
    final composing = value.composing;
    final key = Object.hash(
      text.hashCode,
      text.length,
      selection.start,
      selection.end,
      composing.start,
      composing.end,
      withComposing,
      focusMode,
      font,
      fontSize,
      palette.isDark,
      style?.hashCode,
    );
    if (_cacheKey == key && _cache != null) {
      return _cache!;
    }

    final base = (style ?? baseStyle).copyWith(color: palette.fg);
    final built = _build(text, base, selection, composing, withComposing);
    _cacheKey = key;
    _cache = built;
    return built;
  }

  TextSpan _build(
    String text,
    TextStyle base,
    TextSelection selection,
    TextRange composing,
    bool withComposing,
  ) {
    final markStyle = base.copyWith(color: palette.mark);
    final headingStyle = base.copyWith(
      color: palette.highlight,
      fontWeight: FontWeight.w600,
    );
    final strongStyle = base.copyWith(
      color: palette.highlight,
      fontWeight: FontWeight.w600,
    );
    final emphasisStyle = base.copyWith(
      color: palette.highlight,
      fontStyle: FontStyle.italic,
    );
    final codeStyle = base.copyWith(
      color: palette.highlight,
      backgroundColor: palette.line.withValues(alpha: 0.75),
    );
    final codeBlockStyle = base.copyWith(color: palette.ui);
    final linkStyle = base.copyWith(
      color: palette.accent,
      decoration: TextDecoration.underline,
      decorationColor: palette.accent.withValues(alpha: 0.45),
    );
    final linkUrlStyle = base.copyWith(color: palette.ui);
    final ruleStyle = base.copyWith(color: palette.mark);

    final ranges = <_StyledRange>[];
    var cursor = 0;

    void appendMerged(int start, int end, TextStyle style) {
      if (ranges.isNotEmpty &&
          ranges.last.end == start &&
          ranges.last.style == style) {
        ranges.last.end = end;
      } else {
        ranges.add(_StyledRange(start, end, style));
      }
    }

    void add(int start, int end, TextStyle style) {
      var from = start.clamp(0, text.length);
      var to = end.clamp(0, text.length);
      if (to <= from) {
        return;
      }
      if (from > cursor) {
        appendMerged(cursor, from, base);
        from = cursor;
      }
      if (from < cursor) {
        from = cursor;
      }
      if (to <= from) {
        return;
      }
      appendMerged(from, to, style);
      cursor = to;
    }

    void inline(String line, int offset, TextStyle lineBase) {
      var position = 0;
      for (final match in _inlinePattern.allMatches(line)) {
        if (match.start > position) {
          add(
            offset + position,
            offset + match.start,
            lineBase,
          );
        }

        final boldMarker = match.group(1);
        final boldText = match.group(2);
        final italicStar = match.group(3);
        final italicUnderscore = match.group(4);
        final linkText = match.group(5);
        final linkUrl = match.group(6);

        if (boldMarker != null && boldText != null) {
          add(
            offset + match.start,
            offset + match.start + boldMarker.length,
            markStyle,
          );
          final contentStart = match.start + boldMarker.length;
          add(
            offset + contentStart,
            offset + contentStart + boldText.length,
            strongStyle,
          );
          add(
            offset + contentStart + boldText.length,
            offset + match.end,
            markStyle,
          );
        } else if (italicStar != null) {
          add(offset + match.start, offset + match.start + 1, markStyle);
          add(
            offset + match.start + 1,
            offset + match.end - 1,
            emphasisStyle,
          );
          add(offset + match.end - 1, offset + match.end, markStyle);
        } else if (italicUnderscore != null) {
          add(offset + match.start, offset + match.start + 1, markStyle);
          add(
            offset + match.start + 1,
            offset + match.end - 1,
            emphasisStyle,
          );
          add(offset + match.end - 1, offset + match.end, markStyle);
        } else if (linkText != null && linkUrl != null) {
          final bracketStart = match.start;
          add(offset + bracketStart, offset + bracketStart + 1, markStyle);
          final textStart = bracketStart + 1;
          add(
            offset + textStart,
            offset + textStart + linkText.length,
            linkStyle,
          );
          final urlStart = textStart + linkText.length;
          add(offset + urlStart, offset + urlStart + 2, markStyle);
          add(
            offset + urlStart + 2,
            offset + urlStart + 2 + linkUrl.length,
            linkUrlStyle,
          );
          add(offset + match.end - 1, offset + match.end, markStyle);
        } else if (match.group(0)!.startsWith('`')) {
          add(offset + match.start, offset + match.end, codeStyle);
        }

        position = match.end;
      }
      if (position < line.length) {
        add(offset + position, offset + line.length, lineBase);
      }
    }

    void styleLine(String line, int offset) {
      if (line.isEmpty) {
        return;
      }
      if (_ruleLine.hasMatch(line)) {
        add(offset, offset + line.length, ruleStyle);
        return;
      }

      final heading = _headingLine.firstMatch(line);
      if (heading != null) {
        final marker = heading.group(1)!;
        add(offset, offset + marker.length, markStyle);
        inline(
          heading.group(2)!,
          offset + marker.length,
          headingStyle,
        );
        return;
      }

      final prefix = _prefixLine.firstMatch(line);
      if (prefix != null) {
        final leading = prefix.group(1)!;
        final marker = prefix.group(2)!;
        final rest = prefix.group(3)!;
        add(offset, offset + leading.length, base);
        add(
          offset + leading.length,
          offset + leading.length + marker.length,
          markStyle,
        );
        inline(
          rest,
          offset + leading.length + marker.length,
          base,
        );
        return;
      }

      inline(line, offset, base);
    }

    var inCode = false;
    var lineStart = 0;
    while (lineStart <= text.length) {
      var lineEnd = text.indexOf('\n', lineStart);
      final hasNewline = lineEnd >= 0;
      if (!hasNewline) {
        lineEnd = text.length;
      }
      final line = text.substring(lineStart, lineEnd);

      if (line.trimLeft().startsWith('```') ||
          line.trimLeft().startsWith('~~~')) {
        add(lineStart, lineEnd, markStyle);
        inCode = !inCode;
      } else if (inCode) {
        add(lineStart, lineEnd, codeBlockStyle);
      } else {
        styleLine(line, lineStart);
      }

      if (hasNewline) {
        add(lineEnd, lineEnd + 1, base);
      }
      if (!hasNewline) {
        break;
      }
      lineStart = lineEnd + 1;
    }

    if (cursor < text.length) {
      appendMerged(cursor, text.length, base);
    }

    final focus = _focusRange(text, selection);
    var processed = ranges;
    if (focusMode != FocusMode.off) {
      processed = _applyFocus(ranges, focus);
    }
    if (withComposing &&
        composing.isValid &&
        !composing.isCollapsed) {
      processed = _applyComposing(
        processed,
        composing,
        text.length,
      );
    }

    if (processed.isEmpty) {
      return TextSpan(style: base, text: '');
    }

    return TextSpan(
      style: base,
      children: [
        for (final range in processed)
          TextSpan(
            text: text.substring(range.start, range.end),
            style: range.style,
          ),
      ],
    );
  }

  MarkdownRange _focusRange(String text, TextSelection selection) {
    final caret = selection.isValid
        ? selection.extentOffset.clamp(0, text.length)
        : 0;
    switch (focusMode) {
      case FocusMode.off:
        return MarkdownRange(0, text.length);
      case FocusMode.sentence:
        return sentenceRange(text, caret);
      case FocusMode.paragraph:
        return paragraphRange(text, caret);
    }
  }

  List<_StyledRange> _applyFocus(
    List<_StyledRange> ranges,
    MarkdownRange focus,
  ) {
    final result = <_StyledRange>[];
    TextStyle dim(TextStyle style) => style.copyWith(
          color: palette.dim,
          backgroundColor: Colors.transparent,
          decorationColor: palette.dim,
        );

    void addRange(int start, int end, TextStyle style) {
      if (end <= start) {
        return;
      }
      if (result.isNotEmpty &&
          result.last.end == start &&
          result.last.style == style) {
        result.last.end = end;
      } else {
        result.add(_StyledRange(start, end, style));
      }
    }

    for (final range in ranges) {
      if (range.start >= focus.start && range.end <= focus.end) {
        addRange(range.start, range.end, range.style);
      } else if (range.end <= focus.start || range.start >= focus.end) {
        addRange(range.start, range.end, dim(range.style));
      } else {
        final leftEnd = focus.start.clamp(range.start, range.end);
        addRange(range.start, leftEnd, dim(range.style));
        final middleEnd = focus.end.clamp(leftEnd, range.end);
        addRange(leftEnd, middleEnd, range.style);
        addRange(middleEnd, range.end, dim(range.style));
      }
    }
    return result;
  }

  List<_StyledRange> _applyComposing(
    List<_StyledRange> ranges,
    TextRange composing,
    int length,
  ) {
    final start = composing.start.clamp(0, length);
    final end = composing.end.clamp(0, length);
    if (end <= start) {
      return ranges;
    }
    final result = <_StyledRange>[];

    void addRange(int from, int to, TextStyle style) {
      if (to <= from) {
        return;
      }
      if (result.isNotEmpty &&
          result.last.end == from &&
          result.last.style == style) {
        result.last.end = to;
      } else {
        result.add(_StyledRange(from, to, style));
      }
    }

    for (final range in ranges) {
      if (range.end <= start || range.start >= end) {
        addRange(range.start, range.end, range.style);
        continue;
      }
      final leftEnd = start.clamp(range.start, range.end);
      addRange(range.start, leftEnd, range.style);
      final middleEnd = end.clamp(leftEnd, range.end);
      addRange(
        leftEnd,
        middleEnd,
        range.style.copyWith(
          decoration: TextDecoration.underline,
          decorationColor: palette.accent,
        ),
      );
      addRange(middleEnd, range.end, range.style);
    }
    return result;
  }
}
