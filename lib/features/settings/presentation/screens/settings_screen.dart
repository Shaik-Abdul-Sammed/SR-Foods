import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_assets.dart';

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
              _sectionHeader('BUSINESS'),
              _tile(context, 'Products', Icons.inventory_2_outlined, () => context.go(AppRoutes.products), color: AppColors.primary),
              _tile(context, 'Customers', Icons.people_outlined, () => context.go(AppRoutes.customers), color: AppColors.secondary),
              _tile(context, 'Production', Icons.production_quantity_limits_rounded, () => context.go(AppRoutes.production), color: AppColors.accent),
              _tile(context, 'Inventory', Icons.warehouse_outlined, () => context.go(AppRoutes.inventory), color: const Color(0xFF0277BD)),
              _tile(context, 'Billing', Icons.receipt_long_outlined, () => context.go(AppRoutes.billing), color: AppColors.success),
              _tile(context, 'Payments', Icons.payments_outlined, () => context.go(AppRoutes.payments), color: const Color(0xFF7B1FA2)),
              _tile(context, 'Expenses', Icons.money_off_outlined, () => context.go(AppRoutes.expenses), color: AppColors.error),
              const SizedBox(height: 12),
              _sectionHeader('INSIGHTS'),
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
}
