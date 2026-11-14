import '../database/app_database.dart';
import '../domain/recipe.dart';

class CustomerProfitabilityReport {
  final int customerId;
  final String shopName;
  final String ownerName;
  final String phone;
  final int totalOrders;
  final double totalRevenue;
  final double totalCogs; // Cost of goods sold based on BOM
  final double grossProfit;
  final double grossMarginPercentage;
  final double averageOrderValue;
  final String churnRisk; // 'LOW' | 'MEDIUM' | 'HIGH'
  final String profitabilityTier; // 'PLATINUM' | 'GOLD' | 'SILVER' | 'AT_RISK'
  final String strategicAdvice;

  const CustomerProfitabilityReport({
    required this.customerId,
    required this.shopName,
    required this.ownerName,
    required this.phone,
    required this.totalOrders,
    required this.totalRevenue,
    required this.totalCogs,
    required this.grossProfit,
    required this.grossMarginPercentage,
    required this.averageOrderValue,
    required this.churnRisk,
    required this.profitabilityTier,
    required this.strategicAdvice,
  });
}

class CustomerProfitabilityService {
  CustomerProfitabilityService._();
  static final CustomerProfitabilityService instance = CustomerProfitabilityService._();

  /// Computes Customer Lifetime Value (CLV), Gross Margin %, and Churn Probability
  Future<List<CustomerProfitabilityReport>> computeProfitability(AppDatabase db) async {
    final customers = await db.select(db.customers).get();
    final orders = await (db.select(db.orders)
          ..where((o) => o.status.isNotIn(['cancelled'])))
        .get();
    final orderItems = await db.select(db.orderItems).get();

    // Map order items by order ID
    final Map<int, List<OrderItem>> itemsByOrder = {};
    for (final item in orderItems) {
      itemsByOrder.putIfAbsent(item.orderId, () => []).add(item);
    }

    // Map orders by customer ID
    final Map<int, List<Order>> ordersByCustomer = {};
    for (final order in orders) {
      ordersByCustomer.putIfAbsent(order.customerId, () => []).add(order);
    }

    final now = DateTime.now();
    final List<CustomerProfitabilityReport> reports = [];

    for (final customer in customers) {
      final custOrders = ordersByCustomer[customer.id] ?? [];
      final orderCount = custOrders.length;

      if (orderCount == 0) {
        reports.add(CustomerProfitabilityReport(
          customerId: customer.id,
          shopName: customer.shopName,
          ownerName: customer.ownerName,
          phone: customer.phone,
          totalOrders: 0,
          totalRevenue: 0.0,
          totalCogs: 0.0,
          grossProfit: 0.0,
          grossMarginPercentage: 0.0,
          averageOrderValue: 0.0,
          churnRisk: 'HIGH',
          profitabilityTier: 'AT_RISK',
          strategicAdvice: 'New lead with no order history. Send introductory catalog on WhatsApp.',
        ));
        continue;
      }

      double totalRevenue = 0.0;
      double totalCogs = 0.0;

      for (final o in custOrders) {
        totalRevenue += o.grandTotal;
        final items = itemsByOrder[o.id] ?? [];
        for (final item in items) {
          final recipe = StandardRecipes.getRecipeFor(item.productName);
          final costPerPack = recipe.computeCostPerPack(100);
          totalCogs += costPerPack * item.quantity;
        }
      }

      final grossProfit = totalRevenue - totalCogs;
      final marginPct = totalRevenue > 0 ? (grossProfit / totalRevenue) * 100.0 : 0.0;
      final aov = totalRevenue / orderCount;

      // Churn calculation based on days since latest order
      custOrders.sort((a, b) => b.orderDate.compareTo(a.orderDate));
      final daysSinceLast = now.difference(custOrders.first.orderDate).inDays;

      String churn;
      if (daysSinceLast > 14) {
        churn = 'HIGH';
      } else if (daysSinceLast > 7) {
        churn = 'MEDIUM';
      } else {
        churn = 'LOW';
      }

      String tier;
      String advice;

      if (totalRevenue >= 50000 && marginPct >= 28.0) {
        tier = 'PLATINUM';
        advice = 'Highest value account. Maintain VIP priority dispatch and dedicated sales follow-up.';
      } else if (totalRevenue >= 20000 && marginPct >= 22.0) {
        tier = 'GOLD';
        advice = 'Solid consistent retailer. Cross-sell complementary SKUs (e.g. Pulka & Chapathi).';
      } else if (marginPct < 15.0) {
        tier = 'AT_RISK';
        advice = 'Low margin account. Reduce discretionary discounts or negotiate minimum order quantity.';
      } else {
        tier = 'SILVER';
        advice = 'Steady customer with growth potential. Encourage larger weekly drops to reduce delivery trips.';
      }

      reports.add(CustomerProfitabilityReport(
        customerId: customer.id,
        shopName: customer.shopName,
        ownerName: customer.ownerName,
        phone: customer.phone,
        totalOrders: orderCount,
        totalRevenue: double.parse(totalRevenue.toStringAsFixed(0)),
        totalCogs: double.parse(totalCogs.toStringAsFixed(0)),
        grossProfit: double.parse(grossProfit.toStringAsFixed(0)),
        grossMarginPercentage: double.parse(marginPct.toStringAsFixed(1)),
        averageOrderValue: double.parse(aov.toStringAsFixed(0)),
        churnRisk: churn,
        profitabilityTier: tier,
        strategicAdvice: advice,
      ));
    }

    // Sort by highest gross profit first
    reports.sort((a, b) => b.grossProfit.compareTo(a.grossProfit));
    return reports;
  }
}
