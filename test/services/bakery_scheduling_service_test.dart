import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:sr_foods/core/database/app_database.dart';
import 'package:sr_foods/core/services/bakery_scheduling_service.dart';

void main() {
  late AppDatabase db;
  late BakerySchedulingService schedulingService;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    schedulingService = const BakerySchedulingService();
  });

  tearDown(() async {
    await db.close();
  });

  group('BakerySchedulingService', () {
    test('scheduleBatch performs correct reverse timeline calculation', () async {
      final deliveryDate = DateTime(2026, 11, 20, 10, 0); // 10:00 AM
      final result = await schedulingService.scheduleBatch(
        db: db,
        productId: 141, // First bakery product
        quantity: 50,
        deliveryDate: deliveryDate,
        ovenId: 'OVEN-ROTARY-01',
        ovenType: 'rotary',
        proofingMinutes: 45,
        bakingMinutes: 35,
        coolingMinutes: 60,
      );

      expect(result.scheduleId, greaterThan(0));
      expect(result.ovenId, equals('OVEN-ROTARY-01'));
      expect(result.ovenType, equals('rotary'));
      expect(result.quantity, equals(50));
      expect(result.status, equals('scheduled'));

      // Cooling: 60m => bakeEnd = 09:00
      expect(result.bakeEnd, equals(DateTime(2026, 11, 20, 9, 0)));
      // Baking: 35m => bakeStart = 08:25
      expect(result.bakeStart, equals(DateTime(2026, 11, 20, 8, 25)));
      // Proofing: 45m => proofingStart = 07:40
      expect(result.proofingStart, equals(DateTime(2026, 11, 20, 7, 40)));
    });

    test('blockOverbookedSlot throws StateError on overlapping window', () async {
      final deliveryDate = DateTime(2026, 11, 20, 10, 0);
      await schedulingService.scheduleBatch(
        db: db,
        productId: 141,
        quantity: 50,
        deliveryDate: deliveryDate,
        ovenId: 'OVEN-01',
        proofingMinutes: 45,
        bakingMinutes: 30,
        coolingMinutes: 30, // bakeStart = 09:00, bakeEnd = 09:30
      );

      // Try overlapping slot: 09:15 to 09:45
      expect(
        () => schedulingService.blockOverbookedSlot(
          db: db,
          ovenId: 'OVEN-01',
          start: DateTime(2026, 11, 20, 9, 15),
          end: DateTime(2026, 11, 20, 9, 45),
        ),
        throwsA(isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('Oven OVEN-01 conflict: Already booked'),
        )),
      );
    });

    test('blockOverbookedSlot allows adjacent and non-overlapping slots', () async {
      final deliveryDate = DateTime(2026, 11, 20, 10, 0);
      await schedulingService.scheduleBatch(
        db: db,
        productId: 141,
        quantity: 50,
        deliveryDate: deliveryDate,
        ovenId: 'OVEN-01',
        bakingMinutes: 30,
        coolingMinutes: 30, // bakeStart = 09:00, bakeEnd = 09:30
      );

      // Adjacent slot right after: 09:30 to 10:00 (should not throw)
      await schedulingService.blockOverbookedSlot(
        db: db,
        ovenId: 'OVEN-01',
        start: DateTime(2026, 11, 20, 9, 30),
        end: DateTime(2026, 11, 20, 10, 0),
      );

      // Non-overlapping slot earlier: 07:00 to 08:00 (should not throw)
      await schedulingService.blockOverbookedSlot(
        db: db,
        ovenId: 'OVEN-01',
        start: DateTime(2026, 11, 20, 7, 0),
        end: DateTime(2026, 11, 20, 8, 0),
      );
    });

    test('blockOverbookedSlot ignores aborted schedules', () async {
      final start = DateTime(2026, 11, 20, 8, 0);
      final end = DateTime(2026, 11, 20, 9, 0);

      await db.into(db.ovenSchedules).insert(
        OvenSchedulesCompanion.insert(
          ovenId: 'OVEN-01',
          ovenType: const Value('deck'),
          scheduledStart: start,
          scheduledEnd: end,
          productId: 141,
          quantity: 20,
          status: const Value('aborted'),
        ),
      );

      // Same slot should be free because existing schedule was aborted
      await schedulingService.blockOverbookedSlot(
        db: db,
        ovenId: 'OVEN-01',
        start: start,
        end: end,
      );
    });

    test('different ovens do not conflict on identical time slot', () async {
      final delivery = DateTime(2026, 11, 20, 10, 0);
      final r1 = await schedulingService.scheduleBatch(
        db: db,
        productId: 141,
        quantity: 30,
        deliveryDate: delivery,
        ovenId: 'OVEN-01',
        ovenType: 'rotary',
      );

      final r2 = await schedulingService.scheduleBatch(
        db: db,
        productId: 142,
        quantity: 40,
        deliveryDate: delivery,
        ovenId: 'OVEN-02',
        ovenType: 'deck',
      );

      expect(r1.scheduleId, isNot(equals(r2.scheduleId)));
      expect(r1.ovenId, equals('OVEN-01'));
      expect(r2.ovenId, equals('OVEN-02'));
    });

    test('ovenCapacityCheck calculates total booked minutes and available slots', () async {
      final date = DateTime(2026, 11, 20);

      // Book 08:00 - 09:00 (60 min)
      await db.into(db.ovenSchedules).insert(
        OvenSchedulesCompanion.insert(
          ovenId: 'OVEN-01',
          ovenType: const Value('deck'),
          scheduledStart: DateTime(2026, 11, 20, 8, 0),
          scheduledEnd: DateTime(2026, 11, 20, 9, 0),
          productId: 141,
          quantity: 25,
          status: const Value('scheduled'),
        ),
      );

      // Book 10:00 - 11:30 (90 min)
      await db.into(db.ovenSchedules).insert(
        OvenSchedulesCompanion.insert(
          ovenId: 'OVEN-01',
          ovenType: const Value('deck'),
          scheduledStart: DateTime(2026, 11, 20, 10, 0),
          scheduledEnd: DateTime(2026, 11, 20, 11, 30),
          productId: 141,
          quantity: 35,
          status: const Value('scheduled'),
        ),
      );

      final cap = await schedulingService.ovenCapacityCheck(
        db: db,
        ovenId: 'OVEN-01',
        date: date,
      );

      expect(cap.ovenId, equals('OVEN-01'));
      expect(cap.hasCapacity, isTrue);
      expect(cap.totalBookedMinutes, equals(150)); // 60 + 90
      expect(cap.availableSlots.length, equals(3));
      // Slot 1: 04:00 to 08:00
      expect(cap.availableSlots[0].start, equals(DateTime(2026, 11, 20, 4, 0)));
      expect(cap.availableSlots[0].end, equals(DateTime(2026, 11, 20, 8, 0)));
      // Slot 2: 09:00 to 10:00
      expect(cap.availableSlots[1].start, equals(DateTime(2026, 11, 20, 9, 0)));
      expect(cap.availableSlots[1].end, equals(DateTime(2026, 11, 20, 10, 0)));
      // Slot 3: 11:30 to 22:00
      expect(cap.availableSlots[2].start, equals(DateTime(2026, 11, 20, 11, 30)));
      expect(cap.availableSlots[2].end, equals(DateTime(2026, 11, 20, 22, 0)));
    });

    test('scheduleBatch writes custom notes and links batchId', () async {
      // First insert production batch
      final batchId = await db.into(db.productionBatches).insert(
        ProductionBatchesCompanion.insert(
          batchNumber: 'BAKE-BATCH-202611-01',
          productId: 141,
          quantityProduced: 100,
          operatorName: 'Head Baker',
          manufacturingDate: DateTime(2026, 11, 20),
          status: const Value('planned'),
        ),
      );

      final result = await schedulingService.scheduleBatch(
        db: db,
        productId: 141,
        quantity: 100,
        deliveryDate: DateTime(2026, 11, 20, 15, 0),
        ovenId: 'OVEN-DECK-03',
        ovenType: 'deck',
        batchId: batchId,
        notes: 'Artisan sourdough rustic bake with high steam injection',
      );

      final row = await (db.select(db.ovenSchedules)..where((t) => t.id.equals(result.scheduleId))).getSingle();
      expect(row.batchId, equals(batchId));
      expect(row.ovenType, equals('deck'));
      expect(row.notes, contains('Artisan sourdough rustic bake'));
      expect(row.quantity, equals(100));
    });

    test('scheduleBatch throws StateError when attempting double booking', () async {
      final delivery = DateTime(2026, 11, 20, 12, 0);

      await schedulingService.scheduleBatch(
        db: db,
        productId: 141,
        quantity: 20,
        deliveryDate: delivery,
        ovenId: 'OVEN-ROTARY-01',
        bakingMinutes: 30,
        coolingMinutes: 30,
      );

      // Attempt second batch on same oven with overlapping schedule
      expect(
        () => schedulingService.scheduleBatch(
          db: db,
          productId: 142,
          quantity: 20,
          deliveryDate: delivery,
          ovenId: 'OVEN-ROTARY-01',
          bakingMinutes: 30,
          coolingMinutes: 30,
        ),
        throwsA(isA<StateError>()),
      );
    });
  });
}
