import 'dart:typed_data';
import 'dart:async';
import 'package:record/record.dart';
import '../services/wav_encoder.dart';
import '../widgets/media_viewer.dart';

import 'package:image_picker/image_picker.dart';
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
  final List<Uint8List> pendingImages = [];
  final Set<int> removedImageIds = {};
  List<DiaryImage> savedImages = [];
  bool pickingImage = false;
  bool pickingMedia = false;
  bool isRecording = false;
  final AudioRecorder _recorder = AudioRecorder();
  StreamSubscription<Uint8List>? _pcmSubscription;
  final BytesBuilder _pcmBuffer = BytesBuilder(copy: false);
  bool _recordTooLarge = false;
  final List<NewDiaryMedia> pendingMedia = [];
  final Set<int> removedMediaIds = {};
  List<DiaryMedia> savedMedia = [];


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
      final existingMedia = widget.entry == null
          ? <DiaryMedia>[]
          : await DiaryDatabase.instance.getEntryMedia(widget.entry!.id);
      final existingImages = widget.entry == null
          ? <DiaryImage>[]
          : await DiaryDatabase.instance.getEntryImages(widget.entry!.id);
      if (!mounted) return;
      placeController.text = contextData.place;
      timeController.text = contextData.timeOfDay;
      peopleController.text = contextData.people;
      atmosphereController.text = contextData.atmosphere;
      periodController.text = contextData.lifePeriod;
      setState(() {
        savedImages = existingImages;
        savedMedia = existingMedia;
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
    _pcmSubscription?.cancel();
    if (isRecording) { _recorder.stop(); }
    _recorder.dispose();
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
    if (isRecording) { _message("Останови запись голоса перед сохранением"); return; }
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
        newImages: pendingImages,
        removedImageIds: removedImageIds,
        newMedia: pendingMedia,
        removedMediaIds: removedMediaIds,
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

  Future<void> pickImage() async {
    if (pickingImage || isSaving) return;
    if (savedImages.length - removedImageIds.length + pendingImages.length >= 5) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Максимум 5 фотографий на запись'),
      ));
      return;
    }
    setState(() => pickingImage = true);
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        imageQuality: 80,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      if (bytes.lengthInBytes > 5 * 1024 * 1024) {
        throw StateError('Фото слишком большое (максимум 5 МБ)');
      }
      if (!mounted) return;
      setState(() => pendingImages.add(bytes));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не получилось выбрать фото: $error')),
      );
    } finally {
      if (mounted) setState(() => pickingImage = false);
    }
  }

  Future<void> selectPhotoOrCamera(ImageSource source) async {
    if (pickingImage || isSaving) return;
    if (savedImages.length - removedImageIds.length + pendingImages.length >= 5) {
      _message('Максимум пять фотографий'); return;
    }
    setState(() => pickingImage = true);
    try {
      final selected = await ImagePicker().pickImage(
          source: source, maxWidth: 1600, imageQuality: 80);
      if (selected == null) return;
      final bytes = await selected.readAsBytes();
      if (bytes.lengthInBytes > 5 * 1024 * 1024) throw StateError('Фото больше 5 МБ');
      if (mounted) setState(() => pendingImages.add(bytes));
    } catch (error) { _message('Ошибка фотографии: $error'); }
    finally { if (mounted) setState(() => pickingImage = false); }
  }

  void _message(String message) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)));
  }

  Future<void> selectVideo(ImageSource source) async {
    if (pickingMedia || isSaving || isRecording) return;
    if (savedMedia.length - removedMediaIds.length + pendingMedia.length >= 5) {
      _message('Максимум пять аудио и видео'); return;
    }
    setState(() => pickingMedia = true);
    try {
      final selected = await ImagePicker().pickVideo(
        source: source, maxDuration: const Duration(seconds: 30));
      if (selected == null) return;
      // maxDuration affects camera recording, not pre-existing gallery videos.
      final bytes = await selected.readAsBytes();
      if (bytes.isEmpty || bytes.lengthInBytes > 20 * 1024 * 1024) {
        throw StateError('Выбери видео размером до 20 МБ');
      }
      if (mounted) setState(() => pendingMedia.add(NewDiaryMedia(
        kind: 'video', bytes: bytes, mime: 'video/mp4')));
    } catch (error) { _message('Ошибка видео: $error'); }
    finally { if (mounted) setState(() => pickingMedia = false); }
  }

  Future<void> startRecording() async {
    if (isSaving || isRecording || pickingMedia) return;
    if (savedMedia.length - removedMediaIds.length + pendingMedia.length >= 5) {
      _message('Максимум пять аудио и видео'); return;
    }
    try {
      if (!await _recorder.hasPermission()) { _message('Нет доступа к микрофону'); return; }
      _pcmBuffer.clear();
      _recordTooLarge = false;
      final stream = await _recorder.startStream(const RecordConfig(
        encoder: AudioEncoder.pcm16bits, sampleRate: 16000, numChannels: 1));
      _pcmSubscription = stream.listen((chunk) {
        if (_pcmBuffer.length + chunk.length > 5 * 1024 * 1024 - 44) {
          _recordTooLarge = true;
          stopRecording();
        } else { _pcmBuffer.add(chunk); }
      }, onError: (Object error) => _message('Ошибка микрофона: $error'));
      if (mounted) setState(() => isRecording = true);
    } catch (error) { _message('Не удалось начать запись: $error'); }
  }

  Future<void> stopRecording() async {
    if (!isRecording) return;
    setState(() => isRecording = false);
    try {
      await _recorder.stop();
      await _pcmSubscription?.cancel();
      _pcmSubscription = null;
      final pcm = _pcmBuffer.takeBytes();
      if (_recordTooLarge) { _message('Аудиозапись ограничена 5 МБ'); }
      if (pcm.isEmpty) { _message('Пустая запись'); return; }
      final wav = pcmToWav(pcm);
      if (mounted) setState(() => pendingMedia.add(NewDiaryMedia(
        kind: 'audio', bytes: wav, mime: 'audio/wav')));
    } catch (error) { _message('Ошибка сохранения голоса: $error'); }
  }

  Widget mediaPreview(String kind, Uint8List bytes, VoidCallback remove) =>
    Card(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(children: [
          Row(children: [
            Icon(kind == 'audio' ? Icons.mic : Icons.videocam_outlined),
            const SizedBox(width: 8),
            Expanded(child: Text(kind == 'audio' ? 'Голосовое сообщение' : 'Видеозапись')),
            IconButton(onPressed: remove, icon: const Icon(Icons.close),
                tooltip: 'Удалить вложение'),
          ]),
          if (kind == 'audio') JournalAudioPlayer(bytes: bytes)
          else JournalVideoPlayer(bytes: bytes),
        ]),
      ),
    );

  Widget imagePreview(Uint8List bytes, VoidCallback remove) => Stack(
    children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.memory(bytes, width: 96, height: 96, fit: BoxFit.cover),
      ),
      Positioned(
        right: 0,
        top: 0,
        child: IconButton.filledTonal(
          tooltip: 'Убрать фотографию',
          icon: const Icon(Icons.close, size: 17),
          onPressed: remove,
        ),
      ),
    ],
  );

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
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: isLoading || isSaving || pickingImage ? null : pickImage,
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: Text(pickingImage ? 'Открываем галерею...' : 'Фото из галереи'),
              ),
              Wrap(spacing: 8, runSpacing: 8, children: [
                OutlinedButton.icon(
                  onPressed: pickingImage || isSaving ? null : () => selectPhotoOrCamera(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt_outlined), label: const Text('Снять фото')),
                OutlinedButton.icon(
                  onPressed: pickingMedia || isSaving || isRecording ? null : () => selectVideo(ImageSource.gallery),
                  icon: const Icon(Icons.video_library_outlined), label: const Text('Добавить видео')),
                OutlinedButton.icon(
                  onPressed: pickingMedia || isSaving || isRecording ? null : () => selectVideo(ImageSource.camera),
                  icon: const Icon(Icons.videocam_outlined), label: const Text('Снять видео')),
                OutlinedButton.icon(
                  onPressed: isSaving ? null : (isRecording ? stopRecording : startRecording),
                  icon: Icon(isRecording ? Icons.stop_circle : Icons.mic_none),
                  label: Text(isRecording ? 'Стоп (запись голоса)' : 'Записать голос')),
              ]),
              if (isRecording) const Text('● Идёт запись голоса. Нажми «Стоп» перед сохранением.'),
              if (pendingMedia.isNotEmpty || savedMedia.isNotEmpty) ...[
                const SizedBox(height: 8),
                for (final media in savedMedia)
                  if (!removedMediaIds.contains(media.id))
                    mediaPreview(media.kind, media.bytes,
                      () => setState(() => removedMediaIds.add(media.id))),
                for (var i = 0; i < pendingMedia.length; i++)
                  mediaPreview(pendingMedia[i].kind, pendingMedia[i].bytes,
                    () => setState(() => pendingMedia.removeAt(i))),
              ],
              if (pendingImages.isNotEmpty || savedImages.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final image in savedImages)
                      if (!removedImageIds.contains(image.id))
                        imagePreview(image.bytes, () => setState(
                          () => removedImageIds.add(image.id))),
                    for (var i = 0; i < pendingImages.length; i++)
                      imagePreview(pendingImages[i], () => setState(
                        () => pendingImages.removeAt(i))),
                  ],
                ),
              ],
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
