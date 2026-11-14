import 'app_database.dart';
import 'catalog_seed_100.dart';
import 'catalog_seed_dairy.dart';
import 'catalog_seed_bakery.dart';

/// Structured audit report of catalog SKUs across specialized verticals
class SkuAuditResult {
  final int totalSkus;
  final int frozenSkus;
  final int dairySkus;
  final int bakerySkus;
  final bool isBalanced;
  final Map<String, int> categoriesCount;

  const SkuAuditResult({
    required this.totalSkus,
    required this.frozenSkus,
    required this.dairySkus,
    required this.bakerySkus,
    required this.isBalanced,
    required this.categoriesCount,
  });

  Map<String, dynamic> toMap() {
    return {
      'totalSkus': totalSkus,
      'frozenSkus': frozenSkus,
      'dairySkus': dairySkus,
      'bakerySkus': bakerySkus,
      'isBalanced': isBalanced,
      'categoriesCount': categoriesCount,
    };
  }
}

/// Helper service for auditing and verifying SKU distribution in SR Foods v2
class SkuAuditQuery {
  const SkuAuditQuery();

  /// Audits the seeded master catalog in memory
  static SkuAuditResult auditCatalogSeed() {
    final frozen = get100CatalogSkus();
    final dairy = get40DairySkus();
    final bakery = get40BakerySkus();

    final catMap = <String, int>{};
    for (final p in frozen) {
      final c = p.category.value;
      catMap[c] = (catMap[c] ?? 0) + 1;
    }
    for (final p in dairy) {
      final c = p.category.value;
      catMap[c] = (catMap[c] ?? 0) + 1;
    }
    for (final p in bakery) {
      final c = p.category.value;
      catMap[c] = (catMap[c] ?? 0) + 1;
    }

    final total = frozen.length + dairy.length + bakery.length;
    return SkuAuditResult(
      totalSkus: total,
      frozenSkus: frozen.length,
      dairySkus: dairy.length,
      bakerySkus: bakery.length,
      isBalanced: total >= 180 && frozen.length >= 100 && dairy.length >= 40 && bakery.length >= 40,
      categoriesCount: catMap,
    );
  }

  /// Audits live SKUs directly from the Drift SQLite database
  static Future<SkuAuditResult> auditDatabase(AppDatabase db) async {
    final products = await db.select(db.products).get();

    int frozen = 0;
    int dairy = 0;
    int bakery = 0;
    final catMap = <String, int>{};

    for (final p in products) {
      final cat = p.category.toLowerCase();
      catMap[p.category] = (catMap[p.category] ?? 0) + 1;

      if (cat.contains('dairy') || cat.contains('milk') || cat.contains('cheese') || cat.contains('paneer')) {
        dairy++;
      } else if (cat.contains('bakery') || cat.contains('bread') || cat.contains('cake') || cat.contains('pastry') || cat.contains('bun')) {
        bakery++;
      } else {
        frozen++;
      }
    }

    return SkuAuditResult(
      totalSkus: products.length,
      frozenSkus: frozen,
      dairySkus: dairy,
      bakerySkus: bakery,
      isBalanced: products.length >= 180,
      categoriesCount: catMap,
    );
  }
}
