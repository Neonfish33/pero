import 'package:flutter_test/flutter_test.dart';
import 'package:pero/sync/cloud_sync.dart';

void main() {
  group('decideSyncAction', () {
    test('uploads when the remote file does not exist', () {
      expect(
        decideSyncAction(
          hasRemote: false,
          hasState: false,
          localChanged: true,
          remoteChanged: false,
        ),
        SyncAction.upload,
      );
    });

    test('keeps both versions when there is no sync baseline', () {
      expect(
        decideSyncAction(
          hasRemote: true,
          hasState: false,
          localChanged: true,
          remoteChanged: true,
        ),
        SyncAction.conflict,
      );
    });

    test('skips when nothing changed', () {
      expect(
        decideSyncAction(
          hasRemote: true,
          hasState: true,
          localChanged: false,
          remoteChanged: false,
        ),
        SyncAction.skip,
      );
    });

    test('downloads when only the cloud copy changed', () {
      expect(
        decideSyncAction(
          hasRemote: true,
          hasState: true,
          localChanged: false,
          remoteChanged: true,
        ),
        SyncAction.download,
      );
    });

    test('uploads when only the local copy changed', () {
      expect(
        decideSyncAction(
          hasRemote: true,
          hasState: true,
          localChanged: true,
          remoteChanged: false,
        ),
        SyncAction.upload,
      );
    });

    test('keeps both versions when both copies changed', () {
      expect(
        decideSyncAction(
          hasRemote: true,
          hasState: true,
          localChanged: true,
          remoteChanged: true,
        ),
        SyncAction.conflict,
      );
    });
  });

  group('documentIdFromFileName', () {
    test('extracts an id from a markdown file name', () {
      expect(
        CloudSync.documentIdFromFileName('m5x9a1-abc123.md'),
        'm5x9a1-abc123',
      );
      expect(CloudSync.documentIdFromFileName('legacy_id-1.md'), 'legacy_id-1');
    });

    test('ignores other files and unsafe names', () {
      expect(CloudSync.documentIdFromFileName('notes.txt'), isNull);
      expect(CloudSync.documentIdFromFileName('с заметкой.md'), isNull);
      expect(CloudSync.documentIdFromFileName('../escape.md'), isNull);
      expect(CloudSync.documentIdFromFileName('.md'), isNull);
    });
  });

  group('SyncReport', () {
    test('describes counters and errors', () {
      final report = SyncReport()
        ..uploaded = 2
        ..downloaded = 1
        ..conflicts = 1
        ..skipped = 3
        ..errors.add('bad file');

      expect(
        report.describe(),
        'загружено: 2, скачано: 1, конфликтов: 1, удалено в облаке: 0, '
        'без изменений: 3, ошибок: 1',
      );
      expect(report.total, 8);
    });
  });
}
