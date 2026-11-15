import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sr_foods/core/database/app_database.dart';
import 'package:sr_foods/core/services/logistics/warehouse_slotting_service.dart';

void main() {
  late AppDatabase db;
  late WarehouseSlottingService service;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    service = WarehouseSlottingService(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('WarehouseSlottingService Tests', () {
    test('1. Registers racking location and updates existing record on conflict', () async {
      final locId = await service.registerLocation(
        locationCode: 'A-01-02-01',
        zone: 'cold_chilled',
        capacityUnits: 150,
        currentUnits: 40,
      );

      expect(locId, greaterThan(0));

      final loc = await (db.select(db.warehouseLocations)..where((tbl) => tbl.locationCode.equals('A-01-02-01'))).getSingle();
      expect(loc.capacityUnits, 150);
      expect(loc.currentUnits, 40);
    });

    test('2. Categorizes SKUs into ABC velocity tiers', () {
      final items = [
        const SkuVelocityItem(productId: 1, skuCode: 'SRF-DAI-001', totalPicksPast30Days: 500),
        const SkuVelocityItem(productId: 2, skuCode: 'SRF-DAI-002', totalPicksPast30Days: 300),
        const SkuVelocityItem(productId: 3, skuCode: 'SRF-BAK-001', totalPicksPast30Days: 200),
        const SkuVelocityItem(productId: 4, skuCode: 'SRF-BAK-002', totalPicksPast30Days: 80),
        const SkuVelocityItem(productId: 5, skuCode: 'SRF-FRO-001', totalPicksPast30Days: 20),
      ];

      final abc = service.categorizeAbcVelocity(items);
      expect(abc['A']!.length, 1);
      expect(abc['A']!.first.skuCode, 'SRF-DAI-001'); // Top velocity item
      expect(abc['B']!.length, 2);
      expect(abc['C']!.length, 2);
    });

    test('3. Computes serpentine pick path with sequential stop ordering', () {
      final locations = [
        const WarehouseLocation(id: 1, locationCode: 'A-02-01-01', zone: 'ambient', capacityUnits: 100, currentUnits: 20, pickPriority: 1),
        const WarehouseLocation(id: 2, locationCode: 'A-01-01-01', zone: 'ambient', capacityUnits: 100, currentUnits: 20, pickPriority: 1),
        const WarehouseLocation(id: 3, locationCode: 'B-01-01-01', zone: 'ambient', capacityUnits: 100, currentUnits: 20, pickPriority: 1),
      ];

      final path = service.computeSerpentinePickPath(locations);
      expect(path.length, 3);
      expect(path[0].pickSequence, 1);
      expect(path[1].pickSequence, 2);
      expect(path[2].pickSequence, 3);
      expect(path[2].estimatedWalkingSteps, greaterThan(path[0].estimatedWalkingSteps));
    });
  });
}
