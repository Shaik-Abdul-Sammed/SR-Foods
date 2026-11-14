import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

import 'tables.dart';
import 'catalog_seed_100.dart';
import 'catalog_seed_dairy.dart';

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
    SyncQueue,
    RawMaterials,
    HygieneLogs,
    Entities,
    Distributors,
    ExportOrders,
    ExportLines,
    ExportShipments,
    ComplianceProfiles,
    FxRates,
    HsCodes,
    CustomerPriceLists,
    CreditNotes,
    DebitNotes,
    StandingOrders,
    MachineEvents,
    WastageLogs,
    ReturnLogs,
    Complaints,
    MilkProcurements,
    FatPricingRules,
    OvenSchedules,
    CustomOrders,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());
  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 6;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) async {
          await m.createAll();
          await _seedDefaultData();
        },
        onUpgrade: (Migrator m, int from, int to) async {
          if (from < 2) {
            await m.createTable(syncQueue);
          }
          if (from < 3) {
            await m.createTable(rawMaterials);
            await m.createTable(hygieneLogs);
          }
          if (from < 4) {
            await m.createTable(entities);
            await m.createTable(distributors);
            await m.createTable(exportOrders);
            await m.createTable(exportLines);
            await m.createTable(exportShipments);
            await m.createTable(complianceProfiles);
            await m.createTable(fxRates);
            await m.createTable(hsCodes);
          }
          if (from < 5) {
            await m.addColumn(products, products.storageType);
            await m.addColumn(products, products.allergens);
            await m.addColumn(products, products.hsnCode);
            await m.addColumn(products, products.shelfLifeDays);
            await m.addColumn(products, products.unitsPerInnerPack);
            await m.addColumn(products, products.packsPerMasterCarton);
            await m.addColumn(products, products.gtin);
            await m.addColumn(products, products.fssaiCategoryCode);
            await m.addColumn(products, products.nutritionPer100gJson);
            await m.addColumn(products, products.primaryMarkets);
            await m.addColumn(products, products.priceBandCurrency);
            await m.createTable(customerPriceLists);
            await m.createTable(creditNotes);
            await m.createTable(debitNotes);
            await m.createTable(standingOrders);
            await m.createTable(machineEvents);
            await m.createTable(wastageLogs);
            await m.createTable(returnLogs);
            await m.createTable(complaints);

            // Backfill existing products with compliant baseline
            await customStatement(
              'UPDATE products SET '
              "storage_type = 'chilled', "
              "allergens = 'Wheat (Gluten)', "
              "hsn_code = '1905.90.90', "
              'shelf_life_days = 7, '
              'units_per_inner_pack = 1, '
              'packs_per_master_carton = 20, '
              "price_band_currency = 'INR' "
              "WHERE storage_type IS NULL OR storage_type = ''",
            );
          }
          if (from < 6) {
            await m.addColumn(appSettings, appSettings.activeVerticalsJson);
            await m.addColumn(appSettings, appSettings.primaryVertical);
            await m.addColumn(products, products.fatPercentExpected);
            await m.addColumn(products, products.snfPercentExpected);
            await m.addColumn(products, products.milkType);
            await m.addColumn(products, products.procurementSlot);
            await m.addColumn(products, products.isPasteurized);
            await m.addColumn(products, products.isCultured);
            await m.addColumn(products, products.bakeDateRequired);
            await m.addColumn(products, products.proofingMinutes);
            await m.addColumn(products, products.ovenType);
            await m.addColumn(products, products.freshnessWindowHours);
            await m.addColumn(products, products.dayOldDiscountPercent);
            await m.addColumn(products, products.isCustomOrder);
            await m.addColumn(productionBatches, productionBatches.fatPercentActual);
            await m.addColumn(productionBatches, productionBatches.snfPercentActual);
            await m.addColumn(productionBatches, productionBatches.milkSupplierId);
            await m.addColumn(productionBatches, productionBatches.chillingCenterId);
            await m.addColumn(productionBatches, productionBatches.pasteurizationTempC);
            await m.addColumn(productionBatches, productionBatches.pasteurizationDurationSec);
            await m.addColumn(productionBatches, productionBatches.bakedAt);
            await m.addColumn(productionBatches, productionBatches.proofedAt);
            await m.addColumn(productionBatches, productionBatches.ovenId);
            await m.addColumn(productionBatches, productionBatches.freshnessUntil);
            await m.addColumn(productionBatches, productionBatches.dayOldAppliedAt);
            await m.createTable(milkProcurements);
            await m.createTable(fatPricingRules);
            await m.createTable(ovenSchedules);
            await m.createTable(customOrders);
            await customStatement(
              "INSERT OR IGNORE INTO fat_pricing_rules (id, name, base_rate_per_liter_minor, base_fat_percent, fat_slab_step, price_step_per_liter_minor, is_active) VALUES "
              "(1, 'Standard Cow Milk Rule', 3800, 3.5, 0.1, 30, 1), "
              "(2, 'Premium Buffalo Milk Rule', 5800, 6.0, 0.1, 40, 1)",
            );
            await customStatement(
              'UPDATE app_settings SET '
              "active_verticals_json = '[\"frozen\"]', "
              "primary_vertical = 'frozen' "
              'WHERE active_verticals_json IS NULL',
            );
            await customStatement(
              "INSERT OR IGNORE INTO app_settings (key, value, type) VALUES ('active_verticals', '[\"frozen\"]', 'json')",
            );
            await customStatement(
              "INSERT OR IGNORE INTO app_settings (key, value, type) VALUES ('primary_vertical', 'frozen', 'string')",
            );
          }
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
    // Insert 100-SKU master catalog
    final catalog100 = get100CatalogSkus();

    for (final product in catalog100) {
      final productId = await into(products).insert(product);
      // Create inventory entry for each product
      await into(inventory).insert(
        InventoryCompanion.insert(
          productId: productId,
          openingStock: const Value(50),
          currentStock: const Value(50),
        ),
      );
    }

    // Insert 40-SKU Dairy master catalog
    final catalogDairy = get40DairySkus();
    for (final product in catalogDairy) {
      final productId = await into(products).insert(product);
      await into(inventory).insert(
        InventoryCompanion.insert(
          productId: productId,
          openingStock: const Value(30),
          currentStock: const Value(30),
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
      ('fssai_license_number', '10123999000123'),
      ('fssai_license_valid_till', '2027-12-31'),
      ('min_gross_margin_pct', '25.0'),
      ('active_verticals', '["frozen"]'),
      ('primary_vertical', 'frozen'),
    ];

    for (final (key, value) in defaultSettings) {
      await into(appSettings).insert(
        AppSettingsCompanion.insert(key: key, value: value),
      );
    }

    // Insert default factory raw materials
    final defaultMaterials = [
      RawMaterialsCompanion.insert(
        name: 'Maida Flour',
        category: 'flour',
        currentStock: const Value(500.0),
        unit: const Value('kg'),
        minStock: const Value(150.0),
        lastPurchasePrice: const Value(38.0),
      ),
      RawMaterialsCompanion.insert(
        name: 'Whole Wheat Atta',
        category: 'flour',
        currentStock: const Value(400.0),
        unit: const Value('kg'),
        minStock: const Value(120.0),
        lastPurchasePrice: const Value(42.0),
      ),
      RawMaterialsCompanion.insert(
        name: 'Refined Sunflower Oil',
        category: 'oil',
        currentStock: const Value(120.0),
        unit: const Value('L'),
        minStock: const Value(40.0),
        lastPurchasePrice: const Value(135.0),
      ),
      RawMaterialsCompanion.insert(
        name: 'Iodized Salt',
        category: 'salt',
        currentStock: const Value(60.0),
        unit: const Value('kg'),
        minStock: const Value(20.0),
        lastPurchasePrice: const Value(18.0),
      ),
      RawMaterialsCompanion.insert(
        name: 'Food Grade Pouches (50u)',
        category: 'packaging',
        currentStock: const Value(3500.0),
        unit: const Value('pcs'),
        minStock: const Value(800.0),
        lastPurchasePrice: const Value(1.80),
      ),
    ];

    for (final rm in defaultMaterials) {
      await into(rawMaterials).insert(rm);
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

  /// Log an activity for security, audit, and compliance
  Future<void> logActivity({
    required String action,
    String? entityType,
    int? entityId,
    String? details,
    String? userId,
  }) async {
    await into(activityLogs).insert(
      ActivityLogsCompanion.insert(
        action: action,
        entityType: Value(entityType),
        entityId: Value(entityId),
        details: Value(details),
        userId: Value(userId),
        createdAt: Value(DateTime.now()),
      ),
    );
  }

  /// Get recent activity logs for audit view (up to limit, default 200)
  Future<List<ActivityLog>> getRecentActivityLogs({int limit = 200}) async {
    return (select(activityLogs)
          ..orderBy([(l) => OrderingTerm.desc(l.createdAt)])
          ..limit(limit))
        .get();
  }

  /// Enqueue an action into the offline-first sync queue
  Future<int> enqueueSync({
    required String action,
    required String entityType,
    required String payload,
  }) async {
    return into(syncQueue).insert(
      SyncQueueCompanion.insert(
        action: action,
        entityType: entityType,
        payload: payload,
      ),
    );
  }

  /// Get all raw materials
  Future<List<RawMaterial>> getAllRawMaterials() async {
    return (select(rawMaterials)..orderBy([(r) => OrderingTerm.asc(r.name)])).get();
  }

  /// Get raw materials with stock below minStock reorder point
  Future<List<RawMaterial>> getLowStockRawMaterials() async {
    return (select(rawMaterials)
          ..where((r) => r.currentStock.isSmallerOrEqual(r.minStock))
          ..orderBy([(r) => OrderingTerm.asc(r.currentStock)]))
        .get();
  }

  /// Deduct or adjust raw material stock
  Future<void> updateRawMaterialStock(int materialId, double newStock) async {
    await (update(rawMaterials)..where((r) => r.id.equals(materialId))).write(
      RawMaterialsCompanion(
        currentStock: Value(newStock),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Record a daily hygiene & food safety inspection log
  Future<int> recordHygieneLog({
    required String inspectorName,
    required double doughChillingTemp,
    required bool surfacesSanitized,
    required bool personalHygienePassed,
    required bool pestActivityDetected,
    String? notes,
  }) async {
    final status = (!pestActivityDetected && surfacesSanitized && personalHygienePassed && doughChillingTemp <= 6.0)
        ? 'pass'
        : 'flag';
    return into(hygieneLogs).insert(
      HygieneLogsCompanion.insert(
        inspectorName: inspectorName,
        doughChillingTemp: doughChillingTemp,
        surfacesSanitized: Value(surfacesSanitized),
        personalHygienePassed: Value(personalHygienePassed),
        pestActivityDetected: Value(pestActivityDetected),
        status: Value(status),
        notes: Value(notes),
        inspectionDate: Value(DateTime.now()),
      ),
    );
  }

  /// Get recent hygiene logs for FSSAI compliance audit
  Future<List<HygieneLog>> getRecentHygieneLogs({int limit = 30}) async {
    return (select(hygieneLogs)
          ..orderBy([(h) => OrderingTerm.desc(h.inspectionDate)])
          ..limit(limit))
        .get();
  }

  /// Get batches expiring within given number of days
  Future<List<ProductionBatche>> getExpiringBatches({int days = 5}) async {
    final threshold = DateTime.now().add(Duration(days: days));
    return (select(productionBatches)
          ..where((b) => b.expiryDate.isSmallerOrEqualValue(threshold) & b.status.equals('completed'))
          ..orderBy([(b) => OrderingTerm.asc(b.expiryDate)]))
        .get();
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'sr_foods.db'));
    return NativeDatabase.createInBackground(file, logStatements: false);
  });
}
