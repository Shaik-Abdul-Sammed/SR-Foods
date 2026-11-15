import 'package:drift/drift.dart';
import '../database/app_database.dart';
import '../domain/money.dart';

class LostContainerAlert {
  final int id;
  final String containerCode;
  final String containerType;
  final int? customerId;
  final Money depositHeld;
  final int daysWithCustomer;
  final DateTime lastScanAt;

  const LostContainerAlert({
    required this.id,
    required this.containerCode,
    required this.containerType,
    this.customerId,
    required this.depositHeld,
    required this.daysWithCustomer,
    required this.lastScanAt,
  });
}

/// Service managing reusable crates, 40L milk cans, and bakery transport trays
class ContainerReturnService {
  const ContainerReturnService();

  /// Issues a returnable container to a customer and records the refundable deposit
  Future<void> issueContainer({
    required AppDatabase db,
    required String containerCode,
    required int customerId,
    required int depositAmountMinor,
    String containerType = 'crate',
    String? notes,
  }) async {
    final now = DateTime.now();

    await db.into(db.returnableContainers).insert(
      ReturnableContainersCompanion.insert(
        containerType: containerType,
        containerCode: containerCode,
        customerId: Value(customerId),
        depositAmountMinor: Value(depositAmountMinor),
        status: const Value('with_customer'),
        lastScanAt: Value(now),
        notes: Value(notes),
        createdAt: Value(now),
      ),
      onConflict: DoUpdate(
        (old) => ReturnableContainersCompanion.custom(
          customerId: Variable<int>(customerId),
          depositAmountMinor: Variable<int>(depositAmountMinor),
          status: const Constant('with_customer'),
          lastScanAt: Variable<DateTime>(now),
          notes: notes != null ? Variable<String>(notes) : const Constant(null),
        ),
        target: [db.returnableContainers.containerCode],
      ),
    );
  }

  /// Processes returned container scanned by delivery driver and evaluates condition
  Future<void> returnContainer({
    required AppDatabase db,
    required String containerCode,
    int? driverId,
    String condition = 'good', // 'good' | 'damaged'
    String? notes,
  }) async {
    final now = DateTime.now();
    final newStatus = condition == 'damaged' ? 'damaged' : 'returned';

    await (db.update(db.returnableContainers)
          ..where((t) => t.containerCode.equals(containerCode)))
        .write(
      ReturnableContainersCompanion(
        customerId: const Value(null),
        driverId: Value(driverId),
        status: Value(newStatus),
        lastScanAt: Value(now),
        notes: Value(notes),
      ),
    );
  }

  /// Computes the total refundable security deposit held for a customer
  Future<Money> trackDeposit({
    required AppDatabase db,
    required int customerId,
  }) async {
    final totalMinorExp = db.returnableContainers.depositAmountMinor.sum();
    final query = db.selectOnly(db.returnableContainers)
      ..addColumns([totalMinorExp])
      ..where(db.returnableContainers.customerId.equals(customerId) &
          db.returnableContainers.status.equals('with_customer'));
    final row = await query.getSingle();
    final totalMinor = row.read(totalMinorExp) ?? 0;
    return Money(amountMinor: totalMinor);
  }

  /// Flags containers that have been with a customer longer than the allowed retention period
  Future<List<LostContainerAlert>> flagLostContainers({
    required AppDatabase db,
    int days = 14,
    DateTime? now,
  }) async {
    final currentTime = now ?? DateTime.now();
    final cutoffDate = currentTime.subtract(Duration(days: days));

    final rows = await (db.select(db.returnableContainers)
          ..where((t) =>
              t.status.equals('with_customer') &
              t.lastScanAt.isSmallerThanValue(cutoffDate)))
        .get();

    final alerts = <LostContainerAlert>[];
    for (final r in rows) {
      final daysHeld = currentTime.difference(r.lastScanAt).inDays;
      alerts.add(
        LostContainerAlert(
          id: r.id,
          containerCode: r.containerCode,
          containerType: r.containerType,
          customerId: r.customerId,
          depositHeld: Money(amountMinor: r.depositAmountMinor),
          daysWithCustomer: daysHeld,
          lastScanAt: r.lastScanAt,
        ),
      );
    }

    return alerts;
  }
}
