import 'package:flutter/material.dart';

import '../database/diary_database.dart';
import '../models/diary_models.dart';

class EntryEditor extends StatefulWidget {
  const EntryEditor({super.key, this.entry});

  final DiaryEntry? entry;

  @override
  State<EntryEditor> createState() => _EntryEditorState();
}

class _EntryEditorState extends State<EntryEditor> {
  static const moods = ['😢', '😕', '😐', '🙂', '😄'];

  late final TextEditingController titleController;
  late final TextEditingController contentController;
  late int selectedMood;
  List<DiaryArc> arcs = [];
  List<DiaryMotif> motifs = [];
  Set<int> selectedMotifIds = {};
  final placeController = TextEditingController();
  final timeController = TextEditingController();
  final peopleController = TextEditingController();
  final atmosphereController = TextEditingController();
  final periodController = TextEditingController();
  Set<int> selectedArcIds = {};
  bool isLoading = true;
  bool isSaving = false;

  @override
  void initState() {
    super.initState();
    titleController = TextEditingController(text: widget.entry?.title ?? '');
    contentController = TextEditingController(text: widget.entry?.content ?? '');
    selectedMood = (widget.entry?.mood ?? 2).clamp(0, 4).toInt();
    loadArcs();
  }

  Future<void> loadArcs() async {
    try {
      final loadedArcs = await DiaryDatabase.instance.getArcs();
      final ids = widget.entry == null
          ? <int>{}
          : await DiaryDatabase.instance.getEntryArcIds(widget.entry!.id);
      final loadedMotifs = await DiaryDatabase.instance.getMotifs();
      final motifIds = widget.entry == null ? <int>{} :
          await DiaryDatabase.instance.getEntryMotifIds(widget.entry!.id);
      final contextData = widget.entry == null ? const EntryContext() :
          await DiaryDatabase.instance.getEntryContext(widget.entry!.id);
      if (!mounted) return;
      placeController.text = contextData.place;
      timeController.text = contextData.timeOfDay;
      peopleController.text = contextData.people;
      atmosphereController.text = contextData.atmosphere;
      periodController.text = contextData.lifePeriod;
      setState(() {
        motifs = loadedMotifs;
        selectedMotifIds = motifIds;
        arcs = loadedArcs;
        selectedArcIds = ids;
        isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось загрузить арки: $error')),
      );
    }
  }

  @override
  void dispose() {
    titleController.dispose();
    contentController.dispose();
    placeController.dispose();
    timeController.dispose();
    peopleController.dispose();
    atmosphereController.dispose();
    periodController.dispose();
    super.dispose();
  }

  Future<void> save() async {
    final title = titleController.text.trim();
    final content = contentController.text.trim();
    if (title.isEmpty || content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Заполни заголовок и текст записи')),
      );
      return;
    }
    setState(() => isSaving = true);
    try {
      await DiaryDatabase.instance.saveEntry(
        id: widget.entry?.id,
        title: title,
        content: content,
        mood: selectedMood,
        arcIds: selectedArcIds,
        motifIds: selectedMotifIds,
        entryContext: EntryContext(
          place: placeController.text, timeOfDay: timeController.text,
          people: peopleController.text, atmosphere: atmosphereController.text,
          lifePeriod: periodController.text,
        ),
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      setState(() => isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось сохранить запись: $error')),
      );
    }
  }

  Future<void> addMotif() async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Новый мотив'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 60,
          decoration: const InputDecoration(hintText: 'Например, Дружба'),
          onSubmitted: (value) => Navigator.pop(dialogContext, value),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Отмена')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, controller.text),
              child: const Text('Создать')),
        ],
      ),
    );
    if (!mounted || name == null || name.trim().isEmpty) return;
    try {
      final id = await DiaryDatabase.instance.createMotif(name);
      final loaded = await DiaryDatabase.instance.getMotifs();
      if (!mounted) return;
      setState(() { motifs = loaded; selectedMotifIds.add(id); });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось создать мотив: $error')),
      );
    }
  }

  Widget contextField(TextEditingController controller, String label) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: TextField(
      controller: controller,
      maxLength: 120,
      decoration: InputDecoration(labelText: label,
          border: const OutlineInputBorder(), counterText: ''),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.entry == null ? 'Новая запись' : 'Изменить запись')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: 'Заголовок',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Настроение', style: TextStyle(fontSize: 18)),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  for (int i = 0; i < moods.length; i++)
                    IconButton(
                      tooltip: 'Настроение ${i + 1} из 5',
                      onPressed: () => setState(() => selectedMood = i),
                      style: IconButton.styleFrom(
                        backgroundColor: selectedMood == i
                            ? const Color(0xFFE5D8FA)
                            : null,
                      ),
                      icon: Text(moods[i], style: const TextStyle(fontSize: 27)),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              const Text('Арки (можно выбрать несколько)',
                  style: TextStyle(fontSize: 17)),
              const SizedBox(height: 8),
              if (isLoading)
                const LinearProgressIndicator()
              else if (arcs.isEmpty)
                const Text('Арки ещё не созданы. Их можно добавить во вкладке «Арки».')
              else
                SizedBox(
                  height: 65,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final arc in arcs)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: FilterChip(
                              label: Text(arc.name),
                              selected: selectedArcIds.contains(arc.id),
                              onSelected: (selected) {
                                setState(() {
                                  if (selected) {
                                    selectedArcIds.add(arc.id);
                                  } else {
                                    selectedArcIds.remove(arc.id);
                                  }
                                });
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              const Text('Мотивы (можно выбрать несколько)',
                  style: TextStyle(fontSize: 17)),
              const SizedBox(height: 8),
              Wrap(spacing: 8, children: [
                for (final motif in motifs)
                  FilterChip(
                    label: Text(motif.name),
                    selected: selectedMotifIds.contains(motif.id),
                    onSelected: (selected) => setState(() {
                      if (selected) { selectedMotifIds.add(motif.id); }
                      else { selectedMotifIds.remove(motif.id); }
                    }),
                  ),
                ActionChip(
                  avatar: const Icon(Icons.add, size: 18),
                  label: const Text('Новый мотив'),
                  onPressed: addMotif,
                ),
              ]),
              const SizedBox(height: 16),
              const Text('Контекст записи', style: TextStyle(fontSize: 17)),
              const SizedBox(height: 10),
              contextField(placeController, 'Место'),
              contextField(timeController, 'Время суток'),
              contextField(peopleController, 'Люди рядом'),
              contextField(atmosphereController, 'Атмосфера / погода'),
              contextField(periodController, 'Период жизни'),
              const SizedBox(height: 10),
              const Text('Текст записи', style: TextStyle(fontSize: 17)),
              const SizedBox(height: 8),
              TextField(
                  controller: contentController,
                  minLines: 5,
                  maxLines: 12,
                  decoration: const InputDecoration(
                    hintText: 'Что произошло? О чём ты думаешь?',
                    border: OutlineInputBorder(),
                  ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: isSaving || isLoading ? null : save,
                  icon: const Icon(Icons.save),
                  label: Text(isSaving ? 'Сохраняем...' : 'Сохранить запись'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
