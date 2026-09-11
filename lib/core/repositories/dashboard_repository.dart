import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/app_database.dart';
import '../database/database_provider.dart';

final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  return DashboardRepository(ref.watch(databaseProvider));
});

class DashboardMetrics {
  final double todayRevenue;
  final double totalPendingPayments;
  final int totalOrdersToday;

  DashboardMetrics({
    required this.todayRevenue,
    required this.totalPendingPayments,
    required this.totalOrdersToday,
  });
}

class DashboardRepository {
  final AppDatabase _db;

  DashboardRepository(this._db);

  Stream<DashboardMetrics> watchMetrics() {
    final todayStart = DateTime.now().copyWith(hour: 0, minute: 0, second: 0, millisecond: 0);
    
    final salesStream = _db.select(_db.orders)
      ..where((o) => o.orderDate.isBiggerOrEqualValue(todayStart));
      
    return salesStream.watch().asyncMap((orders) async {
      double todayRevenue = 0.0;
      int totalOrders = orders.length;

      for (var order in orders) {
        todayRevenue += order.grandTotal;
      }

      final customers = await _db.select(_db.customers).get();
      double pendingPayments = 0.0;
      for (var c in customers) {
        pendingPayments += c.currentBalance;
      }

      return DashboardMetrics(
        todayRevenue: todayRevenue,
        totalPendingPayments: pendingPayments,
        totalOrdersToday: totalOrders,
      );
    });
  }

  Stream<List<Product>> watchLowStockProducts() {
    return (_db.select(_db.products)
      ..where((p) => p.currentStock.isSmallerOrEqual(p.minStock)))
        .watch();
  }
}
