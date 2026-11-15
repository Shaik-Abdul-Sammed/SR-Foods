import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' show Variable;
import '../../../../core/database/database_provider.dart';
import '../../../../core/domain/money.dart';
import '../../../../core/services/dairy_pricing_service.dart';
import '../../../../core/services/milk_procurement_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

class MilkProcurementScreen extends ConsumerStatefulWidget {
  const MilkProcurementScreen({super.key});

  @override
  ConsumerState<MilkProcurementScreen> createState() => _MilkProcurementScreenState();
}

class _MilkProcurementScreenState extends ConsumerState<MilkProcurementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _service = const MilkProcurementService();
  final _pricingService = const DairyPricingService();

  final _formKey = GlobalKey<FormState>();
  final _supplierIdCtrl = TextEditingController(text: 'FARMER-042');
  final _litersCtrl = TextEditingController(text: '120.0');
  final _fatCtrl = TextEditingController(text: '6.2');
  final _snfCtrl = TextEditingController(text: '9.1');
  final _notesCtrl = TextEditingController();

  String _currentSlot = 'morning';
  bool _isLoading = false;
  List<Map<String, dynamic>> _recentProcurements = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _currentSlot = _tabController.index == 0 ? 'morning' : 'evening';
      });
      _loadRecentProcurements();
    });
    _loadRecentProcurements();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _supplierIdCtrl.dispose();
    _litersCtrl.dispose();
    _fatCtrl.dispose();
    _snfCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadRecentProcurements() async {
    try {
      final db = ref.read(databaseProvider);
      final rows = await db.customSelect(
        'SELECT id, supplier_id, quantity_liters, fat_percent, snf_percent, '
        'rate_per_liter_minor, total_amount_minor, slot, procurement_date '
        'FROM milk_procurements WHERE slot = ? ORDER BY procurement_date DESC LIMIT 10',
        variables: [Variable.withString(_currentSlot)],
      ).get();

      if (mounted) {
        setState(() {
          _recentProcurements = rows.map((r) => r.data).toList();
        });
      }
    } catch (_) {
      // In-memory or pre-migration fallback
    }
  }

  Future<void> _saveProcurement() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final db = ref.read(databaseProvider);
      final liters = double.parse(_litersCtrl.text);
      final fat = double.parse(_fatCtrl.text);
      final snf = double.parse(_snfCtrl.text);

      await _service.recordProcurement(
        db: db,
        supplierId: _supplierIdCtrl.text.trim(),
        quantityLiters: liters,
        fatPercent: fat,
        snfPercent: snf,
        slot: _currentSlot,
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Milk intake recorded and rate computed successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
        _notesCtrl.clear();
        _loadRecentProcurements();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Intake Error: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final cutoffStatus = _service.slotCutoffCheck(now);

    final liters = double.tryParse(_litersCtrl.text) ?? 0.0;
    final fat = double.tryParse(_fatCtrl.text) ?? 4.0;
    final activeRule = fat >= 5.0 ? FatPricingRuleData.premiumBuffalo : FatPricingRuleData.standardCow;
    final liveTotalMoney = _pricingService.calculateMilkPrice(
      liters: liters,
      fatPercent: fat,
      rule: activeRule,
    );
    final liveRatePerLiter = _pricingService.calculateMilkPrice(
      liters: 1.0,
      fatPercent: fat,
      rule: activeRule,
    );

    // Theoretical fat yield comparing against standard expected fat
    final expectedFatStandard = activeRule.baseFatPercent;
    final fatYieldPct = _pricingService.computeFatYield(
      expectedFat: expectedFatStandard,
      actualFat: fat,
      liters: liters,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Milk Procurement & Intake'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(icon: Icon(Icons.wb_sunny_outlined), text: 'Morning Slot'),
            Tab(icon: Icon(Icons.nights_stay_outlined), text: 'Evening Slot'),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Cutoff Banner
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cutoffStatus.isIntakeAllowed
                    ? AppColors.success.withValues(alpha: 0.12)
                    : AppColors.warning.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: cutoffStatus.isIntakeAllowed ? AppColors.success : AppColors.warning,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    cutoffStatus.isIntakeAllowed ? Icons.check_circle_outline : Icons.schedule,
                    color: cutoffStatus.isIntakeAllowed ? AppColors.success : AppColors.warning,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      cutoffStatus.message,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: cutoffStatus.isIntakeAllowed ? AppColors.success : AppColors.warning,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Live Rate Computation Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Live Fat-Based Pricing ($activeRule)',
                        style: AppTextStyles.labelSmall.copyWith(color: Colors.white.withValues(alpha: 0.8)),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Yield: $fatYieldPct%',
                          style: AppTextStyles.labelSmall.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Rate / Liter', style: AppTextStyles.bodySmall.copyWith(color: Colors.white70)),
                          Text(
                            liveRatePerLiter.format(),
                            style: AppTextStyles.headlineSmall.copyWith(color: Colors.white, fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('Total Settlement', style: AppTextStyles.bodySmall.copyWith(color: Colors.white70)),
                          Text(
                            liveTotalMoney.format(),
                            style: AppTextStyles.headlineSmall.copyWith(color: AppColors.accent, fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Intake Form
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('New Milk Delivery Intake', style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _supplierIdCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Supplier ID / Farmer Code',
                      prefixIcon: Icon(Icons.person_pin_outlined),
                    ),
                    validator: (v) => v == null || v.isEmpty ? 'Supplier ID required' : null,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _litersCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'Volume (Liters)',
                            prefixIcon: Icon(Icons.water_drop_outlined),
                          ),
                          onChanged: (_) => setState(() {}),
                          validator: (v) => v == null || v.isEmpty ? 'Volume required' : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _fatCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'Fat % (Analyzer)',
                            prefixIcon: Icon(Icons.speed_outlined),
                          ),
                          onChanged: (_) => setState(() {}),
                          validator: (v) => v == null || v.isEmpty ? 'Fat % required' : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _snfCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'SNF % (Lactometer)',
                            prefixIcon: Icon(Icons.science_outlined),
                          ),
                          validator: (v) => v == null || v.isEmpty ? 'SNF % required' : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _notesCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Can Numbers / QC Note',
                            prefixIcon: Icon(Icons.edit_note_outlined),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _saveProcurement,
                      icon: const Icon(Icons.save_outlined),
                      label: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : Text('Record ${_currentSlot.toUpperCase()} Intake'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Recent Deliveries Table
            Text(
              'Recent ${_currentSlot.toUpperCase()} Deliveries',
              style: AppTextStyles.titleSmall.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (_recentProcurements.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    'No deliveries logged for this $_currentSlot slot yet.',
                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _recentProcurements.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (ctx, i) {
                  final item = _recentProcurements[i];
                  final litersVal = item['quantity_liters'];
                  final fatVal = item['fat_percent'];
                  final amountMinor = item['total_amount_minor'] as int? ?? 0;
                  final money = Money(amountMinor: amountMinor);

                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFFE0F2F1),
                      child: Icon(Icons.local_shipping, size: 18, color: Color(0xFF00897B)),
                    ),
                    title: Text(
                      '${item['supplier_id']} — $litersVal L @ $fatVal% Fat',
                      style: AppTextStyles.titleSmall,
                    ),
                    subtitle: Text('SNF: ${item['snf_percent']}% | Slot: ${item['slot']}'),
                    trailing: Text(
                      money.format(),
                      style: AppTextStyles.titleSmall.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  );
                },
              ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
