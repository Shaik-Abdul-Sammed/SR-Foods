import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_animate/flutter_animate.dart';


import '../../../../core/database/database_provider.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/theme/app_assets.dart';
import '../../../../core/utils/formatters.dart';
import '../widgets/dashboard_stat_card.dart';
import '../widgets/quick_action_card.dart';
import '../widgets/revenue_chart.dart';
import '../widgets/recent_orders_list.dart';
import '../widgets/low_stock_widget.dart';
import '../widgets/sales_goal_card.dart';

// Providers
final dashboardSummaryProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final db = ref.watch(databaseProvider);
  return db.getDailySummary(DateTime.now());
});

// Use StreamProvider backed by products table watch so low-stock updates in real-time
final lowStockProvider = StreamProvider((ref) async* {
  final db = ref.watch(databaseProvider);
  await for (final _ in (db.select(db.products)).watch()) {
    yield await db.getLowStockProducts();
  }
});

final monthlyRevenueProvider = FutureProvider((ref) async {
  final db = ref.watch(databaseProvider);
  return db.getMonthlyRevenue(DateTime.now().year);
});

// Stream recent orders so the dashboard refreshes when new orders are placed
final recentOrdersProvider = StreamProvider((ref) async* {
  final db = ref.watch(databaseProvider);
  await for (final _ in (db.select(db.orders)).watch()) {
    yield await db.getOrdersWithCustomers(limit: 5);
  }
});


class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeIn;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeIn = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final summaryAsync = ref.watch(dashboardSummaryProvider);
    final monthlyRevenueAsync = ref.watch(monthlyRevenueProvider);

    final now = DateTime.now();
    final currentMonth = now.month;
    final currentSales = monthlyRevenueAsync.maybeWhen(
      data: (data) {
        final currentMonthData = data.firstWhere(
          (m) => m['month'] == currentMonth,
          orElse: () => {'revenue': 0.0},
        );
        return (currentMonthData['revenue'] as double?) ?? 0.0;
      },
      orElse: () => 0.0,
    );

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: FadeTransition(
        opacity: _fadeIn,
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(dashboardSummaryProvider);
            ref.invalidate(lowStockProvider);
            ref.invalidate(monthlyRevenueProvider);
            ref.invalidate(recentOrdersProvider);
            // Optional delay to make the refresh indicator visible
            await Future<void>.delayed(const Duration(milliseconds: 500));
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            slivers: [
              // ===================== App Bar =====================
              SliverAppBar(
                expandedHeight: 0,
                floating: true,
                snap: true,
                pinned: false,
                backgroundColor: Theme.of(context).colorScheme.surface,
                flexibleSpace: Container(),
                title: Row(
                  children: [
                    // Logo
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        image: const DecorationImage(
                          image: AssetImage(AppAssets.logo),
                          fit: BoxFit.cover,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FutureBuilder<String?>(
                          future: const FlutterSecureStorage().read(key: 'owner_name'),
                          builder: (context, snapshot) {
                            final name = snapshot.data ?? 'Owner';
                            return Text(
                              'Welcome, $name',
                              style: AppTextStyles.titleSmall.copyWith(
                                color: Theme.of(context).colorScheme.onSurface,
                                fontWeight: FontWeight.w700,
                              ),
                            );
                          },
                        ),
                        Text(
                          DateFormatter.toFullDate(now),
                          style: AppTextStyles.labelSmall.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                actions: [
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(Icons.search_rounded),
                    tooltip: 'Search',
                  ),
                  Stack(
                    children: [
                      IconButton(
                        onPressed: () {},
                        icon: const Icon(Icons.notifications_outlined),
                        tooltip: 'Notifications',
                      ),
                      Positioned(
                        right: 8,
                        top: 8,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppColors.error,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 4),
                ],
              ),
  
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // =================== Hero Header ==================
                    _buildHeroHeader(context, summaryAsync),
  
                    const SizedBox(height: 20),

                    // ============= Sales Target Goal =================
                    SalesGoalCard(currentSales: currentSales),

                    const SizedBox(height: 20),
  
                    // ============= Quick Actions =====================
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'QUICK ACTIONS',
                        style: AppTextStyles.overline.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    _buildQuickActions(context),
  
                    const SizedBox(height: 24),
  
                    // ============= Today's Stats ======================
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        "TODAY'S OVERVIEW",
                        style: AppTextStyles.overline.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    _buildStatCards(context, summaryAsync),
  
                    const SizedBox(height: 24),
  
                    // ============= Revenue Chart ======================
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'MONTHLY REVENUE',
                            style: AppTextStyles.overline.copyWith(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            DateFormatter.toMonthYear(now),
                            style: AppTextStyles.labelSmall.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    const RevenueChart()
                        .animate()
                        .fade(duration: 600.ms, delay: 300.ms)
                        .slideY(begin: 0.1, end: 0, duration: 600.ms, curve: Curves.easeOutQuad),
  
                    const SizedBox(height: 24),
  
                    // ============= Low Stock Alert ====================
                    const LowStockWidget(),
  
                    const SizedBox(height: 24),
  
                    // ============= Recent Orders =====================
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'RECENT ORDERS',
                            style: AppTextStyles.overline.copyWith(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          TextButton(
                            onPressed: () => context.go(AppRoutes.orders),
                            child: Text(
                              'View All',
                              style: AppTextStyles.labelSmall.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const RecentOrdersList()
                        .animate()
                        .fade(duration: 500.ms, delay: 500.ms)
                        .slideY(begin: 0.1, end: 0, duration: 500.ms, curve: Curves.easeOutQuad),
  
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroHeader(
    BuildContext context,
    AsyncValue<Map<String, dynamic>> summaryAsync,
  ) {
    return summaryAsync.when(
      loading: () => _buildHeroSkeleton(),
      error: (e, _) => const SizedBox(),
      data: (summary) {
        final revenue = (summary['revenue'] as double?) ?? 0.0;
        final ordersCount = (summary['ordersCount'] as int?) ?? 0;
        final pendingAmount = (summary['pendingAmount'] as double?) ?? 0.0;

        return Container(
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: AppColors.heroGradient,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Today's Revenue",
                          style: AppTextStyles.labelMedium.copyWith(
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          CurrencyFormatter.format(revenue),
                          style: AppTextStyles.displaySmall.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '$ordersCount orders',
                                style: AppTextStyles.labelSmall.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Pending amount
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Column(
                          children: [
                            const Icon(
                              Icons.pending_actions_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Pending',
                              style: AppTextStyles.labelSmall.copyWith(
                                color: Colors.white.withValues(alpha: 0.8),
                              ),
                            ),
                            Text(
                              CurrencyFormatter.compact(pendingAmount),
                              style: AppTextStyles.titleSmall.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ).animate()
         .fade(duration: 800.ms, delay: 100.ms)
         .slideY(begin: 0.1, end: 0, duration: 800.ms, curve: Curves.easeOutCirc)
         .shimmer(duration: 1500.ms, delay: 800.ms, color: Colors.white24);
      },
    );
  }

  Widget _buildHeroSkeleton() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      height: 130,
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(24),
      ),
    ).animate(onPlay: (controller) => controller.repeat())
     .shimmer(duration: 1200.ms, color: Colors.white24, angle: 1.05);
  }

  Widget _buildQuickActions(BuildContext context) {
    final actions = [
      _QuickAction(
        icon: Icons.add_circle_outline_rounded,
        label: 'New Order',
        color: AppColors.primary,
        onTap: () => context.push(AppRoutes.orderCreate),
      ),
      _QuickAction(
        icon: Icons.person_add_outlined,
        label: 'Add Customer',
        color: AppColors.secondary,
        onTap: () => context.push(AppRoutes.customerCreate),
      ),
      _QuickAction(
        icon: Icons.production_quantity_limits_rounded,
        label: 'Production',
        color: AppColors.accent,
        onTap: () => context.go(AppRoutes.production),
      ),
      _QuickAction(
        icon: Icons.payments_outlined,
        label: 'Record Payment',
        color: const Color(0xFF7B1FA2),
        onTap: () => context.push(AppRoutes.paymentCreate),
      ),
    ];

    return SizedBox(
      height: 110,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        physics: const BouncingScrollPhysics(),
        itemCount: actions.length,
        itemBuilder: (context, index) {
          final action = actions[index];
          return QuickActionCard(
            icon: action.icon,
            label: action.label,
            color: action.color,
            onTap: action.onTap,
          ).animate()
           .fade(duration: 500.ms, delay: (200 + index * 100).ms)
           .slideX(begin: 0.1, end: 0, duration: 500.ms, curve: Curves.easeOutCubic)
           .scale(begin: const Offset(0.9, 0.9), end: const Offset(1, 1), delay: (200 + index * 100).ms, duration: 500.ms, curve: Curves.easeOutBack);
        },
      ),
    );
  }

  Widget _buildStatCards(
    BuildContext context,
    AsyncValue<Map<String, dynamic>> summaryAsync,
  ) {
    return summaryAsync.when(
      loading: () => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.5,
          children: List.generate(
            4,
            (_) => Container(
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
      ),
      error: (e, _) => const SizedBox(),
      data: (summary) {
        final items = [
          _StatItem(
            title: 'Revenue',
            value: CurrencyFormatter.format(
              (summary['revenue'] as double?) ?? 0.0,
            ),
            icon: Icons.trending_up_rounded,
            gradient: AppColors.revenueGradient,
          ),
          _StatItem(
            title: 'Collected',
            value: CurrencyFormatter.format(
              (summary['collected'] as double?) ?? 0.0,
            ),
            icon: Icons.payments_rounded,
            gradient: AppColors.salesGradient,
          ),
          _StatItem(
            title: 'Orders',
            value: '${(summary['ordersCount'] as int?) ?? 0}',
            icon: Icons.receipt_long_rounded,
            gradient: AppColors.ordersGradient,
          ),
          _StatItem(
            title: 'Expenses',
            value: CurrencyFormatter.format(
              (summary['expenses'] as double?) ?? 0.0,
            ),
            icon: Icons.money_off_rounded,
            gradient: AppColors.pendingGradient,
          ),
        ];

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.6,
            children: items
                .asMap()
                .entries
                .map(
                  (entry) => DashboardStatCard(
                    title: entry.value.title,
                    value: entry.value.value,
                    icon: entry.value.icon,
                    gradient: entry.value.gradient,
                  ).animate()
                   .fade(duration: 600.ms, delay: (400 + entry.key * 100).ms)
                   .slideY(begin: 0.1, end: 0, duration: 600.ms, curve: Curves.easeOutCubic)
                   .scale(begin: const Offset(0.9, 0.9), end: const Offset(1, 1), duration: 600.ms, delay: (400 + entry.key * 100).ms, curve: Curves.easeOutBack),
                )
                .toList(),
          ),
        );
      },
    );
  }
}

class _QuickAction {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
}

class _StatItem {
  final String title;
  final String value;
  final IconData icon;
  final LinearGradient gradient;
  const _StatItem({
    required this.title,
    required this.value,
    required this.icon,
    required this.gradient,
  });
}
