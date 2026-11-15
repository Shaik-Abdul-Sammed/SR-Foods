import 'dart:convert';
import 'package:drift/drift.dart';
import '../database/app_database.dart';
import 'result.dart';
import 'use_case.dart';

class IdempotentRequest<In> {
  final String idempotencyKey;
  final String requestPath;
  final In params;
  final Duration ttl;

  const IdempotentRequest({
    required this.idempotencyKey,
    required this.requestPath,
    required this.params,
    this.ttl = const Duration(hours: 24),
  });
}

/// Decorator wrapping any UseCase with transactional idempotency guarantees
class IdempotentUseCase<In, Out> implements UseCase<IdempotentRequest<In>, Out> {
  final AppDatabase db;
  final UseCase<In, Out> innerUseCase;
  final String Function(Out output)? serializer;
  final Out Function(String json)? deserializer;

  const IdempotentUseCase({
    required this.db,
    required this.innerUseCase,
    this.serializer,
    this.deserializer,
  });

  @override
  Future<Result<Out, Object>> call(IdempotentRequest<In> request) async {
    final now = DateTime.now();

    // 1. Check if non-expired key exists
    final existingRow = await (db.select(db.idempotencyKeys)
          ..where((t) => t.key.equals(request.idempotencyKey) & t.expiresAt.isBiggerThanValue(now)))
        .getSingleOrNull();

    if (existingRow != null) {
      if (deserializer != null && existingRow.responsePayload != null) {
        try {
          final cachedOutput = deserializer!(existingRow.responsePayload!);
          return Result.ok(cachedOutput);
        } catch (_) {
          // If deserialization fails, proceed to re-execute
        }
      } else {
        // Cached without payload or no deserializer
        return Result.err(StateError('Duplicate request with key ${request.idempotencyKey} already processed.'));
      }
    }

    // 2. Execute inner use case
    final result = await innerUseCase(request.params);

    // 3. On success, store key and response payload
    if (result.isOk) {
      final outVal = result.unwrap();
      final payloadStr = serializer != null ? serializer!(outVal) : jsonEncode({'status': 'completed'});
      final expiresAt = now.add(request.ttl);

      await db.into(db.idempotencyKeys).insert(
        IdempotencyKeysCompanion.insert(
          key: request.idempotencyKey,
          requestPath: request.requestPath,
          responsePayload: Value(payloadStr),
          expiresAt: expiresAt,
          createdAt: Value(now),
        ),
        onConflict: DoUpdate(
          (old) => IdempotencyKeysCompanion.custom(
            responsePayload: Variable<String>(payloadStr),
            expiresAt: Variable<DateTime>(expiresAt),
          ),
          target: [db.idempotencyKeys.key],
        ),
      );
    }

    return result;
  }

  /// Removes expired idempotency keys
  Future<int> purgeExpired() async {
    final now = DateTime.now();
    return await (db.delete(db.idempotencyKeys)..where((t) => t.expiresAt.isSmallerThanValue(now))).go();
  }
}
