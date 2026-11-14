import 'package:drift/drift.dart';
import '../database/app_database.dart';

class RouteDeliveryStop {
  final int orderId;
  final String orderNumber;
  final int customerId;
  final String shopName;
  final String ownerName;
  final String phone;
  final String? address;
  final String routeName;
  final double grandTotal;
  final double pendingAmount;
  final String paymentStatus;
  final String orderStatus;

  const RouteDeliveryStop({
    required this.orderId,
    required this.orderNumber,
    required this.customerId,
    required this.shopName,
    required this.ownerName,
    required this.phone,
    this.address,
    required this.routeName,
    required this.grandTotal,
    required this.pendingAmount,
    required this.paymentStatus,
    required this.orderStatus,
  });

  bool get isDelivered => orderStatus == 'delivered';
}

class DeliveryRouteSummary {
  final String routeName;
  final int totalStops;
  final int completedStops;
  final double totalCashToCollect;
  final List<RouteDeliveryStop> stops;

  const DeliveryRouteSummary({
    required this.routeName,
    required this.totalStops,
    required this.completedStops,
    required this.totalCashToCollect,
    required this.stops,
  });

  double get progressPercentage =>
      totalStops > 0 ? (completedStops / totalStops) * 100.0 : 0.0;
}

class DeliveryRouteService {
  DeliveryRouteService._();
  static final DeliveryRouteService instance = DeliveryRouteService._();

  /// Groups active pending and processing orders into delivery routes
  Future<List<DeliveryRouteSummary>> getActiveRoutes(AppDatabase db) async {
    final query = db.select(db.orders).join([
      innerJoin(db.customers, db.customers.id.equalsExp(db.orders.customerId)),
    ])..where(db.orders.status.isNotIn(['cancelled']));

    final rows = await query.get();
    final Map<String, List<RouteDeliveryStop>> grouped = {};

    for (final row in rows) {
      final order = row.readTable(db.orders);
      final customer = row.readTable(db.customers);
      final route = (customer.route != null && customer.route!.trim().isNotEmpty)
          ? customer.route!.trim()
          : (customer.area != null && customer.area!.trim().isNotEmpty)
              ? customer.area!.trim()
              : 'Main Town Route';

      final stop = RouteDeliveryStop(
        orderId: order.id,
        orderNumber: order.orderNumber,
        customerId: customer.id,
        shopName: customer.shopName,
        ownerName: customer.ownerName,
        phone: customer.phone,
        address: customer.address,
        routeName: route,
        grandTotal: order.grandTotal,
        pendingAmount: order.pendingAmount,
        paymentStatus: order.paymentStatus,
        orderStatus: order.status,
      );

      grouped.putIfAbsent(route, () => []).add(stop);
    }

    final List<DeliveryRouteSummary> summaries = [];
    grouped.forEach((routeName, stops) {
      // Sort: undelivered first
      stops.sort((a, b) {
        if (a.isDelivered == b.isDelivered) return 0;
        return a.isDelivered ? 1 : -1;
      });

      final completed = stops.where((s) => s.isDelivered).length;
      final cashToCollect = stops
          .where((s) => !s.isDelivered)
          .fold(0.0, (acc, s) => acc + s.pendingAmount);

      summaries.add(DeliveryRouteSummary(
        routeName: routeName,
        totalStops: stops.length,
        completedStops: completed,
        totalCashToCollect: cashToCollect,
        stops: stops,
      ));
    });

    summaries.sort((a, b) => b.totalStops.compareTo(a.totalStops));
    return summaries;
  }

  /// Complete a delivery drop: mark order delivered, record cash/upi received, and log activity
  Future<void> completeDeliveryDrop({
    required AppDatabase db,
    required RouteDeliveryStop stop,
    required double cashCollected,
    String paymentMethod = 'cash',
    String? recipientNote,
    String? driverName,
  }) async {
    // 1. Update order status
    final remainingPending = (stop.pendingAmount - cashCollected).clamp(0.0, 999999.0);
    final isPaid = remainingPending == 0;

    await (db.update(db.orders)..where((o) => o.id.equals(stop.orderId))).write(
      OrdersCompanion(
        status: const Value('delivered'),
        deliveryDate: Value(DateTime.now()),
        paidAmount: Value(cashCollected),
        pendingAmount: Value(remainingPending),
        paymentStatus: Value(isPaid ? 'paid' : 'partial'),
        updatedAt: Value(DateTime.now()),
      ),
    );

    // 2. If money collected, insert Payment receipt
    if (cashCollected > 0) {
      final receiptNum = 'RCT-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
      await db.into(db.payments).insert(
        PaymentsCompanion.insert(
          receiptNumber: receiptNum,
          customerId: stop.customerId,
          orderId: Value(stop.orderId),
          amount: cashCollected,
          method: paymentMethod,
          notes: Value(recipientNote ?? 'Van Delivery Collection'),
        ),
      );

      // 3. Update customer balance
      final customer = await (db.select(db.customers)..where((c) => c.id.equals(stop.customerId))).getSingle();
      final newBalance = (customer.currentBalance - cashCollected).clamp(0.0, 999999.0);
      await (db.update(db.customers)..where((c) => c.id.equals(stop.customerId))).write(
        CustomersCompanion(
          currentBalance: Value(newBalance),
          updatedAt: Value(DateTime.now()),
        ),
      );
    }

    // 4. Audit Log
    await db.logActivity(
      action: 'DELIVERY_COMPLETED',
      entityType: 'Order',
      entityId: stop.orderId,
      details: 'Drop completed for ${stop.shopName}. Collected ₹${cashCollected.toStringAsFixed(0)}. Driver: ${driverName ?? "Delivery Team"}',
    );
  }
}
