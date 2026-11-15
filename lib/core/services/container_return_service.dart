import 'package:drift/drift.dart' show Variable;
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

    await db.customStatement(
      'INSERT INTO returnable_containers ('
      'container_type, container_code, customer_id, deposit_amount_minor, status, last_scan_at, notes, created_at'
      ') VALUES (?, ?, ?, ?, ?, ?, ?, ?) '
      'ON CONFLICT(container_code) DO UPDATE SET '
      'customer_id = excluded.customer_id, '
      'deposit_amount_minor = excluded.deposit_amount_minor, '
      'status = \'with_customer\', '
      'last_scan_at = excluded.last_scan_at, '
      'notes = excluded.notes',
      [
        containerType,
        containerCode,
        customerId,
        depositAmountMinor,
        'with_customer',
        now.toIso8601String(),
        notes,
        now.toIso8601String(),
      ],
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

    await db.customStatement(
      'UPDATE returnable_containers SET '
      'customer_id = NULL, '
      'driver_id = ?, '
      'status = ?, '
      'last_scan_at = ?, '
      'notes = ? '
      'WHERE container_code = ?',
      [
        driverId,
        newStatus,
        now.toIso8601String(),
        notes,
        containerCode,
      ],
    );
  }

  /// Computes the total refundable security deposit held for a customer
  Future<Money> trackDeposit({
    required AppDatabase db,
    required int customerId,
  }) async {
    final result = await db.customSelect(
      'SELECT COALESCE(SUM(deposit_amount_minor), 0) as total_deposit '
      'FROM returnable_containers '
      'WHERE customer_id = ? AND status = ?',
      variables: [
        Variable.withInt(customerId),
        Variable.withString('with_customer'),
      ],
    ).getSingle();

    final totalMinor = result.read<int>('total_deposit');
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

    final rows = await db.customSelect(
      'SELECT id, container_code, container_type, customer_id, deposit_amount_minor, last_scan_at '
      'FROM returnable_containers '
      'WHERE status = ? AND last_scan_at < ?',
      variables: [
        Variable.withString('with_customer'),
        Variable.withDateTime(cutoffDate),
      ],
    ).get();

    final alerts = <LostContainerAlert>[];
    for (final r in rows) {
      final id = r.read<int>('id');
      final code = r.read<String>('container_code');
      final type = r.read<String>('container_type');
      final cId = r.read<int?>('customer_id');
      final deposit = r.read<int>('deposit_amount_minor');
      final scanAt = r.read<DateTime>('last_scan_at');
      final daysHeld = currentTime.difference(scanAt).inDays;

      alerts.add(
        LostContainerAlert(
          id: id,
          containerCode: code,
          containerType: type,
          customerId: cId,
          depositHeld: Money(amountMinor: deposit),
          daysWithCustomer: daysHeld,
          lastScanAt: scanAt,
        ),
      );
    }

    return alerts;
  }
}
