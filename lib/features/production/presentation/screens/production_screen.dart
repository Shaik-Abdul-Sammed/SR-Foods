import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:drift/drift.dart' as drift;
import '../../../../core/database/app_database.dart';
import '../../../../core/database/database_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/formatters.dart';

final productionProvider = StreamProvider<List<ProductionBatche>>((ref) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.productionBatches)..orderBy([(p) => drift.OrderingTerm.desc(p.createdAt)])).watch();
});

class ProductionScreen extends ConsumerWidget {
  const ProductionScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final batchesAsync = ref.watch(productionProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Production')),
      body: batchesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e,_) => Center(child: Text('$e')),
        data: (batches) {
          if (batches.isEmpty) {
            return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.production_quantity_limits_rounded, size: 64, color: AppColors.textSecondary.withValues(alpha: 0.4)),
            const SizedBox(height: 16),
            Text('No production records', style: AppTextStyles.titleMedium.copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            ElevatedButton.icon(onPressed: () => context.push('/production/create'), icon: const Icon(Icons.add_rounded), label: const Text('Add Batch')),
          ]));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: batches.length,
            itemBuilder: (context, i) {
              final b = batches[i];
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2))),
                child: Row(children: [
                  Container(width: 48, height: 48, decoration: BoxDecoration(gradient: AppColors.primaryGradient, borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.fastfood_rounded, color: Colors.white, size: 24)),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(b.batchNumber, style: AppTextStyles.titleSmall),
                    Text('Operator: ${b.operatorName}', style: AppTextStyles.bodySmall),
                    Text(DateFormatter.toDate(b.manufacturingDate), style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary)),
                  ])),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text('${b.quantityProduced}', style: AppTextStyles.headlineSmall.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700)),
                    Text('units', style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary)),
                  ]),
                ]),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/production/create'),
        icon: const Icon(Icons.add_rounded), label: const Text('Record Production'),
      ),
    );
  }
}
