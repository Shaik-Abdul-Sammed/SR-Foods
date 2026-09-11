import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:drift/drift.dart' as drift;
import '../../../../core/database/app_database.dart';
import '../../../../core/database/database_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/formatters.dart';

final invoicesProvider = StreamProvider<List<Invoice>>((ref) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.invoices)..orderBy([(i) => drift.OrderingTerm.desc(i.createdAt)])).watch();
});

class BillingScreen extends ConsumerWidget {
  const BillingScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invoicesAsync = ref.watch(invoicesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Billing & Invoices')),
      body: invoicesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e,_) => Center(child: Text('Error: $e')),
        data: (invoices) {
          if (invoices.isEmpty) {
            return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.receipt_outlined, size: 64, color: AppColors.textSecondary.withValues(alpha: 0.4)),
            const SizedBox(height: 16),
            Text('No invoices yet', style: AppTextStyles.titleMedium.copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            Text('Create an order to generate an invoice', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
          ]));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: invoices.length,
            itemBuilder: (context, i) {
              final inv = invoices[i];
              Color statusColor = inv.status == 'paid' ? AppColors.success : inv.status == 'partial' ? AppColors.warning : AppColors.error;
              return GestureDetector(
                onTap: () => context.push('/billing/${inv.id}'),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2))),
                  child: Row(children: [
                    Container(width: 40, height: 40, decoration: BoxDecoration(gradient: AppColors.primaryGradient, borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.receipt_outlined, color: Colors.white, size: 20)),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(inv.invoiceNumber, style: AppTextStyles.titleSmall),
                      Text(DateFormatter.toDate(inv.invoiceDate), style: AppTextStyles.bodySmall),
                    ])),
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text(CurrencyFormatter.format(inv.grandTotal), style: AppTextStyles.titleSmall.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700)),
                      Container(margin: const EdgeInsets.only(top: 4), padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)), child: Text(inv.status.toUpperCase(), style: AppTextStyles.badge.copyWith(color: statusColor, fontSize: 9))),
                    ]),
                  ]),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
