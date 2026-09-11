import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../dashboard/presentation/screens/dashboard_screen.dart';

class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final revenueAsync = ref.watch(monthlyRevenueProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Analytics')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        physics: const BouncingScrollPhysics(),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('REVENUE TREND ${DateTime.now().year}', style: AppTextStyles.overline.copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          revenueAsync.when(
            loading: () => Container(height: 200, decoration: BoxDecoration(color: AppColors.surfaceVariant, borderRadius: BorderRadius.circular(20)), child: const Center(child: CircularProgressIndicator())),
            error: (e,_) => Container(height: 200, decoration: BoxDecoration(color: AppColors.surfaceVariant, borderRadius: BorderRadius.circular(20)), child: Center(child: Text('Failed to load data', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary)))),
            data: (data) {
              // Ensure maxY is always >= 1 to prevent fl_chart assertion errors
              final rawMax = data.isEmpty ? 0.0 : data.map((d) => d['revenue'] as double).reduce((a, b) => a > b ? a : b);
              final maxY = rawMax <= 0 ? 1.0 : rawMax * 1.2;
              final currentMonth = DateTime.now().month; // 1-based

              return Container(
                padding: const EdgeInsets.all(20), height: 220,
                decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2))),
                child: BarChart(BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maxY,
                  barTouchData: BarTouchData(enabled: false),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 24, getTitlesWidget: (value, meta) {
                      const months = ['J','F','M','A','M','J','J','A','S','O','N','D'];
                      final index = value.toInt();
                      if (index < 0 || index >= months.length) return const SizedBox();
                      return Text(months[index], style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary));
                    })),
                    leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  gridData: const FlGridData(show: false),
                  barGroups: data.asMap().entries.map((entry) {
                    final month = entry.value['month'] as int; // 1-based (Jan=1)
                    final revenue = entry.value['revenue'] as double;
                    // entry.key is 0-based index (Jan=0). month == currentMonth is correct for 1-based comparison
                    final isCurrent = month == currentMonth;
                    return BarChartGroupData(
                      x: entry.key, // 0-based for chart x-axis
                      barRods: [BarChartRodData(
                        toY: revenue <= 0 ? 0.001 : revenue, // avoid 0-height bars
                        gradient: isCurrent ? AppColors.primaryGradient : LinearGradient(colors: [AppColors.primary.withValues(alpha: 0.4), AppColors.primary.withValues(alpha: 0.3)]),
                        width: 16,
                        borderRadius: BorderRadius.circular(4),
                      )],
                    );
                  }).toList(),
                )),
              );
            },
          ),

          const SizedBox(height: 24),

          Text('EXPENSE CATEGORIES', style: AppTextStyles.overline.copyWith(color: AppColors.textSecondary, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(20), height: 200,
            decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2))),
            child: const Center(child: Text('Expense chart will populate with data', style: TextStyle(color: AppColors.textSecondary))),
          ),
        ]),
      ),
    );
  }
}
