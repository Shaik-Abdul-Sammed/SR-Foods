import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/database/database_provider.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/services/ai_expert_engine.dart';
import '../../../../core/services/whatsapp_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/communication_utils.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/services/quantum_optimization_engine.dart';

// Riverpod Providers for AI Expert Engine outputs
final aiProductionForecastProvider =
    FutureProvider.autoDispose<List<ProductionRecommendation>>((ref) async {
  final db = ref.watch(databaseProvider);
  return AiExpertEngine.instance.computeProductionForecast(db);
});

final aiReplenishmentRadarProvider =
    FutureProvider.autoDispose<List<CustomerReplenishmentInsight>>((ref) async {
  final db = ref.watch(databaseProvider);
  return AiExpertEngine.instance.computeReplenishmentRadar(db);
});

final aiCreditRiskAuditProvider =
    FutureProvider.autoDispose<List<CreditRiskAssessment>>((ref) async {
  final db = ref.watch(databaseProvider);
  return AiExpertEngine.instance.computeCreditRiskAudit(db);
});

final aiExecutiveInsightsProvider =
    FutureProvider.autoDispose<List<BusinessOptimizationInsight>>((ref) async {
  final db = ref.watch(databaseProvider);
  return AiExpertEngine.instance.generateExecutiveInsights(db);
});

class AiAdvisorScreen extends ConsumerStatefulWidget {
  const AiAdvisorScreen({super.key});

  @override
  ConsumerState<AiAdvisorScreen> createState() => _AiAdvisorScreenState();
}

class _AiAdvisorScreenState extends ConsumerState<AiAdvisorScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _refreshAll() {
    ref.invalidate(aiProductionForecastProvider);
    ref.invalidate(aiReplenishmentRadarProvider);
    ref.invalidate(aiCreditRiskAuditProvider);
    ref.invalidate(aiExecutiveInsightsProvider);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.auto_awesome, color: AppColors.accent, size: 22),
            SizedBox(width: 8),
            Text('AI Business Advisor'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Recalculate AI Models',
            onPressed: _refreshAll,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: AppColors.accent,
          indicatorWeight: 3,
          tabAlignment: TabAlignment.start,
          tabs: const [
            Tab(icon: Icon(Icons.precision_manufacturing_rounded, size: 20), text: 'Production'),
            Tab(icon: Icon(Icons.radar_rounded, size: 20), text: 'Restock Radar'),
            Tab(icon: Icon(Icons.security_rounded, size: 20), text: 'Credit Shield'),
            Tab(icon: Icon(Icons.insights_rounded, size: 20), text: 'Smart Insights'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildProductionTab(),
          _buildReplenishmentTab(),
          _buildCreditShieldTab(),
          _buildInsightsTab(),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TAB 1: PRODUCTION BATCH ADVISOR
  // ---------------------------------------------------------------------------
  Widget _buildProductionTab() {
    final forecastAsync = ref.watch(aiProductionForecastProvider);

    return forecastAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error loading forecasts: $e')),
      data: (recommendations) {
        if (recommendations.isEmpty) {
          return const Center(child: Text('No active products found to analyze.'));
        }

        final criticalCount = recommendations.where((r) => r.urgency == 'critical').length;

        return RefreshIndicator(
          onRefresh: () async => ref.refresh(aiProductionForecastProvider),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Summary Banner
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: criticalCount > 0
                        ? [const Color(0xFFC62828), const Color(0xFFE53935)]
                        : [const Color(0xFF1B5E20), const Color(0xFF2E7D32)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
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
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        criticalCount > 0 ? Icons.warning_rounded : Icons.check_circle_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            criticalCount > 0
                                ? '$criticalCount Products Need Urgent Production'
                                : 'Stock Levels Stable & Balanced',
                            style: AppTextStyles.titleMedium.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Based on 30-day Exponential Sales Velocity & Lead Time Safety Buffer.',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0),

              const SizedBox(height: 16),
              _buildQuantumMachineSchedulerCard(recommendations),

              const SizedBox(height: 16),
              Text(
                'RECOMMENDED BATCHES TODAY',
                style: AppTextStyles.overline.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),

              ...recommendations.map((rec) => _buildProductionCard(rec)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProductionCard(ProductionRecommendation rec) {
    Color badgeColor;
    String badgeLabel;

    switch (rec.urgency) {
      case 'critical':
        badgeColor = const Color(0xFFD32F2F);
        badgeLabel = 'CRITICAL';
        break;
      case 'warning':
        badgeColor = const Color(0xFFF57C00);
        badgeLabel = 'REORDER SOON';
        break;
      case 'overstocked':
        badgeColor = const Color(0xFF7B1FA2);
        badgeLabel = 'SURPLUS';
        break;
      default:
        badgeColor = const Color(0xFF2E7D32);
        badgeLabel = 'OPTIMAL';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
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
                        rec.product.name,
                        style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'SKU: ${rec.product.sku} • Category: ${rec.product.category}',
                        style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: badgeColor.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    badgeLabel,
                    style: TextStyle(color: badgeColor, fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Metrics Grid
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _metricTile('On Hand', '${rec.currentStock} packs', Colors.blueGrey),
                  _metricTile('Runout Horizon', '${rec.daysOfStockRemaining.toStringAsFixed(1)} days',
                      rec.daysOfStockRemaining <= 1.5 ? Colors.red : Colors.teal),
                  _metricTile('Daily Demand', '${rec.dailyVelocity.toStringAsFixed(1)} /day', Colors.indigo),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Machine & Shift info
            Row(
              children: [
                const Icon(Icons.settings_suggest_rounded, size: 14, color: AppColors.primary),
                const SizedBox(width: 4),
                Text(
                  '${rec.targetMachine} • ${rec.targetShift}',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // AI Recommendation
            Row(
              children: [
                const Icon(Icons.bolt_rounded, color: AppColors.accent, size: 20),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    rec.recommendedBatchUnits > 0
                        ? 'AI Recommends producing ${rec.recommendedBatchUnits} packs today'
                        : 'No batch required today (stock is sufficient)',
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w700,
                      color: rec.recommendedBatchUnits > 0 ? AppColors.primary : AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              rec.reason,
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
            ),
            if (rec.explanation.isNotEmpty) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.lightbulb_outline_rounded, size: 14, color: AppColors.accent),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        rec.explanation,
                        style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: AppColors.textSecondary),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),

            // Action Buttons
            Row(
              children: [
                if (rec.rawMaterialsNeeded.isNotEmpty)
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.receipt_long_rounded, size: 16),
                    label: const Text('Recipe Breakdown'),
                    onPressed: () => _showRecipeSheet(rec),
                  ),
                const Spacer(),
                if (rec.recommendedBatchUnits > 0)
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.add_task_rounded, size: 18),
                    label: const Text('Start Batch'),
                    onPressed: () {
                      context.push(
                        AppRoutes.productionCreate,
                        extra: {
                          'productId': rec.product.id,
                          'quantity': rec.recommendedBatchUnits,
                        },
                      );
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showRecipeSheet(ProductionRecommendation rec) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.kitchen_rounded, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(
                  'Recipe for ${rec.recommendedBatchUnits} packs',
                  style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
              ],
            ),
            Text(
              rec.product.name,
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
            ),
            const Divider(height: 24),
            ...rec.rawMaterialsNeeded.entries.map((entry) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_outline, color: AppColors.secondary, size: 18),
                      const SizedBox(width: 8),
                      Text(entry.key, style: AppTextStyles.bodyMedium),
                      const Spacer(),
                      Text(
                        entry.value.toString(),
                        style: AppTextStyles.titleSmall.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                )),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  Navigator.of(ctx).pop();
                  context.push(
                    AppRoutes.productionCreate,
                    extra: {
                      'productId': rec.product.id,
                      'quantity': rec.recommendedBatchUnits,
                    },
                  );
                },
                child: const Text('Proceed to Start Production Batch'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuantumMachineSchedulerCard(List<ProductionRecommendation> recommendations) {
    final demandMap = <String, int>{
      for (final r in recommendations)
        r.product.sku: r.recommendedBatchUnits > 0 ? r.recommendedBatchUnits : 100,
    };
    final schedule = QuantumOptimizationEngine.instance.optimizeProductionSchedule(
      demandPacksBySku: demandMap,
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.6), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppColors.accent.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.auto_awesome, color: AppColors.accentDark, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Quantum Multi-Machine Scheduler',
                      style: AppTextStyles.titleSmall.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'QUBO-balanced energy & runtime allocation',
                      style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${schedule.overallMachineUtilizationPct.toStringAsFixed(1)}% Load',
                  style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _buildSchedulerMetric(
                  label: 'Machine Runtime',
                  value: '${schedule.totalProductionHours} hrs',
                  icon: Icons.timer_outlined,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildSchedulerMetric(
                  label: 'Power Draw',
                  value: '${schedule.totalEnergyKwh} kWh',
                  icon: Icons.electric_bolt_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildSchedulerMetric(
                  label: 'Packs Scheduled',
                  value: '${schedule.totalPacksScheduled}',
                  icon: Icons.inventory_2_outlined,
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          Text(
            'Optimal Machine Line Sequences:',
            style: AppTextStyles.labelMedium.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ...schedule.assignments.map(
            (a) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_outline_rounded, size: 16, color: AppColors.success),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${a.machineName} → ${a.packCount} pcs of ${a.productName}',
                      style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  Text(
                    '${a.estimatedHours}h (${a.energyKwh} kWh)',
                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSchedulerMetric({required String label, required String value, required IconData icon}) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: AppColors.textSecondary),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TAB 2: REPLENISHMENT RADAR (RETAIL SALES GROWTH)
  // ---------------------------------------------------------------------------
  Widget _buildReplenishmentTab() {
    final radarAsync = ref.watch(aiReplenishmentRadarProvider);

    return radarAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error analyzing replenishment: $e')),
      data: (insights) {
        if (insights.isEmpty) {
          return const Center(child: Text('No customers found to analyze.'));
        }

        final dueCount = insights.where((i) => i.status == 'due_now').length;
        final atRiskCount = insights.where((i) => i.status == 'at_risk').length;

        return RefreshIndicator(
          onRefresh: () async => ref.refresh(aiReplenishmentRadarProvider),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF00695C), Color(0xFF00897B)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.radar_rounded, color: Colors.white, size: 32),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$dueCount Shops Due Restock • $atRiskCount At-Risk',
                            style: AppTextStyles.titleMedium.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '1-tap WhatsApp prompt sends order replenishment notice directly to shop owners.',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),
              Text(
                'REPLENISHMENT RADAR',
                style: AppTextStyles.overline.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),

              ...insights.map((insight) => _buildReplenishmentCard(insight)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildReplenishmentCard(CustomerReplenishmentInsight insight) {
    Color badgeColor;
    String badgeLabel;

    switch (insight.status) {
      case 'due_now':
        badgeColor = const Color(0xFF2E7D32);
        badgeLabel = 'DUE TODAY';
        break;
      case 'at_risk':
        badgeColor = const Color(0xFFD32F2F);
        badgeLabel = 'AT RISK (OVERDUE)';
        break;
      default:
        badgeColor = Colors.blueGrey;
        badgeLabel = 'STOCKED';
    }

    final daysText = insight.daysSinceLastOrder >= 999
        ? 'Never ordered'
        : '${insight.daysSinceLastOrder} days ago';

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                  child: const Icon(Icons.storefront_rounded, color: AppColors.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        insight.customer.shopName,
                        style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Owner: ${insight.customer.ownerName} • Phone: ${insight.customer.phone}',
                        style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: badgeColor.withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    badgeLabel,
                    style: TextStyle(color: badgeColor, fontWeight: FontWeight.bold, fontSize: 10),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Last Order: $daysText',
                  style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w600),
                ),
                Text(
                  'Restock Cycle: every ${insight.avgOrderCycleDays.toStringAsFixed(0)} days',
                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
            if (insight.topOrderedItems.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                'Usual Items: ${insight.topOrderedItems.join(", ")}',
                style: AppTextStyles.labelSmall.copyWith(color: AppColors.primary),
              ),
            ],
            const SizedBox(height: 12),

            Row(
              children: [
                IconButton.filledTonal(
                  icon: const Icon(Icons.phone_rounded, color: AppColors.primary, size: 20),
                  tooltip: 'Call Shop',
                  onPressed: () => CommunicationUtils.launchPhone(context, insight.customer.phone),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF25D366), // WhatsApp Green
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    icon: const Icon(Icons.chat_rounded, size: 18),
                    label: const Text('Send WhatsApp Reorder Nudge'),
                    onPressed: () {
                      WhatsAppService.sendCustomMessage(
                        context: context,
                        phone: insight.customer.phone,
                        message: insight.suggestedWhatsAppMessage,
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TAB 3: CREDIT SHIELD (FINANCIAL RISK AUDIT)
  // ---------------------------------------------------------------------------
  Widget _buildCreditShieldTab() {
    final creditAsync = ref.watch(aiCreditRiskAuditProvider);

    return creditAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error auditing credit: $e')),
      data: (assessments) {
        if (assessments.isEmpty) {
          return const Center(child: Text('No credit customers to audit.'));
        }

        final highRisk = assessments.where((a) => a.riskTier == 'C_HIGH_RISK').length;

        return RefreshIndicator(
          onRefresh: () async => ref.refresh(aiCreditRiskAuditProvider),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: highRisk > 0
                        ? [const Color(0xFF4A148C), const Color(0xFF6A1B9A)]
                        : [const Color(0xFF1565C0), const Color(0xFF1E88E5)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.shield_rounded, color: Colors.white, size: 32),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            highRisk > 0
                                ? '$highRisk Retailers on High-Risk Credit Hold'
                                : 'Credit Portfolio Healthy',
                            style: AppTextStyles.titleMedium.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Expert system analyzes balance-to-limit ratio & invoice overdue age.',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),
              Text(
                'CUSTOMER CREDIT RATINGS',
                style: AppTextStyles.overline.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),

              ...assessments.map((item) => _buildCreditCard(item)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCreditCard(CreditRiskAssessment assessment) {
    Color tierColor;
    String tierName;

    switch (assessment.riskTier) {
      case 'A_EXCELLENT':
        tierColor = const Color(0xFF2E7D32);
        tierName = 'TIER A (EXCELLENT)';
        break;
      case 'B_CAUTION':
        tierColor = const Color(0xFFF57C00);
        tierName = 'TIER B (CAUTION)';
        break;
      default:
        tierColor = const Color(0xFFD32F2F);
        tierName = 'TIER C (HIGH RISK)';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
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
                        assessment.customer.shopName,
                        style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Owner: ${assessment.customer.ownerName} • Phone: ${assessment.customer.phone}',
                        style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: tierColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: tierColor.withValues(alpha: 0.4)),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '${assessment.creditScore}/100',
                        style: TextStyle(color: tierColor, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      Text(
                        tierName,
                        style: TextStyle(color: tierColor, fontWeight: FontWeight.bold, fontSize: 9),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Balance: ${CurrencyFormatter.format(assessment.currentBalance)}',
                  style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.bold),
                ),
                Text(
                  'Limit: ${CurrencyFormatter.format(assessment.creditLimit)}',
                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: 6),

            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (assessment.utilizationPercentage / 100.0).clamp(0.0, 1.0),
                backgroundColor: Colors.grey.withValues(alpha: 0.2),
                valueColor: AlwaysStoppedAnimation<Color>(tierColor),
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 10),

            Text(
              'Recommendation: ${assessment.recommendation}',
              style: AppTextStyles.bodySmall.copyWith(
                fontWeight: FontWeight.w600,
                color: tierColor,
              ),
            ),

            if (assessment.riskFactors.isNotEmpty) ...[
              const SizedBox(height: 6),
              ...assessment.riskFactors.map(
                (f) => Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Row(
                    children: [
                      const Icon(Icons.circle, size: 6, color: Colors.red),
                      const SizedBox(width: 6),
                      Text(f, style: AppTextStyles.labelSmall.copyWith(color: Colors.red[800])),
                    ],
                  ),
                ),
              ),
            ],

            if (assessment.currentBalance > 0) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF25D366),
                    side: const BorderSide(color: Color(0xFF25D366)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  icon: const Icon(Icons.chat_rounded, size: 16),
                  label: const Text('Send WhatsApp Balance Reminder'),
                  onPressed: () {
                    WhatsAppService.sharePaymentReminder(
                      context: context,
                      customer: assessment.customer,
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TAB 4: EXECUTIVE INSIGHTS & PROFITABILITY
  // ---------------------------------------------------------------------------
  Widget _buildInsightsTab() {
    final insightsAsync = ref.watch(aiExecutiveInsightsProvider);

    return insightsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error generating insights: $e')),
      data: (insights) {
        return RefreshIndicator(
          onRefresh: () async => ref.refresh(aiExecutiveInsightsProvider),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: insights.length,
            itemBuilder: (context, index) {
              final item = insights[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: item.badgeColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(item.icon, color: item.badgeColor, size: 28),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.title,
                              style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              item.message,
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: AppColors.textSecondary,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  static Widget _metricTile(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: color)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
      ],
    );
  }
}
