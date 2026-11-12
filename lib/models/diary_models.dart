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
