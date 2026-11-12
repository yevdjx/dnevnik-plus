import 'package:flutter/material.dart';

import '../database/diary_database.dart';
import '../models/diary_models.dart';
import 'entry_detail.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  static const emojis = ['😢', '😕', '😐', '🙂', '😄'];
  final queryController = TextEditingController();
  final contextController = TextEditingController();
  List<DiaryEntry> results = [];
  List<DiaryArc> arcs = [];
  List<DiaryMotif> motifs = [];
  int? arcId, motifId, mood;
  DateTime? from, to;
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    loadFilters();
  }

  Future<void> loadFilters() async {
    try {
      final a = await DiaryDatabase.instance.getArcs();
      final m = await DiaryDatabase.instance.getMotifs();
      if (!mounted) return;
      setState(() { arcs = a; motifs = m; });
      await search();
    } catch (e) {
      if (!mounted) return;
      setState(() { loading = false; error = '$e'; });
    }
  }

  Future<void> search() async {
    setState(() { loading = true; error = null; });
    try {
      final rows = await DiaryDatabase.instance.searchEntries(EntryFilters(
        text: queryController.text, contextText: contextController.text,
        arcId: arcId, motifId: motifId, mood: mood, from: from, to: to,
      ));
      if (!mounted) return;
      setState(() { results = rows; loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { loading = false; error = '$e'; });
    }
  }

  String format(DateTime? value) => value == null
      ? 'Любая дата' : '${value.day.toString().padLeft(2, '0')}.${value.month.toString().padLeft(2, '0')}.${value.year}';

  Future<void> pickDate({required bool start}) async {
    final current = start ? from : to;
    final picked = await showDatePicker(
      context: context, initialDate: current ?? DateTime.now(),
      firstDate: DateTime(2000), lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() { if (start) { from = picked; } else { to = picked; } });
    await search();
  }

  Future<void> reset() async {
    queryController.clear();
    contextController.clear();
    setState(() { arcId = null; motifId = null; mood = null; from = null; to = null; });
    await search();
  }

  Future<void> openEntry(DiaryEntry entry) async {
    await Navigator.push<bool>(context,
        MaterialPageRoute(builder: (_) => EntryDetail(entry: entry)));
    if (mounted) {
      await loadFilters();
    }
  }

  @override
  void dispose() {
    queryController.dispose();
    contextController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Поиск по дневнику')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(controller: queryController,
            decoration: const InputDecoration(labelText: 'Слова в заголовке или тексте',
                prefixIcon: Icon(Icons.search), border: OutlineInputBorder()),
            onSubmitted: (_) => search(),
          ),
          const SizedBox(height: 12),
          TextField(controller: contextController,
            decoration: const InputDecoration(labelText: 'Контекст: место, люди, атмосфера...',
                border: OutlineInputBorder()),
            onSubmitted: (_) => search(),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            value: arcId,
            decoration: const InputDecoration(labelText: 'Арка', border: OutlineInputBorder()),
            items: [const DropdownMenuItem<int>(value: null, child: Text('Любая арка')),
              for (final arc in arcs) DropdownMenuItem(value: arc.id, child: Text(arc.name))],
            onChanged: (value) { setState(() => arcId = value); search(); },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            value: motifId,
            decoration: const InputDecoration(labelText: 'Мотив', border: OutlineInputBorder()),
            items: [const DropdownMenuItem<int>(value: null, child: Text('Любой мотив')),
              for (final motif in motifs) DropdownMenuItem(value: motif.id, child: Text(motif.name))],
            onChanged: (value) { setState(() => motifId = value); search(); },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            value: mood,
            decoration: const InputDecoration(labelText: 'Настроение', border: OutlineInputBorder()),
            items: [const DropdownMenuItem<int>(value: null, child: Text('Любое настроение')),
              for (int i = 0; i < 5; i++) DropdownMenuItem(value: i, child: Text(emojis[i]))],
            onChanged: (value) { setState(() => mood = value); search(); },
          ),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: [
            OutlinedButton.icon(onPressed: () => pickDate(start: true),
                icon: const Icon(Icons.event), label: Text('От: ${format(from)}')),
            OutlinedButton.icon(onPressed: () => pickDate(start: false),
                icon: const Icon(Icons.event), label: Text('До: ${format(to)}')),
          ]),
          if (from != null && to != null && from!.isAfter(to!))
            const Text('Начальная дата позже конечной: результатов не будет.'),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: FilledButton.icon(onPressed: search,
                icon: const Icon(Icons.search), label: const Text('Найти'))),
            const SizedBox(width: 8),
            OutlinedButton(onPressed: reset, child: const Text('Сбросить')),
          ]),
          const SizedBox(height: 22),
          Text('Найдено записей: ${results.length}',
              style: Theme.of(context).textTheme.titleMedium),
          if (loading) const LinearProgressIndicator(),
          if (error != null) Text('Ошибка поиска: $error'),
          if (!loading && error == null && results.isEmpty)
            const Padding(padding: EdgeInsets.all(20),
                child: Text('По заданным условиям записей нет.')),
          for (final entry in results)
            Card(child: ListTile(
              leading: Text(emojis[entry.mood.clamp(0, 4).toInt()],
                  style: const TextStyle(fontSize: 25)),
              title: Text(entry.title),
              subtitle: Text(entry.content, maxLines: 2,
                  overflow: TextOverflow.ellipsis),
              onTap: () => openEntry(entry),
            )),
        ],
      ),
    );
  }
}
