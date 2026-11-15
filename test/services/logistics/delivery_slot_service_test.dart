import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sr_foods/core/database/app_database.dart';
import 'package:sr_foods/core/services/logistics/delivery_slot_service.dart';

void main() {
  late AppDatabase db;
  late DeliverySlotService service;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    service = DeliverySlotService(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('DeliverySlotService Tests', () {
    test('1. Creates slot and queries available slots for date', () async {
      final now = DateTime.now();
      final slotId = await service.createSlot(
        slotName: 'morning',
        slotDate: now,
        startTime: now,
        endTime: now.add(const Duration(hours: 3)),
        maxCapacityOrders: 2,
      );

      expect(slotId, greaterThan(0));

      final available = await service.getAvailableSlots(now);
      expect(available.length, 1);
      expect(available.first.slotName, 'morning');
    });

    test('2. Books slot until capacity is reached, transition status to full', () async {
      final now = DateTime.now();
      final slotId = await service.createSlot(
        slotName: 'morning',
        slotDate: now,
        startTime: now,
        endTime: now.add(const Duration(hours: 3)),
        maxCapacityOrders: 2,
      );

      final book1 = await service.bookSlot(slotId);
      expect(book1, isTrue);

      final book2 = await service.bookSlot(slotId);
      expect(book2, isTrue);

      // 3rd booking fails because slot is full
      final book3 = await service.bookSlot(slotId);
      expect(book3, isFalse);

      final available = await service.getAvailableSlots(now);
      expect(available, isEmpty); // Full slot is not listed in open slots
    });

    test('3. Canceling booking re-opens slot capacity', () async {
      final now = DateTime.now();
      final slotId = await service.createSlot(
        slotName: 'evening',
        slotDate: now,
        startTime: now,
        endTime: now.add(const Duration(hours: 3)),
        maxCapacityOrders: 1,
      );

      await service.bookSlot(slotId);
      expect(await service.getAvailableSlots(now), isEmpty);

      await service.cancelBooking(slotId);
      final available = await service.getAvailableSlots(now);
      expect(available.length, 1);
    });
  });
}
