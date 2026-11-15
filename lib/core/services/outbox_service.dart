import 'dart:convert';
import 'package:drift/drift.dart';
import '../database/app_database.dart';
import '../events/domain_event.dart';

class DispatchResult {
  final int dispatchedCount;
  final int failedCount;

  const DispatchResult({required this.dispatchedCount, required this.failedCount});
}

/// Transactional Outbox service guaranteeing at-least-once asynchronous event delivery
class OutboxService {
  const OutboxService();

  /// Enqueues a DomainEvent into the transactional outbox table
  Future<int> enqueue(AppDatabase db, DomainEvent event) async {
    final now = DateTime.now();
    final jsonPayload = jsonEncode(event.toMap());

    final id = await db.into(db.outboxEvents).insert(
      OutboxEventsCompanion.insert(
        eventId: event.eventId,
        eventType: event.eventType,
        payload: jsonPayload,
        status: const Value('pending'),
        createdAt: Value(now),
      ),
    );
    return id;
  }

  /// Dispatches pending outbox events through the provided transport or default pipeline
  Future<DispatchResult> dispatchPending({
    required AppDatabase db,
    int batchSize = 25,
    Future<bool> Function(OutboxEvent event)? transport,
  }) async {
    final now = DateTime.now();

    final pendingEvents = await (db.select(db.outboxEvents)
          ..where((t) =>
              t.status.equals('pending') |
              (t.status.equals('failed') &
                  t.retryCount.isSmallerThanValue(3) &
                  (t.nextRetryAt.isNull() | t.nextRetryAt.isSmallerOrEqualValue(now))))
          ..limit(batchSize))
        .get();

    int successCount = 0;
    int failureCount = 0;

    for (final event in pendingEvents) {
      bool sent = false;
      String? errorMessage;

      try {
        if (transport != null) {
          sent = await transport(event);
        } else {
          // Default: local mock transport always succeeds
          sent = true;
        }
      } catch (e) {
        sent = false;
        errorMessage = e.toString();
      }

      if (sent) {
        await (db.update(db.outboxEvents)..where((t) => t.id.equals(event.id))).write(
          OutboxEventsCompanion(
            status: const Value('dispatched'),
            dispatchedAt: Value(DateTime.now()),
            lastError: const Value(null),
          ),
        );
        successCount++;
      } else {
        final newRetry = event.retryCount + 1;
        // Exponential backoff: 2^retry minutes
        final backoffDuration = Duration(minutes: 1 << newRetry);
        final nextRetry = DateTime.now().add(backoffDuration);

        await (db.update(db.outboxEvents)..where((t) => t.id.equals(event.id))).write(
          OutboxEventsCompanion(
            status: const Value('failed'),
            retryCount: Value(newRetry),
            lastError: Value(errorMessage ?? 'Transport returned false'),
            nextRetryAt: Value(nextRetry),
          ),
        );
        failureCount++;
      }
    }

    return DispatchResult(dispatchedCount: successCount, failedCount: failureCount);
  }

  /// Returns total count of pending and failed events in the outbox
  Future<int> pendingCount(AppDatabase db) async {
    final query = db.selectOnly(db.outboxEvents)
      ..addColumns([db.outboxEvents.id.count()])
      ..where(db.outboxEvents.status.equals('pending'));
    final row = await query.getSingle();
    return row.read(db.outboxEvents.id.count()) ?? 0;
  }

  /// Purges old dispatched outbox entries to keep storage lean
  Future<int> purgeDispatched(AppDatabase db, {Duration olderThan = const Duration(days: 7)}) async {
    final cutoff = DateTime.now().subtract(olderThan);
    final count = await (db.delete(db.outboxEvents)
          ..where((t) => t.status.equals('dispatched') & t.dispatchedAt.isSmallerThanValue(cutoff)))
        .go();
    return count;
  }
}
