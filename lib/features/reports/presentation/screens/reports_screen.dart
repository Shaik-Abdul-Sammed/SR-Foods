import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reports = [
      _ReportItem('Daily Report', 'Today\'s complete business summary', Icons.today_rounded, AppColors.revenueGradient),
      _ReportItem('Sales Report', 'Sales analysis and trends', Icons.bar_chart_rounded, AppColors.salesGradient),
      _ReportItem('Inventory Report', 'Stock levels and movements', Icons.inventory_2_rounded, AppColors.ordersGradient),
      _ReportItem('Expense Report', 'Expense breakdown and analysis', Icons.money_off_rounded, AppColors.pendingGradient),
      _ReportItem('Profit Report', 'Revenue vs expenses analysis', Icons.trending_up_rounded, AppColors.primaryGradient),
      _ReportItem('Outstanding Report', 'Customer outstanding payments', Icons.pending_actions_rounded, AppColors.goldGradient),
      _ReportItem('Customer Ledger', 'Individual customer account history', Icons.people_rounded, AppColors.orangeGradient),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Reports')),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: reports.length,
        itemBuilder: (context, i) {
          final r = reports[i];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Material(
              color: Theme.of(context).colorScheme.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2))),
              clipBehavior: Clip.antiAlias,
              child: ListTile(
                contentPadding: const EdgeInsets.all(14),
                leading: Container(width: 48, height: 48, decoration: BoxDecoration(gradient: r.gradient, borderRadius: BorderRadius.circular(12)), child: Icon(r.icon, color: Colors.white, size: 24)),
                title: Text(r.title, style: AppTextStyles.titleSmall),
                subtitle: Text(r.subtitle, style: AppTextStyles.bodySmall),
                trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.textSecondary),
                onTap: () => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${r.title} - Coming soon!'))),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ReportItem {
  final String title, subtitle;
  final IconData icon;
  final LinearGradient gradient;
  const _ReportItem(this.title, this.subtitle, this.icon, this.gradient);
}
