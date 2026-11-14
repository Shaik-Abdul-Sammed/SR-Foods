import 'package:drift/drift.dart';
import '../database/app_database.dart';

class BatchAllocation {
  final int batchId;
  final String batchNumber;
  final int allocatedPacks;
  final DateTime? expiryDate;

  const BatchAllocation({
    required this.batchId,
    required this.batchNumber,
    required this.allocatedPacks,
    this.expiryDate,
  });

  int get daysUntilExpiry {
    if (expiryDate == null) return 999;
    return expiryDate!.difference(DateTime.now()).inDays;
  }
}

class FefoAllocationResult {
  final bool isFullyAllocated;
  final int totalRequested;
  final int totalAllocated;
  final List<BatchAllocation> allocations;
  final int unfulfilledPacks;

  const FefoAllocationResult({
    required this.isFullyAllocated,
    required this.totalRequested,
    required this.totalAllocated,
    required this.allocations,
    required this.unfulfilledPacks,
  });

  /// Formatted batch string for invoice and traceability (e.g. "PB-PAR-001(10), PB-PAR-002(5)")
  String get batchSummaryString {
    if (allocations.isEmpty) return 'No batch assigned';
    return allocations
        .map((a) => '${a.batchNumber} (${a.allocatedPacks} pk)')
        .join(', ');
  }
}

class ExpiryRiskCategory {
  final String label;
  final String urgency; // 'expired', 'critical', 'warning', 'fresh'
  final List<ProductionBatche> batches;
  final int totalPacks;
  final String actionRecommendation;

  const ExpiryRiskCategory({
    required this.label,
    required this.urgency,
    required this.batches,
    required this.totalPacks,
    required this.actionRecommendation,
  });
}

class FefoInventoryService {
  FefoInventoryService._();
  static final FefoInventoryService instance = FefoInventoryService._();

  /// Allocates stock strictly using First-Expired, First-Out (FEFO) logic.
  /// Selects the earliest expiring batches for the product first.
  Future<FefoAllocationResult> allocateBatches({
    required AppDatabase db,
    required int productId,
    required int requestedPacks,
  }) async {
    if (requestedPacks <= 0) {
      return const FefoAllocationResult(
        isFullyAllocated: true,
        totalRequested: 0,
        totalAllocated: 0,
        allocations: [],
        unfulfilledPacks: 0,
      );
    }

    // Fetch active completed batches ordered by earliest expiry date first
    final candidateBatches = await (db.select(db.productionBatches)
          ..where((b) =>
              b.productId.equals(productId) &
              b.status.equals('completed') &
              b.quantityProduced.isBiggerThanValue(0))
          ..orderBy([
            (b) => OrderingTerm.asc(b.expiryDate),
            (b) => OrderingTerm.asc(b.manufacturingDate),
            (b) => OrderingTerm.asc(b.id),
          ]))
        .get();

    int remainingToAllocate = requestedPacks;
    final List<BatchAllocation> allocations = [];

    for (final batch in candidateBatches) {
      if (remainingToAllocate <= 0) break;

      final availableInBatch = batch.quantityProduced;
      final toTake = availableInBatch >= remainingToAllocate
          ? remainingToAllocate
          : availableInBatch;

      allocations.add(BatchAllocation(
        batchId: batch.id,
        batchNumber: batch.batchNumber,
        allocatedPacks: toTake,
        expiryDate: batch.expiryDate,
      ));

      remainingToAllocate -= toTake;
    }

    final totalAllocated = requestedPacks - remainingToAllocate;

    return FefoAllocationResult(
      isFullyAllocated: remainingToAllocate == 0,
      totalRequested: requestedPacks,
      totalAllocated: totalAllocated,
      allocations: allocations,
      unfulfilledPacks: remainingToAllocate > 0 ? remainingToAllocate : 0,
    );
  }

  /// Categorizes finished goods batches by expiry risk horizon
  Future<List<ExpiryRiskCategory>> getExpiryRiskDashboard(AppDatabase db) async {
    final now = DateTime.now();
    final allBatches = await (db.select(db.productionBatches)
          ..where((b) => b.status.equals('completed'))
          ..orderBy([(b) => OrderingTerm.asc(b.expiryDate)]))
        .get();

    final List<ProductionBatche> expired = [];
    final List<ProductionBatche> critical = []; // < 48 hours
    final List<ProductionBatche> warning = []; // 2 to 5 days
    final List<ProductionBatche> fresh = []; // > 5 days

    for (final b in allBatches) {
      final expiry = b.expiryDate ?? b.manufacturingDate.add(const Duration(days: 5));
      final hoursLeft = expiry.difference(now).inHours;

      if (hoursLeft <= 0) {
        expired.add(b);
      } else if (hoursLeft <= 48) {
        critical.add(b);
      } else if (hoursLeft <= 120) {
        warning.add(b);
      } else {
        fresh.add(b);
      }
    }

    int sumPacks(List<ProductionBatche> list) =>
        list.fold(0, (acc, b) => acc + b.quantityProduced);

    return [
      if (expired.isNotEmpty)
        ExpiryRiskCategory(
          label: 'Expired Batches',
          urgency: 'expired',
          batches: expired,
          totalPacks: sumPacks(expired),
          actionRecommendation:
              'Immediate Write-off required. Do not dispatch. Segregate stock for biological disposal.',
        ),
      if (critical.isNotEmpty)
        ExpiryRiskCategory(
          label: 'Expiring in < 48 Hours',
          urgency: 'critical',
          batches: critical,
          totalPacks: sumPacks(critical),
          actionRecommendation:
              'High Urgency: Push with 10% spot promo to tiffin centres or high-turnover Kiranas today.',
        ),
      if (warning.isNotEmpty)
        ExpiryRiskCategory(
          label: 'Expiring in 2-5 Days',
          urgency: 'warning',
          batches: warning,
          totalPacks: sumPacks(warning),
          actionRecommendation:
              'Prioritize first on today\'s delivery van routes (FEFO schedule).',
        ),
      ExpiryRiskCategory(
        label: 'Fresh Stock (> 5 Days)',
        urgency: 'fresh',
        batches: fresh,
        totalPacks: sumPacks(fresh),
        actionRecommendation: 'Normal distribution rotation. Safe shelf stability.',
      ),
    ];
  }
}
