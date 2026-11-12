import 'package:path/path.dart' show join;
import 'package:sqflite/sqflite.dart';

import '../models/diary_models.dart';

class DiaryDatabase {
  DiaryDatabase._();

  static final DiaryDatabase instance = DiaryDatabase._();
  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;

    final directory = await getDatabasesPath();
    _database = await openDatabase(
      join(directory, 'diary.db'), // Та же БД, что и в версии 0.1
      version: 2,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE entries (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT NOT NULL,
            content TEXT NOT NULL,
            mood INTEGER,
            created_at TEXT NOT NULL
          )
        ''');
        await _createArcTables(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          // Не трогаем entries: уже существующие записи сохранятся.
          await _createArcTables(db);
        }
      },
    );
    return _database!;
  }

  static Future<void> _createArcTables(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS arcs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE COLLATE NOCASE
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS entry_arcs (
        entry_id INTEGER NOT NULL,
        arc_id INTEGER NOT NULL,
        PRIMARY KEY (entry_id, arc_id),
        FOREIGN KEY (entry_id) REFERENCES entries(id) ON DELETE CASCADE,
        FOREIGN KEY (arc_id) REFERENCES arcs(id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_entry_arcs_arc_id
      ON entry_arcs(arc_id)
    ''');
  }

  Future<List<DiaryEntry>> getEntries({int? arcId}) async {
    final db = await database;
    final List<Map<String, Object?>> rows;
    if (arcId == null) {
      rows = await db.query('entries', orderBy: 'created_at DESC, id DESC');
    } else {
      rows = await db.rawQuery('''
        SELECT e.* FROM entries e
        INNER JOIN entry_arcs ea ON ea.entry_id = e.id
        WHERE ea.arc_id = ?
        ORDER BY e.created_at DESC, e.id DESC
      ''', [arcId]);
    }
    return rows.map(DiaryEntry.fromMap).toList();
  }

  Future<List<DiaryArc>> getArcs() async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT a.id, a.name, COUNT(ea.entry_id) AS entry_count
      FROM arcs a
      LEFT JOIN entry_arcs ea ON ea.arc_id = a.id
      GROUP BY a.id, a.name
      ORDER BY a.name COLLATE NOCASE
    ''');
    return rows.map(DiaryArc.fromMap).toList();
  }

  Future<int> createArc(String name) async {
    final db = await database;
    return db.insert('arcs', {'name': name.trim()});
  }

  Future<void> deleteArc(int id) async {
    final db = await database;
    await db.delete('arcs', where: 'id = ?', whereArgs: [id]);
    // ON DELETE CASCADE удалит связи; сами записи останутся.
  }

  Future<Set<int>> getEntryArcIds(int entryId) async {
    final db = await database;
    final rows = await db.query(
      'entry_arcs',
      columns: ['arc_id'],
      where: 'entry_id = ?',
      whereArgs: [entryId],
    );
    return rows.map((row) => row['arc_id'] as int).toSet();
  }

  Future<void> saveEntry({
    int? id,
    required String title,
    required String content,
    required int mood,
    required Set<int> arcIds,
  }) async {
    final db = await database;
    await db.transaction((txn) async {
      late final int entryId;
      if (id == null) {
        entryId = await txn.insert('entries', {
          'title': title,
          'content': content,
          'mood': mood,
          'created_at': DateTime.now().toIso8601String(),
        });
      } else {
        entryId = id;
        await txn.update(
          'entries',
          {'title': title, 'content': content, 'mood': mood},
          where: 'id = ?',
          whereArgs: [id],
        );
        await txn.delete(
          'entry_arcs',
          where: 'entry_id = ?',
          whereArgs: [id],
        );
      }
      for (final arcId in arcIds) {
        await txn.insert('entry_arcs', {
          'entry_id': entryId,
          'arc_id': arcId,
        });
      }
    });
  }

  Future<void> deleteEntry(int id) async {
    final db = await database;
    await db.delete('entries', where: 'id = ?', whereArgs: [id]);
  }
}
