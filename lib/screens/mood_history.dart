import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../database/diary_database.dart';
import '../models/diary_models.dart';

class MoodHistoryScreen extends StatefulWidget {
  const MoodHistoryScreen({super.key});

  @override
  State<MoodHistoryScreen> createState() => _MoodHistoryScreenState();
}

class _MoodHistoryScreenState extends State<MoodHistoryScreen> {
  static const emojis = ['😢', '😕', '😐', '🙂', '😄'];
  List<MoodLog> logs = [];
  bool loading = true;
  DateTime month = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime selectedDate = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);

  DateTime onlyDate(DateTime value) => DateTime(value.year, value.month, value.day);

  @override
  void initState() {
    super.initState();
    reload();
  }

  Future<void> reload() async {
    try {
      final result = await DiaryDatabase.instance.getMoodLogs();
      if (!mounted) return;
      setState(() {
        logs = result;
        loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка загрузки настроения: $error')),
      );
    }
  }

  List<MoodLog> forDay(DateTime day) => logs
      .where((log) => onlyDate(log.createdAt) == onlyDate(day))
      .toList();

  Future<void> removeLog(MoodLog log) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить отметку?'),
        content: const Text('Действие нельзя отменить.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Отмена')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Удалить')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await DiaryDatabase.instance.deleteMoodLog(log.id);
      await reload();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка удаления: $error')),
      );
    }
  }

  String dateLabel(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';

  Widget calendar() {
    final first = DateTime(month.year, month.month, 1);
    final days = DateTime(month.year, month.month + 1, 0).day;
    final offset = first.weekday - 1;
    final total = ((offset + days + 6) ~/ 7) * 7;
    const week = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(children: [
          Row(children: [
            IconButton(
              tooltip: 'Предыдущий месяц',
              onPressed: () => setState(() => month = DateTime(month.year, month.month - 1)),
              icon: const Icon(Icons.chevron_left),
            ),
            Expanded(child: Text('${month.month.toString().padLeft(2, '0')}.${month.year}',
                textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600))),
            IconButton(
              tooltip: 'Следующий месяц',
              onPressed: () => setState(() => month = DateTime(month.year, month.month + 1)),
              icon: const Icon(Icons.chevron_right),
            ),
          ]),
          Row(children: [for (final day in week) Expanded(child: Center(child: Text(day,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500))))]),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7, mainAxisSpacing: 3, crossAxisSpacing: 3, childAspectRatio: 0.9),
            itemCount: total,
            itemBuilder: (context, index) {
              final dayNumber = index - offset + 1;
              if (dayNumber < 1 || dayNumber > days) return const SizedBox.shrink();
              final date = DateTime(month.year, month.month, dayNumber);
              final daily = forDay(date);
              // Если в день несколько отметок, отображаем последнюю (logs отсортированы DESC).
              final current = daily.isEmpty ? null : daily.first;
              final isSelected = date == selectedDate;
              return InkWell(
                borderRadius: BorderRadius.circular(9),
                onTap: () => setState(() => selectedDate = date),
                child: Container(
                  decoration: BoxDecoration(
                    color: isSelected ? Theme.of(context).colorScheme.primaryContainer : null,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text('$dayNumber', style: const TextStyle(fontSize: 12)),
                    Text(current == null ? '·' : emojis[current.mood],
                        style: const TextStyle(fontSize: 14)),
                  ]),
                ),
              );
            },
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selected = forDay(selectedDate);
    // График: последние 30 быстрых отметок (слева старые, справа новые).
    final recent = logs.take(30).toList().reversed.toList();
    return Scaffold(
      appBar: AppBar(title: const Text('История настроения')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(padding: const EdgeInsets.all(16), children: [
              const Text('Отметки настроения без записи',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              const Text('Нажми на день, чтобы увидеть все отметки. В календаре показана последняя за день.'),
              const SizedBox(height: 12),
              calendar(),
              const SizedBox(height: 18),
              Text('Отметки за ${dateLabel(selectedDate)}',
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
              if (selected.isEmpty)
                const Padding(padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text('В этот день быстрых отметок нет.')),
              for (final log in selected)
                ListTile(
                  leading: Text(emojis[log.mood], style: const TextStyle(fontSize: 26)),
                  title: Text('${log.createdAt.hour.toString().padLeft(2, '0')}:${log.createdAt.minute.toString().padLeft(2, '0')}'),
                  trailing: IconButton(
                    tooltip: 'Удалить отметку', icon: const Icon(Icons.delete_outline),
                    onPressed: () => removeLog(log),
                  ),
                ),
              const SizedBox(height: 16),
              const Text('Последние 30 отметок',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              if (recent.isEmpty)
                const Text('Отметок пока нет. Выбери настроение на главном экране.')
              else
                Card(child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(children: [
                    SizedBox(height: 185, width: double.infinity,
                      child: CustomPaint(painter: MoodLinePainter(
                        recent.map((log) => log.mood).toList(),
                        Theme.of(context).colorScheme.primary,
                      ))),
                    const SizedBox(height: 8),
                    const Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [Text('Раньше'), Text('Позже')]),
                  ]),
                )),
              const SizedBox(height: 10),
              const Text('График отражает только быстрые отметки настроения, а не настроение из дневниковых записей.',
                  style: TextStyle(fontSize: 12)),
            ]),
    );
  }
}

class MoodLinePainter extends CustomPainter {
  const MoodLinePainter(this.values, this.lineColor);
  final List<int> values;
  final Color lineColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final linePaint = Paint()..color = lineColor..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round..style = PaintingStyle.stroke;
    final gridPaint = Paint()..color = lineColor.withValues(alpha: 0.16)..strokeWidth = 1;
    const padX = 12.0;
    const padY = 12.0;
    final plotW = math.max(1.0, size.width - 2 * padX);
    final plotH = math.max(1.0, size.height - 2 * padY);
    for (var i = 0; i < 5; i++) {
      final y = padY + plotH * i / 4;
      canvas.drawLine(Offset(padX, y), Offset(padX + plotW, y), gridPaint);
    }
    Offset point(int index) => Offset(
      padX + (values.length == 1 ? plotW / 2 : plotW * index / (values.length - 1)),
      padY + plotH * (4 - values[index]) / 4,
    );
    final path = Path()..moveTo(point(0).dx, point(0).dy);
    for (var i = 1; i < values.length; i++) {
      final p = point(i);
      path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(path, linePaint);
    for (var i = 0; i < values.length; i++) {
      canvas.drawCircle(point(i), 4, Paint()..color = lineColor);
    }
  }

  @override
  bool shouldRepaint(covariant MoodLinePainter oldDelegate) =>
      oldDelegate.lineColor != lineColor ||
      oldDelegate.values.length != values.length ||
      !_sameValues(oldDelegate.values, values);

  bool _sameValues(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
