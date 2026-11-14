import 'dart:math' as math;

/// Single inventory lot for FEFO allocation
class InventoryLot {
  final String lotNumber;
  final String sku;
  final int availableQuantity;
  final DateTime mfgDate;
  final DateTime expiryDate;
  final String binLocation; // e.g. "ZONE-FROZEN-A1"
  final double currentTempCelsius;

  const InventoryLot({
    required this.lotNumber,
    required this.sku,
    required this.availableQuantity,
    required this.mfgDate,
    required this.expiryDate,
    required this.binLocation,
    this.currentTempCelsius = -18.0,
  });
}

/// Single allocation slice against a specific lot
class LotAllocationSlice {
  final String lotNumber;
  final int allocatedQuantity;
  final DateTime expiryDate;
  final int remainingShelfLifeDays;
  final String binLocation;

  const LotAllocationSlice({
    required this.lotNumber,
    required this.allocatedQuantity,
    required this.expiryDate,
    required this.remainingShelfLifeDays,
    required this.binLocation,
  });
}

/// Complete FEFO picking result
class FefoAllocationResult {
  final String sku;
  final int requestedQuantity;
  final int totalAllocatedQuantity;
  final bool isFullyAllocated;
  final List<LotAllocationSlice> allocations;
  final List<String> rejectedExpiredLots;
  final String pickInstructions;

  const FefoAllocationResult({
    required this.sku,
    required this.requestedQuantity,
    required this.totalAllocatedQuantity,
    required this.isFullyAllocated,
    required this.allocations,
    required this.rejectedExpiredLots,
    required this.pickInstructions,
  });
}

/// FEFO (First-Expired, First-Out) Inventory & Warehouse Picking Engine
class FefoAllocationService {
  FefoAllocationService._();
  static final FefoAllocationService instance = FefoAllocationService._();

  /// Allocates required quantity strictly by earliest expiration date first
  FefoAllocationResult allocateFefo({
    required String sku,
    required int requiredQuantity,
    required List<InventoryLot> availableLots,
    DateTime? referenceDate,
    int minimumShelfLifeDaysThreshold = 2, // Don't pick if expiring within 48h
  }) {
    final now = referenceDate ?? DateTime.now();
    final matchingLots = availableLots.where((l) => l.sku == sku && l.availableQuantity > 0).toList();

    final validLots = <InventoryLot>[];
    final rejectedLots = <String>[];

    for (final lot in matchingLots) {
      final daysRemaining = lot.expiryDate.difference(now).inDays;
      if (daysRemaining < minimumShelfLifeDaysThreshold) {
        rejectedLots.add('${lot.lotNumber} (Expired/Near-Expiry: $daysRemaining days left)');
      } else {
        validLots.add(lot);
      }
    }

    // Sort valid lots by expiryDate ASCENDING (First-Expired, First-Out)
    validLots.sort((a, b) => a.expiryDate.compareTo(b.expiryDate));

    final allocations = <LotAllocationSlice>[];
    int remainingToAllocate = requiredQuantity;

    for (final lot in validLots) {
      if (remainingToAllocate <= 0) break;

      final pickQty = math.min(remainingToAllocate, lot.availableQuantity);
      final daysRemaining = lot.expiryDate.difference(now).inDays;

      allocations.add(LotAllocationSlice(
        lotNumber: lot.lotNumber,
        allocatedQuantity: pickQty,
        expiryDate: lot.expiryDate,
        remainingShelfLifeDays: daysRemaining,
        binLocation: lot.binLocation,
      ));

      remainingToAllocate -= pickQty;
    }

    final totalAllocated = requiredQuantity - remainingToAllocate;
    final isFull = remainingToAllocate <= 0;

    final instruction = isFull
        ? 'Pick ${allocations.length} lot(s): ${allocations.map((a) => "${a.allocatedQuantity}pk from ${a.binLocation} [${a.lotNumber}]").join(', ')}'
        : 'INSUFFICIENT STOCK: Allocated $totalAllocated of $requiredQuantity packs. Shortage: $remainingToAllocate packs.';

    return FefoAllocationResult(
      sku: sku,
      requestedQuantity: requiredQuantity,
      totalAllocatedQuantity: totalAllocated,
      isFullyAllocated: isFull,
      allocations: allocations,
      rejectedExpiredLots: rejectedLots,
      pickInstructions: instruction,
    );
  }
}
