import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart';
import 'package:sr_foods/core/database/app_database.dart';
import 'package:sr_foods/core/services/ai_expert_engine.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('AiExpertEngine Tests', () {
    test('computeProductionForecast returns valid recommendations for seeded products', () async {
      // Seed default products
      final pId = await db.into(db.products).insert(
        ProductsCompanion.insert(
          sku: 'SRF-TEST-001',
          name: 'Half Boiled Parota',
          category: const Value('Parota'),
          price: 100.0,
          currentStock: const Value(5), // Below minStock (10)
          minStock: const Value(10),
          isActive: const Value(true),
        ),
      );

      final recommendations = await AiExpertEngine.instance.computeProductionForecast(db);
      expect(recommendations.isNotEmpty, isTrue);

      final rec = recommendations.firstWhere((r) => r.product.id == pId);
      expect(rec.product.name, 'Half Boiled Parota');
      expect(rec.currentStock, 5);
      expect(rec.recommendedBatchUnits, greaterThan(0));
      expect(rec.urgency, anyOf('critical', 'warning'));
      expect(rec.rawMaterialsNeeded.containsKey('Maida Flour (kg)'), isTrue);
    });

    test('computeReplenishmentRadar detects customer order replenishment intervals', () async {
      final cId = await db.into(db.customers).insert(
        CustomersCompanion.insert(
          code: 'CUST-001',
          shopName: 'Krishna Bakery & Sweets',
          ownerName: 'Krishna Rao',
          phone: '9876543210',
          creditLimit: const Value(10000.0),
          currentBalance: const Value(1500.0),
          isActive: const Value(true),
        ),
      );

      final insights = await AiExpertEngine.instance.computeReplenishmentRadar(db);
      expect(insights.isNotEmpty, isTrue);

      final insight = insights.firstWhere((CustomerReplenishmentInsight i) => i.customer.id == cId);
      expect(insight.customer.shopName, 'Krishna Bakery & Sweets');
      expect(insight.suggestedWhatsAppMessage.contains('SR Foods'), isTrue);
    });

    test('computeCreditRiskAudit correctly scores customer risk tier', () async {
      // Safe Customer
      await db.into(db.customers).insert(
        CustomersCompanion.insert(
          code: 'CUST-SAFE',
          shopName: 'Safe Kirana',
          ownerName: 'Ramesh',
          phone: '9876500001',
          creditLimit: const Value(10000.0),
          currentBalance: const Value(1000.0), // 10% utilization
          isActive: const Value(true),
        ),
      );

      // Overdue & High-Risk Customer
      await db.into(db.customers).insert(
        CustomersCompanion.insert(
          code: 'CUST-RISK',
          shopName: 'Defaulter Store',
          ownerName: 'Suresh',
          phone: '9876500002',
          creditLimit: const Value(5000.0),
          currentBalance: const Value(7500.0), // 150% utilization
          isActive: const Value(true),
        ),
      );

      final audit = await AiExpertEngine.instance.computeCreditRiskAudit(db);
      expect(audit.length, greaterThanOrEqualTo(2));

      final safeCust = audit.firstWhere((CreditRiskAssessment a) => a.customer.code == 'CUST-SAFE');
      final riskCust = audit.firstWhere((CreditRiskAssessment a) => a.customer.code == 'CUST-RISK');

      expect(safeCust.creditScore, greaterThan(riskCust.creditScore));
      expect(riskCust.riskTier, 'C_HIGH_RISK');
      expect(riskCust.recommendation.contains('Cash-On-Delivery'), isTrue);
    });

    test('generateExecutiveInsights produces diagnostic tips', () async {
      final tips = await AiExpertEngine.instance.generateExecutiveInsights(db);
      expect(tips.isNotEmpty, isTrue);
      expect(tips.any((BusinessOptimizationInsight t) => t.category == 'sales'), isTrue);
    });
  });
}
