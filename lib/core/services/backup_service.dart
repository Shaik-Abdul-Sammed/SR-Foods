import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

import '../config/app_config.dart';
import '../database/app_database.dart';
import '../logger.dart';

class BackupResult {
  final bool success;
  final String message;
  final String? filePath;

  const BackupResult({
    required this.success,
    required this.message,
    this.filePath,
  });
}

/// Service managing AES-256 encrypted database export (.srbackup) and verified integrity restore.
class BackupService {
  BackupService._();
  static final BackupService instance = BackupService._();

  static const String _magicHeader = 'SRBK01'; // 6 bytes

  /// Checkpoints SQLite WAL mode and creates an AES-256 encrypted .srbackup file
  Future<BackupResult> createEncryptedBackup(AppDatabase db) async {
    try {
      // 1. Force WAL checkpoint to flush all uncommitted journal transactions to disk
      await db.customStatement('PRAGMA wal_checkpoint(TRUNCATE);');

      final dbFolder = await getApplicationDocumentsDirectory();
      final dbFile = File(p.join(dbFolder.path, 'sr_foods.db'));

      if (!await dbFile.exists()) {
        return const BackupResult(
          success: false,
          message: 'Database file sr_foods.db does not exist',
        );
      }

      final dbBytes = await dbFile.readAsBytes();

      // 2. Compute SHA-256 checksum of raw database
      final rawDigest = sha256.convert(dbBytes).bytes;

      // 3. Encrypt payload via AES-256
      final key = _deriveKey(AppConfig.encryptionKey);
      final iv = enc.IV.fromSecureRandom(16);
      final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
      final encrypted = encrypter.encryptBytes(dbBytes, iv: iv);

      // 4. Assemble container: [Header (6B)] + [IV (16B)] + [SHA-256 (32B)] + [Encrypted Data]
      final buffer = BytesBuilder();
      buffer.add(utf8.encode(_magicHeader));
      buffer.add(iv.bytes);
      buffer.add(rawDigest);
      buffer.add(encrypted.bytes);

      final backupsDir = Directory(p.join(dbFolder.path, 'backups'));
      if (!await backupsDir.exists()) {
        await backupsDir.create(recursive: true);
      }

      final fileName = 'sr_foods_${DateTime.now().millisecondsSinceEpoch}.srbackup';
      final backupFile = File(p.join(backupsDir.path, fileName));
      await backupFile.writeAsBytes(buffer.toBytes(), flush: true);

      // Log activity
      await db.logActivity(
        action: 'BACKUP_CREATED',
        entityType: 'database',
        details: 'Encrypted backup created: $fileName (${(backupFile.lengthSync() / 1024).toStringAsFixed(1)} KB)',
      );

      AppLogger.info('Backup created: ${backupFile.path}');
      return BackupResult(
        success: true,
        message: 'Backup created securely ($fileName)',
        filePath: backupFile.path,
      );
    } catch (e, st) {
      AppLogger.error('Failed to create backup', e, st);
      return BackupResult(
        success: false,
        message: 'Failed to create backup: $e',
      );
    }
  }

  /// Verifies file integrity, decrypts, and restores .srbackup into sr_foods.db
  Future<BackupResult> restoreEncryptedBackup(File backupFile, AppDatabase db) async {
    try {
      final bytes = await backupFile.readAsBytes();

      if (bytes.length < 54) {
        return const BackupResult(
          success: false,
          message: 'Corrupted backup file (file too short)',
        );
      }

      // 1. Verify Magic Header
      final header = utf8.decode(bytes.sublist(0, 6));
      if (header != _magicHeader) {
        return const BackupResult(
          success: false,
          message: 'Invalid backup format (Expected SRBK01 signature)',
        );
      }

      final ivBytes = bytes.sublist(6, 22);
      final expectedChecksum = bytes.sublist(22, 54);
      final encryptedPayload = bytes.sublist(54);

      // 2. Decrypt Payload
      final key = _deriveKey(AppConfig.encryptionKey);
      final iv = enc.IV(ivBytes);
      final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.cbc));
      final decryptedBytes = encrypter.decryptBytes(enc.Encrypted(encryptedPayload), iv: iv);

      // 3. Verify SHA-256 Checksum
      final actualChecksum = sha256.convert(decryptedBytes).bytes;
      if (!_compareBytes(expectedChecksum, actualChecksum)) {
        return const BackupResult(
          success: false,
          message: 'Integrity check failed: Checksum mismatch (file may be damaged or tampered)',
        );
      }

      // 4. Test SQLite database validity on a temporary file
      final tempDir = await getTemporaryDirectory();
      final tempFile = File(p.join(tempDir.path, 'verify_restore.db'));
      await tempFile.writeAsBytes(decryptedBytes, flush: true);

      final testDb = sqlite.sqlite3.open(tempFile.path);
      try {
        final result = testDb.select('PRAGMA integrity_check;');
        final status = result.isNotEmpty ? result.first.values.first.toString() : 'error';
        if (status.toLowerCase() != 'ok') {
          return BackupResult(
            success: false,
            message: 'Database validation failed: $status',
          );
        }
      } finally {
        testDb.close();
      }

      // 5. Replace active database file
      final dbFolder = await getApplicationDocumentsDirectory();
      final targetFile = File(p.join(dbFolder.path, 'sr_foods.db'));

      // Checkpoint and overwrite
      await tempFile.copy(targetFile.path);
      await tempFile.delete();

      // Clean WAL and SHM files to prevent stale journal reads
      final walFile = File('${targetFile.path}-wal');
      final shmFile = File('${targetFile.path}-shm');
      if (await walFile.exists()) await walFile.delete();
      if (await shmFile.exists()) await shmFile.delete();

      await db.logActivity(
        action: 'BACKUP_RESTORED',
        entityType: 'database',
        details: 'Restored from ${p.basename(backupFile.path)}',
      );

      return const BackupResult(
        success: true,
        message: 'Database successfully restored! Please restart the app for changes to take full effect.',
      );
    } catch (e, st) {
      AppLogger.error('Failed to restore backup', e, st);
      return BackupResult(
        success: false,
        message: 'Restore failed: $e',
      );
    }
  }

  static enc.Key _deriveKey(String secret) {
    final digest = sha256.convert(utf8.encode(secret)).bytes;
    return enc.Key(Uint8List.fromList(digest));
  }

  static bool _compareBytes(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    int diff = 0;
    for (int i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }
}
