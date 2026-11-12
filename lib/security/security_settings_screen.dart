import 'package:flutter/material.dart';

import 'pin_security.dart';

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
          'Сама база SQLite пока НЕ зашифрована. '
          'Не храни здесь настоящие личные записи до внедрения шифрования.'),
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
