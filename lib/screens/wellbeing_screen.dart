import 'package:flutter/material.dart';

import '../database/diary_database.dart';
import '../models/diary_models.dart';

class WellbeingScreen extends StatefulWidget {
  const WellbeingScreen({super.key});
  @override
  State<WellbeingScreen> createState() => _WellbeingScreenState();
}

class _WellbeingScreenState extends State<WellbeingScreen> {
  List<WellbeingQuestion> questions = [];
  List<WellbeingSession> sessions = [];
  final Map<int, int> ratings = {};
  bool loading = true;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    refresh();
  }

  Future<void> refresh() async {
    try {
      final q = await DiaryDatabase.instance.getWellbeingQuestions();
      final s = await DiaryDatabase.instance.getWellbeingSessions();
      if (!mounted) return;
      setState(() {
        questions = q;
        sessions = s;
        ratings.removeWhere((id, _) => !q.any((e) => e.id == id && e.active));
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
    }
  }

  Future<void> addQuestion() async {
    final controller = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Свой вопрос'),
        content: TextField(controller: controller, autofocus: true,
          maxLength: 150, decoration: const InputDecoration(hintText: 'Например, легко ли было отдыхать?')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
          FilledButton(onPressed: () => Navigator.pop(ctx, controller.text), child: const Text('Добавить')),
        ],
      ),
    );
    if (!mounted || text == null || text.trim().isEmpty) return;
    try {
      await DiaryDatabase.instance.addWellbeingQuestion(text);
      await refresh();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
    }
  }

  Future<void> save() async {
    final active = questions.where((q) => q.active).toList();
    if (active.isEmpty || active.any((q) => !ratings.containsKey(q.id))) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ответь на все включённые вопросы')));
      return;
    }
    // Пользовательские вопросы могут повторять текст, поэтому для корректного
    // хранения результатов просим не использовать одинаковые формулировки.
    if (active.map((q) => q.text).toSet().length != active.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Есть одинаковые вопросы. Отключи один из них.')));
      return;
    }
    setState(() => saving = true);
    try {
      await DiaryDatabase.instance.saveWellbeingSession({
        for (final q in active) q.text: ratings[q.id]!,
      });
      ratings.clear();
      await refresh();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ответы сохранены только на устройстве 💜')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка сохранения: $e')));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final active = questions.where((q) => q.active).toList();
    final last = sessions.isEmpty ? null : sessions.first;
    final isRecent = last != null &&
        DateTime.now().difference(last.createdAt).inDays < 7;
    return Scaffold(
      appBar: AppBar(title: const Text('Самочувствие')),
      body: loading ? const Center(child: CircularProgressIndicator()) :
      ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 100), children: [
        const Text('Еженедельная проверка себя',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const Text('Оцени последнюю неделю от 0 (совсем нет) до 4 (очень). '
          'Это личный инструмент наблюдения, не диагноз и не медицинский тест.'),
        if (isRecent) const Padding(padding: EdgeInsets.only(top: 12),
          child: Text('Ты уже заполняла опросник за последние 7 дней. '
            'Можешь заполнить ещё раз по желанию.')),
        const SizedBox(height: 16),
        for (final q in active) Card(child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(q.text, style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(spacing: 5, children: [
              for (int i = 0; i <= 4; i++) ChoiceChip(
                label: Text('$i'), selected: ratings[q.id] == i,
                onSelected: (_) => setState(() => ratings[q.id] = i),
              ),
            ]),
          ]),
        )),
        if (active.isEmpty) const Padding(padding: EdgeInsets.all(16),
          child: Text('Включи хотя бы один вопрос ниже.')),
        const SizedBox(height: 12),
        FilledButton.icon(onPressed: saving || active.isEmpty ? null : save,
          icon: const Icon(Icons.save_outlined), label: const Text('Сохранить ответы')),
        const SizedBox(height: 24),
        const Text('Предыдущие результаты',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const Text('Индекс 0–100 — среднее твоих ответов, а не клиническая шкала.'),
        if (sessions.isEmpty) const Padding(padding: EdgeInsets.all(12),
          child: Text('Пока нет результатов')),
        for (final item in sessions) ListTile(
          leading: const Icon(Icons.insights_outlined),
          title: Text('${item.score} из 100'),
          subtitle: Text('${item.createdAt.day}.${item.createdAt.month}.${item.createdAt.year}'),
        ),
        const SizedBox(height: 20),
        Row(children: [
          const Expanded(child: Text('Настройка вопросов',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
          IconButton(tooltip: 'Добавить свой вопрос', onPressed: addQuestion,
            icon: const Icon(Icons.add_circle_outline)),
        ]),
        for (final q in questions) SwitchListTile(
          title: Text(q.text), value: q.active,
          onChanged: (v) async {
            await DiaryDatabase.instance.setWellbeingQuestionActive(q.id, v);
            await refresh();
          },
          secondary: IconButton(tooltip: 'Удалить вопрос', icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              await DiaryDatabase.instance.deleteWellbeingQuestion(q.id);
              await refresh();
            }),
        ),
      ]),
    );
  }
}
