import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../../core/database/database_provider.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/services/dairy_kpi_service.dart';
import '../../../../core/services/bakery_kpi_service.dart';
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

final dairyKpiProvider = FutureProvider.autoDispose<DairyKpiSnapshot>((ref) async {
  final db = ref.watch(databaseProvider);
  return const DairyKpiService().computeDairyKpis(db);
});

final bakeryKpiProvider = FutureProvider.autoDispose<BakeryKpiSnapshot>((ref) async {
  final db = ref.watch(databaseProvider);
  return const BakeryKpiService().computeBakeryKpis(db);
});

class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen> {
  String _selectedVertical = 'All';

  @override
  Widget build(BuildContext context) {
    final revenueAsync = ref.watch(monthlyRevenueProvider);
    final expenseCategoriesAsync = ref.watch(categoryExpensesProvider);
    final dairyKpiAsync = ref.watch(dairyKpiProvider);
    final bakeryKpiAsync = ref.watch(bakeryKpiProvider);

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

          const SizedBox(height: 18),

          // Vertical Selector Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _filterChip('All Verticals', 'All', Icons.dashboard_outlined),
                const SizedBox(width: 8),
                _filterChip('Frozen Food', 'Frozen', Icons.ac_unit_rounded),
                const SizedBox(width: 8),
                _filterChip('Dairy', 'Dairy', Icons.water_drop_outlined),
                const SizedBox(width: 8),
                _filterChip('Bakery', 'Bakery', Icons.bakery_dining_outlined),
              ],
            ),
          ),

          const SizedBox(height: 18),

          // Conditional Vertical KPI Cards
          if (_selectedVertical == 'Dairy' || _selectedVertical == 'All') ...[
            _sectionHeader('DAIRY OPERATIONS & COLD CHAIN', Icons.water_drop_outlined, AppColors.primary),
            const SizedBox(height: 10),
            dairyKpiAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => const Text('Unable to load dairy metrics'),
              data: (kpi) => _buildDairyGrid(kpi),
            ),
            const SizedBox(height: 20),
          ],

          if (_selectedVertical == 'Bakery' || _selectedVertical == 'All') ...[
            _sectionHeader('BAKERY OVEN & FRESHNESS YIELD', Icons.bakery_dining_outlined, Colors.brown),
            const SizedBox(height: 10),
            bakeryKpiAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => const Text('Unable to load bakery metrics'),
              data: (kpi) => _buildBakeryGrid(kpi),
            ),
            const SizedBox(height: 20),
          ],

          if (_selectedVertical == 'Frozen' || _selectedVertical == 'All') ...[
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
                          getTitlesWidget: (val, meta) {
                            final idx = val.toInt();
                            if (idx >= 0 && idx < data.length) {
                              final isCurrent = idx + 1 == currentMonth;
                              return Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Text(
                                  data[idx]['month'] as String,
                                  style: AppTextStyles.labelSmall.copyWith(
                                    color: isCurrent ? AppColors.primary : AppColors.textSecondary,
                                    fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                                  ),
                                ),
                              );
                            }
                            return const SizedBox.shrink();
                          },
                        ),
                      ),
                      leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    gridData: const FlGridData(show: false),
                    borderData: FlBorderData(show: false),
                    barGroups: data.asMap().entries.map((entry) {
                      final isCurrent = entry.key + 1 == currentMonth;
                      return BarChartGroupData(
                        x: entry.key,
                        barRods: [
                          BarChartRodData(
                            toY: entry.value['revenue'] as double,
                            color: isCurrent ? AppColors.primary : AppColors.surfaceVariant,
                            width: 14,
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
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
                height: 160,
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Container(
                height: 160,
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Center(
                  child: Text('Failed to load expense breakdown', style: AppTextStyles.bodyMedium),
                ),
              ),
              data: (categories) {
                if (categories.isEmpty) {
                  return Container(
                    height: 120,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Center(
                      child: Text('No expenses recorded yet', style: AppTextStyles.bodyMedium),
                    ),
                  );
                }

                final totalExpense = categories.fold<double>(
                  0.0,
                  (sum, item) => sum + (item['amount'] as double),
                );

                return Container(
                  padding: const EdgeInsets.all(20),
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
          ],

          const SizedBox(height: 32),
        ]),
      ),
    );
  }

  Widget _filterChip(String label, String value, IconData icon) {
    final isSelected = _selectedVertical == value;
    return ChoiceChip(
      avatar: Icon(
        icon,
        size: 16,
        color: isSelected ? Colors.white : AppColors.textSecondary,
      ),
      label: Text(label),
      selected: isSelected,
      selectedColor: AppColors.primary,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : AppColors.textPrimary,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      onSelected: (selected) {
        if (selected) {
          setState(() => _selectedVertical = value);
        }
      },
    );
  }

  Widget _sectionHeader(String title, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Text(
          title,
          style: AppTextStyles.overline.copyWith(
            color: color,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.1,
          ),
        ),
      ],
    );
  }

  Widget _buildDairyGrid(DairyKpiSnapshot kpi) {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.5,
      children: [
        _kpiMetricCard(
          'Milk Intake',
          '${kpi.totalMilkIntakeLiters.toStringAsFixed(0)} L',
          '${kpi.totalCollectionsCount} collections',
          Icons.opacity,
          Colors.blue,
        ),
        _kpiMetricCard(
          'Avg Fat / SNF',
          '${kpi.weightedAvgFat.toStringAsFixed(1)}% / ${kpi.weightedAvgSnf.toStringAsFixed(1)}%',
          'Standard benchmark met',
          Icons.analytics_outlined,
          Colors.indigo,
        ),
        _kpiMetricCard(
          'Container Return',
          '${kpi.containerReturnRate.toStringAsFixed(1)}%',
          'Crates & Cans in pool',
          Icons.inventory_2_outlined,
          Colors.teal,
        ),
        _kpiMetricCard(
          'Chilling Breaches',
          '${kpi.chillingBreachAlerts}',
          kpi.chillingBreachAlerts == 0 ? 'Cold chain intact' : 'Temperature alert',
          Icons.thermostat_outlined,
          kpi.chillingBreachAlerts == 0 ? AppColors.success : AppColors.error,
        ),
      ],
    );
  }

  Widget _buildBakeryGrid(BakeryKpiSnapshot kpi) {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.5,
      children: [
        _kpiMetricCard(
          'Daily Bake',
          '${kpi.dailyBakeUnits} pcs',
          'Yield ${kpi.yieldEfficiencyPercent.toStringAsFixed(1)}%',
          Icons.local_fire_department_outlined,
          Colors.orange,
        ),
        _kpiMetricCard(
          'Oven Utilization',
          '${kpi.ovenUtilizationPercent.toStringAsFixed(1)}%',
          'Batch schedule uptime',
          Icons.microwave_outlined,
          Colors.brown,
        ),
        _kpiMetricCard(
          'Day-Old Markdown',
          '${kpi.dayOldMarkdownRatePercent.toStringAsFixed(1)}%',
          'Target < 5% spoilage',
          Icons.discount_outlined,
          kpi.dayOldMarkdownRatePercent < 5.0 ? AppColors.success : Colors.amber,
        ),
        _kpiMetricCard(
          'Custom Orders',
          '${kpi.customOrderCompletionRate.toStringAsFixed(0)}%',
          '${kpi.activeCustomOrders} active cakes/bakes',
          Icons.cake_outlined,
          Colors.pink,
        ),
      ],
    );
  }

  Widget _kpiMetricCard(String title, String value, String subtitle, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary)),
              Icon(icon, size: 18, color: color),
            ],
          ),
          Text(
            value,
            style: AppTextStyles.titleMedium.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            subtitle,
            style: AppTextStyles.bodySmall.copyWith(fontSize: 10, color: AppColors.textSecondary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
