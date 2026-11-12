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
