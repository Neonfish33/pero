import 'package:flutter/material.dart';

const String kMonoFamily = 'IBM Plex Mono';
const String kSansFamily = 'Inter';
const String kSerifFamily = 'Source Serif 4';

const double kEditorLineHeight = 1.72;

enum EditorFont { mono, sans, serif }

extension EditorFontX on EditorFont {
  String get family {
    switch (this) {
      case EditorFont.mono:
        return kMonoFamily;
      case EditorFont.sans:
        return kSansFamily;
      case EditorFont.serif:
        return kSerifFamily;
    }
  }

  String get label {
    switch (this) {
      case EditorFont.mono:
        return 'Mono';
      case EditorFont.sans:
        return 'Sans';
      case EditorFont.serif:
        return 'Serif';
    }
  }
}

@immutable
class PeroPalette extends ThemeExtension<PeroPalette> {
  const PeroPalette({
    required this.bg,
    required this.fg,
    required this.dim,
    required this.mark,
    required this.accent,
    required this.ui,
    required this.line,
    required this.side,
    required this.highlight,
    required this.isDark,
  });

  final Color bg;
  final Color fg;
  final Color dim;
  final Color mark;
  final Color accent;
  final Color ui;
  final Color line;
  final Color side;
  final Color highlight;
  final bool isDark;

  static const light = PeroPalette(
    bg: Color(0xFFF6F7F8),
    fg: Color(0xFF1C1F24),
    dim: Color(0xFFBCC2C9),
    mark: Color(0xFFA9B0B8),
    accent: Color(0xFF1A8CFF),
    ui: Color(0xFF7B838C),
    line: Color(0xFFE3E6E9),
    side: Color(0xFFEEF0F2),
    highlight: Color(0xFF0B6BCB),
    isDark: false,
  );

  static const dark = PeroPalette(
    bg: Color(0xFF15181C),
    fg: Color(0xFFCFD5DB),
    dim: Color(0xFF505760),
    mark: Color(0xFF5D646D),
    accent: Color(0xFF4DB2FF),
    ui: Color(0xFF838B94),
    line: Color(0xFF262A30),
    side: Color(0xFF1B1F24),
    highlight: Color(0xFF7CC4FF),
    isDark: true,
  );

  static PeroPalette forBrightness(Brightness brightness) =>
      brightness == Brightness.dark ? dark : light;

  @override
  PeroPalette copyWith({
    Color? bg,
    Color? fg,
    Color? dim,
    Color? mark,
    Color? accent,
    Color? ui,
    Color? line,
    Color? side,
    Color? highlight,
    bool? isDark,
  }) {
    return PeroPalette(
      bg: bg ?? this.bg,
      fg: fg ?? this.fg,
      dim: dim ?? this.dim,
      mark: mark ?? this.mark,
      accent: accent ?? this.accent,
      ui: ui ?? this.ui,
      line: line ?? this.line,
      side: side ?? this.side,
      highlight: highlight ?? this.highlight,
      isDark: isDark ?? this.isDark,
    );
  }

  @override
  PeroPalette lerp(ThemeExtension<PeroPalette>? other, double t) {
    if (other is! PeroPalette) {
      return this;
    }
    return PeroPalette(
      bg: Color.lerp(bg, other.bg, t)!,
      fg: Color.lerp(fg, other.fg, t)!,
      dim: Color.lerp(dim, other.dim, t)!,
      mark: Color.lerp(mark, other.mark, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      ui: Color.lerp(ui, other.ui, t)!,
      line: Color.lerp(line, other.line, t)!,
      side: Color.lerp(side, other.side, t)!,
      highlight: Color.lerp(highlight, other.highlight, t)!,
      isDark: t < 0.5 ? isDark : other.isDark,
    );
  }
}

TextStyle peroEditorStyle(
  EditorFont font,
  double fontSize,
  PeroPalette palette,
) {
  return TextStyle(
    fontFamily: font.family,
    fontSize: fontSize,
    height: kEditorLineHeight,
    color: palette.fg,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
  );
}

ThemeData buildPeroTheme(Brightness brightness) {
  final palette = PeroPalette.forBrightness(brightness);
  final scheme = ColorScheme(
    brightness: brightness,
    primary: palette.accent,
    onPrimary: palette.bg,
    secondary: palette.accent,
    onSecondary: palette.bg,
    error: const Color(0xFFD9534F),
    onError: Colors.white,
    surface: palette.bg,
    onSurface: palette.fg,
  );

  final base = ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: palette.bg,
    canvasColor: palette.bg,
    dividerColor: palette.line,
    fontFamily: kSansFamily,
    visualDensity: VisualDensity.adaptivePlatformDensity,
    splashFactory: NoSplash.splashFactory,
    extensions: <ThemeExtension<dynamic>>[palette],
  );

  final textTheme = base.textTheme
      .apply(
        fontFamily: kSansFamily,
        bodyColor: palette.fg,
        displayColor: palette.fg,
      )
      .copyWith(
        bodySmall: TextStyle(
          fontFamily: kSansFamily,
          fontSize: 12,
          color: palette.ui,
        ),
        bodyMedium: TextStyle(
          fontFamily: kSansFamily,
          fontSize: 13,
          color: palette.fg,
        ),
        labelSmall: TextStyle(
          fontFamily: kSansFamily,
          fontSize: 11,
          color: palette.ui,
        ),
      );

  return base.copyWith(
    textTheme: textTheme,
    iconTheme: IconThemeData(color: palette.ui, size: 18),
    dividerTheme: DividerThemeData(color: palette.line, thickness: 1, space: 1),
    tooltipTheme: TooltipThemeData(
      waitDuration: const Duration(milliseconds: 600),
      decoration: BoxDecoration(
        color: palette.fg,
        borderRadius: BorderRadius.circular(6),
      ),
      textStyle: TextStyle(
        fontFamily: kSansFamily,
        fontSize: 12,
        color: palette.bg,
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: palette.bg,
      surfaceTintColor: Colors.transparent,
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: palette.line),
      ),
      textStyle: TextStyle(
        fontFamily: kSansFamily,
        fontSize: 13,
        color: palette.fg,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      isDense: true,
      hintStyle: TextStyle(
        fontFamily: kSansFamily,
        fontSize: 13,
        color: palette.ui,
      ),
      border: InputBorder.none,
      enabledBorder: InputBorder.none,
      focusedBorder: InputBorder.none,
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: palette.accent,
      selectionColor: palette.accent.withValues(alpha: 0.28),
      selectionHandleColor: palette.accent,
    ),
    scrollbarTheme: ScrollbarThemeData(
      thickness: const WidgetStatePropertyAll(6),
      radius: const Radius.circular(3),
      thumbColor: WidgetStatePropertyAll(palette.mark.withValues(alpha: 0.6)),
      trackColor: const WidgetStatePropertyAll(Colors.transparent),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: palette.fg,
      contentTextStyle: TextStyle(
        fontFamily: kSansFamily,
        fontSize: 13,
        color: palette.bg,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 76),
    ),
    drawerTheme: DrawerThemeData(
      backgroundColor: palette.side,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(),
    ),
  );
}
