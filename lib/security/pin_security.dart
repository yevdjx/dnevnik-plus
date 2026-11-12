import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// UI access control only. Does NOT encrypt the SQLite diary.db file.
class PinSecurity extends ChangeNotifier {
  PinSecurity._();
  static final PinSecurity instance = PinSecurity._();

  static const _storage = FlutterSecureStorage();
  static const _saltKey = 'pin_salt_v1';
  static const _hashKey = 'pin_hash_v1';
  static final _kdf = Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: 120000,
    bits: 256,
  );

  bool loading = true;
  bool enabled = false;
  bool locked = true;
  String? initializationError;
  int failedAttempts = 0;
  DateTime? retryAfter;

  static bool validPin(String value) =>
      RegExp(r'^\d{6,12}$').hasMatch(value);

  Future<void> initialize() async {
    try {
      final salt = await _storage.read(key: _saltKey);
      final hash = await _storage.read(key: _hashKey);
      // If either item is missing, don't silently bypass protection.
      if ((salt == null) != (hash == null)) {
        throw StateError('Данные PIN повреждены. Не удаляй приложение.');
      }
      enabled = hash != null;
      locked = enabled;
      initializationError = null;
    } catch (_) {
      initializationError = 'Не удаётся проверить PIN в защищённом хранилище. '
          'Не удаляй приложение и его данные.';
      enabled = true;
      locked = true;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<String> _digest(String pin, List<int> salt) async {
    final secret = await _kdf.deriveKeyFromPassword(password: pin, nonce: salt);
    return base64Encode(await secret.extractBytes());
  }

  Future<void> setPin(String pin) async {
    if (!validPin(pin)) {
      throw ArgumentError('PIN должен содержать 6–12 цифр');
    }
    if (enabled) throw StateError('PIN уже настроен');
    final salt = List<int>.generate(24, (_) => Random.secure().nextInt(256));
    final hash = await _digest(pin, salt);
    await _storage.write(key: _saltKey, value: base64Encode(salt));
    await _storage.write(key: _hashKey, value: hash);
    enabled = true;
    locked = false;
    notifyListeners();
  }

  static bool _constantTimeEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var difference = 0;
    for (var i = 0; i < a.length; i++) {
      difference |= a[i] ^ b[i];
    }
    return difference == 0;
  }

  /// Returns true only on successful verification; applies basic UI rate limit.
  Future<bool> verify(String pin) async {
    if (!enabled || initializationError != null) return false;
    if (retryAfter != null && DateTime.now().isBefore(retryAfter!)) return false;
    final saltText = await _storage.read(key: _saltKey);
    final hashText = await _storage.read(key: _hashKey);
    if (saltText == null || hashText == null) {
      initializationError = 'Проверка PIN недоступна. Не очищай данные приложения.';
      locked = true;
      notifyListeners();
      return false;
    }
    final actual = base64Decode(await _digest(pin, base64Decode(saltText)));
    final expected = base64Decode(hashText);
    final match = _constantTimeEquals(actual, expected);
    if (match) {
      failedAttempts = 0;
      retryAfter = null;
      locked = false;
    } else {
      failedAttempts++;
      if (failedAttempts >= 5) {
        retryAfter = DateTime.now().add(const Duration(seconds: 30));
        failedAttempts = 0;
      }
    }
    notifyListeners();
    return match;
  }

  Future<void> changePin(String oldPin, String newPin) async {
    if (!validPin(newPin)) throw ArgumentError('PIN должен содержать 6–12 цифр');
    // verify() also performs rate limiting.
    if (!await verify(oldPin)) throw StateError('Неверный старый PIN');
    final salt = List<int>.generate(24, (_) => Random.secure().nextInt(256));
    final hash = await _digest(newPin, salt);
    await _storage.write(key: _saltKey, value: base64Encode(salt));
    await _storage.write(key: _hashKey, value: hash);
    notifyListeners();
  }

  void lock() {
    if (enabled && !locked) {
      locked = true;
      notifyListeners();
    }
  }
}
