import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:sr_foods/core/database/app_database.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('SKU Master Catalog 180-Item Validation Tests', () {
    test('1. Master catalog seeds exactly 180 SKUs (100 Frozen + 40 Dairy + 40 Bakery)', () async {
      final allProducts = await db.select(db.products).get();
      expect(allProducts.length, equals(180));

      final dairy = allProducts.where((p) => p.category == 'Dairy').toList();
      final bakery = allProducts.where((p) => p.category == 'Bakery').toList();
      final frozen = allProducts.where((p) => p.category != 'Dairy' && p.category != 'Bakery').toList();

      expect(dairy.length, equals(40));
      expect(bakery.length, equals(40));
      expect(frozen.length, equals(100));
    });

    test('2. Uniqueness check: zero duplicate SKU codes and zero duplicate barcodes', () async {
      final allProducts = await db.select(db.products).get();

      final skuCodes = allProducts.map((p) => p.sku).toList();
      final uniqueSkus = skuCodes.toSet();
      expect(skuCodes.length, equals(uniqueSkus.length), reason: 'Duplicate SKU code detected in catalog!');

      final barcodes = allProducts.map((p) => p.barcode).whereType<String>().toList();
      final uniqueBarcodes = barcodes.toSet();
      expect(barcodes.length, equals(uniqueBarcodes.length), reason: 'Duplicate barcode detected in catalog!');
    });

    test('3. Schema completeness: all 180 SKUs populate core commercial & compliance attributes', () async {
      final allProducts = await db.select(db.products).get();

      for (final p in allProducts) {
        expect(p.sku, startsWith('SRF-'));
        expect(p.name.trim().isNotEmpty, isTrue, reason: '${p.sku} has empty name');
        expect(p.category.trim().isNotEmpty, isTrue, reason: '${p.sku} has empty category');
        expect(p.unit.trim().isNotEmpty, isTrue, reason: '${p.sku} has empty unit');
        expect(p.price, greaterThan(0), reason: '${p.sku} has invalid price <= 0');
        expect(p.costPrice, greaterThan(0), reason: '${p.sku} has invalid cost price <= 0');
        expect(p.hsnCode.length, greaterThanOrEqualTo(4), reason: '${p.sku} has invalid HSN code');
        expect(p.storageType, anyOf(['frozen', 'chilled', 'ambient']), reason: '${p.sku} has invalid storage type');
        expect(p.shelfLifeDays, greaterThan(0), reason: '${p.sku} has invalid shelf life days');
      }
    });

    test('4. Vertical specialization: Dairy SKUs (40 items) populate dairy storage, shelf life & FSSAI', () async {
      final allProducts = await db.select(db.products).get();
      final dairyProducts = allProducts.where((p) => p.category == 'Dairy').toList();

      expect(dairyProducts.length, equals(40));
      for (final p in dairyProducts) {
        expect(p.sku, startsWith('SRF-DAI-1'));
        expect(p.storageType, anyOf(['chilled', 'ambient', 'frozen']), reason: '${p.sku} has unexpected storageType');
        expect(p.shelfLifeDays, inInclusiveRange(2, 365), reason: '${p.sku} shelf life out of bounds');
        expect(p.fssaiCategoryCode, isNotNull, reason: '${p.sku} missing fssaiCategoryCode');
        expect(p.allergens, contains('Milk'), reason: '${p.sku} missing Milk allergen declaration');
      }
    });

    test('5. Vertical specialization: Bakery SKUs (40 items) populate bakery storage, shelf life & gluten', () async {
      final allProducts = await db.select(db.products).get();
      final bakeryProducts = allProducts.where((p) => p.category == 'Bakery').toList();

      expect(bakeryProducts.length, equals(40));
      for (final p in bakeryProducts) {
        expect(p.sku, startsWith('SRF-BKY-2'));
        expect(p.storageType, anyOf(['ambient', 'chilled']), reason: '${p.sku} has unexpected storageType');
        expect(p.shelfLifeDays, inInclusiveRange(1, 180), reason: '${p.sku} shelf life out of bounds');
        expect(p.fssaiCategoryCode, isNotNull, reason: '${p.sku} missing fssaiCategoryCode');
        expect(p.hsnCode, startsWith('1905'), reason: '${p.sku} bakery items must use HSN Chapter 1905');
      }
    });

    test('6. Tax and fiscal compliance: all items map to valid GST and FSSAI classifications', () async {
      final allProducts = await db.select(db.products).get();

      for (final p in allProducts) {
        expect(
          p.taxCategory,
          anyOf(['NONE', 'GST_0', 'GST_5', 'GST_12', 'GST_18', 'GST_28']),
          reason: '${p.sku} has non-standard taxCategory: ${p.taxCategory}',
        );
      }
    });
  });
}
