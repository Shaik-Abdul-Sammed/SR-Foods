import 'package:drift/drift.dart' show Variable;
import '../database/app_database.dart';
import '../domain/money.dart';

class CustomOrderResult {
  final int orderId;
  final int customerId;
  final DateTime orderDate;
  final DateTime deliveryDate;
  final String cakeType;
  final String? decorationNotes;
  final String? photoRef;
  final Money advanceAmount;
  final Money totalAmount;
  final Money balanceDue;
  final String status;

  const CustomOrderResult({
    required this.orderId,
    required this.customerId,
    required this.orderDate,
    required this.deliveryDate,
    required this.cakeType,
    this.decorationNotes,
    this.photoRef,
    required this.advanceAmount,
    required this.totalAmount,
    required this.balanceDue,
    required this.status,
  });
}

/// Service managing made-to-order celebratory cakes, status workflow, and kitchen work-order tickets
class CustomOrderService {
  const CustomOrderService();

  static const List<String> statusPipeline = [
    'enquiry',
    'confirmed',
    'in_production',
    'ready',
    'delivered',
  ];

  /// Creates a new custom cake order and stores it in the database
  Future<CustomOrderResult> createCustomOrder({
    required AppDatabase db,
    required int customerId,
    required DateTime deliveryDate,
    required String cakeType,
    String? decorationNotes,
    String? photoRef,
    required int totalAmountMinor,
    int advanceAmountMinor = 0,
    String status = 'confirmed',
  }) async {
    final now = DateTime.now();

    await db.customStatement(
      'INSERT INTO custom_orders ('
      'customer_id, order_date, delivery_date, cake_type, decoration_notes, '
      'photo_ref, advance_amount_minor, total_amount_minor, status, created_at'
      ') VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
      [
        customerId,
        now.toIso8601String(),
        deliveryDate.toIso8601String(),
        cakeType,
        decorationNotes,
        photoRef,
        advanceAmountMinor,
        totalAmountMinor,
        status,
        now.toIso8601String(),
      ],
    );

    final lastIdRow = await db.customSelect('SELECT last_insert_rowid() as id').getSingle();
    final id = lastIdRow.read<int>('id');
    final balance = totalAmountMinor - advanceAmountMinor;

    return CustomOrderResult(
      orderId: id,
      customerId: customerId,
      orderDate: now,
      deliveryDate: deliveryDate,
      cakeType: cakeType,
      decorationNotes: decorationNotes,
      photoRef: photoRef,
      advanceAmount: Money(amountMinor: advanceAmountMinor),
      totalAmount: Money(amountMinor: totalAmountMinor),
      balanceDue: Money(amountMinor: balance > 0 ? balance : 0),
      status: status,
    );
  }

  /// Advances custom order to the next milestone in the production workflow pipeline
  Future<String> advanceStatus({
    required AppDatabase db,
    required int orderId,
  }) async {
    final rows = await db.customSelect(
      'SELECT status FROM custom_orders WHERE id = ?',
      variables: [Variable.withInt(orderId)],
    ).get();

    if (rows.isEmpty) {
      throw ArgumentError('Custom order #$orderId not found.');
    }

    final currentStatus = rows.first.read<String>('status');
    final currentIndex = statusPipeline.indexOf(currentStatus);

    if (currentIndex == -1 || currentIndex >= statusPipeline.length - 1) {
      return currentStatus; // Already at final stage or cancelled
    }

    final nextStatus = statusPipeline[currentIndex + 1];

    await db.customStatement(
      'UPDATE custom_orders SET status = ? WHERE id = ?',
      [nextStatus, orderId],
    );

    return nextStatus;
  }

  /// Generates formatted ASCII kitchen work-order ticket for pastry chefs and decorators
  Future<String> generateCustomOrderTicket({
    required AppDatabase db,
    required int orderId,
  }) async {
    final rows = await db.customSelect(
      'SELECT co.*, c.shop_name, c.owner_name, c.phone '
      'FROM custom_orders co '
      'LEFT JOIN customers c ON c.id = co.customer_id '
      'WHERE co.id = ?',
      variables: [Variable.withInt(orderId)],
    ).get();

    if (rows.isEmpty) {
      throw ArgumentError('Custom order #$orderId not found.');
    }

    final r = rows.first;
    final cakeType = r.read<String>('cake_type');
    final notes = r.read<String?>('decoration_notes') ?? 'Standard bakery presentation.';
    final delivery = r.read<DateTime>('delivery_date');
    final customer = r.read<String?>('shop_name') ?? r.read<String?>('owner_name') ?? 'Direct Walk-in';
    final phone = r.read<String?>('phone') ?? 'N/A';
    final advance = r.read<int>('advance_amount_minor');
    final total = r.read<int>('total_amount_minor');
    final status = r.read<String>('status').toUpperCase();

    final totalMoney = Money(amountMinor: total);
    final advanceMoney = Money(amountMinor: advance);
    final balanceMoney = Money(amountMinor: total - advance);

    return '''
==================================================
        SR FOODS BAKERY — KITCHEN WORK TICKET
==================================================
ORDER ID:      #CK-$orderId
STATUS:        [$status]
DELIVERY BY:   ${delivery.toLocal().toString().substring(0, 16)}
--------------------------------------------------
CUSTOMER:      $customer
CONTACT:       $phone
--------------------------------------------------
CAKE VARIANT:  $cakeType
DECORATION / INSCRIPTION NOTES:
$notes
--------------------------------------------------
COMMERCIALS:
Total Price:   ${totalMoney.format()}
Advance Paid:  ${advanceMoney.format()}
Balance Due:   ${balanceMoney.format()}
==================================================
[ Chef Sign-off: _________ ]  [ QC Passed: [x] ]
''';
  }
}
