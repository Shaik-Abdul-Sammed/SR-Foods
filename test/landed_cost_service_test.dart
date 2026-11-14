import 'package:flutter_test/flutter_test.dart';
import 'package:sr_foods/core/domain/money.dart';
import 'package:sr_foods/core/i18n/locale_context.dart';
import 'package:sr_foods/core/services/landed_cost_service.dart';

void main() {
  const service = LandedCostService();

  group('Landed Cost & HS-Code Duty Helper: 10 Worked Fixtures', () {
    test('1. UAE: Standard GCC 5% duty + 5% VAT on CIF (exact minor units)', () {
      // FOB: 20,000 AED, Freight: 2,000 AED, Insurance: 500 AED -> CIF = 22,500.00 AED (2,250,000 fils)
      // Duty 5%: 22,500 * 0.05 = 1,125.00 AED (112,500 fils)
      // Taxable for VAT: 22,500 + 1,125 = 23,625.00 AED
      // VAT 5%: 23,625 * 0.05 = 1,181.25 AED -> rounded minor = 118,125 fils
      // Total Landed: 22,500 + 1,125 + 1,181.25 = 24,806.25 AED (2,480,625 fils)
      // 500 cartons -> per carton: 2,480,625 / 500 = 4,961 fils = 49.61 AED
      // 24 units/carton (12,000 units) -> per pack: 2,480,625 / 12,000 = 207 fils = 2.07 AED
      final input = LandedCostInput(
        fobPrice: Money.fromMajor(20000.0, currency: Currency.aed),
        freight: Money.fromMajor(2000.0, currency: Currency.aed),
        insurance: Money.fromMajor(500.0, currency: Currency.aed),
        destinationCountry: 'AE',
        hsCode: '1905.90.90',
        cartonCount: 500,
        unitsPerCarton: 24,
      );

      final result = service.computeLandedCost(input);

      expect(result.cifValue.amountMinor, 2250000);
      expect(result.customsDutyAmount.amountMinor, 112500);
      expect(result.importVatAmount.amountMinor, 118125);
      expect(result.totalLandedCost.amountMinor, 2480625);
      expect(result.costPerCarton.amountMinor, 4961);
      expect(result.costPerConsumerPack.amountMinor, 207);
    });

    test('2. UAE: JAFZA Free Zone Entry with 0% VAT override', () {
      final input = LandedCostInput(
        fobPrice: Money.fromMajor(10000.0, currency: Currency.aed),
        freight: Money.fromMajor(1000.0, currency: Currency.aed),
        insurance: Money.fromMajor(200.0, currency: Currency.aed),
        destinationCountry: 'AE',
        hsCode: '1905.90.90',
        cartonCount: 250,
        vatRateOverride: 0.00,
      );

      final result = service.computeLandedCost(input);
      expect(result.cifValue.amountMinor, 1120000); // 11,200 AED
      expect(result.customsDutyAmount.amountMinor, 56000); // 5% = 560 AED
      expect(result.importVatAmount.amountMinor, 0);
      expect(result.totalLandedCost.amountMinor, 1176000); // 11,760 AED
    });

    test('3. Saudi Arabia (KSA): GCC 5% duty + 15% Standard VAT', () {
      final input = LandedCostInput(
        fobPrice: Money.fromMajor(10000.0, currency: Currency.usd),
        freight: Money.fromMajor(1500.0, currency: Currency.usd),
        insurance: Money.fromMajor(300.0, currency: Currency.usd),
        destinationCountry: 'SA',
        hsCode: '1905.90.90',
        cartonCount: 200,
      );

      final result = service.computeLandedCost(input);
      // CIF = $11,800.00 (1,180,000 cents)
      // Duty 5% = $590.00 (59,000 cents)
      // Taxable = $12,390.00
      // VAT 15% = 12,390 * 0.15 = $1,858.50 (185,850 cents)
      // Total = $14,248.50 (1,424,850 cents)
      expect(result.cifValue.amountMinor, 1180000);
      expect(result.customsDutyAmount.amountMinor, 59000);
      expect(result.importVatAmount.amountMinor, 185850);
      expect(result.totalLandedCost.amountMinor, 1424850);
    });

    test('4. US: Chapter 19 MFN Free (0% duty, 0% import VAT)', () {
      final input = LandedCostInput(
        fobPrice: Money.fromMajor(15000.0, currency: Currency.usd),
        freight: Money.fromMajor(2500.0, currency: Currency.usd),
        insurance: Money.fromMajor(400.0, currency: Currency.usd),
        destinationCountry: 'US',
        hsCode: '1905.90.10',
        cartonCount: 600,
      );

      final result = service.computeLandedCost(input);
      // CIF = $17,900.00
      expect(result.cifValue.amountMinor, 1790000);
      expect(result.customsDutyAmount.amountMinor, 0);
      expect(result.importVatAmount.amountMinor, 0);
      expect(result.totalLandedCost.amountMinor, 1790000);
      // Per carton: 1,790,000 / 600 = 2,983 cents = $29.83
      expect(result.costPerCarton.amountMinor, 2983);
    });

    test('5. US: Special Tariff override (e.g. 2.5% anti-dumping or safeguard)', () {
      final input = LandedCostInput(
        fobPrice: Money.fromMajor(10000.0, currency: Currency.usd),
        freight: Money.fromMajor(1000.0, currency: Currency.usd),
        insurance: Money.fromMajor(200.0, currency: Currency.usd),
        destinationCountry: 'US',
        hsCode: '1905.90.90',
        cartonCount: 400,
        dutyRateOverride: 0.025, // 2.5%
      );

      final result = service.computeLandedCost(input);
      // CIF = $11,200.00
      // Duty 2.5% = $280.00 (28,000 cents)
      // Total = $11,480.00
      expect(result.customsDutyAmount.amountMinor, 28000);
      expect(result.totalLandedCost.amountMinor, 1148000);
    });

    test('6. UK: Global Tariff 0% + 0% VAT Zero-rated human food', () {
      final input = LandedCostInput(
        fobPrice: Money.fromMajor(8000.0, currency: Currency.gbp),
        freight: Money.fromMajor(1200.0, currency: Currency.gbp),
        insurance: Money.fromMajor(150.0, currency: Currency.gbp),
        destinationCountry: 'GB',
        hsCode: '1905.90.90',
        cartonCount: 300,
      );

      final result = service.computeLandedCost(input);
      // CIF = £9,350.00 (935,000 pence)
      expect(result.cifValue.amountMinor, 935000);
      expect(result.customsDutyAmount.amountMinor, 0);
      expect(result.importVatAmount.amountMinor, 0);
      expect(result.totalLandedCost.amountMinor, 935000);
    });

    test('7. UK: Tariff quota breach override (e.g. 8% duty + 20% standard VAT)', () {
      final input = LandedCostInput(
        fobPrice: Money.fromMajor(5000.0, currency: Currency.gbp),
        freight: Money.fromMajor(500.0, currency: Currency.gbp),
        insurance: Money.fromMajor(100.0, currency: Currency.gbp),
        destinationCountry: 'GB',
        hsCode: '1905.90.90',
        cartonCount: 150,
        dutyRateOverride: 0.08,
        vatRateOverride: 0.20,
      );

      final result = service.computeLandedCost(input);
      // CIF = £5,600.00 (560,000 pence)
      // Duty 8% = £448.00 (44,800 pence)
      // Taxable = £6,048.00
      // VAT 20% = £1,209.60 (120,960 pence)
      // Total = £7,257.60 (725,760 pence)
      expect(result.cifValue.amountMinor, 560000);
      expect(result.customsDutyAmount.amountMinor, 44800);
      expect(result.importVatAmount.amountMinor, 120960);
      expect(result.totalLandedCost.amountMinor, 725760);
    });

    test('8. Canada: MFN 0% Customs Duty + 5% Federal GST', () {
      final input = LandedCostInput(
        fobPrice: Money.fromMajor(12000.0, currency: Currency.cad),
        freight: Money.fromMajor(1800.0, currency: Currency.cad),
        insurance: Money.fromMajor(250.0, currency: Currency.cad),
        destinationCountry: 'CA',
        hsCode: '1905.90.90',
        cartonCount: 400,
      );

      final result = service.computeLandedCost(input);
      // CIF = CAD 14,050.00 (1,405,000 cents)
      // Duty 0% = 0
      // GST 5% = CAD 702.50 (70,250 cents)
      // Total = CAD 14,752.50 (1,475,250 cents)
      expect(result.cifValue.amountMinor, 1405000);
      expect(result.customsDutyAmount.amountMinor, 0);
      expect(result.importVatAmount.amountMinor, 70250);
      expect(result.totalLandedCost.amountMinor, 1475250);
    });

    test('9. Canada: Basic Groceries Zero-Rated GST Override (0% GST)', () {
      final input = LandedCostInput(
        fobPrice: Money.fromMajor(6000.0, currency: Currency.cad),
        freight: Money.fromMajor(800.0, currency: Currency.cad),
        insurance: Money.fromMajor(100.0, currency: Currency.cad),
        destinationCountry: 'CA',
        hsCode: '1905.90.90',
        cartonCount: 200,
        vatRateOverride: 0.00,
      );

      final result = service.computeLandedCost(input);
      // CIF = CAD 6,900.00
      expect(result.cifValue.amountMinor, 690000);
      expect(result.importVatAmount.amountMinor, 0);
      expect(result.totalLandedCost.amountMinor, 690000);
    });

    test('10. Australia: 5% Customs Duty + 10% GST on (CIF + Duty)', () {
      final input = LandedCostInput(
        fobPrice: Money.fromMajor(10000.0, currency: Currency.aud),
        freight: Money.fromMajor(1400.0, currency: Currency.aud),
        insurance: Money.fromMajor(200.0, currency: Currency.aud),
        destinationCountry: 'AU',
        hsCode: '1905.90.90',
        cartonCount: 300,
        unitsPerCarton: 24,
      );

      final result = service.computeLandedCost(input);
      // CIF = AUD 11,600.00 (1,160,000 cents)
      // Duty 5% = AUD 580.00 (58,000 cents)
      // Taxable = AUD 12,180.00
      // GST 10% = AUD 1,218.00 (121,800 cents)
      // Total = AUD 13,398.00 (1,339,800 cents)
      expect(result.cifValue.amountMinor, 1160000);
      expect(result.customsDutyAmount.amountMinor, 58000);
      expect(result.importVatAmount.amountMinor, 121800);
      expect(result.totalLandedCost.amountMinor, 1339800);

      // Per carton: 1,339,800 / 300 = 4,466 cents = AUD 44.66
      expect(result.costPerCarton.amountMinor, 4466);
      // Per consumer pack: 1,339,800 / (300 * 24 = 7200) = 186 cents = AUD 1.86
      expect(result.costPerConsumerPack.amountMinor, 186);
    });
  });
}
