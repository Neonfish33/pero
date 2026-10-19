import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

class PeroDatabase {
  PeroDatabase._(this.db);

  final sqlite.Database db;

  static Future<PeroDatabase> open() async {
    final directory = await getApplicationSupportDirectory();
    await directory.create(recursive: true);
    final file = File(
      '${directory.path}${Platform.pathSeparator}pero.sqlite',
    );
    final db = sqlite.sqlite3.open(file.path);
    final database = PeroDatabase._(db);
    database._migrate();
    return database;
  }

  void _migrate() {
    db.execute('PRAGMA journal_mode = WAL');
    db.execute('PRAGMA synchronous = NORMAL');
    db.execute('PRAGMA foreign_keys = ON');

    final version = db.select('PRAGMA user_version').first.values.first as int;
    if (version < 1) {
      db.execute('''
        CREATE TABLE IF NOT EXISTS documents (
          id TEXT NOT NULL PRIMARY KEY,
          title TEXT NOT NULL,
          markdown TEXT NOT NULL,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL,
          file_path TEXT,
          revision INTEGER NOT NULL DEFAULT 0
        )
      ''');
      db.execute('''
        CREATE INDEX IF NOT EXISTS documents_updated_at
        ON documents (updated_at DESC)
      ''');
      db.execute('PRAGMA user_version = 1');
    }
  }

  void close() {
    db.close();
  }
}
