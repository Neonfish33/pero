import 'dart:convert';

import '../documents/document.dart';
import '../editor/markdown_parser.dart';

class LegacySettings {
  const LegacySettings({
    this.font,
    this.focus,
    this.typewriter,
    this.fontSize,
    this.theme,
    this.sidebar,
  });

  final String? font;
  final String? focus;
  final bool? typewriter;
  final double? fontSize;
  final String? theme;
  final bool? sidebar;

  bool get isEmpty =>
      font == null &&
      focus == null &&
      typewriter == null &&
      fontSize == null &&
      theme == null &&
      sidebar == null;
}

class LegacyBackup {
  const LegacyBackup({required this.documents, required this.settings});

  final List<PeroDocument> documents;
  final LegacySettings settings;

  static const List<String> _documentListKeys = <String>['docs', 'documents'];

  static const List<String> _markdownKeys = <String>[
    'markdown',
    'text',
    'content',
    'body',
  ];

  static const List<String> _titleKeys = <String>['title', 'name'];

  static const List<String> _idKeys = <String>['id', 'docId', 'doc_id'];

  static const List<String> _createdKeys = <String>[
    'createdAt',
    'created_at',
    'created',
    't',
  ];

  static const List<String> _updatedKeys = <String>[
    'updatedAt',
    'updated_at',
    'updated',
    'u',
    't',
  ];

  static const List<String> _filePathKeys = <String>[
    'filePath',
    'file_path',
    'path',
  ];

  static const List<String> _revisionKeys = <String>['revision', 'rev'];

  static LegacyBackup parse(String source) {
    if (source.trim().isEmpty) {
      throw const FormatException('Файл резервной копии пуст');
    }

    final dynamic decoded;
    try {
      decoded = jsonDecode(source);
    } on FormatException {
      throw const FormatException('Файл не является корректным JSON');
    }

    final List<dynamic> rawDocuments;
    Map<String, dynamic>? meta;
    if (decoded is List) {
      rawDocuments = decoded;
    } else if (decoded is Map) {
      meta = Map<String, dynamic>.from(decoded);
      final candidate = _firstList(meta, _documentListKeys);
      if (candidate != null) {
        rawDocuments = candidate;
      } else if (_hasAnyKey(meta, _markdownKeys)) {
        rawDocuments = <dynamic>[meta];
      } else {
        throw const FormatException(
          'В файле нет списка документов (docs или documents)',
        );
      }
    } else {
      throw const FormatException(
        'Ожидался список документов или объект с полем docs',
      );
    }

    final seen = <String>{};
    final documents = <PeroDocument>[];
    for (final raw in rawDocuments) {
      if (raw is! Map) {
        continue;
      }
      final map = Map<String, dynamic>.from(raw);
      final text = _firstString(map, _markdownKeys) ?? '';
      final normalized = normalizeNewlines(text);
      final providedId = _firstString(map, _idKeys)?.trim();
      final title = _firstString(map, _titleKeys)?.trim();
      final createdAt = _firstDate(map, _createdKeys) ??
          _firstDate(map, _updatedKeys) ??
          DateTime.now();
      final updatedAt = _firstDate(map, _updatedKeys) ?? createdAt;

      final id = providedId == null || providedId.isEmpty
          ? PeroDocument.create(markdown: normalized).id
          : providedId;
      if (!seen.add(id)) {
        continue;
      }

      documents.add(
        PeroDocument(
          id: id,
          title: title == null || title.isEmpty
              ? deriveTitle(normalized)
              : title,
          markdown: normalized,
          createdAt: createdAt,
          updatedAt: updatedAt,
          filePath: _firstString(map, _filePathKeys),
          revision: _firstInt(map, _revisionKeys) ?? 0,
        ),
      );
    }

    if (documents.isEmpty) {
      throw const FormatException('В резервной копии нет документов');
    }

    return LegacyBackup(
      documents: documents,
      settings: _settingsFromMeta(meta),
    );
  }

  static LegacySettings _settingsFromMeta(Map<String, dynamic>? meta) {
    if (meta == null) {
      return const LegacySettings();
    }

    final font = _oneOf(_firstString(meta, <String>['font']), <String>[
      'mono',
      'sans',
      'serif',
    ]);
    final focus = _oneOf(_firstString(meta, <String>['focus']), <String>[
      'off',
      'sentence',
      'paragraph',
    ]);
    final theme = _oneOf(_firstString(meta, <String>['theme']), <String>[
      'auto',
      'light',
      'dark',
    ]);
    final typewriter = _firstBool(meta, <String>['tw', 'typewriter']);
    final sidebar = _firstBool(meta, <String>['side', 'sidebar']);
    final fontSize = _firstDouble(meta, <String>['fs', 'fontSize']);

    return LegacySettings(
      font: font,
      focus: focus,
      theme: theme,
      typewriter: typewriter,
      sidebar: sidebar,
      fontSize: fontSize?.clamp(13, 30).toDouble(),
    );
  }

  static String? _oneOf(String? value, List<String> allowed) {
    if (value == null) {
      return null;
    }
    final normalized = value.trim().toLowerCase();
    return allowed.contains(normalized) ? normalized : null;
  }

  static List<dynamic>? _firstList(
    Map<String, dynamic> map,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = map[key];
      if (value is List) {
        return value;
      }
    }
    return null;
  }

  static bool _hasAnyKey(Map<String, dynamic> map, List<String> keys) {
    return keys.any(map.containsKey);
  }

  static String? _firstString(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final value = map[key];
      if (value is String) {
        return value;
      }
    }
    return null;
  }

  static int? _firstInt(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final value = map[key];
      if (value is int) {
        return value;
      }
      if (value is num) {
        return value.toInt();
      }
      if (value is String) {
        final parsed = int.tryParse(value);
        if (parsed != null) {
          return parsed;
        }
      }
    }
    return null;
  }

  static double? _firstDouble(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final value = map[key];
      if (value is num) {
        return value.toDouble();
      }
      if (value is String) {
        final parsed = double.tryParse(value);
        if (parsed != null) {
          return parsed;
        }
      }
    }
    return null;
  }

  static bool? _firstBool(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final value = map[key];
      if (value is bool) {
        return value;
      }
      if (value is num) {
        return value != 0;
      }
      if (value is String) {
        final normalized = value.trim().toLowerCase();
        if (normalized == 'true' || normalized == '1') {
          return true;
        }
        if (normalized == 'false' || normalized == '0') {
          return false;
        }
      }
    }
    return null;
  }

  static DateTime? _firstDate(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final parsed = _toDate(map[key]);
      if (parsed != null) {
        return parsed;
      }
    }
    return null;
  }

  static DateTime? _toDate(dynamic value) {
    if (value is int) {
      return _fromEpoch(value);
    }
    if (value is double) {
      return _fromEpoch(value.round());
    }
    if (value is String) {
      final numeric = int.tryParse(value.trim());
      if (numeric != null) {
        return _fromEpoch(numeric);
      }
      return DateTime.tryParse(value.trim())?.toLocal();
    }
    return null;
  }

  static DateTime _fromEpoch(int value) {
    final milliseconds = value.abs() < 100000000000 ? value * 1000 : value;
    return DateTime.fromMillisecondsSinceEpoch(milliseconds);
  }
}
