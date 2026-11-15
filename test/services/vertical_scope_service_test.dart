import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' show DoUpdate, Value, Variable;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sr_foods/core/database/app_database.dart';
import 'package:sr_foods/core/database/database_provider.dart';
import 'package:sr_foods/core/services/vertical_scope_service.dart';

void main() {
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  group('Vertical Scope Tests', () {
    test('1. Vertical.fromString parses names accurately and handles unknown inputs', () {
      expect(Vertical.fromString('dairy'), equals(Vertical.dairy));
      expect(Vertical.fromString('DAIRY '), equals(Vertical.dairy));
      expect(Vertical.fromString('bakery'), equals(Vertical.bakery));
      expect(Vertical.fromString('Bakery'), equals(Vertical.bakery));
      expect(Vertical.fromString('frozen'), equals(Vertical.frozen));
      expect(Vertical.fromString('unknown_xyz'), equals(Vertical.frozen));

      expect(Vertical.frozen.label, equals('Frozen Food'));
      expect(Vertical.dairy.label, equals('Dairy'));
      expect(Vertical.bakery.label, equals('Bakery'));
    });

    test('2. VerticalScope default has frozen enabled and correct defaults', () {
      const scope = VerticalScope();
      expect(scope.isEnabled(Vertical.frozen), isTrue);
      expect(scope.isEnabled(Vertical.dairy), isFalse);
      expect(scope.isEnabled(Vertical.bakery), isFalse);
      expect(scope.primaryVertical, equals(Vertical.frozen));
      expect(scope.activeVerticals(), contains(Vertical.frozen));
    });

    test('3. visibleProductFields returns vertical-specific fields', () {
      const frozenOnly = VerticalScope(enabledVerticals: {Vertical.frozen});
      expect(frozenOnly.visibleProductFields(), contains('storageType'));
      expect(frozenOnly.visibleProductFields(), contains('shelfLifeDays'));
      expect(frozenOnly.visibleProductFields(), isNot(contains('milkType')));
      expect(frozenOnly.visibleProductFields(), isNot(contains('proofingMinutes')));

      const dairyOnly = VerticalScope(
        enabledVerticals: {Vertical.dairy},
        primaryVertical: Vertical.dairy,
      );
      expect(dairyOnly.visibleProductFields(), contains('milkType'));
      expect(dairyOnly.visibleProductFields(), contains('fatPercentExpected'));
      expect(dairyOnly.visibleProductFields(), contains('isPasteurized'));
      expect(dairyOnly.visibleProductFields(), isNot(contains('ovenType')));

      const bakeryOnly = VerticalScope(
        enabledVerticals: {Vertical.bakery},
        primaryVertical: Vertical.bakery,
      );
      expect(bakeryOnly.visibleProductFields(), contains('bakeDateRequired'));
      expect(bakeryOnly.visibleProductFields(), contains('proofingMinutes'));
      expect(bakeryOnly.visibleProductFields(), contains('ovenType'));
      expect(bakeryOnly.visibleProductFields(), contains('freshnessWindowHours'));

      const allThree = VerticalScope(
        enabledVerticals: {Vertical.frozen, Vertical.dairy, Vertical.bakery},
      );
      expect(allThree.visibleProductFields(), contains('storageType'));
      expect(allThree.visibleProductFields(), contains('milkType'));
      expect(allThree.visibleProductFields(), contains('ovenType'));
    });

    test('4. defaultDashboardLayout maps KPI cards for active verticals', () {
      const scope = VerticalScope(
        enabledVerticals: {Vertical.dairy, Vertical.bakery},
        primaryVertical: Vertical.dairy,
      );

      final layout = scope.defaultDashboardLayout();
      expect(layout['primary'], equals('dairy'));
      expect(layout['enabled'], containsAll(['dairy', 'bakery']));

      final cards = layout['kpiCards'] as List<String>;
      expect(cards, contains('milk_procurement_yield'));
      expect(cards, contains('oven_utilization_rate'));
      expect(cards, contains('custom_order_pipeline'));
      expect(cards, isNot(contains('blast_freezer_runtime')));
    });

    test('5. VerticalScopeNotifier enforces at-least-one active vertical rule', () async {
      final notifier = container.read(verticalScopeProvider.notifier);

      expect(
        () => notifier.setActive({}),
        throwsA(isA<ArgumentError>().having(
          (e) => e.message,
          'message',
          contains('At least one vertical must remain enabled'),
        )),
      );
    });

    test('6. VerticalScopeNotifier.setActive persists configuration to AppSettings', () async {
      final notifier = container.read(verticalScopeProvider.notifier);

      await notifier.setActive(
        {Vertical.dairy, Vertical.bakery},
        primary: Vertical.dairy,
      );

      final state = container.read(verticalScopeProvider);
      expect(state.isEnabled(Vertical.dairy), isTrue);
      expect(state.isEnabled(Vertical.bakery), isTrue);
      expect(state.isEnabled(Vertical.frozen), isFalse);
      expect(state.primaryVertical, equals(Vertical.dairy));

      // Verify database persistence in app_settings table
      final rows = await db.select(db.appSettings).get();
      final settings = {for (final r in rows) r.key: r.value};

      expect(settings['active_verticals'], contains('dairy'));
      expect(settings['active_verticals'], contains('bakery'));
      expect(settings['primary_vertical'], equals('dairy'));
    });

    test('7. VerticalScopeNotifier.loadFromDatabase restores saved verticals', () async {
      final now = DateTime.now();
      await db.into(db.appSettings).insert(
        AppSettingsCompanion.insert(
          key: 'active_verticals',
          value: '["dairy"]',
          type: const Value('json'),
          updatedAt: Value(now),
        ),
        onConflict: DoUpdate(
          (old) => AppSettingsCompanion.custom(
            value: const Variable<String>('["dairy"]'),
            updatedAt: Variable<DateTime>(now),
          ),
          target: [db.appSettings.key],
        ),
      );
      await db.into(db.appSettings).insert(
        AppSettingsCompanion.insert(
          key: 'primary_vertical',
          value: 'dairy',
          type: const Value('string'),
          updatedAt: Value(now),
        ),
        onConflict: DoUpdate(
          (old) => AppSettingsCompanion.custom(
            value: const Variable<String>('dairy'),
            updatedAt: Variable<DateTime>(now),
          ),
          target: [db.appSettings.key],
        ),
      );

      // Create a fresh container to test loadFromDatabase
      final newContainer = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)],
      );

      final notifier = newContainer.read(verticalScopeProvider.notifier);
      await notifier.loadFromDatabase();

      final state = newContainer.read(verticalScopeProvider);
      expect(state.isEnabled(Vertical.dairy), isTrue);
      expect(state.isEnabled(Vertical.frozen), isFalse);
      expect(state.primaryVertical, equals(Vertical.dairy));

      newContainer.dispose();
    });
  });
}
