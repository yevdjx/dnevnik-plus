import 'package:flutter/material.dart';

import '../database/diary_database.dart';
import '../models/diary_models.dart';
import 'arc_detail.dart';
import 'entry_detail.dart';
import 'entry_editor.dart';
import 'mood_history.dart';
import 'search_screen.dart';
import 'questions_screen.dart';
import 'wellbeing_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const moods = ['😢', '😕', '😐', '🙂', '😄'];

  int selectedTab = 0;
  List<DiaryEntry> entries = [];
  List<DiaryArc> arcs = [];
  bool loading = true;
  List<MoodLog> moodLogs = [];
  bool savingMood = false;
  bool reflectionPromptsEnabled = true;
  int promptIndex = 0;

  @override
  void initState() {
    super.initState();
    reload();
  }

  Future<void> reload() async {
    try {
      final loadedEntries = await DiaryDatabase.instance.getEntries();
      final loadedArcs = await DiaryDatabase.instance.getArcs();
      final loadedMoods = await DiaryDatabase.instance.getMoodLogs();
      final promptsOn = await DiaryDatabase.instance.promptsEnabled();
      if (!mounted) return;
      setState(() {
        entries = loadedEntries;
        arcs = loadedArcs;
        moodLogs = loadedMoods;
        reflectionPromptsEnabled = promptsOn;
        loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка загрузки данных: $error')),
      );
    }
  }

  Future<void> saveQuickMood(int mood) async {
    if (savingMood) return;
    setState(() => savingMood = true);
    try {
      await DiaryDatabase.instance.addMoodLog(mood);
      await reload();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Настроение сохранено 💜')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось сохранить настроение: $error')),
      );
    } finally {
      if (mounted) setState(() => savingMood = false);
    }
  }

  Future<void> openMoodHistory() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (_) => const MoodHistoryScreen()),
    );
    await reload();
  }

  Future<void> openEditor() async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const EntryEditor()),
    );
    if (saved == true) await reload();
  }

  Future<void> openEntry(DiaryEntry entry) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => EntryDetail(entry: entry)),
    );
    if (changed == true) await reload();
  }

  Future<void> openArc(DiaryArc arc) async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => ArcDetail(arc: arc)),
    );
    // Обновляем счётчики и ленту после редактирования/удаления внутри арки.
    await reload();
  }

  Future<void> createArc() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Новая арка'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 60,
          decoration: const InputDecoration(
            labelText: 'Название',
            hintText: 'Например, Дружба',
          ),
          onSubmitted: (value) => Navigator.pop(dialogContext, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text('Создать'),
          ),
        ],
      ),
    );
    // Освобождаем контроллер после завершения закрытия диалога.
    // Его жизненный цикл завершится с выходом из этого метода.
    final cleaned = name?.trim() ?? '';
    if (cleaned.isEmpty || !mounted) return;
    try {
      await DiaryDatabase.instance.createArc(cleaned);
      await reload();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось создать арку. Возможно, такое название уже есть.')),
      );
    }
  }

  Widget buildEntries() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
      children: [
        const Text('Привет! 🌿',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        const Text('Как ты себя чувствуешь сегодня?',
            style: TextStyle(fontSize: 18)),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            for (int i = 0; i < moods.length; i++)
              IconButton(
                tooltip: 'Сохранить настроение: ${moods[i]}',
                onPressed: savingMood ? null : () => saveQuickMood(i),
                icon: Text(moods[i], style: const TextStyle(fontSize: 30)),
              ),
          ],
        ),
        const SizedBox(height: 10),
        Card(
          child: ListTile(
            leading: const Icon(Icons.show_chart),
            title: const Text('История настроения'),
            subtitle: Text('Быстрых отметок: ${moodLogs.length}'),
            trailing: const Icon(Icons.chevron_right),
            onTap: openMoodHistory,
          ),
        ),
        const SizedBox(height: 12),
        Card(child: ListTile(
          leading: const Icon(Icons.schedule),
          title: const Text('Отложенные вопросы'),
          subtitle: const Text('Вопросы к себе на будущее'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () async {
            await Navigator.push<void>(context,
              MaterialPageRoute(builder: (_) => const QuestionsScreen()));
            if (mounted) await reload();
          },
        )),
        Card(child: ListTile(
          leading: const Icon(Icons.favorite_outline),
          title: const Text('Самочувствие за неделю'),
          subtitle: const Text('Опросник и история ответов'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () async {
            await Navigator.push<void>(context,
              MaterialPageRoute(builder: (_) => const WellbeingScreen()));
            if (mounted) await reload();
          },
        )),
        const SizedBox(height: 12),
        if (reflectionPromptsEnabled) Card(child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Вопрос для размышления',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(reflectionPromptForMood(moodLogs.isEmpty ? null : moodLogs.first.mood,
              promptIndex)),
            Row(children: [
              TextButton.icon(onPressed: () => setState(() => promptIndex++),
                icon: const Icon(Icons.skip_next), label: const Text('Другой вопрос')),
              const Spacer(),
              TextButton(onPressed: () async {
                await DiaryDatabase.instance.setPromptsEnabled(false);
                if (mounted) setState(() => reflectionPromptsEnabled = false);
              }, child: const Text('Отключить')),
            ]),
          ]),
        )) else Align(alignment: Alignment.centerLeft, child: TextButton.icon(
          onPressed: () async {
            await DiaryDatabase.instance.setPromptsEnabled(true);
            if (mounted) setState(() => reflectionPromptsEnabled = true);
          }, icon: const Icon(Icons.lightbulb_outline),
          label: const Text('Включить вопросы для размышления'),
        )),
        const SizedBox(height: 28),
        const Text('Мои записи',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        if (entries.isEmpty)
          const Padding(
            padding: EdgeInsets.all(30),
            child: Center(child: Text('Пока здесь пусто.\nНачни с первой записи 💜',
                textAlign: TextAlign.center)),
          )
        else
          for (final entry in entries)
            Card(
              child: ListTile(
                leading: Text(moods[entry.mood.clamp(0, 4).toInt()],
                    style: const TextStyle(fontSize: 27)),
                title: Text(entry.title),
                subtitle: Text(entry.content,
                    maxLines: 2, overflow: TextOverflow.ellipsis),
                onTap: () => openEntry(entry),
              ),
            ),
      ],
    );
  }

  Widget buildArcs() {
    if (arcs.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('Арки пока не созданы.\nНажми «Новая арка»!',
              textAlign: TextAlign.center),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 80),
      itemCount: arcs.length,
      itemBuilder: (context, index) {
        final arc = arcs[index];
        return Card(
          child: ListTile(
            leading: const Icon(Icons.auto_awesome_outlined),
            title: Text(arc.name),
            subtitle: Text('Записей: ${arc.entryCount}'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => openArc(arc),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Дневник+'), centerTitle: true,
        actions: [IconButton(
          tooltip: 'Поиск', icon: const Icon(Icons.search),
          onPressed: () async {
            await Navigator.push<void>(context,
                MaterialPageRoute(builder: (_) => const SearchScreen()));
            if (mounted) await reload();
          },
        )],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : selectedTab == 0
              ? buildEntries()
              : buildArcs(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedTab,
        onDestinationSelected: (index) => setState(() => selectedTab = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.view_agenda_outlined), label: 'Лента'),
          NavigationDestination(icon: Icon(Icons.hub_outlined), label: 'Арки'),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: selectedTab == 0 ? openEditor : createArc,
        icon: Icon(selectedTab == 0 ? Icons.edit_outlined : Icons.add),
        label: Text(selectedTab == 0 ? 'Новая запись' : 'Новая арка'),
      ),
    );
  }
}
