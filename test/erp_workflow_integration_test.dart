import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:sr_foods/core/database/app_database.dart';
import 'package:sr_foods/core/domain/recipe.dart';
import 'package:sr_foods/core/services/fefo_inventory_service.dart';
import 'package:sr_foods/core/services/delivery_route_service.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  test('Full ERP Integration Workflow: Production -> BOM Deduction -> FEFO Order -> Van Drop -> Cash Payment', () async {
    // 1. Fetch seeded Product and Raw Materials
    final product = await (db.select(db.products)
          ..where((p) => p.sku.isIn(['SRF-BRD-001', 'SRF-HBP-001'])))
        .getSingle();
    final productId = product.id;

    final maida = await (db.select(db.rawMaterials)..where((r) => r.name.equals('Maida Flour'))).getSingle();
    final maidaId = maida.id;

    final oil = await (db.select(db.rawMaterials)..where((r) => r.name.equals('Refined Sunflower Oil'))).getSingle();
    final oilId = oil.id;

    // Reset initial test stock levels
    await db.updateRawMaterialStock(maidaId, 500.0);
    await db.updateRawMaterialStock(oilId, 100.0);

    // 3. Seed Customer
    final customerId = await db.into(db.customers).insert(
      CustomersCompanion.insert(
        code: 'CUST-001',
        shopName: 'Balaji Kirana & General Store',
        ownerName: 'Venkatesh Rao',
        phone: '9848022338',
        route: const Value('Guntur Main Market'),
        creditLimit: const Value(10000.0),
        currentBalance: const Value(0.0),
      ),
    );

    // =========================================================================
    // STEP A: RECORD PRODUCTION BATCH (+100 packs)
    // =========================================================================
    final mfgDate = DateTime.now();
    final recipe = StandardRecipes.parotaRecipe;
    final expiryDate = mfgDate.add(Duration(days: recipe.shelfLifeDays));
    final batchNumber = 'PB-HBP-20261112-001';

    await db.into(db.productionBatches).insert(
      ProductionBatchesCompanion.insert(
        batchNumber: batchNumber,
        productId: productId,
        operatorName: 'SM Subhani',
        quantityProduced: 100,
        manufacturingDate: mfgDate,
        expiryDate: Value(expiryDate),
        status: const Value('completed'),
      ),
    );

    // Update finished goods inventory
    await (db.update(db.products)..where((p) => p.id.equals(productId))).write(
      const ProductsCompanion(currentStock: Value(100)),
    );

    // Deduct raw materials according to BOM (100 packs = 55kg Maida, 6L Oil)
    final materialsNeeded = recipe.computeMaterialsFor(100);
    expect(materialsNeeded['Maida Flour (kg)'], 55.0);
    expect(materialsNeeded['Refined Sunflower Oil (L)'], 6.0);

    await db.updateRawMaterialStock(maidaId, 500.0 - 55.0);
    await db.updateRawMaterialStock(oilId, 100.0 - 6.0);

    final updatedMaida = await (db.select(db.rawMaterials)..where((r) => r.id.equals(maidaId))).getSingle();
    expect(updatedMaida.currentStock, 445.0);

    final updatedOil = await (db.select(db.rawMaterials)..where((r) => r.id.equals(oilId))).getSingle();
    expect(updatedOil.currentStock, 94.0);

    // =========================================================================
    // STEP B: ORDER PLACEMENT WITH FEFO BATCH ALLOCATION (Order 30 packs)
    // =========================================================================
    final fefoResult = await FefoInventoryService.instance.allocateBatches(
      db: db,
      productId: productId,
      requestedPacks: 30,
    );

    expect(fefoResult.isFullyAllocated, isTrue);
    expect(fefoResult.totalAllocated, 30);
    expect(fefoResult.allocations.first.batchNumber, batchNumber);

    // Create Order
    final orderId = await db.into(db.orders).insert(
      OrdersCompanion.insert(
        orderNumber: 'ORD-20261112-001',
        customerId: customerId,
        subtotal: const Value(3000.0),
        grandTotal: const Value(3000.0),
        pendingAmount: const Value(3000.0),
        paymentMethod: const Value('credit'),
        paymentStatus: const Value('unpaid'),
        status: const Value('processing'),
      ),
    );

    await db.into(db.orderItems).insert(
      OrderItemsCompanion.insert(
        orderId: orderId,
        productId: productId,
        productName: 'Half Boiled Parota',
        price: 100.0,
        quantity: 30,
        total: 3000.0,
        batchNumber: Value(fefoResult.batchSummaryString),
      ),
    );

    // Update customer running credit balance
    await (db.update(db.customers)..where((c) => c.id.equals(customerId))).write(
      const CustomersCompanion(currentBalance: Value(3000.0)),
    );

    final customerAfterOrder = await (db.select(db.customers)..where((c) => c.id.equals(customerId))).getSingle();
    expect(customerAfterOrder.currentBalance, 3000.0);

    // =========================================================================
    // STEP C: DELIVERY DISPATCH & ON-SPOT CASH COLLECTION
    // =========================================================================
    final routes = await DeliveryRouteService.instance.getActiveRoutes(db);
    expect(routes.isNotEmpty, isTrue);
    final routeSummary = routes.firstWhere((r) => r.routeName == 'Guntur Main Market');
    expect(routeSummary.totalStops, 1);
    expect(routeSummary.stops.first.orderId, orderId);

    // Driver delivers and collects ₹3,000 cash on spot
    await DeliveryRouteService.instance.completeDeliveryDrop(
      db: db,
      stop: routeSummary.stops.first,
      cashCollected: 3000.0,
      paymentMethod: 'cash',
      recipientNote: 'Received by Venkatesh Rao (Shop Owner)',
      driverName: 'Ramu (Van 1)',
    );

    // Verify order is delivered
    final deliveredOrder = await (db.select(db.orders)..where((o) => o.id.equals(orderId))).getSingle();
    expect(deliveredOrder.status, 'delivered');
    expect(deliveredOrder.paymentStatus, 'paid');
    expect(deliveredOrder.pendingAmount, 0.0);

    // Verify customer balance settled to ₹0
    final settledCustomer = await (db.select(db.customers)..where((c) => c.id.equals(customerId))).getSingle();
    expect(settledCustomer.currentBalance, 0.0);

    // Verify Activity Log was recorded
    final activityLogs = await db.getRecentActivityLogs();
    expect(activityLogs.any((l) => l.action == 'DELIVERY_COMPLETED'), isTrue);
  });
}
