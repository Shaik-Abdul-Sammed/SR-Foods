import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:sr_foods/core/database/app_database.dart';
import 'package:sr_foods/core/domain/money.dart';
import 'package:sr_foods/core/domain/quantity.dart';
import 'package:sr_foods/core/domain/weight_volume_count.dart';
import 'package:sr_foods/core/i18n/locale_context.dart';

void main() {
  group('Money Value Object Tests', () {
    test('Exact integer paise arithmetic prevents floating point error', () {
      final a = Money.fromRupees(0.1);
      final b = Money.fromRupees(0.2);
      final sum = a + b;

      expect(sum.paise, 30);
      expect(sum.inRupees, 0.30);
      expect(sum.format(includeSymbol: false), '0.30');
    });

    test('Money operators +, -, *, / behave correctly', () {
      final m1 = Money.fromRupees(150.0);
      final m2 = Money.fromRupees(50.0);

      expect((m1 + m2).inRupees, 200.0);
      expect((m1 - m2).inRupees, 100.0);
      expect((m1 * 3).inRupees, 450.0);
      expect((m1 / 2).inRupees, 75.0);
      expect(m1 > m2, isTrue);
      expect(m2 < m1, isTrue);
      expect(Money.zero.isZero, isTrue);
    });

    test('Indian currency formatting works as expected', () {
      final money = Money.fromRupees(125000.50);
      expect(money.format().contains('1,25,000.50'), isTrue);
    });

    test('Multi-currency Money v2 representation and minor units', () {
      final aed = Money.fromMajor(45.50, currency: Currency.aed);
      expect(aed.amountMinor, 4550);
      expect(aed.inMajor, 45.50);
      expect(aed.currency, Currency.aed);
      expect(aed.format().contains('45.50'), isTrue);

      final usd = Money.fromMajor(12.99, currency: Currency.usd);
      expect(usd.amountMinor, 1299);
      expect(usd.inMajor, 12.99);

      final gbp = Money.fromMajor(100.00, currency: Currency.gbp);
      expect(gbp.amountMinor, 10000);
    });

    test('FX conversion converts between currencies with rate', () {
      final inr = Money.fromRupees(10000); // ₹10,000
      // Assume 1 INR = 0.044 AED (or rate ~ 0.044)
      final aed = inr.convertTo(Currency.aed, 0.044);
      expect(aed.currency, Currency.aed);
      expect(aed.inMajor, closeTo(440.0, 0.1));
      expect(aed.fxRateToBase, 0.044);

      final usd = Money.fromMajor(100, currency: Currency.usd);
      // Assume 1 USD = 83.50 INR
      final inrConverted = usd.convertTo(Currency.inr, 83.50);
      expect(inrConverted.currency, Currency.inr);
      expect(inrConverted.inMajor, 8350.0);
    });

    test('Mismatched currency arithmetic throws ArgumentError', () {
      final inr = Money.fromRupees(100);
      final usd = Money.fromMajor(100, currency: Currency.usd);

      expect(() => inr + usd, throwsArgumentError);
      expect(() => inr - usd, throwsArgumentError);
      expect(() => inr < usd, throwsArgumentError);
    });
  });

  group('Quantity Value Object Tests', () {
    test('Quantity conversions within category work accurately', () {
      const qKg = Quantity(1.5, ProductUnit.kg);
      final qGrams = qKg.convertTo(ProductUnit.g);

      expect(qGrams.amount, 1500.0);
      expect(qGrams.unit, ProductUnit.g);

      const qLiters = Quantity(2.0, ProductUnit.liter);
      final qMl = qLiters.convertTo(ProductUnit.ml);
      expect(qMl.amount, 2000.0);
    });

    test('Quantity addition with unit normalization', () {
      const q1 = Quantity(500, ProductUnit.g);
      const q2 = Quantity(1.0, ProductUnit.kg);
      final sum = q1 + q2;

      expect(sum.amount, 1500.0);
      expect(sum.unit, ProductUnit.g);
    });

    test('Incompatible unit addition throws ArgumentError', () {
      const mass = Quantity(1.0, ProductUnit.kg);
      const volume = Quantity(1.0, ProductUnit.liter);

      expect(() => mass + volume, throwsArgumentError);
    });
  });

  group('Weight Value Object Tests', () {
    test('Weight metric and imperial conversions', () {
      const wKg = Weight(2.5, WeightUnit.kg);
      expect(wKg.inGrams, 2500.0);
      expect(wKg.inKg, 2.5);
      expect(wKg.inLb, closeTo(5.5115, 0.001));

      final wG = wKg.convertTo(WeightUnit.g);
      expect(wG.value, 2500.0);
      expect(wG.unit, WeightUnit.g);

      const wLb = Weight(10.0, WeightUnit.lb);
      final wConvertedKg = wLb.convertTo(WeightUnit.kg);
      expect(wConvertedKg.value, closeTo(4.5359, 0.001));
    });

    test('Weight arithmetic (+, -, *, /)', () {
      const w1 = Weight(500, WeightUnit.g);
      const w2 = Weight(1.5, WeightUnit.kg);
      final sum = w1 + w2;
      expect(sum.inGrams, 2000.0);
      expect(sum.value, 2000.0); // same unit as w1 (g)

      final diff = w2 - w1;
      expect(diff.inGrams, 1000.0);

      final multiplied = w1 * 4;
      expect(multiplied.value, 2000.0);

      final divided = w2 / 3;
      expect(divided.value, 0.5);
    });

    test('Weight comparison and equality', () {
      const a = Weight(1.0, WeightUnit.kg);
      const b = Weight(1000.0, WeightUnit.g);
      const c = Weight(1.2, WeightUnit.kg);

      expect(a == b, isTrue);
      expect(c > a, isTrue);
      expect(a < c, isTrue);
    });
  });

  group('Volume Value Object Tests', () {
    test('Volume metric and US imperial conversions', () {
      const vL = Volume(5.0, VolumeUnit.l);
      expect(vL.inMl, 5000.0);
      expect(vL.inLiters, 5.0);
      expect(vL.inGallons, closeTo(1.3208, 0.001));

      final vMl = vL.convertTo(VolumeUnit.ml);
      expect(vMl.value, 5000.0);
      expect(vMl.unit, VolumeUnit.ml);
    });

    test('Volume arithmetic and equality', () {
      const v1 = Volume(250, VolumeUnit.ml);
      const v2 = Volume(1.0, VolumeUnit.l);
      final sum = v1 + v2;
      expect(sum.inMl, 1250.0);

      const vL1 = Volume(1.0, VolumeUnit.l);
      const vMl1000 = Volume(1000.0, VolumeUnit.ml);
      expect(vL1 == vMl1000, isTrue);
    });
  });

  group('ItemCount Value Object Tests', () {
    test('Count conversions between pieces, packs, dozen, and master cartons', () {
      const pkts = ItemCount(240, CountUnit.packs);
      final cartons = pkts.convertTo(CountUnit.cartons);
      expect(cartons.amount, 10);
      expect(cartons.unit, CountUnit.cartons);

      const dozen = ItemCount(5, CountUnit.dozen);
      expect(dozen.inPieces, 60);

      final pcs = dozen.convertTo(CountUnit.pieces);
      expect(pcs.amount, 60);
    });

    test('ItemCount arithmetic and comparison', () {
      const c1 = ItemCount(2, CountUnit.cartons); // 48 pcs
      const c2 = ItemCount(12, CountUnit.packs); // 12 pcs
      final sum = c1 + c2;
      expect(sum.inPieces, 60);

      expect(c1 > c2, isTrue);
      expect(c2 < c1, isTrue);
    });
  });

  group('ActivityLogs & SyncQueue Tests', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    test('Activity log append and fetch last entries works correctly', () async {
      await db.logActivity(
        action: 'ORDER_PLACED',
        entityType: 'order',
        entityId: 101,
        details: 'Order of ₹2,500 placed for Shop A',
        userId: 'owner',
      );

      final logs = await db.getRecentActivityLogs(limit: 10);
      expect(logs.length, 1);
      expect(logs.first.action, 'ORDER_PLACED');
      expect(logs.first.details?.contains('Shop A'), isTrue);
    });

    test('SyncQueue enqueues resilient offline mutation payloads', () async {
      final id = await db.enqueueSync(
        action: 'insert',
        entityType: 'order',
        payload: '{"orderNumber": "ORD-001", "total": 2000}',
      );

      expect(id, greaterThan(0));

      final queued = await db.select(db.syncQueue).get();
      expect(queued.length, 1);
      expect(queued.first.status, 'pending');
      expect(queued.first.payload.contains('ORD-001'), isTrue);
    });
  });
}
