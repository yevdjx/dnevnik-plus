import 'package:flutter/material.dart';

import '../database/diary_database.dart';
import '../models/diary_models.dart';
import 'entry_detail.dart';

class ArcDetail extends StatefulWidget {
  const ArcDetail({super.key, required this.arc});

  final DiaryArc arc;

  @override
  State<ArcDetail> createState() => _ArcDetailState();
}

class _ArcDetailState extends State<ArcDetail> {
  List<DiaryEntry> entries = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    reload();
  }

  Future<void> reload() async {
    final data = await DiaryDatabase.instance.getEntries(arcId: widget.arc.id);
    if (!mounted) return;
    setState(() {
      entries = data;
      loading = false;
    });
  }

  Future<void> openEntry(DiaryEntry entry) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => EntryDetail(entry: entry)),
    );
    if (changed == true) await reload();
  }

  Future<void> deleteArc() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Удалить арку?'),
        content: const Text('Записи останутся в дневнике, удалится только арка и её связи.'),
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
    if (confirmed != true || !mounted) return;
    try {
      await DiaryDatabase.instance.deleteArc(widget.arc.id);
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось удалить арку: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.arc.name),
        actions: [
          IconButton(
            tooltip: 'Удалить арку',
            icon: const Icon(Icons.delete_outline),
            onPressed: deleteArc,
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : entries.isEmpty
              ? const Center(child: Text('В этой арке пока нет записей'))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: entries.length,
                  itemBuilder: (context, index) {
                    final entry = entries[index];
                    return Card(
                      child: ListTile(
                        title: Text(entry.title),
                        subtitle: Text(entry.content,
                            maxLines: 2, overflow: TextOverflow.ellipsis),
                        onTap: () => openEntry(entry),
                      ),
                    );
                  },
                ),
    );
  }
}
