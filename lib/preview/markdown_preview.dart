import 'package:flutter/material.dart';

import '../core/theme/pero_theme.dart';
import '../editor/markdown_parser.dart';

class MarkdownPreview extends StatelessWidget {
  const MarkdownPreview({
    super.key,
    required this.markdown,
    required this.baseStyle,
    required this.palette,
  });

  final String markdown;
  final TextStyle baseStyle;
  final PeroPalette palette;

  @override
  Widget build(BuildContext context) {
    final blocks = parseMarkdownBlocks(markdown);
    if (blocks.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Text(
          'Пустой документ',
          style: baseStyle.copyWith(color: palette.dim),
        ),
      );
    }

    final styles = _PreviewStyles(baseStyle, palette);
    return SelectionArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final block in blocks) _buildBlock(block, styles),
        ],
      ),
    );
  }

  Widget _buildBlock(MarkdownBlock block, _PreviewStyles styles) {
    switch (block) {
      case MarkdownHeading():
        final scale = switch (block.level) {
          1 => 1.7,
          2 => 1.35,
          3 => 1.15,
          _ => 1.0,
        };
        final heading = styles.base.copyWith(
          fontSize: (styles.base.fontSize ?? 19) * scale,
          fontWeight: FontWeight.w600,
          height: 1.3,
          color: palette.fg,
        );
        return Padding(
          padding: EdgeInsets.only(
            top: block.level == 1 ? 8 : 18,
            bottom: 6,
          ),
          child: Text.rich(
            TextSpan(
              style: heading,
              children: buildInlineSpans(
                block.text,
                base: heading,
                strong: heading.copyWith(fontWeight: FontWeight.w700),
                emphasis: heading.copyWith(fontStyle: FontStyle.italic),
                code: styles.code.copyWith(fontSize: heading.fontSize),
                link: styles.link.copyWith(fontSize: heading.fontSize),
                mark: styles.mark,
              ),
            ),
          ),
        );
      case MarkdownParagraph():
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Text.rich(
            TextSpan(
              style: styles.base,
              children: styles.inline(block.text),
            ),
          ),
        );
      case MarkdownQuote():
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 10),
          padding: const EdgeInsets.only(left: 14),
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(color: palette.accent, width: 3),
            ),
          ),
          child: Text.rich(
            TextSpan(
              style: styles.base.copyWith(color: palette.ui),
              children: styles.inline(
                block.text,
                base: styles.base.copyWith(color: palette.ui),
              ),
            ),
          ),
        );
      case MarkdownList():
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var index = 0; index < block.items.length; index++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 26,
                        child: Text(
                          block.ordered ? '${index + 1}.' : '•',
                          style: styles.base.copyWith(color: palette.ui),
                        ),
                      ),
                      Expanded(
                        child: Text.rich(
                          TextSpan(
                            style: styles.base,
                            children: styles.inline(block.items[index]),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      case MarkdownCode():
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: palette.line,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            block.code,
            style: styles.mono.copyWith(
              fontSize: (styles.base.fontSize ?? 19) * 0.88,
              height: 1.55,
              color: palette.fg,
            ),
          ),
        );
      case MarkdownRule():
        return Container(
          height: 1,
          color: palette.line,
          margin: const EdgeInsets.symmetric(vertical: 24),
        );
    }
  }
}

class _PreviewStyles {
  _PreviewStyles(this.base, this.palette);

  final TextStyle base;
  final PeroPalette palette;

  TextStyle get strong => base.copyWith(fontWeight: FontWeight.w600);
  TextStyle get emphasis => base.copyWith(fontStyle: FontStyle.italic);
  TextStyle get code => base.copyWith(
        fontFamily: kMonoFamily,
        fontSize: (base.fontSize ?? 19) * 0.9,
        backgroundColor: palette.line,
        color: palette.highlight,
      );
  TextStyle get link => base.copyWith(
        color: palette.accent,
        decoration: TextDecoration.underline,
        decorationColor: palette.accent.withValues(alpha: 0.45),
      );
  TextStyle get mark => base.copyWith(color: palette.mark);
  TextStyle get mono => base.copyWith(fontFamily: kMonoFamily);

  List<InlineSpan> inline(String text, {TextStyle? base}) {
    final current = base ?? this.base;
    return buildInlineSpans(
      text,
      base: current,
      strong: current.copyWith(fontWeight: FontWeight.w600),
      emphasis: current.copyWith(fontStyle: FontStyle.italic),
      code: code.copyWith(color: palette.highlight),
      link: current.copyWith(
        color: palette.accent,
        decoration: TextDecoration.underline,
        decorationColor: palette.accent.withValues(alpha: 0.45),
      ),
      mark: current.copyWith(color: palette.mark),
    );
  }
}
