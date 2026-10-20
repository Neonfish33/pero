import '../documents/document.dart';
import '../documents/document_library.dart';
import '../documents/document_repository.dart';
import '../editor/markdown_parser.dart';
import 'cloud_settings.dart';
import 'sync_state.dart';
import 'webdav_client.dart';

enum SyncAction { upload, download, conflict, skip }

SyncAction decideSyncAction({
  required bool hasRemote,
  required bool hasState,
  required bool localChanged,
  required bool remoteChanged,
}) {
  if (!hasRemote) {
    return SyncAction.upload;
  }
  if (!hasState) {
    return SyncAction.conflict;
  }
  if (!localChanged && !remoteChanged) {
    return SyncAction.skip;
  }
  if (remoteChanged && !localChanged) {
    return SyncAction.download;
  }
  if (localChanged && !remoteChanged) {
    return SyncAction.upload;
  }
  return SyncAction.conflict;
}

class SyncReport {
  int uploaded = 0;
  int downloaded = 0;
  int conflicts = 0;
  int deleted = 0;
  int skipped = 0;
  final List<String> errors = <String>[];
  DateTime? finishedAt;

  int get total =>
      uploaded + downloaded + conflicts + skipped + deleted + errors.length;

  String describe() {
    final parts = <String>[
      'загружено: $uploaded',
      'скачано: $downloaded',
      'конфликтов: $conflicts',
      'удалено в облаке: $deleted',
      'без изменений: $skipped',
    ];
    if (errors.isNotEmpty) {
      parts.add('ошибок: ${errors.length}');
    }
    return parts.join(', ');
  }
}

class CloudSync {
  CloudSync({
    required this.library,
    required this.repository,
    required this.settings,
  });

  static const Duration _tolerance = Duration(seconds: 2);

  final DocumentLibrary library;
  final DocumentRepository repository;
  final CloudSettings settings;

  Future<void> testConnection() async {
    final client = settings.createClient();
    try {
      await client.ensureFolder(settings.folder);
      await client.list(settings.folder);
    } finally {
      client.close();
    }
  }

  Future<SyncReport> synchronize() async {
    final client = settings.createClient();
    final folder = settings.folder;
    final report = SyncReport();
    try {
      library.flush();

      await client.ensureFolder(folder);
      final entries = await client.list(folder);
      final remote = <String, RemoteEntry>{
        for (final entry in entries)
          if (entry.name.toLowerCase().endsWith('.md')) entry.name: entry,
      };
      final states = <String, SyncState>{
        for (final state in repository.syncStates()) state.documentId: state,
      };

      for (final document in library.documents.toList()) {
        final fileName = '${document.id}.md';
        final entry = remote.remove(fileName);
        final state = states.remove(document.id);
        try {
          final remoteModified = entry?.modified;
          final localChanged = state == null ||
              document.updatedAt.isAfter(state.syncedUpdatedAt.add(_tolerance));
          final remoteChanged = state == null ||
              (remoteModified != null &&
                  remoteModified.isAfter(state.remoteModified.add(_tolerance)));
          final action = decideSyncAction(
            hasRemote: entry != null,
            hasState: state != null,
            localChanged: localChanged,
            remoteChanged: remoteChanged,
          );

          switch (action) {
            case SyncAction.upload:
              await client.upload(folder, fileName, document.markdown);
              await _saveState(
                client,
                folder,
                fileName,
                document.id,
                document.updatedAt,
                report,
              );
              report.uploaded++;
            case SyncAction.download:
              final text = await client.download(folder, fileName);
              final modified = remoteModified ?? DateTime.now();
              library.updateFromRemote(
                document.id,
                markdown: text,
                updatedAt: modified,
              );
              repository.upsertSyncState(
                SyncState(
                  documentId: document.id,
                  remotePath: fileName,
                  remoteModified: modified,
                  syncedUpdatedAt: modified,
                  syncedAt: DateTime.now(),
                ),
              );
              report.downloaded++;
            case SyncAction.conflict:
              final text = await client.download(folder, fileName);
              _createConflictCopy(text, remoteModified ?? DateTime.now());
              await client.upload(folder, fileName, document.markdown);
              await _saveState(
                client,
                folder,
                fileName,
                document.id,
                document.updatedAt,
                report,
              );
              report.conflicts++;
            case SyncAction.skip:
              report.skipped++;
          }
        } catch (error) {
          report.errors.add('${document.displayTitle}: $error');
        }
      }

      for (final entry in remote.values) {
        final id = documentIdFromFileName(entry.name);
        if (id == null || library.documentById(id) != null) {
          continue;
        }
        try {
          final text = await client.download(folder, entry.name);
          final normalized = normalizeNewlines(text);
          final modified = entry.modified ?? DateTime.now();
          library.insertDocument(
            PeroDocument(
              id: id,
              title: deriveTitle(normalized),
              markdown: normalized,
              createdAt: modified,
              updatedAt: modified,
              revision: 0,
            ),
          );
          repository.upsertSyncState(
            SyncState(
              documentId: id,
              remotePath: entry.name,
              remoteModified: modified,
              syncedUpdatedAt: modified,
              syncedAt: DateTime.now(),
            ),
          );
          report.downloaded++;
        } catch (error) {
          report.errors.add('${entry.name}: $error');
        }
      }

      for (final state in states.values) {
        try {
          await client.delete(folder, state.remotePath);
          repository.deleteSyncState(state.documentId);
          report.deleted++;
        } catch (error) {
          report.errors.add('${state.remotePath}: $error');
        }
      }
    } finally {
      client.close();
      report.finishedAt = DateTime.now();
    }
    return report;
  }

  Future<void> _saveState(
    WebDavClient client,
    String folder,
    String fileName,
    String documentId,
    DateTime updatedAt,
    SyncReport report,
  ) async {
    DateTime? modified;
    try {
      modified = await client.modified(folder, fileName);
    } catch (error) {
      report.errors.add('$fileName: $error');
    }
    final remoteModified = modified ?? DateTime.now();
    repository.upsertSyncState(
      SyncState(
        documentId: documentId,
        remotePath: fileName,
        remoteModified: remoteModified,
        syncedUpdatedAt: updatedAt,
        syncedAt: DateTime.now(),
      ),
    );
  }

  void _createConflictCopy(String markdown, DateTime remoteModified) {
    final normalized = normalizeNewlines(markdown);
    final title = deriveTitle(normalized);
    final created = PeroDocument.create(
      markdown: normalized,
      title: '$title (конфликт ${_formatTimestamp(DateTime.now())})',
    );
    library.insertDocument(created.copyWith(createdAt: remoteModified));
  }

  static String? documentIdFromFileName(String name) {
    if (!name.toLowerCase().endsWith('.md')) {
      return null;
    }
    final id = name.substring(0, name.length - 3);
    if (!RegExp(r'^[A-Za-z0-9_-]{1,80}$').hasMatch(id)) {
      return null;
    }
    return id;
  }

  static String _formatTimestamp(DateTime value) {
    String two(int number) => number.toString().padLeft(2, '0');
    return '${two(value.day)}.${two(value.month)}.${value.year} '
        '${two(value.hour)}:${two(value.minute)}';
  }
}
