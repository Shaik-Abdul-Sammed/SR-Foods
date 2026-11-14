import '../domain/money.dart';
import '../i18n/locale_context.dart';

class TransferPricingRule {
  final double markupPercentage; // e.g. 15.0% cost-plus
  final int exportHandlingFeePerCartonMinor; // In source currency minor units
  final int documentationFeeMinor; // In source currency minor units

  const TransferPricingRule({
    this.markupPercentage = 15.0,
    this.exportHandlingFeePerCartonMinor = 2500, // e.g. ₹25.00/carton handling
    this.documentationFeeMinor = 150000, // e.g. ₹1,500.00 customs filing
  });
}

class TransferOrderInput {
  final int sourceEntityId;
  final String sourceEntityName;
  final int destinationEntityId;
  final String destinationEntityName;
  final Currency sourceCurrency;
  final Currency destinationCurrency;
  final double fxRateSourceToDest; // 1 unit source = X units dest
  final String sku;
  final String productName;
  final int cartonCount;
  final int unitsPerCarton;
  final int baseFactoryCostMinor; // Factory manufacturing cost per consumer pack

  const TransferOrderInput({
    required this.sourceEntityId,
    required this.sourceEntityName,
    required this.destinationEntityId,
    required this.destinationEntityName,
    required this.sourceCurrency,
    required this.destinationCurrency,
    required this.fxRateSourceToDest,
    required this.sku,
    required this.productName,
    required this.cartonCount,
    this.unitsPerCarton = 24,
    required this.baseFactoryCostMinor,
  });

  int get totalConsumerPacks => cartonCount * unitsPerCarton;
}

class TransferPricingResult {
  final String challanNumber;
  final DateTime challanDate;
  final Money baseCostTotalSource;
  final Money markupAmountSource;
  final Money handlingFeesSource;
  final Money transferPriceTotalSource;
  final Money transferPricePerCartonSource;
  final Money transferPricePerPackSource;
  final Money transferPriceTotalDest;
  final Money transferPricePerCartonDest;
  final Money transferPricePerPackDest;

  const TransferPricingResult({
    required this.challanNumber,
    required this.challanDate,
    required this.baseCostTotalSource,
    required this.markupAmountSource,
    required this.handlingFeesSource,
    required this.transferPriceTotalSource,
    required this.transferPricePerCartonSource,
    required this.transferPricePerPackSource,
    required this.transferPriceTotalDest,
    required this.transferPricePerCartonDest,
    required this.transferPricePerPackDest,
  });
}

class EntityPnlSummary {
  final int entityId;
  final String entityName;
  final Currency currency;
  final Money grossRevenue;
  final Money cogs;
  final Money grossProfit;
  final Money operatingExpenses;
  final Money netOperatingProfit;
  final double grossMarginPercent;
  final double netMarginPercent;

  const EntityPnlSummary({
    required this.entityId,
    required this.entityName,
    required this.currency,
    required this.grossRevenue,
    required this.cogs,
    required this.grossProfit,
    required this.operatingExpenses,
    required this.netOperatingProfit,
    required this.grossMarginPercent,
    required this.netMarginPercent,
  });
}

class TransferPricingEngine {
  const TransferPricingEngine();

  /// Calculate cost-plus arm's length transfer price compliant with OECD Transfer Pricing Guidelines & Indian Section 92C
  TransferPricingResult calculateTransferPrice(
    TransferOrderInput input, {
    TransferPricingRule rule = const TransferPricingRule(),
    DateTime? timestamp,
  }) {
    if (input.cartonCount <= 0) throw ArgumentError('Carton count must be > 0');
    if (input.totalConsumerPacks <= 0) throw ArgumentError('Units must be > 0');

    final date = timestamp ?? DateTime.now();
    final challanNo = 'DC-TRF-${input.sourceEntityId}-${input.destinationEntityId}-${date.millisecondsSinceEpoch.toString().substring(6)}';

    // 1. Base Factory Manufacturing Cost (Source currency)
    final totalBaseCostMinor = input.baseFactoryCostMinor * input.totalConsumerPacks;
    final baseCostTotal = Money(amountMinor: totalBaseCostMinor, currency: input.sourceCurrency);

    // 2. Arm's Length Cost-Plus Markup (e.g. 15%)
    final markupMinor = (totalBaseCostMinor * (rule.markupPercentage / 100.0)).round();
    final markupAmount = Money(amountMinor: markupMinor, currency: input.sourceCurrency);

    // 3. Handling & Documentation Fees
    final totalHandlingMinor = (rule.exportHandlingFeePerCartonMinor * input.cartonCount) + rule.documentationFeeMinor;
    final handlingFees = Money(amountMinor: totalHandlingMinor, currency: input.sourceCurrency);

    // 4. Total Transfer Price in Source Currency
    final totalSourceMinor = totalBaseCostMinor + markupMinor + totalHandlingMinor;
    final transferTotalSource = Money(amountMinor: totalSourceMinor, currency: input.sourceCurrency);

    final perCartonSourceMinor = (totalSourceMinor / input.cartonCount).round();
    final perCartonSource = Money(amountMinor: perCartonSourceMinor, currency: input.sourceCurrency);

    final perPackSourceMinor = (totalSourceMinor / input.totalConsumerPacks).round();
    final perPackSource = Money(amountMinor: perPackSourceMinor, currency: input.sourceCurrency);

    // 5. Foreign Currency Conversion to Destination Entity Currency
    final transferTotalDest = transferTotalSource.convertTo(input.destinationCurrency, input.fxRateSourceToDest);
    final perCartonDest = perCartonSource.convertTo(input.destinationCurrency, input.fxRateSourceToDest);
    final perPackDest = perPackSource.convertTo(input.destinationCurrency, input.fxRateSourceToDest);

    return TransferPricingResult(
      challanNumber: challanNo,
      challanDate: date,
      baseCostTotalSource: baseCostTotal,
      markupAmountSource: markupAmount,
      handlingFeesSource: handlingFees,
      transferPriceTotalSource: transferTotalSource,
      transferPricePerCartonSource: perCartonSource,
      transferPricePerPackSource: perPackSource,
      transferPriceTotalDest: transferTotalDest,
      transferPricePerCartonDest: perCartonDest,
      transferPricePerPackDest: perPackDest,
    );
  }

  /// Generate audited P&L report for a specific business entity in its local currency
  EntityPnlSummary computeEntityPnl({
    required int entityId,
    required String entityName,
    required Currency currency,
    required Money grossRevenue,
    required Money cogs,
    required Money operatingExpenses,
  }) {
    if (grossRevenue.currency != currency || cogs.currency != currency || operatingExpenses.currency != currency) {
      throw ArgumentError('All financial figures must match entity operating currency ${currency.code}');
    }

    final grossProfit = grossRevenue - cogs;
    final netOperatingProfit = grossProfit - operatingExpenses;

    final grossMargin = grossRevenue.amountMinor > 0
        ? (grossProfit.amountMinor / grossRevenue.amountMinor) * 100.0
        : 0.0;

    final netMargin = grossRevenue.amountMinor > 0
        ? (netOperatingProfit.amountMinor / grossRevenue.amountMinor) * 100.0
        : 0.0;

    return EntityPnlSummary(
      entityId: entityId,
      entityName: entityName,
      currency: currency,
      grossRevenue: grossRevenue,
      cogs: cogs,
      grossProfit: grossProfit,
      operatingExpenses: operatingExpenses,
      netOperatingProfit: netOperatingProfit,
      grossMarginPercent: double.parse(grossMargin.toStringAsFixed(2)),
      netMarginPercent: double.parse(netMargin.toStringAsFixed(2)),
    );
  }
}
