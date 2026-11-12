import 'package:flutter_test/flutter_test.dart';
import 'package:dnevnik_plus/models/diary_models.dart';

void main() {
  test('Отложенный вопрос в будущем не доступен', () {
    final q = DelayedQuestion(id: 1, question: 'Почему?',
      dueAt: DateTime.now().add(const Duration(days: 2)));
    expect(q.due, isFalse);
    expect(q.answered, isFalse);
  });
  test('Ответ на старый вопрос сохранён в модели', () {
    final q = DelayedQuestion.fromMap({
      'id': 1, 'question': 'Что изменилось?',
      'due_at': '2020-01-01T00:00:00', 'answer': 'Многое',
    });
    expect(q.due, isTrue);
    expect(q.answered, isTrue);
  });
  test('Комментарии читаются из SQLite map', () {
    final c = EntryComment.fromMap({
      'id': 1, 'entry_id': 2, 'content': 'Теперь думаю иначе',
      'created_at': '2026-01-01T12:00:00',
    });
    expect(c.entryId, 2);
    expect(c.content, 'Теперь думаю иначе');
  });
}
