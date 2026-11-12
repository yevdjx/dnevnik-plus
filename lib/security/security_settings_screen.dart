import 'package:flutter/material.dart';

import 'pin_security.dart';
import '../database/diary_database.dart';
import 'encrypted_database.dart';

class SecuritySettingsScreen extends StatefulWidget {
  const SecuritySettingsScreen({super.key});

  @override
  State<SecuritySettingsScreen> createState() => _SecuritySettingsScreenState();
}

class _SecuritySettingsScreenState extends State<SecuritySettingsScreen> {
  final oldPin = TextEditingController();
  final newPin = TextEditingController();
  final confirm = TextEditingController();
  bool busy = false;
  String? error;
  bool migrating = false;
  bool? encrypted;

  @override
  void initState() {
    super.initState();
    _checkEncryption();
  }

  Future<void> _checkEncryption() async {
    try {
      final enabled = await EncryptedDatabase.instance.enabled;
      if (mounted) setState(() => encrypted = enabled);
    } catch (e) {
      if (mounted) setState(() => error = 'Ошибка проверки базы: $e');
    }
  }

  Future<void> _encrypt() async {
    if (migrating || encrypted != false) return;
    if (!PinSecurity.instance.enabled) {
      setState(() => error = 'Сначала установи PIN');
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Создать зашифрованную копию?'),
        content: const Text(
          'Перед продолжением сделай резервную копию базы вне эмулятора. '
          'Исходная НЕЗАШИФРОВАННАЯ diary.db останется на устройстве '
          'для восстановления. Новые записи после переноса пойдут в '
          'зашифрованную базу. Ключ хранится в Android Keystore через '
          'flutter_secure_storage. Потеря ключа означает потерю доступа '
          'к новой базе. Это тестовая миграция, не финальная защита.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Отмена')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Копия сделана')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() { migrating = true; error = null; });
    try {
      final report = await DiaryDatabase.instance.enableEncryption();
      if (!mounted) return;
      setState(() => encrypted = true);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Экспорт проверен: ${report.tableCount} таблиц, '
          '${report.totalRows} строк. Перезапусти приложение.'),
      ));
    } catch (e) {
      if (mounted) setState(() => error =
        'Шифрование не завершено: $e. Не удаляй старую базу.');
    } finally {
      if (mounted) setState(() => migrating = false);
    }
  }


  @override
  void dispose() {
    oldPin.dispose();
    newPin.dispose();
    confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (busy) return;
    if (!PinSecurity.validPin(newPin.text)) {
      setState(() => error = 'Нужны 6–12 цифр');
      return;
    }
    if (newPin.text != confirm.text) {
      setState(() => error = 'PIN не совпадают');
      return;
    }
    setState(() { busy = true; error = null; });
    try {
      final manager = PinSecurity.instance;
      if (manager.enabled) {
        await manager.changePin(oldPin.text, newPin.text);
      } else {
        await manager.setPin(newPin.text);
      }
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('PIN настроен 💜')));
    } catch (e) {
      if (mounted) setState(() => error = 'Не удалось изменить PIN: $e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final enabled = PinSecurity.instance.enabled;
    return Scaffold(
      appBar: AppBar(title: const Text('Безопасность')),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        Text(enabled ? 'Изменить PIN' : 'Установить PIN',
          style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        const Text('PIN ограничивает доступ через интерфейс приложения. '
          'Шифрование базы настраивается ниже. '
          'Не храни настоящие личные записи до полной проверки защиты.'),
        const SizedBox(height: 20),
        if (enabled) ...[
          TextField(controller: oldPin, obscureText: true,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Текущий PIN',
              border: OutlineInputBorder())),
          const SizedBox(height: 12),
        ],
        TextField(controller: newPin, obscureText: true,
          keyboardType: TextInputType.number, maxLength: 12,
          decoration: const InputDecoration(labelText: 'Новый PIN (6–12 цифр)',
            border: OutlineInputBorder())),
        const SizedBox(height: 12),
        TextField(controller: confirm, obscureText: true,
          keyboardType: TextInputType.number, maxLength: 12,
          decoration: const InputDecoration(labelText: 'Повтори новый PIN',
            border: OutlineInputBorder())),
        if (error != null) Text(error!,
          style: TextStyle(color: Theme.of(context).colorScheme.error)),
        const SizedBox(height: 12),
        FilledButton.icon(onPressed: busy ? null : _save,
          icon: const Icon(Icons.lock),
          label: Text(busy ? 'Сохранение...' : 'Сохранить PIN')),
        const Divider(height: 40),
        Text('Шифрование SQLite (экспериментально)',
          style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(encrypted == null ? 'Проверяем статус...' :
          encrypted! ? 'Зашифрованная база активна. ВНИМАНИЕ: старая '
              'незашифрованная diary.db пока осталась на устройстве.' :
              'Пока используется обычная SQLite без шифрования.'),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: migrating || encrypted != false || !enabled ? null : _encrypt,
          icon: const Icon(Icons.shield_outlined),
          label: Text(migrating ? 'Экспорт и проверка...' :
            encrypted == true ? 'SQLCipher активен' :
            'Создать зашифрованную копию'),
        ),
        const Text('Тестовая v0.8. Оригинал не удаляется автоматически. '
          'PIN блокирует интерфейс, но не является ключом SQLCipher.'),
        const SizedBox(height: 12),
        if (enabled) TextButton.icon(
          onPressed: () {
            PinSecurity.instance.lock();
            Navigator.of(context).pop();
          },
          icon: const Icon(Icons.lock_outline),
          label: const Text('Заблокировать сейчас')),
      ]),
    );
  }
}
