import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:drift/drift.dart' as drift;
import '../../../../core/database/app_database.dart';
import '../../../../core/database/database_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/formatters.dart';

final expensesProvider = StreamProvider<List<Expense>>((ref) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.expenses)..orderBy([(e) => drift.OrderingTerm.desc(e.createdAt)])).watch();
});

class ExpensesScreen extends ConsumerWidget {
  const ExpensesScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expensesAsync = ref.watch(expensesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Expenses')),
      body: expensesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e,_) => Center(child: Text('Error: $e')),
        data: (expenses) {
          final total = expenses.fold(0.0, (s, e) => s + e.amount);
          return Column(children: [
            Container(margin: const EdgeInsets.all(16), padding: const EdgeInsets.all(16), decoration: BoxDecoration(gradient: AppColors.pendingGradient, borderRadius: BorderRadius.circular(16)), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('Total Expenses', style: AppTextStyles.titleSmall.copyWith(color: Colors.white)),
              Text(CurrencyFormatter.format(total), style: AppTextStyles.headlineSmall.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
            ])),
            Expanded(child: expenses.isEmpty ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.money_off_rounded, size: 64, color: AppColors.textSecondary.withValues(alpha: 0.4)),
              const SizedBox(height: 16),
              Text('No expenses recorded', style: AppTextStyles.titleMedium.copyWith(color: AppColors.textSecondary)),
              const SizedBox(height: 16),
              ElevatedButton.icon(onPressed: () => context.push('/expenses/create'), icon: const Icon(Icons.add_rounded), label: const Text('Add Expense')),
            ])) : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: expenses.length,
              itemBuilder: (context, i) {
                final e = expenses[i];
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2))),
                  child: Row(children: [
                    Container(width: 40, height: 40, decoration: BoxDecoration(gradient: AppColors.pendingGradient, borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.money_off_rounded, color: Colors.white, size: 20)),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(e.description, style: AppTextStyles.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                      Text(e.category.toUpperCase(), style: AppTextStyles.labelSmall.copyWith(color: const Color(0xFF7B1FA2))),
                      Text(DateFormatter.toDate(e.expenseDate), style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
                    ])),
                    Text(CurrencyFormatter.format(e.amount), style: AppTextStyles.titleSmall.copyWith(color: AppColors.error, fontWeight: FontWeight.w700)),
                  ]),
                );
              },
            )),
          ]);
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/expenses/create'),
        icon: const Icon(Icons.add_rounded), label: const Text('Add Expense'),
      ),
    );
  }
}
