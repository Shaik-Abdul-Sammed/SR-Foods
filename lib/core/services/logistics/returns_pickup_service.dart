import 'package:drift/drift.dart';
import '../../database/app_database.dart';

class PickupRequest {
  final int customerId;
  final String containerType;
  final int quantity;
  final int depositPerUnitMinor;
  final String? reason; // 'empty_container', 'expired_stock', 'damaged'

  const PickupRequest({
    required this.customerId,
    required this.containerType,
    required this.quantity,
    this.depositPerUnitMinor = 20000, // ₹200.00 default deposit for insulated crate/can
    this.reason = 'empty_container',
  });
}

class PickupResult {
  final int totalUnitsCollected;
  final int totalDepositRefundMinor;
  final bool isProcessed;

  const PickupResult({
    required this.totalUnitsCollected,
    required this.totalDepositRefundMinor,
    required this.isProcessed,
  });

  double get depositRefundRupees => totalDepositRefundMinor / 100.0;
}

/// Reverse logistics scheduler for returnable crates, milk cans, and damaged/expired returns.
class ReturnsPickupService {
  final AppDatabase db;

  ReturnsPickupService(this.db);

  /// Schedules and processes a container return pickup.
  Future<PickupResult> processPickup(PickupRequest request) async {
    final totalRefundMinor = request.quantity * request.depositPerUnitMinor;
    final now = DateTime.now();

    // Insert records for returned container units
    for (int i = 0; i < request.quantity; i++) {
      final code = '${request.containerType.toUpperCase()}-${request.customerId}-${now.millisecondsSinceEpoch}-$i';
      await db.into(db.returnableContainers).insert(
            ReturnableContainersCompanion.insert(
              containerType: request.containerType,
              containerCode: code,
              customerId: Value(request.customerId),
              depositAmountMinor: Value(request.depositPerUnitMinor),
              status: const Value('returned'),
              lastScanAt: Value(now),
              notes: Value(request.reason),
            ),
          );
    }

    return PickupResult(
      totalUnitsCollected: request.quantity,
      totalDepositRefundMinor: totalRefundMinor,
      isProcessed: true,
    );
  }

  /// Calculates total unreturned containers and deposit held for a customer.
  Future<int> getCustomerOutstandingDepositMinor(int customerId) async {
    final rows = await (db.select(db.returnableContainers)..where((tbl) => tbl.customerId.equals(customerId))).get();

    int balanceMinor = 0;
    for (final r in rows) {
      if (r.status == 'with_customer') {
        balanceMinor += r.depositAmountMinor;
      } else if (r.status == 'returned') {
        balanceMinor -= r.depositAmountMinor;
      }
    }
    return balanceMinor < 0 ? 0 : balanceMinor;
  }
}
