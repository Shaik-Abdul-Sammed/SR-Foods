// ignore_for_file: deprecated_member_use
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

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
      final dbFolder = await getApplicationDocumentsDirectory();
      final dbFile = File(p.join(dbFolder.path, 'sr_foods.db'));
      
      if (!await dbFile.exists()) {
        throw Exception('Database file not found');
      }

      final backupDir = Directory(p.join(dbFolder.path, 'backups'));
      if (!await backupDir.exists()) {
        await backupDir.create();
      }

      final backupFileName = 'sr_foods_backup_${DateTime.now().millisecondsSinceEpoch}.db';
      final backupFile = File(p.join(backupDir.path, backupFileName));
      await dbFile.copy(backupFile.path);

      await _checkLastBackup();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Backup created successfully!'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create backup: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _exportDatabase() async {
    setState(() => _isProcessing = true);
    try {
      final dbFolder = await getApplicationDocumentsDirectory();
      final dbFile = File(p.join(dbFolder.path, 'sr_foods.db'));
      
      if (!await dbFile.exists()) {
        throw Exception('Database file not found');
      }

      final xFile = XFile(dbFile.path);
      await Share.shareXFiles([xFile], text: 'SR Foods Database Backup');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to export database: $e'), backgroundColor: AppColors.error),
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
        final sourceFile = File(result.files.single.path!);
        final dbFolder = await getApplicationDocumentsDirectory();
        final dbFile = File(p.join(dbFolder.path, 'sr_foods.db'));

        // Overwrite the current database
        await sourceFile.copy(dbFile.path);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Database restored! Please restart the app.'), backgroundColor: AppColors.success),
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
    return Scaffold(
      appBar: AppBar(title: const Text('Backup & Restore')),
      body: _isProcessing 
        ? const Center(child: CircularProgressIndicator())
        : Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: double.infinity, padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(gradient: AppColors.primaryGradient, borderRadius: BorderRadius.circular(20)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.cloud_done_rounded, color: Colors.white, size: 40),
              const SizedBox(height: 12),
              Text('Your Data is Safe', style: AppTextStyles.headlineSmall.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text('Last backup: $_lastBackup', style: AppTextStyles.bodyMedium.copyWith(color: Colors.white.withValues(alpha: 0.8))),
            ]),
          ),
          const SizedBox(height: 24),
          _ActionCard(title: 'Create Backup', subtitle: 'Create a complete backup of your data locally', icon: Icons.backup_rounded, color: AppColors.primary, onTap: _createBackup),
          const SizedBox(height: 12),
          _ActionCard(title: 'Restore Backup', subtitle: 'Restore data from a previous backup file', icon: Icons.restore_rounded, color: AppColors.secondary, onTap: _restoreBackup),
          const SizedBox(height: 12),
          _ActionCard(title: 'Export Database', subtitle: 'Share your database file via Email or Drive', icon: Icons.download_rounded, color: AppColors.accent, onTap: _exportDatabase),
          const SizedBox(height: 24),
          Text('BACKUP HISTORY', style: AppTextStyles.overline.copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          Expanded(child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.history_rounded, size: 48, color: AppColors.textSecondary.withValues(alpha: 0.4)),
            const SizedBox(height: 8),
            Text('History shown in device storage', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary)),
          ]))),
        ]),
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
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2))),
        child: Row(children: [
          Container(width: 48, height: 48, decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: color, size: 24)),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: AppTextStyles.titleSmall),
            Text(subtitle, style: AppTextStyles.bodySmall),
          ])),
          const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.textSecondary),
        ]),
      ),
    );
  }
}
