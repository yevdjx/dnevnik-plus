
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' show join;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const DiaryApp());
}

// База данных SQLite
class DiaryDatabase {
  static Database? _database;

  static Future<Database> get database async {
    if (_database != null) return _database!;

    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'diary.db');

    _database = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE entries (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT NOT NULL,
            content TEXT NOT NULL,
            mood INTEGER,
            created_at TEXT NOT NULL
          )
        ''');
      },
    );

    return _database!;
  }

  static Future<void> addEntry(
      String title,
      String content,
      int mood,
      ) async {
    final db = await database;

    await db.insert('entries', {
      'title': title,
      'content': content,
      'mood': mood,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  static Future<List<Map<String, dynamic>>> getEntries() async {
    final db = await database;

    return db.query(
      'entries',
      orderBy: 'created_at DESC, id DESC',
    );
  }

  static Future<void> deleteEntry(int id) async {
    final db = await database;

    await db.delete(
      'entries',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}

// Основное приложение
class DiaryApp extends StatelessWidget {
  const DiaryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Дневник+',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF9C83C9),
        ),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

// Главный экран
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Map<String, dynamic>> entries = [];
  bool isLoading = true;

  final moods = ['😢', '😕', '😐', '🙂', '😄'];

  @override
  void initState() {
    super.initState();
    loadEntries();
  }

  Future<void> loadEntries() async {
    final data = await DiaryDatabase.getEntries();

    if (!mounted) return;

    setState(() {
      entries = data;
      isLoading = false;
    });
  }

  Future<void> openEditor() async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => const EntryEditor(),
      ),
    );

    if (saved == true) {
      await loadEntries();
    }
  }

  Future<void> openEntry(Map<String, dynamic> entry) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(entry['title'] as String),
        content: SingleChildScrollView(
          child: Text(entry['content'] as String),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Закрыть'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );

    if (shouldDelete == true) {
      await DiaryDatabase.deleteEntry(entry['id'] as int);
      await loadEntries();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Дневник+'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Привет! 🌿',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Как ты себя чувствуешь сегодня?',
              style: TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 20),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                for (final mood in moods)
                  Text(
                    mood,
                    style: const TextStyle(fontSize: 32),
                  ),
              ],
            ),

            const SizedBox(height: 35),
            const Text(
              'Мои записи',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 15),

            Expanded(
              child: isLoading
                  ? const Center(
                child: CircularProgressIndicator(),
              )
                  : entries.isEmpty
                  ? const Center(
                child: Text(
                  'Пока здесь пусто.\n'
                      'Начни с первой записи 💜',
                  textAlign: TextAlign.center,
                ),
              )
                  : ListView.builder(
                itemCount: entries.length,
                itemBuilder: (context, index) {
                  final entry = entries[index];
                  final mood = entry['mood'] as int;

                  return Card(
                    child: ListTile(
                      leading: Text(
                        moods[mood],
                        style: const TextStyle(
                          fontSize: 28,
                        ),
                      ),
                      title: Text(
                        entry['title'] as String,
                      ),
                      subtitle: Text(
                        entry['content'] as String,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () => openEntry(entry),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: openEditor,
        icon: const Icon(Icons.edit),
        label: const Text('Новая запись'),
      ),
    );
  }
}

// Экран создания записи
class EntryEditor extends StatefulWidget {
  const EntryEditor({super.key});

  @override
  State<EntryEditor> createState() => _EntryEditorState();
}

class _EntryEditorState extends State<EntryEditor> {
  final titleController = TextEditingController();
  final contentController = TextEditingController();

  final moods = ['😢', '😕', '😐', '🙂', '😄'];

  int selectedMood = 2;
  bool isSaving = false;

  @override
  void dispose() {
    titleController.dispose();
    contentController.dispose();
    super.dispose();
  }

  Future<void> saveEntry() async {
    final title = titleController.text.trim();
    final content = contentController.text.trim();

    if (title.isEmpty || content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Заполни заголовок и текст записи'),
        ),
      );
      return;
    }

    setState(() => isSaving = true);

    try {
      await DiaryDatabase.addEntry(
        title,
        content,
        selectedMood,
      );

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;

      setState(() => isSaving = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка сохранения: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Новая запись'),
      ),
      body: Padding(
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
            const SizedBox(height: 20),

            const Text(
              'Какое у тебя настроение?',
              style: TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 12),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                for (int i = 0; i < moods.length; i++)
                  IconButton(
                    onPressed: () {
                      setState(() => selectedMood = i);
                    },
                    style: IconButton.styleFrom(
                      backgroundColor: selectedMood == i
                          ? const Color(0xFFE5D8FA)
                          : null,
                    ),
                    icon: Text(
                      moods[i],
                      style: const TextStyle(fontSize: 28),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 20),

            Expanded(
              child: TextField(
                controller: contentController,
                expands: true,
                maxLines: null,
                textAlignVertical: TextAlignVertical.top,
                decoration: const InputDecoration(
                  hintText: 'Что произошло сегодня? '
                      'О чём ты думаешь?',
                  border: OutlineInputBorder(),
                ),
              ),
            ),

            const SizedBox(height: 16),

            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: isSaving ? null : saveEntry,
                icon: const Icon(Icons.save),
                label: Text(
                  isSaving ? 'Сохранение...' : 'Сохранить запись',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
