import 'dart:math' as math;
import '../database/app_database.dart';

/// RFM Segmentation labels
enum RfmSegment {
  champions('Champions', 'Highest value and highly frequent buyers', 0xFF2E7D32),
  loyal('Loyal Customers', 'Consistent orders and high repeat cadence', 0xFF1565C0),
  potential('Potential Loyalists', 'Recent customers with growing basket size', 0xFF00838F),
  atRisk('At Risk', 'High past value but overdue for reorder', 0xFFE65100),
  hibernating('Hibernating', 'Low frequency and long inactivity', 0xFF6A1B9A),
  lost('Lost / Churned', 'No orders in over 60+ days', 0xFFC62828);

  final String label;
  final String description;
  final int colorValue;
  const RfmSegment(this.label, this.description, this.colorValue);
}

/// Churn Risk Level
enum ChurnRiskLevel {
  low('Low Risk', 0xFF2E7D32),
  moderate('Moderate Risk', 0xFFF57F17),
  high('High Risk', 0xFFE65100),
  critical('Critical / Imminent Churn', 0xFFC62828);

  final String label;
  final int colorValue;
  const ChurnRiskLevel(this.label, this.colorValue);
}

/// Dunning Tier for AR collections
enum DunningTier {
  current('Current / Healthy', 'No overdue balances', 0xFF2E7D32),
  reminderDue('Reminder Due', 'Payment overdue 1-15 days', 0xFFF57F17),
  formalNotice('Formal Notice', 'Payment overdue 16-30 days', 0xFFE65100),
  creditFrozen('Credit Frozen', 'Payment overdue >30 days or limit breached', 0xFFC62828);

  final String label;
  final String description;
  final int colorValue;
  const DunningTier(this.label, this.description, this.colorValue);
}

/// Margin Contribution Tier
enum MarginTier {
  diamond('Diamond (High Volume & High Margin)', 0xFF00838F),
  gold('Gold (High Margin, Moderate Volume)', 0xFFF9A825),
  silver('Silver (Standard Margin & Volume)', 0xFF546E7A),
  bronze('Bronze (Low Margin / High Discount)', 0xFF8D6E63);

  final String label;
  final int colorValue;
  const MarginTier(this.label, this.colorValue);
}

/// Comprehensive 360 Customer Intelligence Profile
class Hotel360Profile {
  final Customer customer;
  final RfmSegment rfmSegment;
  final double rfmScore; // 1.0 - 5.0
  final int daysSinceLastOrder;
  final double averageOrderValue;
  final double totalRevenue;
  final double grossMarginRupees;
  final double grossMarginPercentage;
  final MarginTier marginTier;
  final double orderCycleDays;
  final double cycleStdDev;
  final double regularityScore; // 0.0 - 1.0
  final double churnRiskProbability; // 0.0 - 1.0
  final ChurnRiskLevel churnRiskLevel;
  final List<String> churnSignals;
  final double estimatedWalletShare; // 0.0 - 1.0
  final double potentialMonthlySpend;
  final double daysSalesOutstanding; // DSO
  final double overdueBalance;
  final DunningTier dunningTier;
  final List<Map<String, dynamic>> topSkus; // [{sku, name, quantity, revenue}]
  final List<String> crossSellRecommendations;
  final double priceElasticityIndex;
  final double returnRatePercentage;
  final double creditUtilizationPercentage;
  final double projected12mLtv;
  final String nextBestAction;
  final String nextBestActionDetail;
  final String suggestedWhatsAppMessage;

  const Hotel360Profile({
    required this.customer,
    required this.rfmSegment,
    required this.rfmScore,
    required this.daysSinceLastOrder,
    required this.averageOrderValue,
    required this.totalRevenue,
    required this.grossMarginRupees,
    required this.grossMarginPercentage,
    required this.marginTier,
    required this.orderCycleDays,
    required this.cycleStdDev,
    required this.regularityScore,
    required this.churnRiskProbability,
    required this.churnRiskLevel,
    required this.churnSignals,
    required this.estimatedWalletShare,
    required this.potentialMonthlySpend,
    required this.daysSalesOutstanding,
    required this.overdueBalance,
    required this.dunningTier,
    required this.topSkus,
    required this.crossSellRecommendations,
    required this.priceElasticityIndex,
    required this.returnRatePercentage,
    required this.creditUtilizationPercentage,
    required this.projected12mLtv,
    required this.nextBestAction,
    required this.nextBestActionDetail,
    required this.suggestedWhatsAppMessage,
  });
}

/// Singleton Service for advanced on-device customer intelligence
class CustomerIntelligenceService {
  CustomerIntelligenceService._();
  static final CustomerIntelligenceService instance = CustomerIntelligenceService._();

  /// Analyzes a customer end-to-end and computes all 14 intelligence metrics
  Hotel360Profile buildHotel360Profile({
    required Customer customer,
    required List<Order> orders,
    required List<OrderItem> orderItems,
    required List<Invoice> invoices,
    required List<Product> products,
    List<ReturnLog> returnLogs = const [],
    DateTime? referenceDate,
    int estimatedDailyMeals = 150,
  }) {
    final now = referenceDate ?? DateTime.now();
    final customerOrders = orders.where((o) => o.customerId == customer.id).toList()
      ..sort((a, b) => b.orderDate.compareTo(a.orderDate));

    final customerInvoices = invoices.where((i) => i.customerId == customer.id).toList();
    final customerOrderIds = customerOrders.map((o) => o.id).toSet();
    final customerItems = orderItems.where((item) => customerOrderIds.contains(item.orderId)).toList();

    // 1. Recency, Frequency, Monetary
    final daysSinceLastOrder = customerOrders.isEmpty
        ? 999
        : now.difference(customerOrders.first.orderDate).inDays;
    final totalRevenue = customerOrders.fold<double>(0.0, (sum, o) => sum + o.grandTotal);
    final avgOrderValue = customerOrders.isEmpty ? 0.0 : totalRevenue / customerOrders.length;
    final rfm = _computeRfm(daysSinceLastOrder, customerOrders.length, totalRevenue);

    // 2. Order Regularity & Cadence
    final regularity = _computeRegularity(customerOrders);

    // 3. Margin Contribution
    final marginData = _computeMargin(customerItems, products, totalRevenue);

    // 4. AR Aging, DSO & Dunning
    final arData = _computeArDelinquency(customer, customerInvoices, now);

    // 5. Churn Risk Probability
    final churn = _computeChurnRisk(
      daysSinceLastOrder: daysSinceLastOrder,
      cycleDays: regularity.cycleDays,
      cycleStdDev: regularity.cycleStdDev,
      overdueBalance: arData.overdueAmount,
      dso: arData.dso,
      orderCount: customerOrders.length,
    );

    // 6. Wallet-share Estimation
    final walletShare = _computeWalletShare(customerOrders, estimatedDailyMeals);

    // 7. Top SKUs & Cross-sell recommendations
    final skuBreakdown = _computeTopSkusAndCrossSell(customerItems, products);

    // 8. Return rate
    final customerReturns = returnLogs.where((r) => r.customerId == customer.id).toList();
    final returnPacks = customerReturns.fold<int>(0, (sum, r) => sum + r.quantity);
    final totalOrderedPacks = customerItems.fold<int>(0, (sum, i) => sum + i.quantity);
    final returnRate = totalOrderedPacks > 0
        ? (returnPacks / totalOrderedPacks) * 100
        : 0.0;

    // 9. Credit Utilization
    final creditUtil = customer.creditLimit > 0
        ? (customer.currentBalance / customer.creditLimit) * 100
        : 0.0;

    // 10. LTV Projection (12-month)
    final monthlyRunRate = customerOrders.isEmpty
        ? 0.0
        : (totalRevenue / math.max(1, customerOrders.length)) * (30.0 / math.max(1.0, regularity.cycleDays));
    final projectedLtv = (monthlyRunRate * 12.0) * (marginData.marginPct / 100.0) * (1.0 - churn.riskProbability);

    // 11. Next Best Action
    final nextAction = _determineNextBestAction(
      customer: customer,
      churnRisk: churn.level,
      dunningTier: arData.tier,
      rfmSegment: rfm.segment,
      overdueBalance: arData.overdueAmount,
      crossSellSkus: skuBreakdown.crossSellRecommendations,
      daysSinceLastOrder: daysSinceLastOrder,
      cycleDays: regularity.cycleDays,
    );

    return Hotel360Profile(
      customer: customer,
      rfmSegment: rfm.segment,
      rfmScore: rfm.score,
      daysSinceLastOrder: daysSinceLastOrder,
      averageOrderValue: avgOrderValue,
      totalRevenue: totalRevenue,
      grossMarginRupees: marginData.grossMarginRupees,
      grossMarginPercentage: marginData.marginPct,
      marginTier: marginData.tier,
      orderCycleDays: regularity.cycleDays,
      cycleStdDev: regularity.cycleStdDev,
      regularityScore: regularity.regularityScore,
      churnRiskProbability: churn.riskProbability,
      churnRiskLevel: churn.level,
      churnSignals: churn.signals,
      estimatedWalletShare: walletShare.share,
      potentialMonthlySpend: walletShare.potentialSpend,
      daysSalesOutstanding: arData.dso,
      overdueBalance: arData.overdueAmount,
      dunningTier: arData.tier,
      topSkus: skuBreakdown.topSkus,
      crossSellRecommendations: skuBreakdown.crossSellRecommendations,
      priceElasticityIndex: 0.85, // inelastic staple food default
      returnRatePercentage: double.parse(returnRate.toStringAsFixed(1)),
      creditUtilizationPercentage: double.parse(creditUtil.toStringAsFixed(1)),
      projected12mLtv: double.parse(projectedLtv.toStringAsFixed(0)),
      nextBestAction: nextAction.title,
      nextBestActionDetail: nextAction.detail,
      suggestedWhatsAppMessage: nextAction.suggestedMessage,
    );
  }

  // --- Internal Helper Algorithms ---

  _RfmResult _computeRfm(int recencyDays, int orderCount, double monetary) {
    int rScore = recencyDays <= 3 ? 5 : (recencyDays <= 7 ? 4 : (recencyDays <= 14 ? 3 : (recencyDays <= 30 ? 2 : 1)));
    int fScore = orderCount >= 20 ? 5 : (orderCount >= 10 ? 4 : (orderCount >= 5 ? 3 : (orderCount >= 2 ? 2 : 1)));
    int mScore = monetary >= 50000 ? 5 : (monetary >= 25000 ? 4 : (monetary >= 10000 ? 3 : (monetary >= 3000 ? 2 : 1)));

    final avgScore = (rScore + fScore + mScore) / 3.0;

    RfmSegment segment;
    if (rScore >= 4 && fScore >= 4 && mScore >= 4) {
      segment = RfmSegment.champions;
    } else if (fScore >= 3 && rScore >= 3) {
      segment = RfmSegment.loyal;
    } else if (rScore >= 4 && fScore <= 2) {
      segment = RfmSegment.potential;
    } else if (rScore <= 2 && fScore >= 3) {
      segment = RfmSegment.atRisk;
    } else if (rScore <= 2 && fScore <= 2 && recencyDays <= 60) {
      segment = RfmSegment.hibernating;
    } else {
      segment = RfmSegment.lost;
    }

    return _RfmResult(segment, double.parse(avgScore.toStringAsFixed(1)));
  }

  _RegularityResult _computeRegularity(List<Order> orders) {
    if (orders.length < 2) {
      return const _RegularityResult(cycleDays: 3.0, cycleStdDev: 0.0, regularityScore: 0.5);
    }

    final intervals = <double>[];
    for (int i = 0; i < orders.length - 1; i++) {
      final days = orders[i].orderDate.difference(orders[i + 1].orderDate).inHours / 24.0;
      if (days > 0) intervals.add(days);
    }

    if (intervals.isEmpty) {
      return const _RegularityResult(cycleDays: 3.0, cycleStdDev: 0.0, regularityScore: 0.5);
    }

    final mean = intervals.reduce((a, b) => a + b) / intervals.length;
    double variance = 0.0;
    for (final val in intervals) {
      variance += math.pow(val - mean, 2);
    }
    final stdDev = math.sqrt(variance / intervals.length);

    // Regularity score: lower stdDev relative to mean = higher regularity
    final cv = mean > 0 ? (stdDev / mean) : 1.0;
    final score = (1.0 - math.min(1.0, cv)).clamp(0.0, 1.0);

    return _RegularityResult(
      cycleDays: double.parse(mean.toStringAsFixed(1)),
      cycleStdDev: double.parse(stdDev.toStringAsFixed(1)),
      regularityScore: double.parse(score.toStringAsFixed(2)),
    );
  }

  _MarginResult _computeMargin(List<OrderItem> items, List<Product> products, double totalRevenue) {
    if (items.isEmpty || totalRevenue <= 0) {
      return const _MarginResult(grossMarginRupees: 0.0, marginPct: 25.0, tier: MarginTier.silver);
    }

    final productCostMap = {for (var p in products) p.id: p.costPrice};
    double totalCost = 0.0;

    for (final item in items) {
      final costPerUnit = productCostMap[item.productId] ?? (item.price * 0.70);
      totalCost += (costPerUnit * item.quantity);
    }

    final grossMargin = math.max(0.0, totalRevenue - totalCost);
    final marginPct = (grossMargin / totalRevenue) * 100.0;

    MarginTier tier;
    if (marginPct >= 35.0 && totalRevenue >= 25000) {
      tier = MarginTier.diamond;
    } else if (marginPct >= 28.0) {
      tier = MarginTier.gold;
    } else if (marginPct >= 20.0) {
      tier = MarginTier.silver;
    } else {
      tier = MarginTier.bronze;
    }

    return _MarginResult(
      grossMarginRupees: double.parse(grossMargin.toStringAsFixed(0)),
      marginPct: double.parse(marginPct.toStringAsFixed(1)),
      tier: tier,
    );
  }

  _ArResult _computeArDelinquency(Customer customer, List<Invoice> invoices, DateTime now) {
    double totalOutstanding = customer.currentBalance;
    double overdueAmount = 0.0;

    for (final inv in invoices) {
      if (inv.status != 'paid' && inv.dueDate != null) {
        if (now.isAfter(inv.dueDate!)) {
          overdueAmount += inv.pendingAmount;
        }
      }
    }

    // DSO approximation = (Accounts Receivable / Total Invoiced) * 30
    final totalInvoiced = invoices.fold<double>(0.0, (sum, i) => sum + i.grandTotal);
    final dso = totalInvoiced > 0
        ? math.min(120.0, (totalOutstanding / totalInvoiced) * 60.0)
        : 0.0;

    DunningTier tier;
    if (overdueAmount <= 0 && customer.currentBalance <= customer.creditLimit) {
      tier = DunningTier.current;
    } else if (overdueAmount > 0 && overdueAmount <= (customer.creditLimit * 0.5)) {
      tier = DunningTier.reminderDue;
    } else if (overdueAmount > (customer.creditLimit * 0.5) && overdueAmount <= customer.creditLimit) {
      tier = DunningTier.formalNotice;
    } else {
      tier = DunningTier.creditFrozen;
    }

    return _ArResult(
      dso: double.parse(dso.toStringAsFixed(1)),
      overdueAmount: double.parse(overdueAmount.toStringAsFixed(0)),
      tier: tier,
    );
  }

  _ChurnResult _computeChurnRisk({
    required int daysSinceLastOrder,
    required double cycleDays,
    required double cycleStdDev,
    required double overdueBalance,
    required double dso,
    required int orderCount,
  }) {
    final signals = <String>[];
    double risk = 0.05; // baseline 5%

    if (orderCount == 0) {
      return const _ChurnResult(0.5, ChurnRiskLevel.moderate, ['New customer with zero purchase history']);
    }

    // Cycle deviation
    final expectedWindow = cycleDays + (cycleStdDev * 1.5);
    if (daysSinceLastOrder > expectedWindow) {
      final ratio = daysSinceLastOrder / math.max(1.0, cycleDays);
      if (ratio >= 3.0) {
        risk += 0.50;
        signals.add('Overdue by ${ratio.toStringAsFixed(1)}x normal reorder cadence');
      } else if (ratio >= 2.0) {
        risk += 0.35;
        signals.add('Past expected reorder date by $daysSinceLastOrder days');
      } else {
        risk += 0.15;
        signals.add('Slightly delayed beyond usual replenishment cadence');
      }
    }

    // AR distress
    if (overdueBalance > 0) {
      risk += 0.20;
      signals.add('Overdue unpaid debt causing delivery friction');
    }
    if (dso > 45) {
      risk += 0.15;
      signals.add('High Days Sales Outstanding (${dso.toStringAsFixed(0)} days)');
    }

    risk = risk.clamp(0.0, 1.0);

    ChurnRiskLevel level;
    if (risk >= 0.70) {
      level = ChurnRiskLevel.critical;
    } else if (risk >= 0.40) {
      level = ChurnRiskLevel.high;
    } else if (risk >= 0.20) {
      level = ChurnRiskLevel.moderate;
    } else {
      level = ChurnRiskLevel.low;
    }

    return _ChurnResult(
      double.parse(risk.toStringAsFixed(2)),
      level,
      signals.isEmpty ? ['Healthy ordering cadence with no risk signals'] : signals,
    );
  }

  _WalletShareResult _computeWalletShare(List<Order> orders, int estimatedDailyMeals) {
    // Benchmark: 1 meal uses ~1.5 flatbread units (Parota/Chapathi).
    // Monthly meal capacity = daily * 30 days * 1.5 units
    final benchmarkMonthlyUnits = estimatedDailyMeals * 30 * 1.5;
    final benchmarkMonthlySpend = benchmarkMonthlyUnits * 6.5; // avg Rs 6.5 per piece

    // Estimate customer monthly spend with SR Foods
    final recentTotal = orders.take(5).fold<double>(0.0, (sum, o) => sum + o.grandTotal);
    final monthlySpend = orders.isEmpty ? 0.0 : (recentTotal / math.min(orders.length, 5)) * 10; // ~10 drops/mo

    final share = benchmarkMonthlySpend > 0
        ? (monthlySpend / benchmarkMonthlySpend).clamp(0.05, 1.0)
        : 0.30;

    return _WalletShareResult(
      share: double.parse(share.toStringAsFixed(2)),
      potentialSpend: double.parse(benchmarkMonthlySpend.toStringAsFixed(0)),
    );
  }

  _SkuBreakdownResult _computeTopSkusAndCrossSell(List<OrderItem> items, List<Product> allProducts) {
    final qtyMap = <int, int>{};
    final revMap = <int, double>{};
    final nameMap = <int, String>{};

    for (final item in items) {
      qtyMap[item.productId] = (qtyMap[item.productId] ?? 0) + item.quantity;
      revMap[item.productId] = (revMap[item.productId] ?? 0.0) + item.total;
      nameMap[item.productId] = item.productName;
    }

    final sorted = qtyMap.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final topSkus = sorted.take(5).map((e) {
      return {
        'productId': e.key,
        'name': nameMap[e.key] ?? 'Product #${e.key}',
        'quantity': e.value,
        'revenue': revMap[e.key] ?? 0.0,
      };
    }).toList();

    // Cross-sell logic
    final boughtProductIds = qtyMap.keys.toSet();
    final crossSell = <String>[];

    final hasParota = items.any((i) => i.productName.toLowerCase().contains('parota') || i.productName.toLowerCase().contains('parotta'));
    final hasChapathi = items.any((i) => i.productName.toLowerCase().contains('chapathi') || i.productName.toLowerCase().contains('roti'));
    final hasPulka = items.any((i) => i.productName.toLowerCase().contains('pulka'));

    if (hasParota && !hasChapathi) {
      crossSell.add('Whole Wheat Chapathi (High margin hotel breakfast staple)');
    }
    if ((hasParota || hasChapathi) && !hasPulka) {
      crossSell.add('Oil-Free Pulka Roti (Popular diet/dinner caterer item)');
    }
    if (crossSell.isEmpty && allProducts.isNotEmpty) {
      for (final p in allProducts) {
        if (!boughtProductIds.contains(p.id)) {
          crossSell.add('${p.name} (Trial sample)');
          if (crossSell.length >= 2) break;
        }
      }
    }

    return _SkuBreakdownResult(topSkus, crossSell);
  }

  _NextActionResult _determineNextBestAction({
    required Customer customer,
    required ChurnRiskLevel churnRisk,
    required DunningTier dunningTier,
    required RfmSegment rfmSegment,
    required double overdueBalance,
    required List<String> crossSellSkus,
    required int daysSinceLastOrder,
    required double cycleDays,
  }) {
    if (dunningTier == DunningTier.creditFrozen) {
      return _NextActionResult(
        title: 'Freeze Credit & Collect Overdue',
        detail: 'Customer has ₹${overdueBalance.toStringAsFixed(0)} overdue. Require cash/UPI before next dispatch.',
        suggestedMessage: 'Namaste ${customer.ownerName} garu, polite reminder from SR Foods: an overdue balance of ₹${overdueBalance.toStringAsFixed(0)} is pending. Please clear via UPI to ensure tomorrow’s dispatch is not delayed. Thank you!',
      );
    }

    if (churnRisk == ChurnRiskLevel.critical || churnRisk == ChurnRiskLevel.high) {
      return _NextActionResult(
        title: 'Win-Back Call & Special Incentive',
        detail: 'Last order was $daysSinceLastOrder days ago (usual cycle $cycleDays days). Immediate call recommended.',
        suggestedMessage: 'Namaste ${customer.ownerName} garu, we noticed you haven\'t ordered your regular fresh Parota/Chapathi batch. Are stock levels running low? We can arrange priority van delivery for tomorrow morning. Let us know!',
      );
    }

    if (crossSellSkus.isNotEmpty) {
      final item = crossSellSkus.first;
      return _NextActionResult(
        title: 'Cross-Sell: Pitch $item',
        detail: 'High wallet-share potential. Offer 5 free trial packs with next Parota delivery.',
        suggestedMessage: 'Namaste ${customer.ownerName} garu, we are offering complimentary sample packs of our new $item with your next delivery. Shall we add 10 packs to your morning order?',
      );
    }

    return _NextActionResult(
      title: 'Schedule Regular Restock Drop',
      detail: 'Customer in healthy cadence. Confirm morning route drop.',
      suggestedMessage: 'Namaste ${customer.ownerName} garu, dispatching tomorrow morning’s standard order for ${customer.shopName}. Please confirm if you need any extra crates. Thank you!',
    );
  }
}

class _RfmResult {
  final RfmSegment segment;
  final double score;
  const _RfmResult(this.segment, this.score);
}

class _RegularityResult {
  final double cycleDays;
  final double cycleStdDev;
  final double regularityScore;
  const _RegularityResult({required this.cycleDays, required this.cycleStdDev, required this.regularityScore});
}

class _MarginResult {
  final double grossMarginRupees;
  final double marginPct;
  final MarginTier tier;
  const _MarginResult({required this.grossMarginRupees, required this.marginPct, required this.tier});
}

class _ArResult {
  final double dso;
  final double overdueAmount;
  final DunningTier tier;
  const _ArResult({required this.dso, required this.overdueAmount, required this.tier});
}

class _ChurnResult {
  final double riskProbability;
  final ChurnRiskLevel level;
  final List<String> signals;
  const _ChurnResult(this.riskProbability, this.level, this.signals);
}

class _WalletShareResult {
  final double share;
  final double potentialSpend;
  const _WalletShareResult({required this.share, required this.potentialSpend});
}

class _SkuBreakdownResult {
  final List<Map<String, dynamic>> topSkus;
  final List<String> crossSellRecommendations;
  const _SkuBreakdownResult(this.topSkus, this.crossSellRecommendations);
}

class _NextActionResult {
  final String title;
  final String detail;
  final String suggestedMessage;
  const _NextActionResult({required this.title, required this.detail, required this.suggestedMessage});
}
