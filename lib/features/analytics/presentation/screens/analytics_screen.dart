import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../../core/database/database_provider.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/formatters.dart';
import '../../../dashboard/presentation/screens/dashboard_screen.dart';

final categoryExpensesProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final db = ref.watch(databaseProvider);
  final allExpenses = await db.select(db.expenses).get();
  final Map<String, double> totals = {};
  for (final exp in allExpenses) {
    totals[exp.category] = (totals[exp.category] ?? 0.0) + exp.amount;
  }
  return totals.entries.map((e) => {'category': e.key, 'amount': e.value}).toList()
    ..sort((a, b) => (b['amount'] as double).compareTo(a['amount'] as double));
});

class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final revenueAsync = ref.watch(monthlyRevenueProvider);
    final expenseCategoriesAsync = ref.watch(categoryExpensesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics & Intelligence'),
        actions: [
          IconButton(
            icon: const Icon(Icons.auto_awesome, color: AppColors.accent),
            tooltip: 'AI Business Advisor',
            onPressed: () => context.push(AppRoutes.aiAdvisor),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        physics: const BouncingScrollPhysics(),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // AI Advisor Shortcut Card
          InkWell(
            onTap: () => context.push(AppRoutes.aiAdvisor),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF4A148C), Color(0xFF7B1FA2)],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.purple.withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.auto_awesome, color: AppColors.accent, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'AI Business Advisor',
                          style: AppTextStyles.titleMedium.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Forecast production, detect overdue restock, audit customer credit.',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: Colors.white.withValues(alpha: 0.85),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white70, size: 16),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          Text(
            'REVENUE TREND ${DateTime.now().year}',
            style: AppTextStyles.overline.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          revenueAsync.when(
            loading: () => Container(
              height: 220,
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Container(
              height: 220,
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Center(
                child: Text(
                  'Failed to load data',
                  style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
                ),
              ),
            ),
            data: (data) {
              final rawMax = data.isEmpty
                  ? 0.0
                  : data.map((d) => d['revenue'] as double).reduce((a, b) => a > b ? a : b);
              final maxY = rawMax <= 0 ? 1.0 : rawMax * 1.2;
              final currentMonth = DateTime.now().month;

              return Container(
                padding: const EdgeInsets.all(20),
                height: 220,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                  ),
                ),
                child: BarChart(BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maxY,
                  barTouchData: BarTouchData(enabled: false),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 24,
                        getTitlesWidget: (value, meta) {
                          const months = ['J', 'F', 'M', 'A', 'M', 'J', 'J', 'A', 'S', 'O', 'N', 'D'];
                          final index = value.toInt();
                          if (index < 0 || index >= months.length) return const SizedBox();
                          return Text(
                            months[index],
                            style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary),
                          );
                        },
                      ),
                    ),
                    leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  gridData: const FlGridData(show: false),
                  barGroups: data.asMap().entries.map((entry) {
                    final month = entry.value['month'] as int;
                    final revenue = entry.value['revenue'] as double;
                    final isCurrent = month == currentMonth;
                    return BarChartGroupData(
                      x: entry.key,
                      barRods: [
                        BarChartRodData(
                          toY: revenue <= 0 ? 0.001 : revenue,
                          gradient: isCurrent
                              ? AppColors.primaryGradient
                              : LinearGradient(colors: [
                                  AppColors.primary.withValues(alpha: 0.4),
                                  AppColors.primary.withValues(alpha: 0.3),
                                ]),
                          width: 16,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ],
                    );
                  }).toList(),
                )),
              );
            },
          ),

          const SizedBox(height: 24),

          Text(
            'EXPENSE BREAKDOWN',
            style: AppTextStyles.overline.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          expenseCategoriesAsync.when(
            loading: () => Container(
              height: 180,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('Error loading expenses: $e'),
            ),
            data: (categories) {
              if (categories.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(24),
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.receipt_long_outlined, size: 40, color: AppColors.textSecondary),
                      const SizedBox(height: 8),
                      Text(
                        'No expenses logged yet.',
                        style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        icon: const Icon(Icons.add),
                        label: const Text('Record Expense'),
                        onPressed: () => context.push(AppRoutes.expenseCreate),
                      ),
                    ],
                  ),
                );
              }

              final totalExpense =
                  categories.fold<double>(0.0, (sum, item) => sum + (item['amount'] as double));

              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                  ),
                ),
                child: Column(
                  children: categories.map((cat) {
                    final name = (cat['category'] as String).toUpperCase();
                    final amount = cat['amount'] as double;
                    final pct = totalExpense > 0 ? (amount / totalExpense) : 0.0;

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(name, style: AppTextStyles.titleSmall),
                              Text(
                                CurrencyFormatter.format(amount),
                                style: AppTextStyles.titleSmall.copyWith(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: pct,
                              backgroundColor: Colors.grey.withValues(alpha: 0.2),
                              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.secondary),
                              minHeight: 6,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              );
            },
          ),
          const SizedBox(height: 32),
        ]),
      ),
    );
  }
}
