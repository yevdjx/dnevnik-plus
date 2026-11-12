import 'package:flutter_test/flutter_test.dart';
import 'package:dnevnik_plus/models/diary_models.dart';

void main() {
  test('DiaryEntry reads existing SQLite row', () {
    final entry = DiaryEntry.fromMap({
      'id': 7,
      'title': 'Тест',
      'content': 'Первая запись',
      'mood': 3,
      'created_at': '2026-11-12T15:00:00',
    });
    expect(entry.id, 7);
    expect(entry.title, 'Тест');
    expect(entry.mood, 3);
  });

  test('DiaryArc reads count from SQLite row', () {
    final arc = DiaryArc.fromMap({'id': 2, 'name': 'Учёба', 'entry_count': 4});
    expect(arc.name, 'Учёба');
    expect(arc.entryCount, 4);
  });

  test('MoodLog reads SQLite row', () {
  final log = MoodLog.fromMap({
    'id': 3,
    'mood': 4,
    'created_at': '2026-11-12T20:00:00',
  });
  expect(log.id, 3);
  expect(log.mood, 4);
  expect(log.createdAt.day, 12);
});
}
