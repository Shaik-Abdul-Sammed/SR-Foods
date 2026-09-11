import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import 'tables.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    Products,
    Customers,
    Orders,
    OrderItems,
    Invoices,
    Payments,
    ProductionBatches,
    Inventory,
    InventoryTransactions,
    Expenses,
    Users,
    AppSettings,
    AppNotifications,
    BackupHistory,
    ActivityLogs,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());
  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) async {
          await m.createAll();
          await _seedDefaultData();
        },
        onUpgrade: (Migrator m, int from, int to) async {
          // Future migrations here
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
          await customStatement('PRAGMA journal_mode = WAL');
          await customStatement('PRAGMA synchronous = NORMAL');
          await customStatement('PRAGMA cache_size = -64000'); // 64MB cache
          await customStatement('PRAGMA temp_store = MEMORY');
        },
      );

  /// Seed default products and owner user
  Future<void> _seedDefaultData() async {
    // Insert default products
    final defaultProducts = [
      ProductsCompanion.insert(
        sku: 'SRF-HBP-001',
        name: 'Half Boiled Parota',
        category: const Value('Parota'),
        price: 100.0,
        piecesPerPack: const Value(10),
        weightGrams: const Value(800.0),
        description: const Value('Soft half-boiled parota, 10 pieces per pack, 800g'),
        isActive: const Value(true),
        isAvailable: const Value(true),
        minStock: const Value(10),
      ),
      ProductsCompanion.insert(
        sku: 'SRF-TC-002',
        name: 'Triangular Chapathi',
        category: const Value('Chapathi'),
        price: 80.0,
        piecesPerPack: const Value(20),
        weightGrams: const Value(800.0),
        description: const Value('Triangular shaped chapathi, 20 pieces per pack, 800g'),
        isActive: const Value(true),
        isAvailable: const Value(true),
        minStock: const Value(10),
      ),
      ProductsCompanion.insert(
        sku: 'SRF-PUL-003',
        name: 'Pulka',
        category: const Value('Pulka'),
        price: 50.0,
        piecesPerPack: const Value(20),
        weightGrams: const Value(800.0),
        description: const Value('Soft pulka, 20 pieces per pack, 800g'),
        isActive: const Value(true),
        isAvailable: const Value(true),
        minStock: const Value(10),
      ),
      ProductsCompanion.insert(
        sku: 'SRF-PUR-004',
        name: 'Puri',
        category: const Value('Puri'),
        price: 50.0,
        piecesPerPack: const Value(20),
        weightGrams: const Value(800.0),
        description: const Value('Crispy puri, 20 pieces per pack, 800g'),
        isActive: const Value(true),
        isAvailable: const Value(true),
        minStock: const Value(10),
      ),
    ];

    for (final product in defaultProducts) {
      final productId = await into(products).insert(product);
      // Create inventory entry for each product
      await into(inventory).insert(
        InventoryCompanion.insert(
          productId: productId,
          openingStock: const Value(0),
          currentStock: const Value(0),
        ),
      );
    }

    // Insert default owner user
    await into(users).insert(
      UsersCompanion.insert(
        name: 'SM Subhani',
        role: const Value('owner'),
        isActive: const Value(true),
      ),
    );

    // Insert default settings
    final defaultSettings = [
      ('business_name', 'SR Foods'),
      ('owner_name', 'SM Subhani'),
      ('business_address', ''),
      ('business_phone', ''),
      ('invoice_prefix', 'SRF'),
      ('currency', 'INR'),
      ('currency_symbol', '₹'),
      ('gst_number', ''),
      ('theme_mode', 'system'),
      ('language', 'en'),
      ('low_stock_threshold', '10'),
      ('auto_backup', 'true'),
      ('backup_frequency', 'daily'),
    ];

    for (final (key, value) in defaultSettings) {
      await into(appSettings).insert(
        AppSettingsCompanion.insert(key: key, value: value),
      );
    }
  }

  // ===================== Custom Queries =====================

  /// Get order with customer info
  Future<List<Map<String, dynamic>>> getOrdersWithCustomers({
    String? status,
    DateTime? fromDate,
    DateTime? toDate,
    int? limit,
    int? offset,
  }) async {
    var query = (select(orders)
      ..orderBy([(o) => OrderingTerm.desc(o.createdAt)]));

    if (status != null) {
      query = query..where((o) => o.status.equals(status));
    }

    return query.join([
      leftOuterJoin(customers, customers.id.equalsExp(orders.customerId)),
    ]).map((row) {
      final order = row.readTable(orders);
      final customer = row.readTableOrNull(customers);
      return {'order': order, 'customer': customer};
    }).get();
  }

  /// Get daily summary
  Future<Map<String, dynamic>> getDailySummary(DateTime date) async {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final todayOrders = await (select(orders)
          ..where((o) =>
              o.orderDate.isBiggerOrEqualValue(startOfDay) &
              o.orderDate.isSmallerThanValue(endOfDay) &
              o.status.isNotIn(['cancelled'])))
        .get();

    final todayPayments = await (select(payments)
          ..where((p) =>
              p.paymentDate.isBiggerOrEqualValue(startOfDay) &
              p.paymentDate.isSmallerThanValue(endOfDay)))
        .get();

    final todayExpenses = await (select(expenses)
          ..where((e) =>
              e.expenseDate.isBiggerOrEqualValue(startOfDay) &
              e.expenseDate.isSmallerThanValue(endOfDay)))
        .get();

    final totalRevenue = todayOrders.fold<double>(
      0.0,
      (sum, o) => sum + o.grandTotal,
    );
    final totalCollected = todayPayments.fold<double>(
      0.0,
      (sum, p) => sum + p.amount,
    );
    final totalExpenses = todayExpenses.fold<double>(
      0.0,
      (sum, e) => sum + e.amount,
    );

    return {
      'ordersCount': todayOrders.length,
      'revenue': totalRevenue,
      'collected': totalCollected,
      'expenses': totalExpenses,
      'profit': totalRevenue - totalExpenses,
      'pendingAmount': totalRevenue - totalCollected,
    };
  }

  /// Get pending payment customers
  Future<List<Map<String, dynamic>>> getPendingPayments() async {
    return (select(customers)
          ..where((c) => c.currentBalance.isBiggerThanValue(0.0))
          ..orderBy([(c) => OrderingTerm.desc(c.currentBalance)]))
        .map((c) => {'customer': c})
        .get();
  }

  /// Get low stock products
  Future<List<Product>> getLowStockProducts() async {
    return (select(products)
          ..where((p) => p.currentStock.isSmallerOrEqual(p.minStock))
          ..where((p) => p.isActive.equals(true)))
        .get();
  }

  /// Search across entities
  Future<Map<String, dynamic>> globalSearch(String query) async {
    final productResults = await (select(products)
          ..where((p) =>
              p.name.like('%$query%') |
              p.sku.like('%$query%') |
              p.barcode.like('%$query%')))
        .get();

    final customerResults = await (select(customers)
          ..where((c) =>
              c.shopName.like('%$query%') |
              c.ownerName.like('%$query%') |
              c.phone.like('%$query%') |
              c.code.like('%$query%')))
        .get();

    final orderResults = await (select(orders)
          ..where((o) => o.orderNumber.like('%$query%')))
        .get();

    return {
      'products': productResults,
      'customers': customerResults,
      'orders': orderResults,
    };
  }

  /// Get monthly revenue data for chart
  Future<List<Map<String, dynamic>>> getMonthlyRevenue(int year) async {
    final results = <Map<String, dynamic>>[];
    for (int month = 1; month <= 12; month++) {
      final start = DateTime(year, month, 1);
      final end = DateTime(year, month + 1, 1);

      final monthOrders = await (select(orders)
            ..where((o) =>
                o.orderDate.isBiggerOrEqualValue(start) &
                o.orderDate.isSmallerThanValue(end) &
                o.status.isNotIn(['cancelled'])))
          .get();

      final revenue = monthOrders.fold<double>(0.0, (s, o) => s + o.grandTotal);
      results.add({'month': month, 'revenue': revenue});
    }
    return results;
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'sr_foods.db'));
    return NativeDatabase.createInBackground(file, logStatements: false);
  });
}
