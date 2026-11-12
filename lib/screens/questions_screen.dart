import 'package:flutter/material.dart';
import '../database/diary_database.dart';
import '../models/diary_models.dart';

class QuestionsScreen extends StatefulWidget {
  const QuestionsScreen({super.key});
  @override
  State<QuestionsScreen> createState() => _QuestionsScreenState();
}

class _QuestionsScreenState extends State<QuestionsScreen> {
  List<DelayedQuestion> questions = [];
  bool loading = true;
  @override
  void initState() { super.initState(); reload(); }

  Future<void> reload() async {
    final result = await DiaryDatabase.instance.getQuestions();
    if (mounted) setState(() { questions = result; loading = false; });
  }

  Future<void> editQuestion([DelayedQuestion? existing]) async {
    final controller = TextEditingController(text: existing?.question ?? '');
    DateTime selected = existing?.dueAt ?? DateTime.now().add(const Duration(days: 1));
    final result = await showDialog<(String, DateTime)>(context: context,
      builder: (dialogContext) => StatefulBuilder(builder: (context, update) => AlertDialog(
        title: Text(existing == null ? 'Отложенный вопрос' : 'Изменить вопрос'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: controller, maxLines: 3,
              decoration: const InputDecoration(labelText: 'Вопрос себе')),
          OutlinedButton.icon(icon: const Icon(Icons.event),
            label: Text('Показать ${selected.day}.${selected.month}.${selected.year}'),
            onPressed: () async {
              final d = await showDatePicker(context: context,
                initialDate: selected, firstDate: DateTime(2020),
                lastDate: DateTime(2100));
              if (d != null) update(() => selected = d);
            }),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Отмена')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, (controller.text, selected)),
              child: const Text('Сохранить')),
        ],
      )));
    if (result == null || !mounted) return;
    try {
      await DiaryDatabase.instance.saveQuestion(id: existing?.id,
          question: result.$1, dueAt: result.$2);
      await reload();
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Не удалось сохранить: $error')));
    }
  }

  Future<void> answer(DelayedQuestion q) async {
    final controller = TextEditingController();
    final value = await showDialog<String>(context: context, builder: (ctx) => AlertDialog(
      title: Text(q.question),
      content: TextField(controller: controller, maxLines: 5,
          decoration: const InputDecoration(labelText: 'Твой ответ')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
        FilledButton(onPressed: () => Navigator.pop(ctx, controller.text), child: const Text('Ответить')),
      ],
    ));
    if (value == null || value.trim().isEmpty) return;
    await DiaryDatabase.instance.answerQuestion(q.id, value);
    await reload();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Отложенные вопросы')),
    body: loading ? const Center(child: CircularProgressIndicator()) :
      ListView(padding: const EdgeInsets.all(16), children: [
        const Text('Вопросы сохраняются на устройстве. Они становятся доступны для ответа после выбранной даты.'),
        const SizedBox(height: 12),
        for (final q in questions)
          Card(child: ListTile(
            leading: Icon(q.answered ? Icons.check_circle_outline :
                q.due ? Icons.help_outline : Icons.lock_clock),
            title: Text(q.due ? q.question : 'Вопрос откроется позже'),
            subtitle: Text(q.answered ? 'Ответ: ${q.answer}' :
                q.due ? 'Можно ответить сейчас' :
                'Дата открытия: ${q.dueAt.day}.${q.dueAt.month}.${q.dueAt.year}'),
            onTap: q.due && !q.answered ? () => answer(q) : null,
            trailing: PopupMenuButton<String>(
              onSelected: (choice) async {
                if (choice == 'edit') { await editQuestion(q); }
                if (choice == 'delete') {
                  await DiaryDatabase.instance.deleteQuestion(q.id);
                  await reload();
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('Изменить')),
                PopupMenuItem(value: 'delete', child: Text('Удалить')),
              ],
            ),
          )),
      ]),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: () => editQuestion(), icon: const Icon(Icons.add),
      label: const Text('Новый вопрос')),
  );
}
