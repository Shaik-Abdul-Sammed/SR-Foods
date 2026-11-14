import 'dart:convert';
import 'package:drift/drift.dart';
import '../database/app_database.dart';

/// Multi-unit measurement conversion result
class UnitConversionResult {
  final int totalPieces;
  final int totalPacks;
  final double masterCartons;
  final double palletLoads;
  final double totalWeightKg;

  const UnitConversionResult({
    required this.totalPieces,
    required this.totalPacks,
    required this.masterCartons,
    required this.palletLoads,
    required this.totalWeightKg,
  });
}

/// Service to handle automated recurring standing orders and B2B bulk unit conversions
class StandingOrderService {
  StandingOrderService._();
  static final StandingOrderService instance = StandingOrderService._();

  /// Standard pallets hold 40 master cartons
  static const int cartonsPerPallet = 40;

  /// Converts pack quantities across B2B multi-unit tiers (Pieces, Inner Packs, Master Cartons, Pallets)
  UnitConversionResult convertUnits({
    required Product product,
    required int quantityPacks,
  }) {
    final pieces = quantityPacks * product.piecesPerPack;
    final cartons = product.packsPerMasterCarton > 0
        ? quantityPacks / product.packsPerMasterCarton
        : quantityPacks.toDouble();
    final pallets = cartons / cartonsPerPallet;
    final totalKg = (quantityPacks * product.weightGrams) / 1000.0;

    return UnitConversionResult(
      totalPieces: pieces,
      totalPacks: quantityPacks,
      masterCartons: double.parse(cartons.toStringAsFixed(2)),
      palletLoads: double.parse(pallets.toStringAsFixed(3)),
      totalWeightKg: double.parse(totalKg.toStringAsFixed(2)),
    );
  }

  /// Determines if a recurring standing order is due on a given target date
  bool shouldGenerateOrderForDate({
    required StandingOrder standingOrder,
    required DateTime targetDate,
  }) {
    if (!standingOrder.isActive) return false;

    // Check date validity
    if (targetDate.isBefore(DateTime(standingOrder.activeFrom.year, standingOrder.activeFrom.month, standingOrder.activeFrom.day))) {
      return false;
    }
    if (standingOrder.activeTo != null && targetDate.isAfter(standingOrder.activeTo!)) {
      return false;
    }

    // Check if already generated today
    if (standingOrder.lastGeneratedAt != null) {
      final last = standingOrder.lastGeneratedAt!;
      if (last.year == targetDate.year && last.month == targetDate.month && last.day == targetDate.day) {
        return false;
      }
    }

    // Parse recurring days (1 = Monday, 7 = Sunday)
    try {
      final List<dynamic> days = jsonDecode(standingOrder.recurringDaysJson) as List<dynamic>;
      final weekday = targetDate.weekday; // 1 = Monday, 7 = Sunday
      return days.map((e) => (e as num).toInt()).contains(weekday);
    } catch (_) {
      return false;
    }
  }

  /// Generates an order in the database for a due standing order
  Future<int?> generateStandingOrderExecution({
    required AppDatabase db,
    required StandingOrder standingOrder,
    required DateTime targetDate,
  }) async {
    if (!shouldGenerateOrderForDate(standingOrder: standingOrder, targetDate: targetDate)) {
      return null;
    }

    final basketList = jsonDecode(standingOrder.defaultBasketJson) as List<dynamic>;
    if (basketList.isEmpty) return null;

    final customer = await (db.select(db.customers)..where((c) => c.id.equals(standingOrder.customerId))).getSingleOrNull();
    if (customer == null) return null;

    final orderNumber = 'ORD-AUTO-${standingOrder.customerId}-${targetDate.year}${targetDate.month.toString().padLeft(2, '0')}${targetDate.day.toString().padLeft(2, '0')}';

    // Calculate subtotal
    double subtotal = 0.0;
    final itemInserts = <Map<String, dynamic>>[];

    for (final item in basketList) {
      final prodId = (item['productId'] as num).toInt();
      final qty = (item['quantity'] as num).toInt();
      final product = await (db.select(db.products)..where((p) => p.id.equals(prodId))).getSingleOrNull();

      if (product != null) {
        final lineTotal = product.price * qty;
        subtotal += lineTotal;
        itemInserts.add({
          'productId': prodId,
          'productName': product.name,
          'price': product.price,
          'quantity': qty,
          'total': lineTotal,
        });
      }
    }

    final orderId = await db.into(db.orders).insert(
          OrdersCompanion.insert(
            orderNumber: orderNumber,
            customerId: standingOrder.customerId,
            subtotal: Value(subtotal),
            grandTotal: Value(subtotal),
            pendingAmount: Value(subtotal),
            orderDate: Value(targetDate),
            status: const Value('pending'),
            paymentStatus: const Value('unpaid'),
            notes: const Value('Generated via Automated Daily Standing Order Schedule'),
          ),
        );

    for (final itm in itemInserts) {
      await db.into(db.orderItems).insert(
            OrderItemsCompanion.insert(
              orderId: orderId,
              productId: itm['productId'] as int,
              productName: itm['productName'] as String,
              price: itm['price'] as double,
              quantity: itm['quantity'] as int,
              total: itm['total'] as double,
            ),
          );
    }

    // Update lastGeneratedAt on standing order
    await (db.update(db.standingOrders)..where((s) => s.id.equals(standingOrder.id))).write(
      StandingOrdersCompanion(
        lastGeneratedAt: Value(targetDate),
      ),
    );

    return orderId;
  }
}
