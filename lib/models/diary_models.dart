class DiaryEntry {
  const DiaryEntry({
    required this.id,
    required this.title,
    required this.content,
    required this.mood,
    required this.createdAt,
  });

  final int id;
  final String title;
  final String content;
  final int mood;
  final DateTime createdAt;

  factory DiaryEntry.fromMap(Map<String, Object?> map) {
    return DiaryEntry(
      id: map['id'] as int,
      title: map['title'] as String,
      content: map['content'] as String,
      mood: (map['mood'] as int?) ?? 2,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}

class DiaryArc {
  const DiaryArc({
    required this.id,
    required this.name,
    required this.entryCount,
  });

  final int id;
  final String name;
  final int entryCount;

  factory DiaryArc.fromMap(Map<String, Object?> map) {
    return DiaryArc(
      id: map['id'] as int,
      name: map['name'] as String,
      entryCount: (map['entry_count'] as int?) ?? 0,
    );
  }
}


/// Одна самостоятельная отметка настроения (без дневниковой записи).
class MoodLog {
  const MoodLog({required this.id, required this.mood, required this.createdAt});

  final int id;
  final int mood; // 0..4: от грустного до радостного
  final DateTime createdAt;

  factory MoodLog.fromMap(Map<String, Object?> map) => MoodLog(
        id: map['id'] as int,
        mood: map['mood'] as int,
        createdAt: DateTime.parse(map['created_at'] as String),
      );
}

class DiaryMotif {
  const DiaryMotif({required this.id, required this.name});
  final int id;
  final String name;
  factory DiaryMotif.fromMap(Map<String, Object?> row) => DiaryMotif(
    id: row['id'] as int, name: row['name'] as String,
  );
}

class EntryContext {
  const EntryContext({this.place = '', this.timeOfDay = '', this.people = '',
      this.atmosphere = '', this.lifePeriod = ''});
  final String place;
  final String timeOfDay;
  final String people;
  final String atmosphere;
  final String lifePeriod;
  factory EntryContext.fromMap(Map<String, Object?> row) => EntryContext(
    place: (row['place'] as String?) ?? '',
    timeOfDay: (row['time_of_day'] as String?) ?? '',
    people: (row['people'] as String?) ?? '',
    atmosphere: (row['atmosphere'] as String?) ?? '',
    lifePeriod: (row['life_period'] as String?) ?? '',
  );
  Map<String, Object?> toMap(int entryId) => {
    'entry_id': entryId, 'place': place.trim(), 'time_of_day': timeOfDay.trim(),
    'people': people.trim(), 'atmosphere': atmosphere.trim(),
    'life_period': lifePeriod.trim(),
  };
}

class EntryFilters {
  const EntryFilters({this.text = '', this.arcId, this.motifId, this.mood,
      this.from, this.to, this.contextText = ''});
  final String text;
  final int? arcId;
  final int? motifId;
  final int? mood;
  final DateTime? from;
  final DateTime? to;
  final String contextText;
}

class EntryVisibility {
  const EntryVisibility({required this.entryId, required this.kind, required this.visibleAt});
  final int entryId;
  final String kind;
  final DateTime visibleAt;
  factory EntryVisibility.fromMap(Map<String, Object?> row) => EntryVisibility(
    entryId: row['entry_id'] as int, kind: row['kind'] as String,
    visibleAt: DateTime.parse(row['visible_at'] as String));
}

class EntryComment {
  const EntryComment({required this.id, required this.entryId,
      required this.content, required this.createdAt});
  final int id;
  final int entryId;
  final String content;
  final DateTime createdAt;
  factory EntryComment.fromMap(Map<String, Object?> row) => EntryComment(
    id: row['id'] as int, entryId: row['entry_id'] as int,
    content: row['content'] as String,
    createdAt: DateTime.parse(row['created_at'] as String));
}

class DelayedQuestion {
  const DelayedQuestion({required this.id, required this.question,
      required this.dueAt, this.answer});
  final int id;
  final String question;
  final DateTime dueAt;
  final String? answer;
  bool get due => !dueAt.isAfter(DateTime.now());
  bool get answered => answer != null;
  factory DelayedQuestion.fromMap(Map<String, Object?> row) => DelayedQuestion(
    id: row['id'] as int, question: row['question'] as String,
    dueAt: DateTime.parse(row['due_at'] as String), answer: row['answer'] as String?);
}
