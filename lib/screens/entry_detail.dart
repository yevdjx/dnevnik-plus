import 'package:flutter/material.dart';

import '../database/diary_database.dart';
import '../models/diary_models.dart';
import 'entry_editor.dart';

class EntryDetail extends StatelessWidget {
  const EntryDetail({super.key, required this.entry});

  final DiaryEntry entry;
  static const moods = ['😢', '😕', '😐', '🙂', '😄'];

  Future<void> delete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Удалить запись?'),
        content: const Text('Это действие нельзя отменить.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await DiaryDatabase.instance.deleteEntry(entry.id);
      if (context.mounted) Navigator.pop(context, true);
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось удалить запись: $error')),
      );
    }
  }

  Future<void> edit(BuildContext context) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => EntryEditor(entry: entry)),
    );
    if (changed == true && context.mounted) {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mood = entry.mood.clamp(0, 4).toInt();
    final date = entry.createdAt;
    final dateText = '${date.day.toString().padLeft(2, '0')}.'
        '${date.month.toString().padLeft(2, '0')}.${date.year}';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Запись'),
        actions: [
          IconButton(
            tooltip: 'Редактировать',
            onPressed: () => edit(context),
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            tooltip: 'Удалить',
            onPressed: () => delete(context),
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(entry.title, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 10),
          Text('$dateText   ${moods[mood]}',
              style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 24),
          SelectableText(entry.content, style: const TextStyle(fontSize: 17)),
        ],
      ),
    );
  }
}
