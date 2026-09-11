import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:drift/drift.dart' as drift;
import '../../../../core/database/app_database.dart';
import '../../../../core/database/database_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/formatters.dart';

final paymentsProvider = StreamProvider<List<Payment>>((ref) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.payments)..orderBy([(p) => drift.OrderingTerm.desc(p.createdAt)])).watch();
});

class PaymentsScreen extends ConsumerWidget {
  const PaymentsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paymentsAsync = ref.watch(paymentsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Payments')),
      body: paymentsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e,_) => Center(child: Text('Error: $e')),
        data: (payments) {
          if (payments.isEmpty) {
            return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.payments_outlined, size: 64, color: AppColors.textSecondary.withValues(alpha: 0.4)),
            const SizedBox(height: 16),
            Text('No payments recorded', style: AppTextStyles.titleMedium.copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            ElevatedButton.icon(onPressed: () => context.push('/payments/create'), icon: const Icon(Icons.add_rounded), label: const Text('Record Payment')),
          ]));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: payments.length,
            itemBuilder: (context, i) {
              final p = payments[i];
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2))),
                child: Row(children: [
                  Container(width: 40, height: 40, decoration: BoxDecoration(gradient: AppColors.salesGradient, borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.payments_rounded, color: Colors.white, size: 20)),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(p.receiptNumber, style: AppTextStyles.titleSmall),
                    Text(p.method.toUpperCase(), style: AppTextStyles.labelSmall.copyWith(color: AppColors.secondary)),
                    Text(DateFormatter.toDate(p.paymentDate), style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
                  ])),
                  Text(CurrencyFormatter.format(p.amount), style: AppTextStyles.titleMedium.copyWith(color: AppColors.success, fontWeight: FontWeight.w700)),
                ]),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/payments/create'),
        icon: const Icon(Icons.add_rounded), label: const Text('Record Payment'),
      ),
    );
  }
}
