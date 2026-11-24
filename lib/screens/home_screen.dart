import 'package:flutter/material.dart';

import '../database/diary_database.dart';
import '../models/diary_models.dart';
import '../security/security_settings_screen.dart';
import 'arc_detail.dart';
import 'entry_detail.dart';
import 'entry_editor.dart';
import 'mood_history.dart';
import 'questions_screen.dart';
import 'search_screen.dart';
import 'wellbeing_screen.dart';

const _ink = Color(0xFF302B27);
const _muted = Color(0xFF786E64);
const _accent = Color(0xFF9D783B);
const _cream = Color(0xFFF1E7DA);

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _moods = ['😢', '😕', '😐', '🙂', '😄'];
  int selectedTab = 0;
  bool loading = true;
  bool savingMood = false;
  List<DiaryEntry> entries = [];
  List<DiaryArc> arcs = [];
  List<DiaryMotif> motifs = [];
  List<MoodLog> moods = [];
  Map<String, List<DiaryEntry>> placeGroups = {};

  @override
  void initState() {
    super.initState();
    reload();
  }

  Future<void> reload() async {
    try {
      final database = DiaryDatabase.instance;
      final fetchedEntries = await database.getEntries();
      final fetchedArcs = await database.getArcs();
      final fetchedMotifs = await database.getMotifs();
      final fetchedMoods = await database.getMoodLogs();
      final groups = <String, List<DiaryEntry>>{};
      for (final entry in fetchedEntries) {
        final location = (await database.getEntryContext(entry.id)).place.trim();
        if (location.isNotEmpty) {
          groups.putIfAbsent(location, () => []).add(entry);
        }
      }
      if (!mounted) return;
      setState(() {
        entries = fetchedEntries;
        arcs = fetchedArcs;
        motifs = fetchedMotifs;
        moods = fetchedMoods;
        placeGroups = groups;
        loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось загрузить дневник: $error')),
      );
    }
  }

  Future<void> _open(Widget screen) async {
    await Navigator.push<Object?>(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
    if (mounted) await reload();
  }

  Future<void> _openEditor() async => _open(const EntryEditor());

  Future<void> _openEntry(DiaryEntry entry) async =>
      _open(EntryDetail(entry: entry));

  Future<void> _createArc() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Новая арка'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 60,
          decoration: const InputDecoration(hintText: 'Например, Дружба'),
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
    // Контроллер не освобождаем до завершения анимации закрытия диалога.
    if (name == null || name.trim().isEmpty || !mounted) return;
    try {
      await DiaryDatabase.instance.createArc(name.trim());
      await reload();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось создать арку: $error')),
      );
    }
  }

  Future<void> _createMotif() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Новый мотив'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 60,
          decoration: const InputDecoration(hintText: 'Например, Доверие'),
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
    if (name == null || name.trim().isEmpty || !mounted) return;
    try {
      await DiaryDatabase.instance.createMotif(name.trim());
      await reload();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось создать мотив: $error')),
      );
    }
  }

  Future<void> _openMotif(DiaryMotif motif) async {
    final selected = await DiaryDatabase.instance.searchEntries(
      EntryFilters(motifId: motif.id),
    );
    if (!mounted) return;
    await _open(_EntryCollectionScreen(
      title: 'Мотив «${motif.name}»',
      entries: selected,
    ));
  }

  Future<void> _saveMood(int mood) async {
    if (savingMood) return;
    setState(() => savingMood = true);
    try {
      await DiaryDatabase.instance.addMoodLog(mood);
      await reload();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Настроение сохранено')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка сохранения: $error')),
      );
    } finally {
      if (mounted) setState(() => savingMood = false);
    }
  }

  Widget _header(String title, {String? subtitle}) => Padding(
    padding: const EdgeInsets.only(top: 12, bottom: 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(
          fontSize: 25, fontWeight: FontWeight.w700, color: _ink,
        )),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(color: _muted)),
        ],
      ],
    ),
  );

  Widget _entryCard(DiaryEntry entry) {
    final date = entry.createdAt;
    final dateText = '${date.day.toString().padLeft(2, '0')}.'
        '${date.month.toString().padLeft(2, '0')}.${date.year}';
    return Card(
      child: InkWell(
        onTap: () => _openEntry(entry),
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(entry.title, style: const TextStyle(
                color: _ink, fontSize: 18, fontWeight: FontWeight.w600,
              )),
              const SizedBox(height: 4),
              Text('$dateText  ${_moods[entry.mood.clamp(0, 4).toInt()]}',
                style: const TextStyle(color: _muted, fontSize: 12)),
              const SizedBox(height: 12),
              Text(entry.content, maxLines: 5, overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: _ink, height: 1.4)),
              const SizedBox(height: 8),
              const Align(
                alignment: Alignment.centerRight,
                child: Icon(Icons.chevron_right, color: _accent),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _home() => ListView(
    padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
    children: [
      _header('Дневник+', subtitle: 'Создавай воспоминания'),
      SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: _openEditor,
          icon: const Icon(Icons.add_circle_outline, size: 26),
          label: const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Text('Новая запись', style: TextStyle(fontSize: 17)),
          ),
          style: FilledButton.styleFrom(backgroundColor: _accent),
        ),
      ),
      const SizedBox(height: 17),
      const Text('Последняя запись', style: TextStyle(
        fontSize: 18, fontWeight: FontWeight.w600, color: _ink,
      )),
      const SizedBox(height: 7),
      if (entries.isEmpty)
        const Card(child: Padding(
          padding: EdgeInsets.all(22),
          child: Text('Пока нет записей. Начни с первой!'),
        ))
      else
        _entryCard(entries.first),
      if (entries.length > 1) ...[
        const SizedBox(height: 16),
        const Text('Другие записи', style: TextStyle(
          fontSize: 18, fontWeight: FontWeight.w600, color: _ink,
        )),
        ...entries.skip(1).take(5).map(_entryCard),
        TextButton.icon(
          onPressed: () => _open(_EntryCollectionScreen(
            title: 'Все записи', entries: entries,
          )),
          icon: const Icon(Icons.menu_book_outlined),
          label: const Text('Посмотреть все записи'),
        ),
      ],
      const SizedBox(height: 15),
      const Text('Как ты себя чувствуешь?', style: TextStyle(
        fontSize: 17, fontWeight: FontWeight.w600, color: _ink,
      )),
      const SizedBox(height: 7),
      Card(child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            for (var i = 0; i < _moods.length; i++)
              IconButton(
                tooltip: 'Сохранить настроение ${_moods[i]}',
                onPressed: savingMood ? null : () => _saveMood(i),
                icon: Text(_moods[i], style: const TextStyle(fontSize: 25)),
              ),
          ],
        ),
      )),
      TextButton.icon(
        onPressed: () => _open(const MoodHistoryScreen()),
        icon: const Icon(Icons.bar_chart_outlined),
        label: Text('История настроения (${moods.length})'),
      ),
    ],
  );

  Widget _directory({
    required String title,
    required String hint,
    required List<Widget> children,
    required VoidCallback? onAdd,
  }) => ListView(
    padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
    children: [
      _header(title, subtitle: hint),
      if (onAdd != null)
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: Text('Создать ${title == 'Арки' ? 'арку' : 'мотив'}'),
          ),
        ),
      const SizedBox(height: 12),
      if (children.isEmpty)
        const Card(child: Padding(
          padding: EdgeInsets.all(22),
          child: Text('Здесь пока пусто.'),
        ))
      else
        ...children,
    ],
  );

  Widget _directoryItem({
    required String name,
    required String count,
    required IconData icon,
    required VoidCallback onTap,
  }) => Card(
    child: ListTile(
      leading: Icon(icon, color: _accent),
      title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(count, style: const TextStyle(color: _muted)),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    ),
  );

  Widget _arcs() => _directory(
    title: 'Арки',
    hint: 'Истории, которые продолжаются',
    onAdd: _createArc,
    children: [
      for (final arc in arcs)
        _directoryItem(
          name: arc.name,
          count: 'Записей: ${arc.entryCount}',
          icon: Icons.auto_stories_outlined,
          onTap: () => _open(ArcDetail(arc: arc)),
        ),
    ],
  );

  Widget _motifs() => _directory(
    title: 'Мотивы',
    hint: 'Повторяющиеся темы твоего дневника',
    onAdd: _createMotif,
    children: [
      for (final motif in motifs)
        _directoryItem(
          name: motif.name,
          count: 'Открыть связанные записи',
          icon: Icons.psychology_outlined,
          onTap: () => _openMotif(motif),
        ),
    ],
  );

  Widget _contexts() {
    final places = placeGroups.keys.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return _directory(
      title: 'Контексты',
      hint: 'Группы по месту, указанному в записи',
      onAdd: null,
      children: [
        for (final place in places)
          _directoryItem(
            name: place,
            count: 'Записей: ${placeGroups[place]!.length}',
            icon: Icons.place_outlined,
            onTap: () => _open(_EntryCollectionScreen(
              title: 'Контекст «$place»',
              entries: placeGroups[place]!,
            )),
          ),
        if (places.isEmpty)
          const Card(child: Padding(
            padding: EdgeInsets.all(16),
            child: Text('Добавь место в разделе «Контекст записи» при создании записи.'),
          )),
      ],
    );
  }

  Widget _settings() => ListView(
    padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
    children: [
      _header('Настройки', subtitle: 'Дневник и дополнительные функции'),
      _settingsTile(Icons.search, 'Поиск по записям',
        () => _open(const SearchScreen())),
      _settingsTile(Icons.bar_chart_outlined, 'Динамика настроения',
        () => _open(const MoodHistoryScreen())),
      _settingsTile(Icons.schedule_outlined, 'Отложенные вопросы',
        () => _open(const QuestionsScreen())),
      _settingsTile(Icons.favorite_outline, 'Самочувствие за неделю',
        () => _open(const WellbeingScreen())),
      _settingsTile(Icons.lock_outline, 'Безопасность и PIN',
        () => _open(const SecuritySettingsScreen())),
      const SizedBox(height: 16),
      const Padding(
        padding: EdgeInsets.all(12),
        child: Text(
          'Дневник+ · Интерфейс v0.9\n'
          'Личные записи хранятся на устройстве.',
          style: TextStyle(color: _muted),
        ),
      ),
    ],
  );

  Widget _settingsTile(IconData icon, String title, VoidCallback onTap) => Card(
    child: ListTile(
      leading: Icon(icon, color: _accent),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Дневник+', style: TextStyle(
          fontWeight: FontWeight.w700,
        )),
        actions: [
          IconButton(
            tooltip: 'Поиск',
            onPressed: () => _open(const SearchScreen()),
            icon: const Icon(Icons.search),
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : IndexedStack(index: selectedTab, children: [
              _home(), _arcs(), _motifs(), _contexts(), _settings(),
            ]),
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          height: 72,
          backgroundColor: _cream,
          indicatorColor: const Color(0xFFE3D0B6),
          labelTextStyle: WidgetStateProperty.all(
            const TextStyle(fontSize: 10, color: _ink),
          ),
        ),
        child: NavigationBar(
          selectedIndex: selectedTab,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          onDestinationSelected: (index) => setState(() => selectedTab = index),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: 'Главная',
            ),
            NavigationDestination(
              icon: Icon(Icons.auto_stories_outlined),
              selectedIcon: Icon(Icons.auto_stories),
              label: 'Арки',
            ),
            NavigationDestination(
              icon: Icon(Icons.psychology_outlined),
              selectedIcon: Icon(Icons.psychology),
              label: 'Мотивы',
            ),
            NavigationDestination(
              icon: Icon(Icons.layers_outlined),
              selectedIcon: Icon(Icons.layers),
              label: 'Контексты',
            ),
            NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings),
              label: 'Настройки',
            ),
          ],
        ),
      ),
    );
  }
}

class _EntryCollectionScreen extends StatefulWidget {
  const _EntryCollectionScreen({required this.title, required this.entries});
  final String title;
  final List<DiaryEntry> entries;

  @override
  State<_EntryCollectionScreen> createState() => _EntryCollectionScreenState();
}

class _EntryCollectionScreenState extends State<_EntryCollectionScreen> {
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.title)),
    body: widget.entries.isEmpty
        ? const Center(child: Text('Пока нет связанных записей'))
        : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: widget.entries.length,
            itemBuilder: (context, i) {
              final entry = widget.entries[i];
              return Card(child: ListTile(
                title: Text(entry.title),
                subtitle: Text(entry.content,
                    maxLines: 3, overflow: TextOverflow.ellipsis),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  final changed = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(builder: (_) => EntryDetail(entry: entry)),
                  );
                  // После изменения или удаления возвращаемся к обновляемому списку.
                  if (changed == true && context.mounted) {
                    Navigator.pop(context);
                  }
                },
              ));
            },
          ),
  );
}
