import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/theme/pero_theme.dart';
import '../editor/focus_mode.dart';

enum ThemePreference { auto, light, dark }

extension ThemePreferenceX on ThemePreference {
  String get label {
    switch (this) {
      case ThemePreference.auto:
        return 'авто';
      case ThemePreference.light:
        return 'светлая';
      case ThemePreference.dark:
        return 'тёмная';
    }
  }

  ThemePreference get next {
    switch (this) {
      case ThemePreference.auto:
        return ThemePreference.light;
      case ThemePreference.light:
        return ThemePreference.dark;
      case ThemePreference.dark:
        return ThemePreference.auto;
    }
  }
}

enum ColumnWidth { narrow, normal, wide }

extension ColumnWidthX on ColumnWidth {
  String get label {
    switch (this) {
      case ColumnWidth.narrow:
        return 'узкая';
      case ColumnWidth.normal:
        return 'обычная';
      case ColumnWidth.wide:
        return 'широкая';
    }
  }

  double get editorWidth {
    switch (this) {
      case ColumnWidth.narrow:
        return 680;
      case ColumnWidth.normal:
        return 860;
      case ColumnWidth.wide:
        return 1040;
    }
  }

  double get previewWidth => editorWidth * 0.85;

  ColumnWidth get next {
    switch (this) {
      case ColumnWidth.narrow:
        return ColumnWidth.normal;
      case ColumnWidth.normal:
        return ColumnWidth.wide;
      case ColumnWidth.wide:
        return ColumnWidth.narrow;
    }
  }
}

class SettingsController extends ChangeNotifier {
  SettingsController(this._prefs) {
    _read();
  }

  static const _fontKey = 'pero.font';
  static const _fontSizeKey = 'pero.fontSize';
  static const _themeKey = 'pero.theme';
  static const _focusKey = 'pero.focus';
  static const _typewriterKey = 'pero.typewriter';
  static const _sidebarKey = 'pero.sidebar';
  static const _columnKey = 'pero.column';

  final SharedPreferences _prefs;

  EditorFont font = EditorFont.mono;
  double fontSize = 19;
  ThemePreference theme = ThemePreference.auto;
  FocusMode focusMode = FocusMode.off;
  bool typewriter = false;
  bool sidebar = true;
  ColumnWidth columnWidth = ColumnWidth.normal;

  ThemeMode get themeMode {
    switch (theme) {
      case ThemePreference.auto:
        return ThemeMode.system;
      case ThemePreference.light:
        return ThemeMode.light;
      case ThemePreference.dark:
        return ThemeMode.dark;
    }
  }

  void _read() {
    final fontName = _prefs.getString(_fontKey);
    if (fontName != null) {
      for (final value in EditorFont.values) {
        if (value.name == fontName) {
          font = value;
          break;
        }
      }
    }

    final size = _prefs.getDouble(_fontSizeKey);
    if (size != null) {
      fontSize = size.clamp(13, 30).toDouble();
    }

    final themeName = _prefs.getString(_themeKey);
    if (themeName != null) {
      for (final value in ThemePreference.values) {
        if (value.name == themeName) {
          theme = value;
          break;
        }
      }
    }

    final focusName = _prefs.getString(_focusKey);
    if (focusName != null) {
      for (final value in FocusMode.values) {
        if (value.name == focusName) {
          focusMode = value;
          break;
        }
      }
    }

    typewriter = _prefs.getBool(_typewriterKey) ?? typewriter;
    sidebar = _prefs.getBool(_sidebarKey) ?? sidebar;

    final columnName = _prefs.getString(_columnKey);
    if (columnName != null) {
      for (final value in ColumnWidth.values) {
        if (value.name == columnName) {
          columnWidth = value;
          break;
        }
      }
    }
  }

  void setFont(EditorFont value) {
    if (font == value) {
      return;
    }
    font = value;
    _prefs.setString(_fontKey, value.name);
    notifyListeners();
  }

  void setFontSize(double value) {
    final clamped = value.clamp(13, 30).toDouble();
    if (fontSize == clamped) {
      return;
    }
    fontSize = clamped;
    _prefs.setDouble(_fontSizeKey, clamped);
    notifyListeners();
  }

  void setTheme(ThemePreference value) {
    if (theme == value) {
      return;
    }
    theme = value;
    _prefs.setString(_themeKey, value.name);
    notifyListeners();
  }

  void cycleTheme() => setTheme(theme.next);

  void setFocusMode(FocusMode value) {
    if (focusMode == value) {
      return;
    }
    focusMode = value;
    _prefs.setString(_focusKey, value.name);
    notifyListeners();
  }

  void setTypewriter(bool value) {
    if (typewriter == value) {
      return;
    }
    typewriter = value;
    _prefs.setBool(_typewriterKey, value);
    notifyListeners();
  }

  void setSidebar(bool value) {
    if (sidebar == value) {
      return;
    }
    sidebar = value;
    _prefs.setBool(_sidebarKey, value);
    notifyListeners();
  }

  void setColumnWidth(ColumnWidth value) {
    if (columnWidth == value) {
      return;
    }
    columnWidth = value;
    _prefs.setString(_columnKey, value.name);
    notifyListeners();
  }

  void cycleColumnWidth() => setColumnWidth(columnWidth.next);
}
