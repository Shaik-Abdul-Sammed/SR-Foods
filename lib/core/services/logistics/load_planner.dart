class CargoItem {
  final String id;
  final String name;
  final double lengthCm;
  final double widthCm;
  final double heightCm;
  final double weightKg;
  final bool isFragile; // e.g. Bakery items can't support heavy tubs
  final String zone; // 'frozen', 'chilled', 'ambient'

  const CargoItem({
    required this.id,
    required this.name,
    required this.lengthCm,
    required this.widthCm,
    required this.heightCm,
    required this.weightKg,
    this.isFragile = false,
    this.zone = 'ambient',
  });

  double get volumeCbm => (lengthCm * widthCm * heightCm) / 1000000.0;
}

class PlacedCargoItem {
  final CargoItem item;
  final double xCm;
  final double yCm;
  final double zCm;

  const PlacedCargoItem({
    required this.item,
    required this.xCm,
    required this.yCm,
    required this.zCm,
  });
}

class VehicleCargoBay {
  final double lengthCm;
  final double widthCm;
  final double heightCm;
  final double maxWeightKg;

  const VehicleCargoBay({
    required this.lengthCm,
    required this.widthCm,
    required this.heightCm,
    required this.maxWeightKg,
  });

  double get totalVolumeCbm => (lengthCm * widthCm * heightCm) / 1000000.0;
}

class LoadPlanResult {
  final List<PlacedCargoItem> placedItems;
  final List<CargoItem> unplacedItems;
  final double totalLoadedWeightKg;
  final double totalLoadedVolumeCbm;
  final double volumeUtilizationPercentage;
  final double weightUtilizationPercentage;

  const LoadPlanResult({
    required this.placedItems,
    required this.unplacedItems,
    required this.totalLoadedWeightKg,
    required this.totalLoadedVolumeCbm,
    required this.volumeUtilizationPercentage,
    required this.weightUtilizationPercentage,
  });
}

/// 3D Bin Packing and Load Placement Optimizer for Delivery Cargo Vans.
///
/// Implements layer-based bottom-to-top stacking with weight distribution and fragility awareness.
class LoadPlanner {
  final VehicleCargoBay cargoBay;

  const LoadPlanner(this.cargoBay);

  LoadPlanResult planLoad(List<CargoItem> items) {
    // Sort items: Heavy/non-fragile first (bottom layers), fragile items last (top layers)
    final sortedItems = List<CargoItem>.from(items)
      ..sort((a, b) {
        if (a.isFragile && !b.isFragile) return 1;
        if (!a.isFragile && b.isFragile) return -1;
        return b.weightKg.compareTo(a.weightKg);
      });

    final placed = <PlacedCargoItem>[];
    final unplaced = <CargoItem>[];

    double currentX = 0.0;
    double currentY = 0.0;
    double currentZ = 0.0;
    double rowMaxY = 0.0;
    double layerMaxZ = 0.0;
    double loadedWeight = 0.0;

    for (final item in sortedItems) {
      // Dimension bounds check
      if (item.lengthCm > cargoBay.lengthCm ||
          item.widthCm > cargoBay.widthCm ||
          item.heightCm > cargoBay.heightCm) {
        unplaced.add(item);
        continue;
      }

      if (loadedWeight + item.weightKg > cargoBay.maxWeightKg) {
        unplaced.add(item);
        continue;
      }

      // Check fit along X (length)
      if (currentX + item.lengthCm > cargoBay.lengthCm) {
        // Next row in Y (width)
        currentX = 0.0;
        currentY += rowMaxY;
        rowMaxY = 0.0;
      }

      // Check fit along Y (width)
      if (currentY + item.widthCm > cargoBay.widthCm) {
        // Next layer in Z (height)
        currentX = 0.0;
        currentY = 0.0;
        currentZ += layerMaxZ;
        rowMaxY = 0.0;
        layerMaxZ = 0.0;
      }

      // Check fit along Z (height)
      if (currentZ + item.heightCm > cargoBay.heightCm) {
        unplaced.add(item);
        continue;
      }

      // Item fits
      placed.add(PlacedCargoItem(
        item: item,
        xCm: currentX,
        yCm: currentY,
        zCm: currentZ,
      ));

      loadedWeight += item.weightKg;
      if (item.widthCm > rowMaxY) rowMaxY = item.widthCm;
      if (item.heightCm > layerMaxZ) layerMaxZ = item.heightCm;
      currentX += item.lengthCm;
    }

    final loadedVol = placed.fold<double>(0.0, (acc, p) => acc + p.item.volumeCbm);
    final volUtil = (loadedVol / cargoBay.totalVolumeCbm) * 100.0;
    final wtUtil = (loadedWeight / cargoBay.maxWeightKg) * 100.0;

    return LoadPlanResult(
      placedItems: List.unmodifiable(placed),
      unplacedItems: List.unmodifiable(unplaced),
      totalLoadedWeightKg: (loadedWeight * 10.0).round() / 10.0,
      totalLoadedVolumeCbm: (loadedVol * 1000.0).round() / 1000.0,
      volumeUtilizationPercentage: (volUtil * 10.0).round() / 10.0,
      weightUtilizationPercentage: (wtUtil * 10.0).round() / 10.0,
    );
  }
}
