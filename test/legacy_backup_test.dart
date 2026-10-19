import 'package:flutter_test/flutter_test.dart';
import 'package:pero/storage/legacy_backup.dart';

void main() {
  group('LegacyBackup.parse', () {
    test('reads the old localStorage schema with docs and text', () {
      const source = r'''{
        "docs": [
          {"id": "abc123", "text": "# Привет\n\nМир", "t": 1700000000000}
        ],
        "cur": "abc123",
        "font": "sans",
        "focus": "paragraph",
        "tw": true,
        "fs": 22,
        "theme": "dark",
        "side": false,
        "prev": false
      }''';

      final backup = LegacyBackup.parse(source);

      expect(backup.documents, hasLength(1));
      final document = backup.documents.first;
      expect(document.id, 'abc123');
      expect(document.markdown, '# Привет\n\nМир');
      expect(document.title, 'Привет');
      expect(
        document.createdAt,
        DateTime.fromMillisecondsSinceEpoch(1700000000000),
      );
      expect(
        document.updatedAt,
        DateTime.fromMillisecondsSinceEpoch(1700000000000),
      );

      expect(backup.settings.font, 'sans');
      expect(backup.settings.focus, 'paragraph');
      expect(backup.settings.theme, 'dark');
      expect(backup.settings.typewriter, isTrue);
      expect(backup.settings.sidebar, isFalse);
      expect(backup.settings.fontSize, 22);
      expect(backup.settings.isEmpty, isFalse);
    });

    test('reads a generic documents array with ISO dates', () {
      const source = r'''{
        "documents": [
          {
            "id": "a1",
            "markdown": "Первый",
            "createdAt": "2026-01-02T03:04:05Z",
            "updatedAt": "2026-01-03T04:05:06Z",
            "revision": 7,
            "filePath": "C:/docs/one.md"
          }
        ]
      }''';

      final backup = LegacyBackup.parse(source);
      final document = backup.documents.single;

      expect(document.id, 'a1');
      expect(document.markdown, 'Первый');
      expect(document.title, 'Первый');
      expect(document.createdAt, DateTime.parse('2026-01-02T03:04:05Z').toLocal());
      expect(document.updatedAt, DateTime.parse('2026-01-03T04:05:06Z').toLocal());
      expect(document.revision, 7);
      expect(document.filePath, 'C:/docs/one.md');
      expect(backup.settings.isEmpty, isTrue);
    });

    test('accepts a bare list and generates unique ids', () {
      const source = '[{"text": "Один"}, {"text": "Два"}]';

      final backup = LegacyBackup.parse(source);

      expect(backup.documents, hasLength(2));
      expect(
        backup.documents.map((document) => document.id).toSet(),
        hasLength(2),
      );
    });

    test('accepts a single document object', () {
      const source = r'{"markdown": "# Заметка\n\nТекст"}';

      final backup = LegacyBackup.parse(source);

      expect(backup.documents, hasLength(1));
      expect(backup.documents.single.title, 'Заметка');
    });

    test('keeps the first document for repeated ids', () {
      const source = r'''{
        "docs": [
          {"id": "same", "text": "Первый"},
          {"id": "same", "text": "Второй"}
        ]
      }''';

      final backup = LegacyBackup.parse(source);

      expect(backup.documents, hasLength(1));
      expect(backup.documents.single.markdown, 'Первый');
    });

    test('ignores unknown settings and clamps font size', () {
      const source = r'''{
        "docs": [{"text": "Текст"}],
        "font": "comic",
        "focus": "line",
        "theme": "sepia",
        "fs": 100
      }''';

      final backup = LegacyBackup.parse(source);

      expect(backup.settings.font, isNull);
      expect(backup.settings.focus, isNull);
      expect(backup.settings.theme, isNull);
      expect(backup.settings.fontSize, 30);
    });

    test('treats seconds and milliseconds timestamps differently', () {
      const source = r'''{
        "docs": [
          {"id": "seconds", "text": "Секунды", "t": 1700000000},
          {"id": "millis", "text": "Миллисекунды", "t": 1700000000000}
        ]
      }''';

      final backup = LegacyBackup.parse(source);

      expect(
        backup.documents[0].createdAt,
        DateTime.fromMillisecondsSinceEpoch(1700000000000),
      );
      expect(
        backup.documents[1].createdAt,
        DateTime.fromMillisecondsSinceEpoch(1700000000000),
      );
    });

    test('rejects empty, malformed and document-less input', () {
      expect(() => LegacyBackup.parse(''), throwsFormatException);
      expect(() => LegacyBackup.parse('не json'), throwsFormatException);
      expect(
        () => LegacyBackup.parse('{"settings": {}}'),
        throwsFormatException,
      );
      expect(() => LegacyBackup.parse('{"docs": []}'), throwsFormatException);
      expect(() => LegacyBackup.parse('42'), throwsFormatException);
    });
  });
}
