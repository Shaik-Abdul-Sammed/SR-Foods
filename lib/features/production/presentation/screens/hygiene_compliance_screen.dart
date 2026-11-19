import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/database/database_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/services/fssai_hygiene_service.dart';

final hygieneLogsProvider = FutureProvider.autoDispose<List<HygieneLog>>((ref) async {
  final db = ref.watch(databaseProvider);
  return db.getRecentHygieneLogs(limit: 30);
});

final fssaiLicenseProvider = FutureProvider.autoDispose<FssaiLicenseStatus>((ref) async {
  final db = ref.watch(databaseProvider);
  return FssaiHygieneService.instance.checkLicenseStatus(db);
});

class HygieneComplianceScreen extends ConsumerStatefulWidget {
  const HygieneComplianceScreen({super.key});

  @override
  ConsumerState<HygieneComplianceScreen> createState() => _HygieneComplianceScreenState();
}

class _HygieneComplianceScreenState extends ConsumerState<HygieneComplianceScreen> {
  final _tempCtrl = TextEditingController(text: '3.2');
  final _inspectorCtrl = TextEditingController(text: 'QA Inspector');
  final _notesCtrl = TextEditingController();
  bool _surfacesClean = true;
  bool _hygienePassed = true;
  bool _pestClear = true;

  @override
  void dispose() {
    _tempCtrl.dispose();
    _inspectorCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _showAddInspectionDialog() {
    bool isSaving = false;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Daily FSSAI Hygiene Audit', style: AppTextStyles.titleMedium),
                      IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(ctx)),
                    ],
                  ),
                  const Divider(height: 16),
                  TextFormField(
                    controller: _inspectorCtrl,
                    decoration: const InputDecoration(labelText: 'Inspector / Food Safety Supervisor'),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _tempCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Dough Chilling / Cold Room Temp (°C)',
                      helperText: 'FSSAI standard requirement: 2°C to 4°C',
                    ),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Food Contact Surfaces Sanitized'),
                    subtitle: const Text('Mixer, dough sheeter, cutters sanitized with food-grade chlorine'),
                    value: _surfacesClean,
                    onChanged: (v) => setSheetState(() => _surfacesClean = v),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Personal Hygiene Verified'),
                    subtitle: const Text('Clean aprons, hairnets, trimmed nails, no jewelry'),
                    value: _hygienePassed,
                    onChanged: (v) => setSheetState(() => _hygienePassed = v),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Pest & Rodent Screen Clear'),
                    subtitle: const Text('Insect screens intact, zero rodent traces'),
                    value: _pestClear,
                    onChanged: (v) => setSheetState(() => _pestClear = v),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _notesCtrl,
                    decoration: const InputDecoration(labelText: 'Audit Notes / Actions Taken'),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: isSaving
                        ? null
                        : () async {
                            setSheetState(() => isSaving = true);
                            final temp = double.tryParse(_tempCtrl.text.trim()) ?? 3.5;
                            final db = ref.read(databaseProvider);
                            await db.recordHygieneLog(
                              inspectorName: _inspectorCtrl.text.trim(),
                              doughChillingTemp: temp,
                              surfacesSanitized: _surfacesClean,
                              personalHygienePassed: _hygienePassed,
                              pestActivityDetected: !_pestClear,
                              notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
                            );
                            if (ctx.mounted) Navigator.pop(ctx);
                            ref.invalidate(hygieneLogsProvider);
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Daily Hygiene Inspection Logged!'),
                                backgroundColor: AppColors.success,
                              ),
                            );
                          },
                    child: const Text('Save Inspection Record'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _exportMonthlyPdf() async {
    try {
      final db = ref.read(databaseProvider);
      final pdfBytes = await FssaiHygieneService.instance.generateMonthlyHygieneReportPdf(
        db: db,
        month: DateTime.now(),
      );
      await Printing.layoutPdf(
        onLayout: (format) async => pdfBytes,
        name: 'FSSAI_Monthly_Hygiene_Report_${DateTime.now().year}_${DateTime.now().month}.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating PDF: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final licenseAsync = ref.watch(fssaiLicenseProvider);
    final logsAsync = ref.watch(hygieneLogsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('FSSAI & Food Safety'),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_rounded),
            tooltip: 'Export Monthly Audit PDF',
            onPressed: _exportMonthlyPdf,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // FSSAI License Banner
            licenseAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('Error: $e'),
              data: (lic) {
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: lic.isExpiringSoon ? AppColors.warning.withValues(alpha: 0.15) : AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: lic.isExpiringSoon ? AppColors.warning : Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.verified_user_rounded, color: AppColors.primary, size: 24),
                              const SizedBox(width: 8),
                              Text('FSSAI License', style: AppTextStyles.titleMedium),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: lic.isExpired ? AppColors.error : AppColors.success,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              lic.isExpired ? 'EXPIRED' : 'ACTIVE',
                              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('Reg. No: ${lic.licenseNumber}', style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold)),
                      Text('Valid Until: ${DateFormatter.toDate(lic.validTill)} (${lic.daysRemaining} days remaining)', style: AppTextStyles.bodySmall),
                      if (lic.isExpiringSoon) ...[
                        const SizedBox(height: 8),
                        const Text(
                          'Renewal Notice: FSSAI license expires in less than 30 days! Submit renewal form on FoSCoS portal.',
                          style: TextStyle(color: AppColors.warning, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 20),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _showAddInspectionDialog,
                    icon: const Icon(Icons.add_task_rounded),
                    label: const Text('Log Daily Audit'),
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: _exportMonthlyPdf,
                  icon: const Icon(Icons.print_rounded),
                  label: const Text('Monthly PDF'),
                ),
              ],
            ),
            const SizedBox(height: 24),

            Text('Daily Inspection Logbook (Schedule 4)', style: AppTextStyles.titleMedium),
            const SizedBox(height: 8),

            logsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('Error: $e'),
              data: (logs) {
                if (logs.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(color: AppColors.surfaceVariant, borderRadius: BorderRadius.circular(12)),
                    child: const Center(child: Text('No daily audits recorded yet. Tap "Log Daily Audit" to start.')),
                  );
                }

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: logs.length,
                  itemBuilder: (context, i) {
                    final log = logs[i];
                    final isPass = log.status == 'pass';
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isPass ? AppColors.success.withValues(alpha: 0.3) : AppColors.warning.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isPass ? Icons.check_circle_rounded : Icons.warning_rounded,
                            color: isPass ? AppColors.success : AppColors.warning,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(DateFormatter.toDate(log.inspectionDate), style: AppTextStyles.titleSmall),
                                Text(
                                  'Inspector: ${log.inspectorName} • Chilling: ${log.doughChillingTemp}°C',
                                  style: AppTextStyles.bodySmall,
                                ),
                                if (log.notes != null && log.notes!.isNotEmpty)
                                  Text(log.notes!, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: (isPass ? AppColors.success : AppColors.warning).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              log.status.toUpperCase(),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: isPass ? AppColors.success : AppColors.warning,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
