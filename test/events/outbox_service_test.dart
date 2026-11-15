import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:sr_foods/core/database/app_database.dart';
import 'package:sr_foods/core/events/domain_event.dart';
import 'package:sr_foods/core/services/outbox_service.dart';

void main() {
  late AppDatabase db;
  late OutboxService outboxService;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    outboxService = const OutboxService();
  });

  tearDown(() async {
    await db.close();
  });

  group('Transactional Outbox Service Tests', () {
    test('1. enqueue saves event with pending status and valid payload', () async {
      final event = OrderPlacedEvent(
        orderId: 777,
        customerId: 10,
        totalAmountMinor: 150000,
        vertical: 'bakery',
      );

      final rowId = await outboxService.enqueue(db, event);
      expect(rowId, greaterThan(0));

      final row = await (db.select(db.outboxEvents)..where((t) => t.id.equals(rowId))).getSingle();
      expect(row.eventId, equals(event.eventId));
      expect(row.eventType, equals('OrderPlaced'));
      expect(row.status, equals('pending'));
      expect(row.payload, contains('"orderId":777'));
      expect(row.retryCount, equals(0));
    });

    test('2. dispatchPending delivers events and marks status dispatched with timestamp', () async {
      await outboxService.enqueue(
        db,
        MilkCollectedEvent(
          supplierId: 'VILL-1',
          quantityLiters: 100.0,
          fatPercent: 4.5,
          snfPercent: 8.5,
          totalAmountMinor: 450000,
        ),
      );

      final result = await outboxService.dispatchPending(
        db: db,
        transport: (event) async => true, // Mock successful delivery
      );

      expect(result.dispatchedCount, equals(1));
      expect(result.failedCount, equals(0));

      final rows = await db.select(db.outboxEvents).get();
      expect(rows.first.status, equals('dispatched'));
      expect(rows.first.dispatchedAt, isNotNull);
    });

    test('3. dispatchPending increments retryCount and records lastError on failure', () async {
      await outboxService.enqueue(
        db,
        ContainerIssuedEvent(
          containerCode: 'CAN-ERR-1',
          customerId: 2,
          depositAmountMinor: 50000,
        ),
      );

      final result = await outboxService.dispatchPending(
        db: db,
        transport: (event) async => throw Exception('503 Service Unavailable'),
      );

      expect(result.dispatchedCount, equals(0));
      expect(result.failedCount, equals(1));

      final rows = await db.select(db.outboxEvents).get();
      final failedRow = rows.first;
      expect(failedRow.status, equals('failed'));
      expect(failedRow.retryCount, equals(1));
      expect(failedRow.lastError, contains('503 Service Unavailable'));
      expect(failedRow.nextRetryAt, isNotNull);
    });

    test('4. dispatchPending retries previously failed events when backoff expires', () async {
      // Seed a failed event whose nextRetryAt is in the past
      final pastDate = DateTime.now().subtract(const Duration(minutes: 10));
      await db.into(db.outboxEvents).insert(
        OutboxEventsCompanion.insert(
          eventId: 'RETRY-EV-01',
          eventType: 'OrderPlaced',
          payload: '{"orderId":999}',
          status: const Value('failed'),
          retryCount: const Value(1),
          nextRetryAt: Value(pastDate),
        ),
      );

      final result = await outboxService.dispatchPending(
        db: db,
        transport: (event) async => true, // Succeeds on retry
      );

      expect(result.dispatchedCount, equals(1));
      final row = await (db.select(db.outboxEvents)..where((t) => t.eventId.equals('RETRY-EV-01'))).getSingle();
      expect(row.status, equals('dispatched'));
    });

    test('5. dispatchPending respects batchSize constraint', () async {
      for (int i = 1; i <= 5; i++) {
        await outboxService.enqueue(
          db,
          OrderDeliveredEvent(orderId: i),
        );
      }

      final result = await outboxService.dispatchPending(
        db: db,
        batchSize: 3,
        transport: (e) async => true,
      );

      expect(result.dispatchedCount, equals(3));
      final remainingPending = await outboxService.pendingCount(db);
      expect(remainingPending, equals(2));
    });

    test('6. pendingCount returns accurate active count', () async {
      expect(await outboxService.pendingCount(db), equals(0));

      await outboxService.enqueue(db, OrderDeliveredEvent(orderId: 10));
      await outboxService.enqueue(db, OrderDeliveredEvent(orderId: 11));

      expect(await outboxService.pendingCount(db), equals(2));
    });

    test('7. purgeDispatched cleans up old dispatched records without touching active events', () async {
      final oldDate = DateTime.now().subtract(const Duration(days: 15));

      // Old dispatched (should be purged)
      await db.into(db.outboxEvents).insert(
        OutboxEventsCompanion.insert(
          eventId: 'OLD-DISPATCHED-01',
          eventType: 'OrderDelivered',
          payload: '{}',
          status: const Value('dispatched'),
          dispatchedAt: Value(oldDate),
        ),
      );

      // Recent dispatched (should NOT be purged)
      await db.into(db.outboxEvents).insert(
        OutboxEventsCompanion.insert(
          eventId: 'RECENT-DISPATCHED-02',
          eventType: 'OrderDelivered',
          payload: '{}',
          status: const Value('dispatched'),
          dispatchedAt: Value(DateTime.now()),
        ),
      );

      // Pending event (should NEVER be purged)
      await outboxService.enqueue(db, OrderDeliveredEvent(orderId: 99));

      final purged = await outboxService.purgeDispatched(db, olderThan: const Duration(days: 7));
      expect(purged, equals(1));

      final remaining = await db.select(db.outboxEvents).get();
      expect(remaining.length, equals(2));
      expect(remaining.map((r) => r.eventId), containsAll(['RECENT-DISPATCHED-02']));
    });
  });
}
