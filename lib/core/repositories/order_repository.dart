import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/app_database.dart';
import '../database/database_provider.dart';
import 'customer_ledger_repository.dart';

final orderRepositoryProvider = Provider<OrderRepository>((ref) {
  return OrderRepository(
    db: ref.watch(databaseProvider),
    ledgerRepository: ref.watch(customerLedgerRepositoryProvider),
  );
});

class OrderItemInput {
  final int productId;
  final String productName;
  final double price;
  final int quantity;
  final double total;

  OrderItemInput({
    required this.productId,
    required this.productName,
    required this.price,
    required this.quantity,
    required this.total,
  });
}

class OrderRepository {
  final AppDatabase db;
  final CustomerLedgerRepository ledgerRepository;

  OrderRepository({
    required this.db,
    required this.ledgerRepository,
  });

  /// Creates an order, deducts inventory, and charges the customer ledger atomically
  Future<void> createOrder({
    required int customerId,
    required List<OrderItemInput> items,
    required double grandTotal,
  }) async {
    await db.transaction(() async {
      // 1. Create the Order
      final orderId = await db.into(db.orders).insert(
        OrdersCompanion.insert(
          orderNumber: 'ORD-${DateTime.now().millisecondsSinceEpoch}',
          customerId: customerId,
          grandTotal: Value(grandTotal),
          pendingAmount: Value(grandTotal),
        ),
      );

      // 2. Insert Order Items and Update Inventory
      for (final item in items) {
        await db.into(db.orderItems).insert(
          OrderItemsCompanion.insert(
            orderId: orderId,
            productId: item.productId,
            productName: item.productName,
            price: item.price,
            quantity: item.quantity,
            total: item.total,
          ),
        );

        // Deduct from inventory
        final inventoryRow = await (db.select(db.inventory)..where((i) => i.productId.equals(item.productId))).getSingleOrNull();
        if (inventoryRow != null) {
          final newStock = inventoryRow.currentStock - item.quantity;
          await (db.update(db.inventory)..where((i) => i.productId.equals(item.productId))).write(
            InventoryCompanion(
              currentStock: Value(newStock),
              updatedAt: Value(DateTime.now()),
            ),
          );
        }

        // Deduct from product table currentStock
        final productRow = await (db.select(db.products)..where((p) => p.id.equals(item.productId))).getSingle();
        final newProductStock = productRow.currentStock - item.quantity;
        await (db.update(db.products)..where((p) => p.id.equals(item.productId))).write(
          ProductsCompanion(
            currentStock: Value(newProductStock),
            updatedAt: Value(DateTime.now()),
          ),
        );
      }

      // 3. Charge the customer in the ledger
      await ledgerRepository.chargeCustomerForOrder(
        customerId: customerId,
        orderTotal: grandTotal,
      );
    });
  }
}
