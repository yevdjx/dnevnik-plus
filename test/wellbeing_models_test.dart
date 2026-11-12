import 'package:flutter_test/flutter_test.dart';
import 'package:dnevnik_plus/models/diary_models.dart';

void main() {
  test('Индекс самочувствия считается по шкале 0..100', () {
    expect(wellbeingScore([0, 0, 0]), 0);
    expect(wellbeingScore([4, 4, 4]), 100);
    expect(wellbeingScore([2, 2, 2, 2]), 50);
    expect(() => wellbeingScore([]), throwsArgumentError);
    expect(() => wellbeingScore([5]), throwsArgumentError);
  });
  test('Вопросы и результаты читаются из SQLite', () {
    final q = WellbeingQuestion.fromMap({'id': 7, 'text': 'Как дела?', 'active': 1});
    expect(q.active, isTrue);
    final s = WellbeingSession.fromMap({
      'id': 3, 'created_at': '2026-11-12T12:00:00', 'score': 75,
    });
    expect(s.score, 75);
  });
  test('Подсказки учитывают настроение и переключение', () {
    expect(reflectionPromptForMood(0, 0), isNotEmpty);
    expect(reflectionPromptForMood(4, 0), isNot(reflectionPromptForMood(0, 0)));
    expect(reflectionPromptForMood(2, 1), isNot(reflectionPromptForMood(2, 0)));
  });
}
