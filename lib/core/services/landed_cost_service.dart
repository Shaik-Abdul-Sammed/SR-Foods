import '../domain/money.dart';

class TariffSchedule {
  final double customsDutyRate;
  final double importVatRate;
  final String notes;

  const TariffSchedule({
    required this.customsDutyRate,
    required this.importVatRate,
    this.notes = '',
  });
}

class LandedCostInput {
  final Money fobPrice;
  final Money freight;
  final Money insurance;
  final String destinationCountry;
  final String hsCode;
  final int cartonCount;
  final int unitsPerCarton;
  final double? dutyRateOverride;
  final double? vatRateOverride;

  const LandedCostInput({
    required this.fobPrice,
    required this.freight,
    required this.insurance,
    required this.destinationCountry,
    required this.hsCode,
    required this.cartonCount,
    this.unitsPerCarton = 24,
    this.dutyRateOverride,
    this.vatRateOverride,
  });
}

class LandedCostResult {
  final Money cifValue;
  final double customsDutyRate;
  final Money customsDutyAmount;
  final double importVatRate;
  final Money importVatAmount;
  final Money totalLandedCost;
  final Money costPerCarton;
  final Money costPerConsumerPack;

  const LandedCostResult({
    required this.cifValue,
    required this.customsDutyRate,
    required this.customsDutyAmount,
    required this.importVatRate,
    required this.importVatAmount,
    required this.totalLandedCost,
    required this.costPerCarton,
    required this.costPerConsumerPack,
  });
}

class LandedCostService {
  const LandedCostService();

  // Known tariff schedules for Chapter 19 Bakery & Flatbreads (HS 1905.90)
  static const Map<String, TariffSchedule> defaultTariffSchedules = {
    'AE': TariffSchedule(customsDutyRate: 0.05, importVatRate: 0.05, notes: 'GCC Common Customs Tariff 5% + UAE VAT 5%'),
    'SA': TariffSchedule(customsDutyRate: 0.05, importVatRate: 0.15, notes: 'GCC Customs 5% + KSA VAT 15%'),
    'US': TariffSchedule(customsDutyRate: 0.00, importVatRate: 0.00, notes: 'US HTS Chapter 19 duty free for unleavened flatbreads'),
    'GB': TariffSchedule(customsDutyRate: 0.00, importVatRate: 0.00, notes: 'UK Global Tariff 0% + UK VAT Zero-Rated for basic food'),
    'CA': TariffSchedule(customsDutyRate: 0.00, importVatRate: 0.05, notes: 'Canada MFN 0% + Federal GST 5%'),
    'AU': TariffSchedule(customsDutyRate: 0.05, importVatRate: 0.10, notes: 'Australia Customs Duty 5% + GST 10%'),
    'IN': TariffSchedule(customsDutyRate: 0.30, importVatRate: 0.05, notes: 'India BCD 30% + IGST 5%'),
  };

  /// Compute exact CIF landed cost, customs duties, import VAT, and per-pack landed margin
  LandedCostResult computeLandedCost(LandedCostInput input) {
    if (input.cartonCount <= 0) throw ArgumentError('Carton count must be > 0');
    if (input.unitsPerCarton <= 0) throw ArgumentError('Units per carton must be > 0');

    // 1. CIF Value = FOB + Freight + Insurance
    final cif = input.fobPrice + input.freight + input.insurance;
    final currency = input.fobPrice.currency;

    // 2. Resolve duty and tax schedules
    final country = input.destinationCountry.toUpperCase().trim();
    final schedule = defaultTariffSchedules[country] ??
        const TariffSchedule(customsDutyRate: 0.05, importVatRate: 0.05);

    final effectiveDutyRate = input.dutyRateOverride ?? schedule.customsDutyRate;
    final effectiveVatRate = input.vatRateOverride ?? schedule.importVatRate;

    // 3. Customs Duty = CIF * Duty Rate (exact minor units)
    final dutyMinor = (cif.amountMinor * effectiveDutyRate).round();
    final customsDuty = Money(amountMinor: dutyMinor, currency: currency);

    // 4. Taxable value for VAT = CIF + Customs Duty
    final taxableForVat = cif + customsDuty;
    final vatMinor = (taxableForVat.amountMinor * effectiveVatRate).round();
    final importVat = Money(amountMinor: vatMinor, currency: currency);

    // 5. Total Landed Cost = CIF + Customs Duty + Import VAT
    final totalLanded = cif + customsDuty + importVat;

    // 6. Per-carton and per-consumer-pack exact landed costs
    final cartonCostMinor = (totalLanded.amountMinor / input.cartonCount).round();
    final costPerCarton = Money(amountMinor: cartonCostMinor, currency: currency);

    final totalPacks = input.cartonCount * input.unitsPerCarton;
    final packCostMinor = (totalLanded.amountMinor / totalPacks).round();
    final costPerConsumerPack = Money(amountMinor: packCostMinor, currency: currency);

    return LandedCostResult(
      cifValue: cif,
      customsDutyRate: effectiveDutyRate,
      customsDutyAmount: customsDuty,
      importVatRate: effectiveVatRate,
      importVatAmount: importVat,
      totalLandedCost: totalLanded,
      costPerCarton: costPerCarton,
      costPerConsumerPack: costPerConsumerPack,
    );
  }
}
