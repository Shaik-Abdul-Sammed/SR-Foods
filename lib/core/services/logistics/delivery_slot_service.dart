import 'package:drift/drift.dart';
import '../../database/app_database.dart';

class DeliverySlotService {
  final AppDatabase db;

  DeliverySlotService(this.db);

  /// Creates a delivery booking slot.
  Future<int> createSlot({
    required String slotName,
    required DateTime slotDate,
    required DateTime startTime,
    required DateTime endTime,
    int maxCapacityOrders = 50,
  }) async {
    return db.into(db.deliverySlots).insert(
          DeliverySlotsCompanion.insert(
            slotName: slotName,
            slotDate: slotDate,
            startTime: startTime,
            endTime: endTime,
            maxCapacityOrders: Value(maxCapacityOrders),
            bookedOrdersCount: const Value(0),
            status: const Value('open'),
          ),
        );
  }

  /// Retrieves available (non-full, open) slots for a given date.
  Future<List<DeliverySlot>> getAvailableSlots(DateTime date) async {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);

    return (db.select(db.deliverySlots)
          ..where((tbl) =>
              tbl.slotDate.isBiggerOrEqualValue(startOfDay) &
              tbl.slotDate.isSmallerOrEqualValue(endOfDay) &
              tbl.status.equals('open')))
        .get();
  }

  /// Attempts to book an order into a delivery slot.
  /// Returns true if successfully booked; false if slot is full or closed.
  Future<bool> bookSlot(int slotId) async {
    final slot = await (db.select(db.deliverySlots)..where((tbl) => tbl.id.equals(slotId))).getSingleOrNull();
    if (slot == null || slot.status != 'open') {
      return false;
    }

    final newCount = slot.bookedOrdersCount + 1;
    final isFull = newCount >= slot.maxCapacityOrders;

    await (db.update(db.deliverySlots)..where((tbl) => tbl.id.equals(slotId))).write(
      DeliverySlotsCompanion(
        bookedOrdersCount: Value(newCount),
        status: Value(isFull ? 'full' : 'open'),
      ),
    );

    return true;
  }

  /// Cancels an order booking and decrements the slot booking count.
  Future<void> cancelBooking(int slotId) async {
    final slot = await (db.select(db.deliverySlots)..where((tbl) => tbl.id.equals(slotId))).getSingleOrNull();
    if (slot == null) return;

    final newCount = (slot.bookedOrdersCount - 1).clamp(0, slot.maxCapacityOrders);
    await (db.update(db.deliverySlots)..where((tbl) => tbl.id.equals(slotId))).write(
      DeliverySlotsCompanion(
        bookedOrdersCount: Value(newCount),
        status: const Value('open'),
      ),
    );
  }
}
