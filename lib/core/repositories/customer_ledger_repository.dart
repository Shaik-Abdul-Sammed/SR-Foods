import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/app_database.dart';
import '../database/database_provider.dart';

final customerLedgerRepositoryProvider = Provider<CustomerLedgerRepository>((ref) {
  return CustomerLedgerRepository(ref.watch(databaseProvider));
});

class CustomerLedgerRepository {
  final AppDatabase _db;

  CustomerLedgerRepository(this._db);

  /// Records a payment and updates the customer's ledger atomically
  Future<void> recordPayment({
    required int customerId,
    required double amount,
    required String method,
    String? upiTransactionId,
  }) async {
    await _db.transaction(() async {
      // 1. Insert payment record
      await _db.into(_db.payments).insert(
        PaymentsCompanion.insert(
          receiptNumber: 'RCPT-${DateTime.now().millisecondsSinceEpoch}',
          customerId: customerId,
          amount: amount,
          method: method,
          upiTransactionId: Value(upiTransactionId),
        ),
      );

      // 2. Update customer balance (Decrease debt)
      final customer = await (_db.select(_db.customers)..where((c) => c.id.equals(customerId))).getSingle();
      final newBalance = customer.currentBalance - amount;
      
      await (_db.update(_db.customers)..where((c) => c.id.equals(customerId))).write(
        CustomersCompanion(
          currentBalance: Value(newBalance),
          updatedAt: Value(DateTime.now()),
        ),
      );
    });
  }

  /// Charges the customer for an order (Increases debt)
  Future<void> chargeCustomerForOrder({
    required int customerId,
    required double orderTotal,
  }) async {
    await _db.transaction(() async {
      final customer = await (_db.select(_db.customers)..where((c) => c.id.equals(customerId))).getSingle();
      final newBalance = customer.currentBalance + orderTotal;
      
      await (_db.update(_db.customers)..where((c) => c.id.equals(customerId))).write(
        CustomersCompanion(
          currentBalance: Value(newBalance),
          updatedAt: Value(DateTime.now()),
        ),
      );
    });
  }
}
