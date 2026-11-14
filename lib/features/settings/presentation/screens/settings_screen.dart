import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_assets.dart';
import '../../../../core/services/vertical_scope_service.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('More')),
      body: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Business Info Card
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(gradient: AppColors.primaryGradient, borderRadius: BorderRadius.circular(20)),
            child: Row(children: [
              Container(
                width: 64, 
                height: 64, 
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2), 
                  borderRadius: BorderRadius.circular(16),
                  image: const DecorationImage(
                    image: AssetImage(AppAssets.owner),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(AppConfig.businessName, style: AppTextStyles.headlineSmall.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(Icons.verified_rounded, color: AppColors.accent, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      'National Enterprise Admin',
                      style: AppTextStyles.labelSmall.copyWith(color: AppColors.accent, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text('Owner: ${AppConfig.ownerName}', style: AppTextStyles.bodyMedium.copyWith(color: Colors.white.withValues(alpha: 0.9), fontWeight: FontWeight.w600)),
                Text('v${AppConfig.appVersion}', style: AppTextStyles.labelSmall.copyWith(color: Colors.white.withValues(alpha: 0.6))),
              ])),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _sectionHeader('BUSINESS VERTICALS'),
              _verticalSelectionCard(context, ref),
              const SizedBox(height: 12),
              _sectionHeader('BUSINESS'),
              _tile(context, 'Products', Icons.inventory_2_outlined, () => context.go(AppRoutes.products), color: AppColors.primary),
              _tile(context, 'Customers', Icons.people_outlined, () => context.go(AppRoutes.customers), color: AppColors.secondary),
              _tile(context, 'Production Batches', Icons.precision_manufacturing_rounded, () => context.go(AppRoutes.production), color: AppColors.accent),
              _tile(context, 'Delivery Van Routes', Icons.local_shipping_outlined, () => context.push(AppRoutes.driverRoutes), color: const Color(0xFF00897B)),
              _tile(context, 'Raw Materials & BOM', Icons.grain_rounded, () => context.push(AppRoutes.rawMaterials), color: const Color(0xFFE65100)),
              if (ref.watch(verticalScopeProvider).isEnabled(Vertical.dairy))
                _tile(context, 'Milk Procurement Intake', Icons.water_drop_outlined, () => context.push(AppRoutes.milkProcurement), color: const Color(0xFF00897B)),
              _tile(context, 'FSSAI Food Safety Audit', Icons.verified_user_rounded, () => context.push(AppRoutes.hygiene), color: const Color(0xFF2E7D32)),
              _tile(context, 'Inventory', Icons.warehouse_outlined, () => context.go(AppRoutes.inventory), color: const Color(0xFF0277BD)),
              _tile(context, 'Billing', Icons.receipt_long_outlined, () => context.go(AppRoutes.billing), color: AppColors.success),
              _tile(context, 'Payments', Icons.payments_outlined, () => context.go(AppRoutes.payments), color: const Color(0xFF7B1FA2)),
              _tile(context, 'Expenses', Icons.money_off_outlined, () => context.go(AppRoutes.expenses), color: AppColors.error),
              const SizedBox(height: 12),
              _sectionHeader('INSIGHTS'),
              _tile(context, 'AI Business Advisor', Icons.auto_awesome, () => context.push(AppRoutes.aiAdvisor), color: const Color(0xFF6A1B9A)),
              _tile(context, 'Reports', Icons.bar_chart_rounded, () => context.go(AppRoutes.reports), color: AppColors.primary),
              _tile(context, 'Analytics', Icons.analytics_outlined, () => context.go(AppRoutes.analytics), color: AppColors.secondary),
              const SizedBox(height: 12),
              _sectionHeader('DATA'),
              _tile(context, 'Backup & Restore', Icons.backup_outlined, () => context.go(AppRoutes.backup), color: AppColors.info),
              const SizedBox(height: 12),
              _sectionHeader('SECURITY'),
              _tile(context, 'Change PIN', Icons.pin_outlined, () => {}, color: AppColors.primary),
              _tile(context, 'Biometric Auth', Icons.fingerprint_rounded, () => {}, color: AppColors.success),
              const SizedBox(height: 24),
              Center(child: Text('SR Foods v${AppConfig.appVersion}\n${AppConfig.ownerName}', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary), textAlign: TextAlign.center)),
              const SizedBox(height: 32),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      child: Text(title, style: AppTextStyles.overline.copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.w700)),
    );
  }

  Widget _tile(BuildContext context, String title, IconData icon, VoidCallback onTap, {required Color color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.15))),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          leading: Container(width: 38, height: 38, decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: color, size: 20)),
          title: Text(title, style: AppTextStyles.titleSmall),
          trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.textSecondary),
          onTap: onTap,
        ),
      ),
    );
  }

  Widget _verticalSelectionCard(BuildContext context, WidgetRef ref) {
    final verticalScope = ref.watch(verticalScopeProvider);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.category_rounded, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                'Active Specializations',
                style: AppTextStyles.titleSmall.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Select the operational food verticals deployed on this instance:',
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          _verticalCheckbox(
            context,
            ref,
            label: 'Frozen Food (Parota, Chapathi, Flatbreads)',
            vertical: Vertical.frozen,
            icon: Icons.ac_unit_rounded,
            color: const Color(0xFF0288D1),
            isSelected: verticalScope.isEnabled(Vertical.frozen),
            currentSet: verticalScope.activeVerticals(),
          ),
          _verticalCheckbox(
            context,
            ref,
            label: 'Dairy (Fresh Milk, Curd, Ghee, Paneer)',
            vertical: Vertical.dairy,
            icon: Icons.water_drop_rounded,
            color: const Color(0xFF00897B),
            isSelected: verticalScope.isEnabled(Vertical.dairy),
            currentSet: verticalScope.activeVerticals(),
          ),
          _verticalCheckbox(
            context,
            ref,
            label: 'Bakery (Breads, Buns, Cakes, Pastries)',
            vertical: Vertical.bakery,
            icon: Icons.bakery_dining_rounded,
            color: const Color(0xFFE65100),
            isSelected: verticalScope.isEnabled(Vertical.bakery),
            currentSet: verticalScope.activeVerticals(),
          ),
        ],
      ),
    );
  }

  Widget _verticalCheckbox(
    BuildContext context,
    WidgetRef ref, {
    required String label,
    required Vertical vertical,
    required IconData icon,
    required Color color,
    required bool isSelected,
    required Set<Vertical> currentSet,
  }) {
    return CheckboxListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      activeColor: color,
      value: isSelected,
      secondary: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color, size: 18),
      ),
      title: Text(label, style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
      onChanged: (bool? checked) {
        if (checked == null) return;
        final newSet = Set<Vertical>.from(currentSet);
        if (checked) {
          newSet.add(vertical);
        } else {
          if (newSet.length <= 1) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('At least one vertical must remain enabled.'),
                backgroundColor: AppColors.error,
              ),
            );
            return;
          }
          newSet.remove(vertical);
        }

        // Show confirmation dialog before applying change
        showDialog<bool>(
          context: context,
          builder: (dialogCtx) => AlertDialog(
            title: const Text('Update Business Verticals'),
            content: const Text(
              'Existing SKUs and orders are preserved. New forms will show fields for the selected verticals.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogCtx).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogCtx).pop(true),
                child: const Text('Confirm'),
              ),
            ],
          ),
        ).then((confirmed) {
          if (confirmed == true) {
            ref.read(verticalScopeProvider.notifier).setActive(newSet);
          }
        });
      },
    );
  }
}
