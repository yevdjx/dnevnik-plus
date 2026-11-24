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
  String? visibilityKind;
  DateTime? visibleAt;

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
      final visibility = widget.entry == null ? null :
          await DiaryDatabase.instance.getVisibility(widget.entry!.id);
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
        visibilityKind = visibility?.kind;
        visibleAt = visibility?.visibleAt;
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
        visibilityKind: visibilityKind,
        visibleAt: visibleAt,
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
    const ink = Color(0xFF342D27);
    const gold = Color(0xFF9F7A3D);
    const paper = Color(0xFFF2E7D9);
    final selectedColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.entry == null ? 'Новая запись' : 'Изменить запись'),
        actions: [
          TextButton.icon(
            onPressed: isSaving || isLoading ? null : save,
            icon: const Icon(Icons.check),
            label: const Text('Готово'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.entry == null
                    ? 'Новая запись • ${DateTime.now().day.toString().padLeft(2, '0')}.${DateTime.now().month.toString().padLeft(2, '0')}.${DateTime.now().year}'
                    : 'Редактирование записи',
                style: const TextStyle(color: Color(0xFF807266), fontSize: 12),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: titleController,
                textCapitalization: TextCapitalization.sentences,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: ink),
                decoration: const InputDecoration(
                  hintText: 'Название записи',
                  filled: true,
                  fillColor: paper,
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: contentController,
                textCapitalization: TextCapitalization.sentences,
                keyboardType: TextInputType.multiline,
                minLines: 7,
                maxLines: 15,
                decoration: const InputDecoration(
                  hintText: 'Что произошло? О чём ты думаешь?',
                  alignLabelWithHint: true,
                  filled: true,
                  fillColor: paper,
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Настроение', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (int i = 0; i < moods.length; i++)
                    IconButton(
                      tooltip: 'Настроение ${i + 1} из 5',
                      onPressed: () => setState(() => selectedMood = i),
                      style: IconButton.styleFrom(
                        backgroundColor: selectedMood == i ? selectedColor.withValues(alpha: 0.14) : null,
                        side: selectedMood == i ? BorderSide(color: selectedColor, width: 1.5) : BorderSide.none,
                      ),
                      icon: Text(moods[i], style: const TextStyle(fontSize: 27)),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              if (isLoading) const LinearProgressIndicator(),
              Card(
                color: paper,
                elevation: 0,
                clipBehavior: Clip.antiAlias,
                child: ExpansionTile(
                  initiallyExpanded: widget.entry != null && selectedArcIds.isNotEmpty,
                  leading: const Icon(Icons.auto_stories_outlined, color: gold),
                  title: const Text('Арки'),
                  subtitle: const Text('Свяжи запись с историями'),
                  childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                  children: [
                    if (arcs.isEmpty)
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text('Арки ещё не созданы. Добавь их во вкладке «Арки».', style: TextStyle(fontSize: 13)),
                      )
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          for (final arc in arcs)
                            FilterChip(
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
                        ],
                      ),
                  ],
                ),
              ),
              Card(
                color: paper,
                elevation: 0,
                clipBehavior: Clip.antiAlias,
                child: ExpansionTile(
                  leading: const Icon(Icons.psychology_outlined, color: gold),
                  title: const Text('Мотивы'),
                  subtitle: const Text('Темы и повторяющиеся мысли'),
                  childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          for (final motif in motifs)
                            FilterChip(
                              label: Text(motif.name),
                              selected: selectedMotifIds.contains(motif.id),
                              onSelected: (selected) => setState(() {
                                if (selected) {
                                  selectedMotifIds.add(motif.id);
                                } else {
                                  selectedMotifIds.remove(motif.id);
                                }
                              }),
                            ),
                          ActionChip(
                            avatar: const Icon(Icons.add, size: 18),
                            label: const Text('Новый мотив'),
                            onPressed: addMotif,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Card(
                color: paper,
                elevation: 0,
                clipBehavior: Clip.antiAlias,
                child: ExpansionTile(
                  leading: const Icon(Icons.layers_outlined, color: gold),
                  title: const Text('Контекст'),
                  subtitle: const Text('Место, время, люди, атмосфера'),
                  childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                  children: [
                    contextField(placeController, 'Место'),
                    contextField(timeController, 'Время суток'),
                    contextField(peopleController, 'Люди рядом'),
                    contextField(atmosphereController, 'Атмосфера / погода'),
                    contextField(periodController, 'Период жизни'),
                  ],
                ),
              ),
              Card(
                color: paper,
                elevation: 0,
                clipBehavior: Clip.antiAlias,
                child: ExpansionTile(
                  initiallyExpanded: visibilityKind != null,
                  leading: const Icon(Icons.lock_clock_outlined, color: gold),
                  title: const Text('Доступ к записи'),
                  subtitle: const Text('Обычная, письмо в будущее или замороженная'),
                  childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                  children: [
                    DropdownButtonFormField<String>(
                      key: ValueKey(visibilityKind ?? 'normal'),
                      initialValue: visibilityKind ?? 'normal',
                      decoration: const InputDecoration(border: OutlineInputBorder()),
                      items: const [
                        DropdownMenuItem(value: 'normal', child: Text('Обычная запись')),
                        DropdownMenuItem(value: 'future', child: Text('Письмо в будущее')),
                        DropdownMenuItem(value: 'frozen', child: Text('Заморозить до даты')),
                      ],
                      onChanged: (value) => setState(() {
                        visibilityKind = value == 'normal' ? null : value;
                        if (visibilityKind == null) visibleAt = null;
                      }),
                    ),
                    if (visibilityKind != null) ...[
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.event),
                        label: Text(visibleAt == null
                            ? 'Выбрать дату открытия'
                            : 'Открыть ${visibleAt!.day}.${visibleAt!.month}.${visibleAt!.year}'),
                        onPressed: () async {
                          final now = DateTime.now();
                          final first = DateTime(now.year, now.month, now.day + 1);
                          final last = DateTime(now.year + 30);
                          final initial = visibleAt != null && !visibleAt!.isBefore(first) && !visibleAt!.isAfter(last)
                              ? visibleAt!
                              : first;
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: initial,
                            firstDate: first,
                            lastDate: last,
                          );
                          if (picked != null && mounted) {
                            setState(() => visibleAt = picked);
                          }
                        },
                      ),
                      const Text('Это скрытие в приложении, а не отдельное шифрование.',
                          style: TextStyle(fontSize: 12)),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: isSaving || isLoading ? null : save,
                icon: const Icon(Icons.save_outlined),
                label: Text(isSaving ? 'Сохраняем...' : 'Сохранить запись'),
                style: FilledButton.styleFrom(
                  backgroundColor: gold,
                  minimumSize: const Size.fromHeight(52),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
