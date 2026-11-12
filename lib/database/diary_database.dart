import 'package:sqflite_sqlcipher/sqflite.dart';

import '../security/encrypted_database.dart';

import '../models/diary_models.dart';

class DiaryDatabase {
  DiaryDatabase._();

  static final DiaryDatabase instance = DiaryDatabase._();
  Database? _database;
  Future<Database>? _opening;

  Future<Database> get database async {
    if (_database != null && _database!.isOpen) return _database!;
    return _opening ??= _openWithSchema().whenComplete(() => _opening = null);
  }

  Future<Database> _openWithSchema() async {
    final locator = EncryptedDatabase.instance;
    final location = await locator.activeDatabase();
    final db = await openDatabase(
      location.path,
      password: location.password,
      version: 6,
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
        await _createReflectionTables(db);
        await _createWellbeingTables(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) await _createArcTables(db);
        if (oldVersion < 3) await _createMoodTable(db);
        if (oldVersion < 4) await _createMotifContextTables(db);
        if (oldVersion < 5) await _createReflectionTables(db);
        if (oldVersion < 6) await _createWellbeingTables(db);
      },
    );
    _database = db;
    return db;
  }

  /// Manually triggered from security settings after a local backup.
  /// Does not delete the old plaintext diary.db.
  Future<MigrationReport> enableEncryption() async {
    if (_opening != null) await _opening;
    if (_database != null && _database!.isOpen) {
      await _database!.close();
      _database = null;
    }
    try {
      return await EncryptedDatabase.instance.migrate();
    } finally {
      // Next request opens the encrypted database after successful migration.
      _database = null;
      _opening = null;
    }
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

  static Future<void> _createReflectionTables(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS entry_visibility (
        entry_id INTEGER PRIMARY KEY,
        kind TEXT NOT NULL CHECK(kind IN ('future', 'frozen')),
        visible_at TEXT NOT NULL,
        FOREIGN KEY (entry_id) REFERENCES entries(id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS entry_comments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        entry_id INTEGER NOT NULL,
        content TEXT NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (entry_id) REFERENCES entries(id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS delayed_questions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        question TEXT NOT NULL,
        due_at TEXT NOT NULL,
        created_at TEXT NOT NULL,
        answered_at TEXT,
        answer TEXT
      )
    ''');
  }

  static Future<void> _createWellbeingTables(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS wellbeing_questions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        text TEXT NOT NULL,
        active INTEGER NOT NULL DEFAULT 1 CHECK(active IN (0, 1))
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS wellbeing_sessions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        created_at TEXT NOT NULL,
        score INTEGER NOT NULL CHECK(score BETWEEN 0 AND 100)
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS wellbeing_answers (
        session_id INTEGER NOT NULL,
        question_text TEXT NOT NULL,
        rating INTEGER NOT NULL CHECK(rating BETWEEN 0 AND 4),
        FOREIGN KEY(session_id) REFERENCES wellbeing_sessions(id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS app_preferences (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
    // Начальные вопросы добавляются только при пустом списке.
    final count = Sqflite.firstIntValue(await db.rawQuery(
      'SELECT COUNT(*) FROM wellbeing_questions')) ?? 0;
    if (count == 0) {
      for (final q in defaultWellbeingQuestions) {
        await db.insert('wellbeing_questions', {'text': q, 'active': 1});
      }
    }
  }

  Future<List<WellbeingQuestion>> getWellbeingQuestions({bool onlyActive = false}) async {
    final db = await database;
    final rows = await db.query('wellbeing_questions',
      where: onlyActive ? 'active = 1' : null, orderBy: 'id ASC');
    return rows.map(WellbeingQuestion.fromMap).toList();
  }

  Future<void> addWellbeingQuestion(String text) async {
    if (text.trim().isEmpty) throw ArgumentError('Введите вопрос');
    final db = await database;
    await db.insert('wellbeing_questions', {'text': text.trim(), 'active': 1});
  }

  Future<void> setWellbeingQuestionActive(int id, bool active) async {
    final db = await database;
    await db.update('wellbeing_questions', {'active': active ? 1 : 0},
      where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteWellbeingQuestion(int id) async {
    final db = await database;
    await db.delete('wellbeing_questions', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> saveWellbeingSession(Map<String, int> answers) async {
    final db = await database;
    final questions = await getWellbeingQuestions(onlyActive: true);
    if (questions.isEmpty || answers.length != questions.length ||
        questions.any((q) => !answers.containsKey(q.text))) {
      throw ArgumentError('Нужно ответить на все активные вопросы');
    }
    for (final rating in answers.values) {
      if (rating < 0 || rating > 4) throw ArgumentError('Оценка от 0 до 4');
    }
    final score = wellbeingScore(answers.values.toList());
    await db.transaction((txn) async {
      final id = await txn.insert('wellbeing_sessions', {
        'created_at': DateTime.now().toIso8601String(), 'score': score,
      });
      for (final entry in answers.entries) {
        await txn.insert('wellbeing_answers', {
          'session_id': id, 'question_text': entry.key, 'rating': entry.value,
        });
      }
    });
  }

  Future<List<WellbeingSession>> getWellbeingSessions() async {
    final db = await database;
    final rows = await db.query('wellbeing_sessions',
      orderBy: 'created_at DESC, id DESC');
    return rows.map(WellbeingSession.fromMap).toList();
  }

  Future<bool> promptsEnabled() async {
    final db = await database;
    final rows = await db.query('app_preferences', where: 'key = ?',
      whereArgs: ['reflection_prompts'], limit: 1);
    return rows.isEmpty || rows.first['value'] == '1';
  }

  Future<void> setPromptsEnabled(bool enabled) async {
    final db = await database;
    await db.insert('app_preferences',
      {'key': 'reflection_prompts', 'value': enabled ? '1' : '0'},
      conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Дата сравнивается с локальным временем, записанным в ISO-8601.
  /// Это скрытие в интерфейсе, не криптографическая защита.
  Future<void> setVisibility(int entryId, String? kind, DateTime? date) async {
    final db = await database;
    if (kind == null) {
      await db.delete('entry_visibility', where: 'entry_id = ?', whereArgs: [entryId]);
      return;
    }
    if (kind != 'future' && kind != 'frozen') throw ArgumentError('Неверный тип');
    if (date == null || !date.isAfter(DateTime.now())) {
      throw ArgumentError('Выбери дату в будущем');
    }
    await db.insert('entry_visibility', {
      'entry_id': entryId, 'kind': kind, 'visible_at': date.toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<EntryVisibility?> getVisibility(int entryId) async {
    final db = await database;
    final rows = await db.query('entry_visibility', where: 'entry_id = ?',
        whereArgs: [entryId], limit: 1);
    return rows.isEmpty ? null : EntryVisibility.fromMap(rows.first);
  }

  Future<List<EntryComment>> getComments(int entryId) async {
    final db = await database;
    final rows = await db.query('entry_comments', where: 'entry_id = ?',
        whereArgs: [entryId], orderBy: 'created_at ASC, id ASC');
    return rows.map(EntryComment.fromMap).toList();
  }

  Future<void> addComment(int entryId, String text) async {
    if (text.trim().isEmpty) throw ArgumentError('Пустой комментарий');
    final db = await database;
    await db.insert('entry_comments', {
      'entry_id': entryId, 'content': text.trim(),
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> deleteComment(int id) async {
    final db = await database;
    await db.delete('entry_comments', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<DelayedQuestion>> getQuestions() async {
    final db = await database;
    final rows = await db.query('delayed_questions', orderBy: 'due_at ASC, id ASC');
    return rows.map(DelayedQuestion.fromMap).toList();
  }

  Future<void> saveQuestion({int? id, required String question,
      required DateTime dueAt, String? answer}) async {
    if (question.trim().isEmpty) throw ArgumentError('Введи вопрос');
    final db = await database;
    final row = <String, Object?>{
      'question': question.trim(), 'due_at': dueAt.toIso8601String(),
    };
    if (id == null) {
      row['created_at'] = DateTime.now().toIso8601String();
      await db.insert('delayed_questions', row);
    } else {
      await db.update('delayed_questions', row, where: 'id = ?', whereArgs: [id]);
    }
  }

  Future<void> answerQuestion(int id, String answer) async {
    if (answer.trim().isEmpty) throw ArgumentError('Введи ответ');
    final db = await database;
    await db.update('delayed_questions', {
      'answer': answer.trim(), 'answered_at': DateTime.now().toIso8601String(),
    }, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteQuestion(int id) async {
    final db = await database;
    await db.delete('delayed_questions', where: 'id = ?', whereArgs: [id]);
  }

  String get _accessiblePredicate =>
      "NOT EXISTS (SELECT 1 FROM entry_visibility v WHERE v.entry_id = e.id "
      "AND v.visible_at > ?)";

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
    conditions.add(_accessiblePredicate);
    args.add(DateTime.now().toIso8601String());
    final where = 'WHERE ${conditions.join(' AND ')}';
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
      rows = await db.rawQuery('''
        SELECT e.* FROM entries e WHERE $_accessiblePredicate
        ORDER BY e.created_at DESC, e.id DESC
      ''', [DateTime.now().toIso8601String()]);
    } else {
      rows = await db.rawQuery('''
        SELECT e.* FROM entries e
        INNER JOIN entry_arcs ea ON ea.entry_id = e.id
        WHERE ea.arc_id = ? AND $_accessiblePredicate
        ORDER BY e.created_at DESC, e.id DESC
      ''', [arcId, DateTime.now().toIso8601String()]);
    }
    return rows.map(DiaryEntry.fromMap).toList();
  }

  Future<List<DiaryArc>> getArcs() async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT a.id, a.name, COUNT(ea.entry_id) AS entry_count
      FROM arcs a
      LEFT JOIN entry_arcs ea ON ea.arc_id = a.id
        AND NOT EXISTS (SELECT 1 FROM entry_visibility v WHERE v.entry_id = ea.entry_id AND v.visible_at > '${DateTime.now().toIso8601String()}')
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
    String? visibilityKind,
    DateTime? visibleAt,
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
      // При редактировании сохраняем прежнюю заморозку, если не передано
      // явное изменение; редактор всегда передаёт актуальное состояние.
      if (visibilityKind != null) {
        if (visibleAt == null || !visibleAt.isAfter(DateTime.now())) {
          throw ArgumentError('Дата открытия должна быть в будущем');
        }
        await txn.insert('entry_visibility', {
          'entry_id': entryId, 'kind': visibilityKind,
          'visible_at': visibleAt.toIso8601String(),
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      } else {
        await txn.delete('entry_visibility', where: 'entry_id = ?', whereArgs: [entryId]);
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
