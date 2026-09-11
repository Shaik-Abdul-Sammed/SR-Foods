import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import '../../../../core/database/app_database.dart';
import '../../../../core/database/database_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

final inventoryWithProductsProvider = FutureProvider<List<Map<String,dynamic>>>((ref) async {
  final db = ref.watch(databaseProvider);
  final products = await (db.select(db.products)..where((p) => p.isActive.equals(true))..orderBy([(p) => drift.OrderingTerm.asc(p.name)])).get();
  return products.map((p) => {'product': p}).toList();
});

class InventoryScreen extends ConsumerWidget {
  const InventoryScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inventoryAsync = ref.watch(inventoryWithProductsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Inventory')),
      body: inventoryAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e,_) => Center(child: Text('Error: $e')),
        data: (items) {
          if (items.isEmpty) return Center(child: Text('No inventory data', style: AppTextStyles.titleMedium.copyWith(color: AppColors.textSecondary)));
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            itemBuilder: (context, i) {
              final product = items[i]['product'] as Product;
              final isLow = product.currentStock <= product.minStock;
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isLow ? AppColors.warning.withValues(alpha: 0.4) : Theme.of(context).colorScheme.outline.withValues(alpha: 0.2), width: isLow ? 1.5 : 1),
                ),
                child: Row(children: [
                  Container(width: 48, height: 48, decoration: BoxDecoration(gradient: isLow ? AppColors.goldGradient : AppColors.primaryGradient, borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.fastfood_rounded, color: Colors.white, size: 24)),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(product.name, style: AppTextStyles.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text('SKU: ${product.sku}', style: AppTextStyles.bodySmall),
                    Text('Min: ${product.minStock} units', style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary)),
                  ])),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text('${product.currentStock}', style: AppTextStyles.headlineSmall.copyWith(color: isLow ? AppColors.error : AppColors.primary, fontWeight: FontWeight.w700)),
                    Text('units', style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary)),
                    if (isLow) Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1), decoration: BoxDecoration(color: AppColors.warningLight, borderRadius: BorderRadius.circular(6)), child: Text('LOW', style: AppTextStyles.badge.copyWith(color: AppColors.warningDark, fontSize: 9))),
                  ]),
                ]),
              );
            },
          );
        },
      ),
    );
  }
}
