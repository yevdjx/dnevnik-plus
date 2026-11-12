import 'package:flutter/material.dart';

import '../database/diary_database.dart';
import '../models/diary_models.dart';
import 'entry_editor.dart';

class EntryDetail extends StatefulWidget {
  const EntryDetail({super.key, required this.entry});

  final DiaryEntry entry;
  @override
  State<EntryDetail> createState() => _EntryDetailState();
}

class _EntryDetailState extends State<EntryDetail> {
  List<String> motifNames = [];
  EntryContext entryContext = const EntryContext();
  bool metadataLoading = true;

  @override
  void initState() {
    super.initState();
    loadMetadata();
  }

  Future<void> loadMetadata() async {
    try {
      final ids = await DiaryDatabase.instance.getEntryMotifIds(widget.entry.id);
      final motifs = await DiaryDatabase.instance.getMotifs();
      final ctx = await DiaryDatabase.instance.getEntryContext(widget.entry.id);
      if (!mounted) return;
      setState(() {
        motifNames = motifs.where((m) => ids.contains(m.id)).map((m) => m.name).toList();
        entryContext = ctx;
        metadataLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => metadataLoading = false);
    }
  }

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
      await DiaryDatabase.instance.deleteEntry(widget.entry.id);
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
      MaterialPageRoute(builder: (_) => EntryEditor(entry: widget.entry)),
    );
    if (changed == true && context.mounted) {
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mood = widget.entry.mood.clamp(0, 4).toInt();
    final date = widget.entry.createdAt;
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
          Text(widget.entry.title, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 10),
          Text('$dateText   ${moods[mood]}',
              style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 24),
          SelectableText(widget.entry.content, style: const TextStyle(fontSize: 17)),
          const SizedBox(height: 24),
          if (metadataLoading) const LinearProgressIndicator(),
          if (motifNames.isNotEmpty) ...[
            const Text('Мотивы', style: TextStyle(fontWeight: FontWeight.bold)),
            Wrap(spacing: 6, children: [
              for (final name in motifNames) Chip(label: Text(name)),
            ]),
          ],
          const SizedBox(height: 8),
          const Text('Контекст', style: TextStyle(fontWeight: FontWeight.bold)),
          if (entryContext.place.isNotEmpty) Text('Место: ${entryContext.place}'),
          if (entryContext.timeOfDay.isNotEmpty) Text('Время суток: ${entryContext.timeOfDay}'),
          if (entryContext.people.isNotEmpty) Text('Люди рядом: ${entryContext.people}'),
          if (entryContext.atmosphere.isNotEmpty) Text('Атмосфера: ${entryContext.atmosphere}'),
          if (entryContext.lifePeriod.isNotEmpty) Text('Период жизни: ${entryContext.lifePeriod}'),
        ],
      ),
    );
  }
}
