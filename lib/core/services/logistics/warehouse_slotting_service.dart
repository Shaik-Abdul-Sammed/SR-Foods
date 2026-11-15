import 'package:drift/drift.dart';
import '../../database/app_database.dart';

class SkuVelocityItem {
  final int productId;
  final String skuCode;
  final int totalPicksPast30Days;

  const SkuVelocityItem({
    required this.productId,
    required this.skuCode,
    required this.totalPicksPast30Days,
  });
}

class PickPathStop {
  final String locationCode;
  final int productId;
  final int pickSequence;
  final int estimatedWalkingSteps;

  const PickPathStop({
    required this.locationCode,
    required this.productId,
    required this.pickSequence,
    required this.estimatedWalkingSteps,
  });
}

class WarehouseSlottingService {
  final AppDatabase db;

  WarehouseSlottingService(this.db);

  /// Registers or updates a warehouse racking slot location.
  Future<int> registerLocation({
    required String locationCode, // e.g. A-01-02-01
    required String zone, // 'dry_ambient', 'cold_chilled', 'frozen_vault'
    int? productId,
    int capacityUnits = 100,
    int currentUnits = 0,
    int pickPriority = 1,
  }) async {
    return db.into(db.warehouseLocations).insert(
          WarehouseLocationsCompanion.insert(
            locationCode: locationCode,
            zone: zone,
            productId: Value(productId),
            capacityUnits: Value(capacityUnits),
            currentUnits: Value(currentUnits),
            pickPriority: Value(pickPriority),
          ),
          onConflict: DoUpdate(
            (old) => WarehouseLocationsCompanion(
              productId: Value(productId),
              capacityUnits: Value(capacityUnits),
              currentUnits: Value(currentUnits),
              pickPriority: Value(pickPriority),
            ),
            target: [db.warehouseLocations.locationCode],
          ),
        );
  }

  /// Categorizes SKUs into ABC velocity tiers based on historical pick frequencies.
  Map<String, List<SkuVelocityItem>> categorizeAbcVelocity(List<SkuVelocityItem> items) {
    if (items.isEmpty) return {'A': [], 'B': [], 'C': []};

    final sorted = List<SkuVelocityItem>.from(items)
      ..sort((a, b) => b.totalPicksPast30Days.compareTo(a.totalPicksPast30Days));

    final totalCount = sorted.length;
    final aCount = (totalCount * 0.20).ceil();
    final bCount = (totalCount * 0.30).ceil();

    final classA = sorted.sublist(0, aCount);
    final classB = sorted.sublist(aCount, (aCount + bCount).clamp(0, totalCount));
    final classC = sorted.sublist((aCount + bCount).clamp(0, totalCount));

    return {
      'A': List.unmodifiable(classA),
      'B': List.unmodifiable(classB),
      'C': List.unmodifiable(classC),
    };
  }

  /// Optimizes order picker traversal using S-shape (serpentine) aisle routing.
  List<PickPathStop> computeSerpentinePickPath(List<WarehouseLocation> locationsToPick) {
    if (locationsToPick.isEmpty) return [];

    // Sort locations by Aisle, then serpentine direction based on odd/even aisle
    final sorted = List<WarehouseLocation>.from(locationsToPick)
      ..sort((a, b) {
        final aParts = a.locationCode.split('-');
        final bParts = b.locationCode.split('-');

        final aAisle = aParts.isNotEmpty ? aParts[0] : '';
        final bAisle = bParts.isNotEmpty ? bParts[0] : '';
        if (aAisle != bAisle) return aAisle.compareTo(bAisle);

        // Within same aisle: odd aisles ascend bay number, even aisles descend
        final aBay = aParts.length > 1 ? int.tryParse(aParts[1]) ?? 0 : 0;
        final bBay = bParts.length > 1 ? int.tryParse(bParts[1]) ?? 0 : 0;
        final isOddAisle = aAisle.hashCode % 2 == 1;

        return isOddAisle ? aBay.compareTo(bBay) : bBay.compareTo(aBay);
      });

    final stops = <PickPathStop>[];
    int steps = 0;
    for (int i = 0; i < sorted.length; i++) {
      steps += 15; // Estimated walking steps between pick bays
      stops.add(PickPathStop(
        locationCode: sorted[i].locationCode,
        productId: sorted[i].productId ?? 0,
        pickSequence: i + 1,
        estimatedWalkingSteps: steps,
      ));
    }

    return stops;
  }
}
