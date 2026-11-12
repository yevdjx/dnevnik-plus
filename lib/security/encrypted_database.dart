import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' show join;
import 'package:sqflite_sqlcipher/sqflite.dart';

class DatabaseLocation {
  const DatabaseLocation(this.path, this.password, this.encrypted);
  final String path;
  final String? password;
  final bool encrypted;
}

class MigrationReport {
  const MigrationReport(this.tableCount, this.totalRows);
  final int tableCount;
  final int totalRows;
}

/// Android-first experimental migration from SQLite to SQLCipher.
/// The old diary.db is NEVER deleted by this code.
class EncryptedDatabase {
  EncryptedDatabase._();
  static final instance = EncryptedDatabase._();

  static const _storage = FlutterSecureStorage();
  static const _keyName = 'diary_sqlcipher_passphrase_v1';
  static const oldName = 'diary.db';
  static const newName = 'diary_secure.db';

  Future<DatabaseLocation> activeDatabase() async {
    final directory = await getDatabasesPath();
    final encryptedPath = join(directory, newName);
    if (await File(encryptedPath).exists()) {
      final passphrase = await _storage.read(key: _keyName);
      if (passphrase == null || passphrase.isEmpty) {
        throw StateError(
          'Ключ SQLCipher недоступен. Не удаляй приложение или базу!'
        );
      }
      return DatabaseLocation(encryptedPath, passphrase, true);
    }
    return DatabaseLocation(join(directory, oldName), null, false);
  }

  Future<bool> get enabled async => (await activeDatabase()).encrypted;

  static String _newPassphrase() {
    final random = Random.secure();
    return base64UrlEncode(List<int>.generate(32, (_) => random.nextInt(256)));
  }

  static Future<Map<String, int>> _counts(Database db) async {
    final result = <String, int>{};
    final rows = await db.rawQuery('''
      SELECT name FROM sqlite_master
      WHERE type = 'table' AND name NOT LIKE 'sqlite_%'
      ORDER BY name
    ''');
    for (final row in rows) {
      final table = row['name'] as String;
      // Table names originate from SQLite schema, not user input.
      final escaped = table.replaceAll('"', '""');
      final count = await db.rawQuery('SELECT COUNT(*) AS n FROM "$escaped"');
      result[table] = (count.first['n'] as num).toInt();
    }
    return result;
  }

  static Future<void> _checkIntegrity(Database db) async {
    final rows = await db.rawQuery('PRAGMA integrity_check');
    if (rows.length != 1 || rows.first.values.single != 'ok') {
      throw StateError('Проверка целостности SQLite не прошла');
    }
  }

  /// Export into a NEW database; verify all table row counts and SQL integrity.
  /// On failure, leave the old database untouched and do not switch over.
  Future<MigrationReport> migrate() async {
    if (!Platform.isAndroid) {
      throw UnsupportedError('Миграция v0.8 проверяется только на Android');
    }
    final directory = await getDatabasesPath();
    final plainPath = join(directory, oldName);
    final securePath = join(directory, newName);
    final stagingPath = join(directory, 'diary_secure_pending.db');

    if (await File(securePath).exists()) {
      throw StateError('Зашифрованная база уже существует');
    }
    if (!await File(plainPath).exists()) {
      throw StateError('Исходная база diary.db не найдена');
    }
    // Never overwrite an unexplained incomplete previous migration.
    if (await File(stagingPath).exists()) {
      throw StateError('Найдена незавершённая миграция. Нужна ручная проверка');
    }

    var passphrase = await _storage.read(key: _keyName);
    if (passphrase == null || passphrase.isEmpty) {
      passphrase = _newPassphrase();
      // Save the key BEFORE creating the encrypted file.
      await _storage.write(key: _keyName, value: passphrase);
    }

    Database? source;
    Database? target;
    var attached = false;
    try {
      source = await openDatabase(plainPath, singleInstance: false);
      await _checkIntegrity(source);
      // Must checkpoint legacy WAL before exporting a consistent snapshot.
      await source.rawQuery('PRAGMA wal_checkpoint(FULL)');
      final before = await _counts(source);
      final version = await source.getVersion();

      // Paths and passphrases cannot contain quotes (base64url and app-private path
      // is escaped defensively). SQLCipher ATTACH does not allow bind parameters
      // for the KEY expression through this plugin API.
      final sqlPath = stagingPath.replaceAll("'", "''");
      final sqlKey = passphrase.replaceAll("'", "''");
      await source.execute(
        "ATTACH DATABASE '$sqlPath' AS encrypted KEY '$sqlKey'"
      );
      attached = true;
      await source.rawQuery("SELECT sqlcipher_export('encrypted')");
      // sqlcipher_export does not copy SQLite user_version.
      await source.execute('PRAGMA encrypted.user_version = $version');
      await source.execute('DETACH DATABASE encrypted');
      attached = false;
      await source.close();
      source = null;

      target = await openDatabase(
        stagingPath, password: passphrase, singleInstance: false,
      );
      await _checkIntegrity(target);
      final after = await _counts(target);
      if (!_sameCounts(before, after) ||
          await target.getVersion() != version) {
        throw StateError('Количество записей или версия схемы не совпадает');
      }

      await target.rawQuery('PRAGMA wal_checkpoint(FULL)');
      await target.rawQuery('PRAGMA journal_mode = DELETE');
      await target.close();

      target = null;

      final file = File(stagingPath);
      final header = await file.openRead(0, 16).fold<List<int>>(
        <int>[], (all, bytes) => all..addAll(bytes),
      );
      if (ascii.decode(header, allowInvalid: true).startsWith('SQLite format 3')) {
        throw StateError('Файл остался незашифрованным');
      }
      await file.rename(securePath);
      // Old plaintext diary.db is deliberately retained for recovery.
      return MigrationReport(after.length, after.values.fold(0, (a, b) => a + b));
    } finally {
      if (attached && source != null) {
        try { await source.execute('DETACH DATABASE encrypted'); } catch (_) {}
      }
      if (target != null) await target.close();
      if (source != null) await source.close();
    }
  }

  static bool _sameCounts(Map<String, int> a, Map<String, int> b) {
    if (a.length != b.length) return false;
    for (final name in a.keys) {
      if (a[name] != b[name]) return false;
    }
    return true;
  }
}
