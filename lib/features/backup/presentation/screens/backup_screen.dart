// ignore_for_file: deprecated_member_use
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/database_provider.dart';
import '../../../../core/services/backup_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

final activityLogsProvider = FutureProvider.autoDispose<List<ActivityLog>>((ref) async {
  final db = ref.watch(databaseProvider);
  return db.getRecentActivityLogs(limit: 200);
});

class BackupScreen extends ConsumerStatefulWidget {
  const BackupScreen({super.key});

  @override
  ConsumerState<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends ConsumerState<BackupScreen> {
  bool _isProcessing = false;
  String _lastBackup = 'Never';

  @override
  void initState() {
    super.initState();
    _checkLastBackup();
  }

  Future<void> _checkLastBackup() async {
    try {
      final dbFolder = await getApplicationDocumentsDirectory();
      final backupDir = Directory(p.join(dbFolder.path, 'backups'));
      if (await backupDir.exists()) {
        final files = backupDir.listSync().whereType<File>().toList();
        if (files.isNotEmpty) {
          files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
          final lastFile = files.first;
          setState(() {
            _lastBackup = DateFormat('MMM dd, yyyy - hh:mm a').format(lastFile.lastModifiedSync());
          });
        }
      }
    } catch (e) {
      debugPrint('Error checking last backup: $e');
    }
  }

  Future<void> _createBackup() async {
    setState(() => _isProcessing = true);
    try {
      final db = ref.read(databaseProvider);
      final result = await BackupService.instance.createEncryptedBackup(db);

      await _checkLastBackup();
      ref.invalidate(activityLogsProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message),
            backgroundColor: result.success ? AppColors.success : AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _exportBackup() async {
    setState(() => _isProcessing = true);
    try {
      final db = ref.read(databaseProvider);
      final result = await BackupService.instance.createEncryptedBackup(db);

      if (!result.success || result.filePath == null) {
        throw Exception(result.message);
      }

      final xFile = XFile(result.filePath!);
      await Share.shareXFiles(
        [xFile],
        text: 'SR Foods Encrypted Backup (.srbackup)',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to export backup: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _restoreBackup() async {
    setState(() => _isProcessing = true);
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.any,
      );

      if (result != null && result.files.single.path != null) {
        final backupFile = File(result.files.single.path!);
        final db = ref.read(databaseProvider);
        
        final restoreResult = await BackupService.instance.restoreEncryptedBackup(backupFile, db);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(restoreResult.message),
              backgroundColor: restoreResult.success ? AppColors.success : AppColors.error,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to restore backup: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final activityLogsAsync = ref.watch(activityLogsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Backup & Audit Logs')),
      body: _isProcessing
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.shield_rounded, color: Colors.white, size: 36),
                        const SizedBox(height: 10),
                        Text(
                          'AES-256 Encrypted Backups',
                          style: AppTextStyles.titleMedium.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Last backup: $_lastBackup',
                          style: AppTextStyles.bodySmall.copyWith(color: Colors.white.withValues(alpha: 0.85)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _ActionCard(
                    title: 'Create Encrypted Backup',
                    subtitle: 'Saves password-protected .srbackup to device storage',
                    icon: Icons.lock_rounded,
                    color: AppColors.primary,
                    onTap: _createBackup,
                  ),
                  const SizedBox(height: 10),
                  _ActionCard(
                    title: 'Restore Encrypted Backup',
                    subtitle: 'Verifies checksum and restores from .srbackup file',
                    icon: Icons.restore_rounded,
                    color: AppColors.secondary,
                    onTap: _restoreBackup,
                  ),
                  const SizedBox(height: 10),
                  _ActionCard(
                    title: 'Share / Export Backup',
                    subtitle: 'Send encrypted backup to WhatsApp, Drive, or Email',
                    icon: Icons.share_rounded,
                    color: AppColors.accent,
                    onTap: _exportBackup,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'SECURITY & AUDIT LOGS (LAST 200 ACTIONS)',
                    style: AppTextStyles.overline.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: activityLogsAsync.when(
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (e, _) => Center(child: Text('Error: $e')),
                      data: (logs) {
                        if (logs.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.history_rounded, size: 40, color: AppColors.textSecondary.withValues(alpha: 0.4)),
                                const SizedBox(height: 8),
                                Text('No activity logs recorded yet', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary)),
                              ],
                            ),
                          );
                        }

                        return ListView.separated(
                          itemCount: logs.length,
                          separatorBuilder: (ctx, index) => const Divider(height: 1),
                          itemBuilder: (context, i) {
                            final log = logs[i];
                            return ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              leading: CircleAvatar(
                                radius: 14,
                                backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                                child: const Icon(Icons.security, size: 14, color: AppColors.primary),
                              ),
                              title: Text(log.action, style: AppTextStyles.labelMedium.copyWith(fontWeight: FontWeight.bold)),
                              subtitle: Text(
                                log.details ?? '${log.entityType ?? ""} #${log.entityId ?? ""}',
                                style: AppTextStyles.bodySmall.copyWith(fontSize: 11),
                              ),
                              trailing: Text(
                                DateFormat('dd MMM, hh:mm a').format(log.createdAt),
                                style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary, fontSize: 10),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final String title, subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _ActionCard({required this.title, required this.subtitle, required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTextStyles.titleSmall),
                  Text(subtitle, style: AppTextStyles.bodySmall.copyWith(fontSize: 11)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}
