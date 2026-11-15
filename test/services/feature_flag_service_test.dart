import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sr_foods/core/database/app_database.dart';
import 'package:sr_foods/core/services/feature_flag_service.dart';

void main() {
  late AppDatabase db;
  late FeatureFlagService service;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    service = FeatureFlagService(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('FeatureFlagService Tests', () {
    test('1. Unset flag defaults to disabled (false)', () async {
      final enabled = await service.isEnabled('unknown_flag');
      expect(enabled, isFalse);
    });

    test('2. Setting flag to enabled returns true', () async {
      await service.setFlag('quantum_solver_enabled', enabled: true);
      final enabled = await service.isEnabled('quantum_solver_enabled');
      expect(enabled, isTrue);
    });

    test('3. Setting flag to disabled returns false', () async {
      await service.setFlag('quantum_solver_enabled', enabled: true);
      await service.setFlag('quantum_solver_enabled', enabled: false);
      final enabled = await service.isEnabled('quantum_solver_enabled');
      expect(enabled, isFalse);
    });

    test('4. Fractional rollout percentage is deterministic for targetIdentifier', () async {
      await service.setFlag('beta_vrp_optimizer', enabled: true, rolloutPercentage: 50);

      // Check determinism for user A
      final firstCheck = await service.isEnabled('beta_vrp_optimizer', targetIdentifier: 'user_42');
      final secondCheck = await service.isEnabled('beta_vrp_optimizer', targetIdentifier: 'user_42');
      expect(firstCheck, equals(secondCheck));

      // With 50% rollout across 100 users, approximately ~50% should be enabled
      int enabledCount = 0;
      for (int i = 0; i < 100; i++) {
        if (await service.isEnabled('beta_vrp_optimizer', targetIdentifier: 'user_$i')) {
          enabledCount++;
        }
      }
      expect(enabledCount, inInclusiveRange(30, 70));
    });

    test('5. Zero rollout percentage disables feature even when enabled=true', () async {
      await service.setFlag('test_zero', enabled: true, rolloutPercentage: 0);
      final enabled = await service.isEnabled('test_zero', targetIdentifier: 'any_user');
      expect(enabled, isFalse);
    });

    test('6. getAllFlags and deleteFlag work properly', () async {
      await service.setFlag('flag_a', enabled: true);
      await service.setFlag('flag_b', enabled: false);

      final flags = await service.getAllFlags();
      expect(flags.length, 2);

      await service.deleteFlag('flag_a');
      final remaining = await service.getAllFlags();
      expect(remaining.length, 1);
      expect(remaining.first.key, 'flag_b');
    });
  });
}
