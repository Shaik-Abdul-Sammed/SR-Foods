import '../database/app_database.dart';
import '../domain/money.dart';
import 'dairy_pricing_service.dart';

class MilkProcurementResult {
  final int procurementId;
  final String supplierId;
  final double quantityLiters;
  final double fatPercent;
  final double snfPercent;
  final Money ratePerLiter;
  final Money totalAmount;
  final String slot;

  const MilkProcurementResult({
    required this.procurementId,
    required this.supplierId,
    required this.quantityLiters,
    required this.fatPercent,
    required this.snfPercent,
    required this.ratePerLiter,
    required this.totalAmount,
    required this.slot,
  });
}

class SlotCutoffStatus {
  final bool isIntakeAllowed;
  final String activeSlot; // 'morning' | 'evening' | 'none'
  final String message;

  const SlotCutoffStatus({
    required this.isIntakeAllowed,
    required this.activeSlot,
    required this.message,
  });
}

/// Service managing dairy milk intake, slot schedules, and batch allocation
class MilkProcurementService {
  final DairyPricingService pricingService;

  const MilkProcurementService({
    this.pricingService = const DairyPricingService(),
  });

  /// Evaluates whether milk intake is open for the current timestamp
  SlotCutoffStatus slotCutoffCheck(DateTime now) {
    final hour = now.hour;
    final minute = now.minute;
    final timeDecimal = hour + (minute / 60.0);

    // Morning slot: 05:00 to 10:30
    if (timeDecimal >= 5.0 && timeDecimal <= 10.5) {
      return const SlotCutoffStatus(
        isIntakeAllowed: true,
        activeSlot: 'morning',
        message: 'Morning milk procurement intake is currently OPEN.',
      );
    }

    // Midday gap: 10:30 to 16:00
    if (timeDecimal > 10.5 && timeDecimal < 16.0) {
      return const SlotCutoffStatus(
        isIntakeAllowed: false,
        activeSlot: 'none',
        message: 'Morning intake closed at 10:30 AM. Evening milk intake opens at 04:00 PM.',
      );
    }

    // Evening slot: 16:00 to 20:30
    if (timeDecimal >= 16.0 && timeDecimal <= 20.5) {
      return const SlotCutoffStatus(
        isIntakeAllowed: true,
        activeSlot: 'evening',
        message: 'Evening milk procurement intake is currently OPEN.',
      );
    }

    // Night gap: 20:30 to 05:00
    return const SlotCutoffStatus(
      isIntakeAllowed: false,
      activeSlot: 'none',
      message: 'Evening intake closed at 08:30 PM. Chilling center locked. Next intake at 05:00 AM.',
    );
  }

  /// Records fresh milk procurement into the database
  Future<MilkProcurementResult> recordProcurement({
    required AppDatabase db,
    required String supplierId,
    required double quantityLiters,
    required double fatPercent,
    required double snfPercent,
    required String slot, // 'morning' | 'evening'
    String? chillingCenterId,
    String? notes,
    FatPricingRuleData? rule,
  }) async {
    final activeRule = rule ?? (fatPercent >= 5.0 ? FatPricingRuleData.premiumBuffalo : FatPricingRuleData.standardCow);
    final totalMoney = pricingService.calculateMilkPrice(
      liters: quantityLiters,
      fatPercent: fatPercent,
      rule: activeRule,
    );
    final ratePerLiter = pricingService.calculateMilkPrice(
      liters: 1.0,
      fatPercent: fatPercent,
      rule: activeRule,
    );

    // Execute direct parameterized SQL to insert into milk_procurements
    await db.customStatement(
      'INSERT INTO milk_procurements ('
      'supplier_id, procurement_date, slot, quantity_liters, fat_percent, snf_percent, '
      'rate_per_liter_minor, total_amount_minor, currency_code, chilling_center_id, notes, created_at'
      ') VALUES (?, CURRENT_TIMESTAMP, ?, ?, ?, ?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP)',
      [
        supplierId,
        slot,
        quantityLiters,
        fatPercent,
        snfPercent,
        ratePerLiter.amountMinor,
        totalMoney.amountMinor,
        'INR',
        chillingCenterId,
        notes,
      ],
    );

    final lastIdRow = await db.customSelect('SELECT last_insert_rowid() as id').getSingle();
    final id = lastIdRow.read<int>('id');

    return MilkProcurementResult(
      procurementId: id,
      supplierId: supplierId,
      quantityLiters: quantityLiters,
      fatPercent: fatPercent,
      snfPercent: snfPercent,
      ratePerLiter: ratePerLiter,
      totalAmount: totalMoney,
      slot: slot,
    );
  }

  /// Links available unassigned milk procurements to a newly created production batch
  Future<int> autoDeductOnProduction({
    required AppDatabase db,
    required int batchId,
    required double requiredLiters,
  }) async {
    final unassignedRows = await db.customSelect(
      'SELECT id, quantity_liters FROM milk_procurements WHERE batch_id IS NULL ORDER BY procurement_date ASC',
    ).get();

    double allocated = 0.0;
    int linkedCount = 0;

    for (final row in unassignedRows) {
      if (allocated >= requiredLiters) break;
      final id = row.read<int>('id');
      final qty = row.read<double>('quantity_liters');

      await db.customStatement(
        'UPDATE milk_procurements SET batch_id = ? WHERE id = ?',
        [batchId, id],
      );
      allocated += qty;
      linkedCount++;
    }

    return linkedCount;
  }
}
