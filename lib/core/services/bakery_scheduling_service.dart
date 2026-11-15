import 'package:drift/drift.dart' show Variable;
import '../database/app_database.dart';

class ScheduledSlot {
  final DateTime start;
  final DateTime end;

  const ScheduledSlot({required this.start, required this.end});
}

class OvenScheduleResult {
  final int scheduleId;
  final String ovenId;
  final String ovenType;
  final int productId;
  final int quantity;
  final DateTime proofingStart;
  final DateTime bakeStart;
  final DateTime bakeEnd;
  final DateTime deliveryDate;
  final String status;

  const OvenScheduleResult({
    required this.scheduleId,
    required this.ovenId,
    required this.ovenType,
    required this.productId,
    required this.quantity,
    required this.proofingStart,
    required this.bakeStart,
    required this.bakeEnd,
    required this.deliveryDate,
    required this.status,
  });
}

class OvenCapacityResult {
  final String ovenId;
  final DateTime date;
  final bool hasCapacity;
  final int totalBookedMinutes;
  final List<ScheduledSlot> availableSlots;

  const OvenCapacityResult({
    required this.ovenId,
    required this.date,
    required this.hasCapacity,
    required this.totalBookedMinutes,
    required this.availableSlots,
  });
}

/// Service managing commercial bakery oven scheduling and proofing timelines
class BakerySchedulingService {
  const BakerySchedulingService();

  /// Throws StateError if the requested oven time slot overlaps with an existing booking
  Future<void> blockOverbookedSlot({
    required AppDatabase db,
    required String ovenId,
    required DateTime start,
    required DateTime end,
  }) async {
    final conflicts = await db.customSelect(
      'SELECT id, scheduled_start, scheduled_end FROM oven_schedules '
      'WHERE oven_id = ? AND status != ? AND scheduled_start < ? AND scheduled_end > ?',
      variables: [
        Variable.withString(ovenId),
        Variable.withString('aborted'),
        Variable.withDateTime(end),
        Variable.withDateTime(start),
      ],
    ).get();

    if (conflicts.isNotEmpty) {
      final first = conflicts.first;
      final cStart = first.read<DateTime>('scheduled_start');
      final cEnd = first.read<DateTime>('scheduled_end');
      throw StateError(
        'Oven $ovenId conflict: Already booked from $cStart to $cEnd for requested window ($start to $end).',
      );
    }
  }

  /// Evaluates available operational slots for a given oven and calendar date
  Future<OvenCapacityResult> ovenCapacityCheck({
    required AppDatabase db,
    required String ovenId,
    required DateTime date,
  }) async {
    final dayStart = DateTime(date.year, date.month, date.day, 4, 0); // 04:00 AM shift
    final dayEnd = DateTime(date.year, date.month, date.day, 22, 0); // 10:00 PM shift

    final bookedRows = await db.customSelect(
      'SELECT scheduled_start, scheduled_end FROM oven_schedules '
      'WHERE oven_id = ? AND status != ? AND scheduled_start >= ? AND scheduled_end <= ? '
      'ORDER BY scheduled_start ASC',
      variables: [
        Variable.withString(ovenId),
        Variable.withString('aborted'),
        Variable.withDateTime(dayStart),
        Variable.withDateTime(dayEnd),
      ],
    ).get();

    int totalMinutes = 0;
    final available = <ScheduledSlot>[];
    DateTime cursor = dayStart;

    for (final row in bookedRows) {
      final bStart = row.read<DateTime>('scheduled_start');
      final bEnd = row.read<DateTime>('scheduled_end');
      totalMinutes += bEnd.difference(bStart).inMinutes;

      if (bStart.isAfter(cursor)) {
        available.add(ScheduledSlot(start: cursor, end: bStart));
      }
      if (bEnd.isAfter(cursor)) {
        cursor = bEnd;
      }
    }

    if (dayEnd.isAfter(cursor)) {
      available.add(ScheduledSlot(start: cursor, end: dayEnd));
    }

    final maxShiftMinutes = 18 * 60; // 18 hours operating window
    final hasCapacity = (totalMinutes + 30) <= maxShiftMinutes;

    return OvenCapacityResult(
      ovenId: ovenId,
      date: date,
      hasCapacity: hasCapacity,
      totalBookedMinutes: totalMinutes,
      availableSlots: available,
    );
  }

  /// Schedules a commercial baking batch by reverse-calculating proofing, baking, and cooling times
  Future<OvenScheduleResult> scheduleBatch({
    required AppDatabase db,
    required int productId,
    required int quantity,
    required DateTime deliveryDate,
    String ovenId = 'OVEN-01',
    String ovenType = 'rotary',
    int proofingMinutes = 45,
    int bakingMinutes = 35,
    int coolingMinutes = 60,
    int? batchId,
    String? notes,
  }) async {
    // Reverse calculation
    final bakeEnd = deliveryDate.subtract(Duration(minutes: coolingMinutes));
    final bakeStart = bakeEnd.subtract(Duration(minutes: bakingMinutes));
    final proofingStart = bakeStart.subtract(Duration(minutes: proofingMinutes));

    // Verify slot is available
    await blockOverbookedSlot(
      db: db,
      ovenId: ovenId,
      start: bakeStart,
      end: bakeEnd,
    );

    await db.customStatement(
      'INSERT INTO oven_schedules ('
      'oven_id, oven_type, batch_id, scheduled_start, scheduled_end, '
      'product_id, quantity, status, notes'
      ') VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
      [
        ovenId,
        ovenType,
        batchId,
        bakeStart.toIso8601String(),
        bakeEnd.toIso8601String(),
        productId,
        quantity,
        'scheduled',
        notes ?? 'Proofing start: ${proofingStart.toIso8601String()}',
      ],
    );

    final lastIdRow = await db.customSelect('SELECT last_insert_rowid() as id').getSingle();
    final id = lastIdRow.read<int>('id');

    return OvenScheduleResult(
      scheduleId: id,
      ovenId: ovenId,
      ovenType: ovenType,
      productId: productId,
      quantity: quantity,
      proofingStart: proofingStart,
      bakeStart: bakeStart,
      bakeEnd: bakeEnd,
      deliveryDate: deliveryDate,
      status: 'scheduled',
    );
  }
}
