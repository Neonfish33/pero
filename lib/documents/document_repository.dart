import 'package:sqlite3/sqlite3.dart' as sqlite;

import '../documents/document.dart';
import '../storage/database.dart';

class DocumentRepository {
  DocumentRepository(this._database);

  final PeroDatabase _database;

  List<PeroDocument> all() {
    final rows = _database.db.select('''
      SELECT id, title, markdown, created_at, updated_at, file_path, revision
      FROM documents
      ORDER BY updated_at DESC
    ''');
    return rows.map(_fromRow).toList(growable: false);
  }

  PeroDocument? byId(String id) {
    final rows = _database.db.select(
      '''
      SELECT id, title, markdown, created_at, updated_at, file_path, revision
      FROM documents
      WHERE id = ?
      ''',
      [id],
    );
    if (rows.isEmpty) {
      return null;
    }
    return _fromRow(rows.first);
  }

  void upsert(PeroDocument document) {
    _database.db.execute(
      '''
      INSERT INTO documents (
        id, title, markdown, created_at, updated_at, file_path, revision
      ) VALUES (?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(id) DO UPDATE SET
        title = excluded.title,
        markdown = excluded.markdown,
        created_at = excluded.created_at,
        updated_at = excluded.updated_at,
        file_path = excluded.file_path,
        revision = excluded.revision
      ''',
      [
        document.id,
        document.title,
        document.markdown,
        document.createdAt.millisecondsSinceEpoch,
        document.updatedAt.millisecondsSinceEpoch,
        document.filePath,
        document.revision,
      ],
    );
  }

  void delete(String id) {
    _database.db.execute('DELETE FROM documents WHERE id = ?', [id]);
  }

  PeroDocument _fromRow(sqlite.Row row) {
    return PeroDocument(
      id: row['id'] as String,
      title: row['title'] as String,
      markdown: row['markdown'] as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        row['created_at'] as int,
      ),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        row['updated_at'] as int,
      ),
      filePath: row['file_path'] as String?,
      revision: row['revision'] as int,
    );
  }
}
