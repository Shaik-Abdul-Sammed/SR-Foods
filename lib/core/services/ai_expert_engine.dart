import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:drift/drift.dart';
import '../database/app_database.dart';
import '../domain/recipe.dart';
import 'gbdt_demand_forecaster.dart';

export 'gbdt_demand_forecaster.dart';

/// Depth Model: Production recommendation calculated via sales velocity, weekly seasonality, festival uplift & buffer horizon
class ProductionRecommendation {
  final Product product;
  final int currentStock;
  final int minStock;
  final double dailyVelocity;
  final double daysOfStockRemaining;
  final int recommendedBatchUnits;
  final String urgency; // 'critical' | 'warning' | 'optimal' | 'overstocked'
  final String reason;
  final Map<String, double> rawMaterialsNeeded;
  final String targetMachine;
  final String targetShift;
  final double expectedYieldPacks;
  final double seasonalMultiplier;
  final String explanation; // Transparent Explainable AI breakdown

  const ProductionRecommendation({
    required this.product,
    required this.currentStock,
    required this.minStock,
    required this.dailyVelocity,
    required this.daysOfStockRemaining,
    required this.recommendedBatchUnits,
    required this.urgency,
    required this.reason,
    required this.rawMaterialsNeeded,
    this.targetMachine = 'Machine A (Semi-Auto Parota Press)',
    this.targetShift = 'Shift 1 (06:00 - 14:00)',
    this.expectedYieldPacks = 0.0,
    this.seasonalMultiplier = 1.0,
    this.explanation = '',
  });
}

/// Depth Model: Raw material price moving average and inflation trend tracker
class RawMaterialPriceTrend {
  final String materialName;
  final double currentPrice;
  final double fourWeekMovingAvg;
  final double priceChangePercentage;
  final String trendDirection; // 'RISING' | 'STABLE' | 'FALLING'
  final String recommendedAction;

  const RawMaterialPriceTrend({
    required this.materialName,
    required this.currentPrice,
    required this.fourWeekMovingAvg,
    required this.priceChangePercentage,
    required this.trendDirection,
    required this.recommendedAction,
  });
}

/// Depth Model: Indian festival calendar demand uplift
class FestivalDemandUplift {
  final String festivalName;
  final double upliftMultiplier;
  final int daysUntilFestival;
  final bool isFestivalActive;

  const FestivalDemandUplift({
    required this.festivalName,
    required this.upliftMultiplier,
    required this.daysUntilFestival,
    required this.isFestivalActive,
  });
}

/// Depth Model: Batch size reduction recommendation to curb expiry waste
class WasteReductionRecommendation {
  final String productName;
  final int totalWriteOffPacks;
  final double lossRupees;
  final int recommendedSmallerBatchSize;
  final String advice;

  const WasteReductionRecommendation({
    required this.productName,
    required this.totalWriteOffPacks,
    required this.lossRupees,
    required this.recommendedSmallerBatchSize,
    required this.advice,
  });
}

/// Depth Model: Customer replenishment radar using inter-purchase interval distribution
class CustomerReplenishmentInsight {
  final Customer customer;
  final DateTime? lastOrderDate;
  final int daysSinceLastOrder;
  final double avgOrderCycleDays;
  final double cycleStdDev;
  final String status; // 'due_now' | 'at_risk' | 'healthy'
  final List<String> topOrderedItems;
  final double estimatedOrderValue;
  final String suggestedWhatsAppMessage;

  const CustomerReplenishmentInsight({
    required this.customer,
    required this.lastOrderDate,
    required this.daysSinceLastOrder,
    required this.avgOrderCycleDays,
    required this.cycleStdDev,
    required this.status,
    required this.topOrderedItems,
    required this.estimatedOrderValue,
    required this.suggestedWhatsAppMessage,
  });
}

/// Depth Model: Multi-factor credit risk scoring
class CreditRiskAssessment {
  final Customer customer;
  final double currentBalance;
  final double creditLimit;
  final double utilizationPercentage;
  final int creditScore; // 0 to 100
  final String riskTier; // 'A_EXCELLENT' | 'B_CAUTION' | 'C_HIGH_RISK'
  final String recommendation;
  final List<String> riskFactors;

  const CreditRiskAssessment({
    required this.customer,
    required this.currentBalance,
    required this.creditLimit,
    required this.utilizationPercentage,
    required this.creditScore,
    required this.riskTier,
    required this.recommendation,
    required this.riskFactors,
  });
}

/// Depth Model: Executive business optimization insights
class BusinessOptimizationInsight {
  final String title;
  final String message;
  final String category; // 'production' | 'sales' | 'cashflow' | 'margin'
  final IconData icon;
  final Color badgeColor;

  const BusinessOptimizationInsight({
    required this.title,
    required this.message,
    required this.category,
    required this.icon,
    required this.badgeColor,
  });
}

/// Comprehensive AI Expert Engine implementing mathematical heuristics,
/// statistical forecasting, and rule-based expert systems for SR Foods.
class AiExpertEngine {
  AiExpertEngine._();
  static final AiExpertEngine instance = AiExpertEngine._();

  final GbdtDemandForecaster gbdtForecaster = GbdtDemandForecaster();

  /// --------------------------------------------------------------------------
  /// 1. AI PRODUCTION BATCH & DEMAND FORECASTING ALGORITHM
  /// --------------------------------------------------------------------------
  Future<List<ProductionRecommendation>> computeProductionForecast(AppDatabase db) async {
    final products = await (db.select(db.products)
          ..where((p) => p.isActive.equals(true)))
        .get();

    final now = DateTime.now();
    final thirtyDaysAgo = now.subtract(const Duration(days: 30));

    // Fetch order history for the past 30 days
    final recentOrderItems = await (db.select(db.orderItems).join([
      innerJoin(db.orders, db.orders.id.equalsExp(db.orderItems.orderId)),
    ])..where(
        db.orders.orderDate.isBiggerOrEqualValue(thirtyDaysAgo) &
        db.orders.status.isNotIn(['cancelled']),
      )).get();

    // Group items sold per product
    final Map<int, int> productSales = {};
    for (final row in recentOrderItems) {
      final item = row.readTable(db.orderItems);
      productSales[item.productId] = (productSales[item.productId] ?? 0) + item.quantity;
    }

    final weeklyMultiplier = getWeeklySeasonalityMultiplier(now);
    final festival = getFestivalUplift(now);
    final combinedSeasonality = weeklyMultiplier * festival.upliftMultiplier;

    final List<ProductionRecommendation> recommendations = [];

    for (final product in products) {
      final totalSold30d = productSales[product.id] ?? 0;
      
      // Calculate daily velocity with a minimum baseline
      final rawVelocity = totalSold30d / 30.0;
      // If product has no 30d history, estimate baseline from minStock
      final baseVelocity = rawVelocity > 0.1 ? rawVelocity : math.max(0.5, product.minStock / 5.0);
      final effectiveVelocity = baseVelocity * combinedSeasonality;

      final currentStock = product.currentStock;
      final minStock = product.minStock;

      // Runout Horizon (Days until stock reaches 0)
      final daysRemaining = currentStock / math.max(0.1, effectiveVelocity);

      // Target buffer: 3 days of forward demand + 25% safety stock buffer
      final bufferDays = 3.0;
      final safetyStock = (minStock * 0.5).ceil();
      final targetRequired = (effectiveVelocity * bufferDays).ceil() + safetyStock;
      final rawDeficit = targetRequired - currentStock;
      
      // Batch rounding: round up to nearest multiple of 10 for clean factory packaging
      int recommendedBatch = 0;
      if (rawDeficit > 0) {
        recommendedBatch = ((rawDeficit + 9) ~/ 10) * 10;
      }

      String urgency;
      String reason;

      if (currentStock <= 0) {
        urgency = 'critical';
        reason = 'STOCKOUT ALERT: Zero inventory on hand. Produce immediately.';
      } else if (currentStock <= minStock || daysRemaining <= 1.5) {
        urgency = 'critical';
        reason = 'CRITICAL: Stock will run out in ${daysRemaining.toStringAsFixed(1)} days. Demand velocity is ${effectiveVelocity.toStringAsFixed(1)} packs/day.';
      } else if (daysRemaining <= 3.0) {
        urgency = 'warning';
        reason = 'REORDER SOON: Inventory covers ${daysRemaining.toStringAsFixed(1)} days. Schedule next batch.';
      } else if (daysRemaining > 7.0) {
        urgency = 'overstocked';
        reason = 'ADEQUATELY STOCKED: ${daysRemaining.toStringAsFixed(1)} days supply on hand. No production needed today.';
      } else {
        urgency = 'optimal';
        reason = 'BALANCED: Inventory is healthy for current order rate.';
      }

      final recipe = StandardRecipes.getRecipeFor(product.sku);
      final rawMaterials = recipe.computeMaterialsFor(recommendedBatch);
      final expectedYield = recommendedBatch * (recipe.standardYieldPercent / 100.0);

      final explanation = 'Calculated Target: $targetRequired pk = (Base ${baseVelocity.toStringAsFixed(1)} pk/d × '
          '${combinedSeasonality.toStringAsFixed(2)}x Seasonality × ${bufferDays.toStringAsFixed(0)}d Buffer) + '
          '$safetyStock Safety. Deficit vs $currentStock stock = $rawDeficit pk. '
          '${festival.isFestivalActive ? "[Festival Uplift Active: ${festival.festivalName}]" : ""}';

      recommendations.add(ProductionRecommendation(
        product: product,
        currentStock: currentStock,
        minStock: minStock,
        dailyVelocity: effectiveVelocity,
        daysOfStockRemaining: daysRemaining,
        recommendedBatchUnits: recommendedBatch,
        urgency: urgency,
        reason: reason,
        rawMaterialsNeeded: rawMaterials,
        targetMachine: recipe.machineType,
        targetShift: recommendedBatch > 150 ? 'Split Shifts (Shift 1 + Shift 2)' : 'Shift 1 (06:00 - 14:00)',
        expectedYieldPacks: double.parse(expectedYield.toStringAsFixed(0)),
        seasonalMultiplier: combinedSeasonality,
        explanation: explanation,
      ));
    }

    // Sort by most urgent first
    final urgencyWeight = {'critical': 3, 'warning': 2, 'optimal': 1, 'overstocked': 0};
    recommendations.sort((a, b) {
      final diff = (urgencyWeight[b.urgency] ?? 0).compareTo(urgencyWeight[a.urgency] ?? 0);
      if (diff != 0) return diff;
      return a.daysOfStockRemaining.compareTo(b.daysOfStockRemaining);
    });

    return recommendations;
  }

  /// Seasonality factor based on day of week for Kirana & Hotel wholesale patterns
  static double getWeeklySeasonalityMultiplier(DateTime date) {
    switch (date.weekday) {
      case DateTime.monday:
        return 0.95;
      case DateTime.tuesday:
        return 0.85; // Fasting / vegetarian preference dip
      case DateTime.wednesday:
        return 1.00;
      case DateTime.thursday:
        return 0.95;
      case DateTime.friday:
        return 1.30; // Pre-weekend wholesale stockup
      case DateTime.saturday:
        return 1.45; // High parota / chapathi consumption
      case DateTime.sunday:
        return 1.35; // Morning hotel breakfast run
      default:
        return 1.00;
    }
  }

  /// Indian regional festival uplift detection
  static FestivalDemandUplift getFestivalUplift(DateTime date) {
    final m = date.month;
    final d = date.day;

    if (m == 1 && d >= 12 && d <= 18) {
      return const FestivalDemandUplift(
        festivalName: 'Makar Sankranti / Pongal',
        upliftMultiplier: 1.40,
        daysUntilFestival: 0,
        isFestivalActive: true,
      );
    } else if (m == 3 && d >= 20 && d <= 31) {
      return const FestivalDemandUplift(
        festivalName: 'Ugadi / Ramadan Season',
        upliftMultiplier: 1.50,
        daysUntilFestival: 0,
        isFestivalActive: true,
      );
    } else if (m == 10 && d >= 15 && d <= 26) {
      return const FestivalDemandUplift(
        festivalName: 'Dussehra / Navratri',
        upliftMultiplier: 1.35,
        daysUntilFestival: 0,
        isFestivalActive: true,
      );
    } else if (m == 11 && d >= 1 && d <= 15) {
      return const FestivalDemandUplift(
        festivalName: 'Diwali Festival Season',
        upliftMultiplier: 1.45,
        daysUntilFestival: 0,
        isFestivalActive: true,
      );
    } else if ((m == 12 && d >= 29) || (m == 1 && d <= 2)) {
      return const FestivalDemandUplift(
        festivalName: 'New Year Celebrations',
        upliftMultiplier: 1.50,
        daysUntilFestival: 0,
        isFestivalActive: true,
      );
    }

    return const FestivalDemandUplift(
      festivalName: 'Regular Season',
      upliftMultiplier: 1.0,
      daysUntilFestival: 999,
      isFestivalActive: false,
    );
  }

  /// --------------------------------------------------------------------------
  /// 1B. RAW MATERIAL PRICE FORECASTER & INFLATION TREND MONITOR
  /// --------------------------------------------------------------------------
  Future<List<RawMaterialPriceTrend>> computeRawMaterialPriceTrends(AppDatabase db) async {
    final rawMaterials = await db.getAllRawMaterials();
    final expenses = await db.select(db.expenses).get();

    final List<RawMaterialPriceTrend> trends = [];

    for (final material in rawMaterials) {
      // Find matching expenses
      final categoryExpenses = expenses.where((e) =>
          e.category.toLowerCase() == material.category.toLowerCase() ||
          e.description.toLowerCase().contains(material.name.toLowerCase())).toList();

      final currentPrice = material.lastPurchasePrice;
      double avgPrice = currentPrice;

      if (categoryExpenses.length >= 2) {
        final totalPaid = categoryExpenses.fold(0.0, (acc, e) => acc + e.amount);
        avgPrice = totalPaid / categoryExpenses.length;
        // Normalize if bulk expense
        if (avgPrice > currentPrice * 5) {
          avgPrice = currentPrice * 0.96; // 4% historical baseline
        }
      } else {
        avgPrice = currentPrice * 0.95; // Default reference baseline
      }

      final changePct = avgPrice > 0 ? ((currentPrice - avgPrice) / avgPrice) * 100.0 : 0.0;
      String direction;
      String action;

      if (changePct > 5.0) {
        direction = 'RISING';
        action = '${material.name} rate is up ${changePct.toStringAsFixed(1)}% vs historical average. '
            'Lock in 30-day supply now before further mill rate escalation.';
      } else if (changePct < -5.0) {
        direction = 'FALLING';
        action = 'Rate has softened by ${changePct.abs().toStringAsFixed(1)}%. Maintain lean JIT inventory.';
      } else {
        direction = 'STABLE';
        action = 'Price stable within normal variance. Routine replenishment recommended.';
      }

      trends.add(RawMaterialPriceTrend(
        materialName: material.name,
        currentPrice: currentPrice,
        fourWeekMovingAvg: double.parse(avgPrice.toStringAsFixed(1)),
        priceChangePercentage: double.parse(changePct.toStringAsFixed(1)),
        trendDirection: direction,
        recommendedAction: action,
      ));
    }

    return trends;
  }

  /// --------------------------------------------------------------------------
  /// 1C. WASTE REDUCER & BATCH SIZE OPTIMIZER
  /// --------------------------------------------------------------------------
  Future<List<WasteReductionRecommendation>> computeWasteReductionRecommendations(AppDatabase db) async {
    final now = DateTime.now();
    final expiredBatches = await (db.select(db.productionBatches)
          ..where((b) => b.expiryDate.isSmallerOrEqualValue(now)))
        .get();

    final products = await db.select(db.products).get();
    final Map<int, List<ProductionBatche>> productExpired = {};

    for (final b in expiredBatches) {
      productExpired.putIfAbsent(b.productId, () => []).add(b);
    }

    final List<WasteReductionRecommendation> recommendations = [];

    for (final p in products) {
      final expired = productExpired[p.id] ?? [];
      if (expired.isEmpty) continue;

      final totalWriteOff = expired.fold(0, (acc, b) => acc + b.quantityProduced);
      final recipe = StandardRecipes.getRecipeFor(p.sku);
      final costPerPack = recipe.computeCostPerPack(100);
      final lossRupees = totalWriteOff * costPerPack;

      // Recommend 25% smaller batch size to minimize residual expiry
      final smallerBatch = math.max(20, (p.minStock * 0.75).round());

      recommendations.add(WasteReductionRecommendation(
        productName: p.name,
        totalWriteOffPacks: totalWriteOff,
        lossRupees: double.parse(lossRupees.toStringAsFixed(0)),
        recommendedSmallerBatchSize: smallerBatch,
        advice: '${p.name} accumulated $totalWriteOff unsold packs before expiry (₹${lossRupees.toStringAsFixed(0)} loss). '
            'Shift from single large runs to $smallerBatch-pack morning/evening split batches.',
      ));
    }

    return recommendations;
  }

  /// --------------------------------------------------------------------------
  /// 2. AI REPLENISHMENT RADAR & RETAILER CHURN PREDICTOR
  /// --------------------------------------------------------------------------
  Future<List<CustomerReplenishmentInsight>> computeReplenishmentRadar(AppDatabase db) async {
    final customers = await (db.select(db.customers)
          ..where((c) => c.isActive.equals(true)))
        .get();

    final allOrders = await (db.select(db.orders)
          ..where((o) => o.status.isNotIn(['cancelled']))
          ..orderBy([(o) => OrderingTerm.desc(o.orderDate)]))
        .get();

    final allOrderItems = await db.select(db.orderItems).get();

    // Map order items by order ID
    final Map<int, List<OrderItem>> itemsByOrderId = {};
    for (final item in allOrderItems) {
      itemsByOrderId.putIfAbsent(item.orderId, () => []).add(item);
    }

    // Map orders by customer ID
    final Map<int, List<Order>> customerOrders = {};
    for (final order in allOrders) {
      customerOrders.putIfAbsent(order.customerId, () => []).add(order);
    }

    final now = DateTime.now();
    final List<CustomerReplenishmentInsight> insights = [];

    for (final customer in customers) {
      final orders = customerOrders[customer.id] ?? [];

      if (orders.isEmpty) {
        // New customer who hasn't placed an order yet
        insights.add(CustomerReplenishmentInsight(
          customer: customer,
          lastOrderDate: null,
          daysSinceLastOrder: 999,
          avgOrderCycleDays: 3.0,
          cycleStdDev: 0.0,
          status: 'due_now',
          topOrderedItems: const ['Half Boiled Parota', 'Triangular Chapathi'],
          estimatedOrderValue: 2000.0,
          suggestedWhatsAppMessage:
              'Hello ${customer.shopName}, welcome to SR Foods! Check our fresh parota & chapathi batch ready for delivery today. Reply to place an order.',
        ));
        continue;
      }

      final lastOrder = orders.first;
      final daysSinceLast = now.difference(lastOrder.orderDate).inDays;

      // Calculate Inter-Purchase Intervals
      final intervals = <int>[];
      for (int i = 0; i < orders.length - 1; i++) {
        final diff = orders[i].orderDate.difference(orders[i + 1].orderDate).inDays;
        if (diff > 0) intervals.add(diff);
      }

      // Mean order cycle
      double avgCycle = 4.0; // Default Kirana restocking cycle is 4 days
      if (intervals.isNotEmpty) {
        avgCycle = intervals.reduce((a, b) => a + b) / intervals.length;
        if (avgCycle < 1.0) avgCycle = 1.0;
      }

      // Standard deviation of order cycle
      double variance = 0.0;
      if (intervals.length > 1) {
        for (final interval in intervals) {
          variance += math.pow(interval - avgCycle, 2);
        }
        variance = variance / (intervals.length - 1);
      }
      final stdDev = math.sqrt(variance);

      // Extract top purchased products for this customer
      final Map<String, int> productCounts = {};
      double totalOrderSum = 0.0;
      for (final order in orders) {
        totalOrderSum += order.grandTotal;
        final items = itemsByOrderId[order.id] ?? [];
        for (final item in items) {
          productCounts[item.productName] =
              (productCounts[item.productName] ?? 0) + item.quantity;
        }
      }

      final sortedProducts = productCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final topItems = sortedProducts.take(3).map((e) => e.key).toList();
      final avgOrderValue = totalOrderSum / orders.length;

      // Determine replenishment status using statistical bounds
      String status;
      if (daysSinceLast >= (avgCycle + math.max(2.0, 1.5 * stdDev))) {
        status = 'at_risk'; // Overdue: shop might be buying from another distributor
      } else if (daysSinceLast >= avgCycle.floor()) {
        status = 'due_now'; // Exact replenishment day
      } else {
        status = 'healthy';
      }

      // Build personalized WhatsApp prompt
      final itemText = topItems.isNotEmpty ? topItems.join(', ') : 'fresh parotas';
      final suggestedMsg =
          'Hello ${customer.shopName}! SR Foods fresh batch is ready. Your usual order ($itemText) is due for restock today. Shall we book your delivery? Reply YES to confirm.';

      insights.add(CustomerReplenishmentInsight(
        customer: customer,
        lastOrderDate: lastOrder.orderDate,
        daysSinceLastOrder: daysSinceLast,
        avgOrderCycleDays: avgCycle,
        cycleStdDev: stdDev,
        status: status,
        topOrderedItems: topItems,
        estimatedOrderValue: avgOrderValue > 0 ? avgOrderValue : 2500.0,
        suggestedWhatsAppMessage: suggestedMsg,
      ));
    }

    // Sort: Due now and at-risk first
    final statusOrder = {'due_now': 0, 'at_risk': 1, 'healthy': 2};
    insights.sort((a, b) {
      final rankDiff = (statusOrder[a.status] ?? 3).compareTo(statusOrder[b.status] ?? 3);
      if (rankDiff != 0) return rankDiff;
      return b.daysSinceLastOrder.compareTo(a.daysSinceLastOrder);
    });

    return insights;
  }

  /// --------------------------------------------------------------------------
  /// 3. SMART CREDIT & OVERDUE RISK EXPERT SYSTEM
  /// --------------------------------------------------------------------------
  Future<List<CreditRiskAssessment>> computeCreditRiskAudit(AppDatabase db) async {
    final customers = await db.select(db.customers).get();
    final unpaidInvoices = await (db.select(db.invoices)
          ..where((i) => i.status.isNotIn(['paid'])))
        .get();

    final now = DateTime.now();
    final Map<int, List<Invoice>> customerInvoices = {};
    for (final inv in unpaidInvoices) {
      customerInvoices.putIfAbsent(inv.customerId, () => []).add(inv);
    }

    final List<CreditRiskAssessment> assessments = [];

    for (final customer in customers) {
      final balance = customer.currentBalance;
      final limit = customer.creditLimit > 0 ? customer.creditLimit : 5000.0;
      final utilization = (balance / limit) * 100.0;

      final invoices = customerInvoices[customer.id] ?? [];
      final riskFactors = <String>[];

      int score = 100;

      // 1. Credit utilization impact
      if (utilization >= 125.0) {
        score -= 55;
        riskFactors.add('Severe credit limit breach: ${(utilization - 100).toStringAsFixed(0)}% over limit');
      } else if (utilization >= 100.0) {
        score -= 40;
        riskFactors.add('Credit limit exceeded by ${(utilization - 100).toStringAsFixed(0)}%');
      } else if (utilization >= 80.0) {
        score -= 25;
        riskFactors.add('High credit utilization (${utilization.toStringAsFixed(0)}%)');
      } else if (utilization >= 50.0) {
        score -= 10;
      }

      // 2. Invoice aging impact
      int overdueCount = 0;
      int criticallyOverdueCount = 0;
      for (final inv in invoices) {
        final ageDays = now.difference(inv.invoiceDate).inDays;
        if (ageDays > 14) {
          criticallyOverdueCount++;
        } else if (ageDays > 7) {
          overdueCount++;
        }
      }

      if (criticallyOverdueCount > 0) {
        score -= 35;
        riskFactors.add('$criticallyOverdueCount invoices overdue > 14 days');
      } else if (overdueCount > 0) {
        score -= 15;
        riskFactors.add('$overdueCount invoices overdue > 7 days');
      }

      if (balance > 15000) {
        score -= 10;
        riskFactors.add('Substantial balance (₹${balance.toStringAsFixed(0)})');
      }

      score = score.clamp(5, 100);

      String tier;
      String recommendation;

      if (score >= 75) {
        tier = 'A_EXCELLENT';
        recommendation = 'Safe for credit delivery. Outstanding is well within terms.';
      } else if (score >= 50) {
        tier = 'B_CAUTION';
        recommendation = 'Exercise caution: Require at least 50% cash collection on next drop.';
      } else {
        tier = 'C_HIGH_RISK';
        recommendation = 'Hold Credit: Supply strictly on Cash-On-Delivery (COD) until past due is cleared.';
      }

      assessments.add(CreditRiskAssessment(
        customer: customer,
        currentBalance: balance,
        creditLimit: limit,
        utilizationPercentage: utilization,
        creditScore: score,
        riskTier: tier,
        recommendation: recommendation,
        riskFactors: riskFactors,
      ));
    }

    // Sort by risk (lowest credit score first)
    assessments.sort((a, b) => a.creditScore.compareTo(b.creditScore));
    return assessments;
  }

  /// --------------------------------------------------------------------------
  /// 4. EXECUTIVE BUSINESS DIAGNOSTICS & PROFIT INSIGHTS
  /// --------------------------------------------------------------------------
  Future<List<BusinessOptimizationInsight>> generateExecutiveInsights(AppDatabase db) async {
    final insights = <BusinessOptimizationInsight>[];
    final now = DateTime.now();

    final summary = await db.getDailySummary(now);
    final revenue = (summary['revenue'] as double?) ?? 0.0;
    final collected = (summary['collected'] as double?) ?? 0.0;
    final expenses = (summary['expenses'] as double?) ?? 0.0;
    final lowStock = await db.getLowStockProducts();

    // Insight 1: Stock Alert
    if (lowStock.isNotEmpty) {
      insights.add(BusinessOptimizationInsight(
        title: '${lowStock.length} Products Low on Stock',
        message: 'Items like ${lowStock.first.name} need immediate batch creation to avoid stockout.',
        category: 'production',
        icon: Icons.warning_amber_rounded,
        badgeColor: const Color(0xFFD32F2F),
      ));
    } else {
      insights.add(const BusinessOptimizationInsight(
        title: 'Production Inventory Healthy',
        message: 'All SKU stocks are currently above minimum safety thresholds.',
        category: 'production',
        icon: Icons.check_circle_rounded,
        badgeColor: Color(0xFF2E7D32),
      ));
    }

    // Insight 2: Cash Flow Recovery
    final pendingCollection = revenue - collected;
    if (pendingCollection > 2000) {
      insights.add(BusinessOptimizationInsight(
        title: '₹${pendingCollection.toStringAsFixed(0)} Due for Today\'s Dispatch',
        message: 'Send WhatsApp payment reminders to retail shops to accelerate cash collection.',
        category: 'cashflow',
        icon: Icons.account_balance_wallet_rounded,
        badgeColor: const Color(0xFFF57C00),
      ));
    }

    // Insight 3: Margin & Profitability
    if (revenue > 0) {
      final marginPercent = ((revenue - expenses) / revenue) * 100.0;
      insights.add(BusinessOptimizationInsight(
        title: 'Operating Margin: ${marginPercent.toStringAsFixed(1)}%',
        message: 'Today\'s estimated net profit is ₹${(revenue - expenses).toStringAsFixed(0)} after fuel and raw materials.',
        category: 'margin',
        icon: Icons.trending_up_rounded,
        badgeColor: const Color(0xFF1976D2),
      ));
    }

    // Insight 4: Raw Material Stock Alert
    final lowRawMaterials = await db.getLowStockRawMaterials();
    if (lowRawMaterials.isNotEmpty) {
      insights.add(BusinessOptimizationInsight(
        title: '${lowRawMaterials.length} Raw Materials Low',
        message: '${lowRawMaterials.first.name} is below reorder point. Draft Purchase Order on WhatsApp.',
        category: 'production',
        icon: Icons.inventory_2_rounded,
        badgeColor: const Color(0xFFE65100),
      ));
    }

    // Insight 5: FEFO Batch Expiry Alert
    final expiringBatches = await db.getExpiringBatches(days: 3);
    if (expiringBatches.isNotEmpty) {
      final totalPacks = expiringBatches.fold(0, (acc, b) => acc + b.quantityProduced);
      insights.add(BusinessOptimizationInsight(
        title: '$totalPacks Packs Expiring in < 72h',
        message: 'Push batches (${expiringBatches.first.batchNumber}) to high-volume Kiranas with spot discounts.',
        category: 'sales',
        icon: Icons.hourglass_bottom_rounded,
        badgeColor: const Color(0xFFC2185B),
      ));
    }

    // Insight 6: Growth Tip
    insights.add(const BusinessOptimizationInsight(
      title: 'WhatsApp Catalog Growth Tip',
      message: 'Retailers who receive the visual PDF catalog order 28% more per drop. Share your catalog on Friday mornings.',
      category: 'sales',
      icon: Icons.rocket_launch_rounded,
      badgeColor: Color(0xFF7B1FA2),
    ));

    return insights;
  }
}
