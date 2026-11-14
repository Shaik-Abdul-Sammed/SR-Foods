import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sr_foods/core/database/app_database.dart';
import 'package:sr_foods/core/database/database_provider.dart';
import 'package:sr_foods/core/i18n/locale_context.dart';
import 'package:sr_foods/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:sr_foods/features/orders/presentation/screens/orders_screen.dart';
import 'package:sr_foods/features/production/presentation/screens/production_screen.dart';
import 'package:sr_foods/features/inventory/presentation/screens/inventory_screen.dart';
import 'package:sr_foods/l10n/app_localizations.dart';

class _RtlLocaleContextNotifier extends LocaleContextNotifier {
  @override
  LocaleContext build() {
    return const LocaleContext(
      locale: Locale('ar'),
      currency: Currency.aed,
      timezone: 'Asia/Dubai',
    );
  }
}

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  Widget createRtlTestApp(Widget home) {
    return ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        localeContextProvider.overrideWith(_RtlLocaleContextNotifier.new),
        ordersListProvider.overrideWith((ref) => Stream.value(<Map<String, dynamic>>[])),
        productionProvider.overrideWith((ref) => Stream.value(<ProductionBatche>[])),
        inventoryWithProductsProvider.overrideWith((ref) => Future.value(<Map<String, dynamic>>[])),
      ],
      child: MaterialApp(
        locale: const Locale('ar'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: home,
        ),
      ),
    );
  }

  group('Phase 1.5 RTL Localization Smoke Tests', () {
    testWidgets('DashboardScreen renders cleanly under Arabic RTL without crash or overflow', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      await tester.pumpWidget(createRtlTestApp(const DashboardScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.byType(DashboardScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('OrdersScreen renders cleanly under Arabic RTL without crash or overflow', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      await tester.pumpWidget(createRtlTestApp(const OrdersScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.byType(OrdersScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('ProductionScreen renders cleanly under Arabic RTL without crash or overflow', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      await tester.pumpWidget(createRtlTestApp(const ProductionScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.byType(ProductionScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('InventoryScreen renders cleanly under Arabic RTL without crash or overflow', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));
      await tester.pumpWidget(createRtlTestApp(const InventoryScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.byType(InventoryScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  });
}
