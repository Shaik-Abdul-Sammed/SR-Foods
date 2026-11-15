import 'package:flutter_test/flutter_test.dart';
import 'package:sr_foods/core/services/logistics/load_planner.dart';

void main() {
  group('LoadPlanner Tests (3D Bin Packing)', () {
    const cargoBay = VehicleCargoBay(
      lengthCm: 250.0,
      widthCm: 160.0,
      heightCm: 150.0,
      maxWeightKg: 1000.0,
    );

    test('1. Places heavy items at the bottom and fragile items on upper layers', () {
      final planner = const LoadPlanner(cargoBay);
      final items = [
        const CargoItem(id: 'FRAG-1', name: 'Bread Crate', lengthCm: 60.0, widthCm: 40.0, heightCm: 30.0, weightKg: 10.0, isFragile: true),
        const CargoItem(id: 'HEAVY-1', name: 'Milk Tub Heavy', lengthCm: 60.0, widthCm: 40.0, heightCm: 40.0, weightKg: 50.0),
        const CargoItem(id: 'HEAVY-2', name: 'Ghee Crate Heavy', lengthCm: 60.0, widthCm: 40.0, heightCm: 40.0, weightKg: 45.0),
      ];

      final result = planner.planLoad(items);

      expect(result.placedItems.length, equals(3));
      expect(result.unplacedItems, isEmpty);

      final heavyPlaced = result.placedItems.firstWhere((p) => p.item.id == 'HEAVY-1');

      // Heavy item placed first on layer Z = 0
      expect(heavyPlaced.zCm, equals(0.0));
      expect(result.totalLoadedWeightKg, equals(105.0));
    });

    test('2. Rejects items exceeding vehicle maximum weight capacity', () {
      const smallBay = VehicleCargoBay(
        lengthCm: 200.0,
        widthCm: 150.0,
        heightCm: 120.0,
        maxWeightKg: 100.0,
      );
      final planner = const LoadPlanner(smallBay);

      final items = [
        const CargoItem(id: 'C1', name: 'Item 1', lengthCm: 50.0, widthCm: 40.0, heightCm: 30.0, weightKg: 60.0),
        const CargoItem(id: 'C2', name: 'Item 2', lengthCm: 50.0, widthCm: 40.0, heightCm: 30.0, weightKg: 70.0),
      ];

      final result = planner.planLoad(items);
      expect(result.placedItems.length, equals(1));
      expect(result.unplacedItems.length, equals(1));
      expect(result.totalLoadedWeightKg, equals(70.0));
    });

    test('3. Rejects items that physically exceed cargo bay dimensions', () {
      final planner = const LoadPlanner(cargoBay);
      final hugeItem = const CargoItem(
        id: 'HUGE',
        name: 'Oversized Pallet',
        lengthCm: 300.0, // Exceeds bay length of 250cm
        widthCm: 100.0,
        heightCm: 100.0,
        weightKg: 200.0,
      );

      final result = planner.planLoad([hugeItem]);
      expect(result.placedItems, isEmpty);
      expect(result.unplacedItems.length, equals(1));
    });

    test('4. Computes volume and weight utilization percentages accurately', () {
      final planner = const LoadPlanner(cargoBay);
      final items = [
        const CargoItem(id: 'I1', name: 'Carton 1', lengthCm: 50.0, widthCm: 50.0, heightCm: 50.0, weightKg: 100.0),
      ];

      final result = planner.planLoad(items);
      expect(result.volumeUtilizationPercentage, greaterThan(0.0));
      expect(result.weightUtilizationPercentage, equals(10.0)); // 100 / 1000 = 10%
    });
  });
}
