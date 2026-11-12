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
      version: 4,
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
        await _createMoodTable(db);
        await _createMotifContextTables(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          // Не трогаем entries: уже существующие записи сохранятся.
          await _createArcTables(db);
        }
        if (oldVersion < 3) {
          await _createMoodTable(db);
        }
        if (oldVersion < 4) {
          await _createMotifContextTables(db);
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

  static Future<void> _createMoodTable(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS mood_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        mood INTEGER NOT NULL CHECK (mood BETWEEN 0 AND 4),
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_mood_logs_created_at
      ON mood_logs(created_at)
    ''');
  }

  static Future<void> _createMotifContextTables(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS motifs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE COLLATE NOCASE
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS entry_motifs (
        entry_id INTEGER NOT NULL,
        motif_id INTEGER NOT NULL,
        PRIMARY KEY (entry_id, motif_id),
        FOREIGN KEY (entry_id) REFERENCES entries(id) ON DELETE CASCADE,
        FOREIGN KEY (motif_id) REFERENCES motifs(id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_entry_motifs_motif
      ON entry_motifs(motif_id)
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS entry_context (
        entry_id INTEGER PRIMARY KEY,
        place TEXT NOT NULL DEFAULT '',
        time_of_day TEXT NOT NULL DEFAULT '',
        people TEXT NOT NULL DEFAULT '',
        atmosphere TEXT NOT NULL DEFAULT '',
        life_period TEXT NOT NULL DEFAULT '',
        FOREIGN KEY (entry_id) REFERENCES entries(id) ON DELETE CASCADE
      )
    ''');
  }

  Future<List<DiaryMotif>> getMotifs() async {
    final db = await database;
    final rows = await db.query('motifs', orderBy: 'name COLLATE NOCASE');
    return rows.map(DiaryMotif.fromMap).toList();
  }

  Future<int> createMotif(String name) async {
    final cleaned = name.trim();
    if (cleaned.isEmpty) throw ArgumentError('Введите название мотива');
    final db = await database;
    return db.insert('motifs', {'name': cleaned});
  }

  Future<void> deleteMotif(int id) async {
    final db = await database;
    await db.delete('motifs', where: 'id = ?', whereArgs: [id]);
  }

  Future<Set<int>> getEntryMotifIds(int entryId) async {
    final db = await database;
    final rows = await db.query('entry_motifs', columns: ['motif_id'],
        where: 'entry_id = ?', whereArgs: [entryId]);
    return rows.map((row) => row['motif_id'] as int).toSet();
  }

  Future<EntryContext> getEntryContext(int entryId) async {
    final db = await database;
    final rows = await db.query('entry_context',
        where: 'entry_id = ?', whereArgs: [entryId], limit: 1);
    return rows.isEmpty ? const EntryContext() : EntryContext.fromMap(rows.first);
  }

  Future<List<DiaryEntry>> searchEntries(EntryFilters filters) async {
    final db = await database;
    final conditions = <String>[];
    final args = <Object?>[];
    if (filters.text.trim().isNotEmpty) {
      conditions.add('(e.title LIKE ? OR e.content LIKE ?)');
      final pattern = '%${filters.text.trim()}%';
      args.addAll([pattern, pattern]);
    }
    if (filters.arcId != null) {
      conditions.add('EXISTS (SELECT 1 FROM entry_arcs ea '
          'WHERE ea.entry_id = e.id AND ea.arc_id = ?)');
      args.add(filters.arcId);
    }
    if (filters.motifId != null) {
      conditions.add('EXISTS (SELECT 1 FROM entry_motifs em '
          'WHERE em.entry_id = e.id AND em.motif_id = ?)');
      args.add(filters.motifId);
    }
    if (filters.mood != null) {
      conditions.add('e.mood = ?');
      args.add(filters.mood);
    }
    if (filters.from != null) {
      conditions.add('e.created_at >= ?');
      final d = filters.from!;
      args.add(DateTime(d.year, d.month, d.day).toIso8601String());
    }
    if (filters.to != null) {
      conditions.add('e.created_at < ?');
      final d = filters.to!;
      args.add(DateTime(d.year, d.month, d.day + 1).toIso8601String());
    }
    if (filters.contextText.trim().isNotEmpty) {
      conditions.add('EXISTS (SELECT 1 FROM entry_context c WHERE c.entry_id = e.id '
          'AND (c.place LIKE ? OR c.time_of_day LIKE ? OR c.people LIKE ? '
          'OR c.atmosphere LIKE ? OR c.life_period LIKE ?))');
      final pattern = '%${filters.contextText.trim()}%';
      args.addAll(List.filled(5, pattern));
    }
    final where = conditions.isEmpty ? '' : 'WHERE ${conditions.join(' AND ')}';
    final rows = await db.rawQuery('''
      SELECT e.* FROM entries e $where
      ORDER BY e.created_at DESC, e.id DESC
    ''', args);
    return rows.map(DiaryEntry.fromMap).toList();
  }

  Future<void> addMoodLog(int mood) async {
    if (mood < 0 || mood > 4) {
      throw ArgumentError.value(mood, 'mood', 'Должно быть от 0 до 4');
    }
    final db = await database;
    await db.insert('mood_logs', {
      'mood': mood,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<List<MoodLog>> getMoodLogs() async {
    final db = await database;
    final rows = await db.query('mood_logs', orderBy: 'created_at DESC, id DESC');
    return rows.map(MoodLog.fromMap).toList();
  }

  Future<void> deleteMoodLog(int id) async {
    final db = await database;
    await db.delete('mood_logs', where: 'id = ?', whereArgs: [id]);
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
    Set<int> motifIds = const {},
    EntryContext entryContext = const EntryContext(),
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
      await txn.delete('entry_motifs', where: 'entry_id = ?', whereArgs: [entryId]);
      for (final motifId in motifIds) {
        await txn.insert('entry_motifs', {'entry_id': entryId, 'motif_id': motifId});
      }
      await txn.insert('entry_context', entryContext.toMap(entryId),
          conflictAlgorithm: ConflictAlgorithm.replace);
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
