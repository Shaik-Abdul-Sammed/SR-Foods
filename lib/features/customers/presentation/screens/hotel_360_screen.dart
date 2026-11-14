import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/database/database_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/communication_utils.dart';
import '../../../../core/services/whatsapp_service.dart';
import '../../../../core/services/customer_intelligence_service.dart';

final hotel360ProfileProvider = FutureProvider.family<Hotel360Profile?, int>((ref, customerId) async {
  final db = ref.watch(databaseProvider);

  final customer = await (db.select(db.customers)..where((c) => c.id.equals(customerId))).getSingleOrNull();
  if (customer == null) return null;

  final orders = await (db.select(db.orders)..where((o) => o.customerId.equals(customerId))).get();
  final orderIds = orders.map((o) => o.id).toList();

  final orderItems = orderIds.isEmpty
      ? <OrderItem>[]
      : await (db.select(db.orderItems)..where((oi) => oi.orderId.isIn(orderIds))).get();

  final invoices = await (db.select(db.invoices)..where((i) => i.customerId.equals(customerId))).get();
  final products = await db.select(db.products).get();
  final returnLogs = await (db.select(db.returnLogs)..where((r) => r.customerId.equals(customerId))).get();

  return CustomerIntelligenceService.instance.buildHotel360Profile(
    customer: customer,
    orders: orders,
    orderItems: orderItems,
    invoices: invoices,
    products: products,
    returnLogs: returnLogs,
  );
});

class Hotel360Screen extends ConsumerWidget {
  final int customerId;
  const Hotel360Screen({super.key, required this.customerId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(hotel360ProfileProvider(customerId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hotel 360° Intelligence'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.refresh(hotel360ProfileProvider(customerId)),
          ),
        ],
      ),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Error loading intelligence: $e')),
        data: (profile) {
          if (profile == null) {
            return const Center(child: Text('Customer not found'));
          }

          final c = profile.customer;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Executive Customer Banner
                _buildHeaderCard(context, profile, c),
                const SizedBox(height: 16),

                // 2. Next Best Action (Highest Priority AI Guidance)
                _buildNextBestActionCard(context, profile, c),
                const SizedBox(height: 16),

                // 3. Core KPI Grid
                _buildKpiGrid(profile),
                const SizedBox(height: 16),

                // 4. Churn Risk & Order Cadence Radar
                _buildChurnAndCadenceCard(profile),
                const SizedBox(height: 16),

                // 5. AR Aging & Financial Health
                _buildFinancialHealthCard(profile, c),
                const SizedBox(height: 16),

                // 6. Top SKUs & Cross-Sell Recommendations
                _buildProductIntelligenceCard(context, profile, c),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeaderCard(BuildContext context, Hotel360Profile profile, Customer c) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: Colors.white.withValues(alpha: 0.2),
                child: Text(
                  c.shopName.isNotEmpty ? c.shopName[0].toUpperCase() : 'H',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c.shopName,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    Text(
                      '${c.ownerName} | ${c.phone}',
                      style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.9)),
                    ),
                    Text(
                      'Route: ${c.route ?? 'Central City'} • Code: ${c.code}',
                      style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.8)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              Chip(
                backgroundColor: Color(profile.rfmSegment.colorValue).withValues(alpha: 0.9),
                label: Text(
                  profile.rfmSegment.label,
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
              Chip(
                backgroundColor: Color(profile.marginTier.colorValue).withValues(alpha: 0.9),
                label: Text(
                  profile.marginTier.label,
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
              Chip(
                backgroundColor: Colors.black.withValues(alpha: 0.25),
                label: Text(
                  'Wallet Share: ${(profile.estimatedWalletShare * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNextBestActionCard(BuildContext context, Hotel360Profile profile, Customer c) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              const Text(
                'AI NEXT BEST ACTION',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary, letterSpacing: 0.5),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            profile.nextBestAction,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            profile.nextBestActionDetail,
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    WhatsAppService.sendCustomMessage(
                      context: context,
                      phone: c.phone,
                      message: profile.suggestedWhatsAppMessage,
                    );
                  },
                  icon: const Icon(Icons.chat, size: 16),
                  label: const Text('WhatsApp 1-Tap', style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF25D366),
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () => CommunicationUtils.launchPhone(context, c.phone),
                icon: const Icon(Icons.call, size: 16),
                label: const Text('Call', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildKpiGrid(Hotel360Profile p) {
    return Row(
      children: [
        Expanded(
          child: _kpiCard(
            title: '12M Proj. LTV',
            value: '₹${p.projected12mLtv.toStringAsFixed(0)}',
            subtitle: 'Gross profit projection',
            color: AppColors.primary,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _kpiCard(
            title: 'Gross Margin',
            value: '${p.grossMarginPercentage.toStringAsFixed(1)}%',
            subtitle: '₹${p.grossMarginRupees.toStringAsFixed(0)} total',
            color: const Color(0xFF00838F),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _kpiCard(
            title: 'Order Cadence',
            value: '${p.orderCycleDays.toStringAsFixed(1)}d',
            subtitle: 'Reg: ${(p.regularityScore * 100).toStringAsFixed(0)}%',
            color: const Color(0xFF6A1B9A),
          ),
        ),
      ],
    );
  }

  Widget _kpiCard({
    required String title,
    required String value,
    required String subtitle,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 2),
          Text(subtitle, style: const TextStyle(fontSize: 9, color: AppColors.textSecondary), maxLines: 1),
        ],
      ),
    );
  }

  Widget _buildChurnAndCadenceCard(Hotel360Profile p) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('CHURN RISK RADAR', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Color(p.churnRiskLevel.colorValue).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  p.churnRiskLevel.label,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(p.churnRiskLevel.colorValue)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: p.churnRiskProbability,
            backgroundColor: Colors.grey.shade200,
            color: Color(p.churnRiskLevel.colorValue),
            minHeight: 8,
            borderRadius: BorderRadius.circular(4),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Days Since Last Order: ${p.daysSinceLastOrder} days', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
              Text('Expected Interval: ${p.orderCycleDays} days', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
            ],
          ),
          const SizedBox(height: 8),
          ...p.churnSignals.map((signal) => Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.warning_amber_rounded, size: 14, color: Colors.orange),
                    const SizedBox(width: 6),
                    Expanded(child: Text(signal, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary))),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildFinancialHealthCard(Hotel360Profile p, Customer c) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('FINANCIAL & CREDIT HEALTH', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
              Chip(
                backgroundColor: Color(p.dunningTier.colorValue).withValues(alpha: 0.15),
                label: Text(
                  p.dunningTier.label,
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(p.dunningTier.colorValue)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Current Balance', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                    Text('₹${c.currentBalance.toStringAsFixed(0)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Credit Limit', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                    Text('₹${c.creditLimit.toStringAsFixed(0)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('DSO', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                    Text('${p.daysSalesOutstanding.toStringAsFixed(0)} days', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: (p.creditUtilizationPercentage / 100).clamp(0.0, 1.0),
            backgroundColor: Colors.grey.shade200,
            color: p.creditUtilizationPercentage > 90 ? Colors.red : Colors.green,
            minHeight: 6,
            borderRadius: BorderRadius.circular(3),
          ),
          const SizedBox(height: 4),
          Text(
            'Credit Limit Utilization: ${p.creditUtilizationPercentage.toStringAsFixed(1)}%',
            style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildProductIntelligenceCard(BuildContext context, Hotel360Profile p, Customer c) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('BREAD BASKET & CROSS-SELL', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
          const SizedBox(height: 10),
          const Text('Top Purchased Items:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          if (p.topSkus.isEmpty)
            const Text('No order history recorded yet', style: TextStyle(fontSize: 11, color: AppColors.textSecondary))
          else
            ...p.topSkus.map((sku) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text('${sku['name']}', style: const TextStyle(fontSize: 12)),
                      ),
                      Text('${sku['quantity']} packs (₹${(sku['revenue'] as double).toStringAsFixed(0)})',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ),
                )),
          const Divider(height: 16),
          const Text('Recommended Cross-Sell Additions:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary)),
          const SizedBox(height: 4),
          if (p.crossSellRecommendations.isEmpty)
            const Text('All standard bread lines already adopted!', style: TextStyle(fontSize: 11, color: AppColors.textSecondary))
          else
            ...p.crossSellRecommendations.map((rec) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      const Icon(Icons.add_circle_outline, size: 14, color: AppColors.primary),
                      const SizedBox(width: 6),
                      Expanded(child: Text(rec, style: const TextStyle(fontSize: 11))),
                    ],
                  ),
                )),
        ],
      ),
    );
  }
}
