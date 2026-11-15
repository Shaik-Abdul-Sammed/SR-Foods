import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import '../database/app_database.dart';

class FeatureFlagService {
  final AppDatabase db;

  FeatureFlagService(this.db);

  /// Checks if a feature flag is enabled.
  /// If [targetIdentifier] (e.g. userId, deviceId) is provided and rollout is fractional,
  /// uses SHA-256 hash modulo 100 for deterministic bucketing.
  Future<bool> isEnabled(String key, {String? targetIdentifier}) async {
    final flag = await (db.select(db.featureFlags)..where((tbl) => tbl.key.equals(key))).getSingleOrNull();
    if (flag == null) {
      return false;
    }

    if (!flag.isEnabled) {
      return false;
    }

    final percentage = int.tryParse(flag.rolloutPercentage ?? '100') ?? 100;
    if (percentage >= 100) return true;
    if (percentage <= 0) return false;

    if (targetIdentifier == null) {
      return true;
    }

    // Deterministic murmur/sha256 bucket 0-99
    final hashBytes = sha256.convert(utf8.encode('$key:$targetIdentifier')).bytes;
    final bucket = (hashBytes[0] | (hashBytes[1] << 8)) % 100;
    return bucket < percentage;
  }

  /// Sets or updates a feature flag configuration.
  Future<void> setFlag(
    String key, {
    required bool enabled,
    int rolloutPercentage = 100,
    String? description,
  }) async {
    final clampedRollout = rolloutPercentage.clamp(0, 100).toString();
    await db.into(db.featureFlags).insert(
          FeatureFlagsCompanion(
            key: Value(key),
            isEnabled: Value(enabled),
            rolloutPercentage: Value(clampedRollout),
            description: Value(description),
            updatedAt: Value(DateTime.now()),
          ),
          onConflict: DoUpdate(
            (old) => FeatureFlagsCompanion(
              isEnabled: Value(enabled),
              rolloutPercentage: Value(clampedRollout),
              description: Value(description),
              updatedAt: Value(DateTime.now()),
            ),
            target: [db.featureFlags.key],
          ),
        );
  }

  /// Retrieves all configured feature flags.
  Future<List<FeatureFlag>> getAllFlags() async {
    return db.select(db.featureFlags).get();
  }

  /// Removes a feature flag.
  Future<int> deleteFlag(String key) async {
    return (db.delete(db.featureFlags)..where((tbl) => tbl.key.equals(key))).go();
  }
}
