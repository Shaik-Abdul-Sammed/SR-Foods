import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/database/database_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/formatters.dart';

final orderDetailProvider = FutureProvider.family<Map<String,dynamic>?, int>((ref, id) async {
  final db = ref.watch(databaseProvider);
  final order = await (db.select(db.orders)..where((o) => o.id.equals(id))).getSingleOrNull();
  if (order == null) return null;
  final customer = await (db.select(db.customers)..where((c) => c.id.equals(order.customerId))).getSingleOrNull();
  final items = await (db.select(db.orderItems)..where((i) => i.orderId.equals(id))).get();
  return {'order': order, 'customer': customer, 'items': items};
});

class OrderDetailScreen extends ConsumerWidget {
  final int id;
  const OrderDetailScreen({super.key, required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(orderDetailProvider(id));
    return async.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e,_) => Scaffold(body: Center(child: Text('Error: $e'))),
      data: (data) {
        if (data == null) return const Scaffold(body: Center(child: Text('Order not found')));
        final order = data['order'] as Order;
        final customer = data['customer'] as Customer?;
        final items = data['items'] as List<OrderItem>;
        return Scaffold(
          appBar: AppBar(title: Text(order.orderNumber)),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              Container(
                width: double.infinity, padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(gradient: AppColors.primaryGradient, borderRadius: BorderRadius.circular(20)),
                child: Column(children: [
                  Text(CurrencyFormatter.format(order.grandTotal), style: AppTextStyles.displaySmall.copyWith(color: Colors.white, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text(customer?.shopName ?? 'Unknown', style: AppTextStyles.bodyMedium.copyWith(color: Colors.white.withValues(alpha: 0.8))),
                  const SizedBox(height: 8),
                  _chip(order.status),
                ]),
              ),
              const SizedBox(height: 16),
              _card(context, 'Order Details', [
                _row('Order No', order.orderNumber),
                _row('Date', DateFormatter.toDateTime(order.orderDate)),
                _row('Payment', order.paymentStatus),
                _row('Pending', CurrencyFormatter.format(order.pendingAmount)),
              ]),
              const SizedBox(height: 12),
              _card(context, 'Items (${items.length})', items.map((item) =>
                Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(item.productName, style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w500)),
                    Text('${item.quantity} × ${CurrencyFormatter.format(item.price)}', style: AppTextStyles.bodySmall),
                  ])),
                  Text(CurrencyFormatter.format(item.total), style: AppTextStyles.titleSmall.copyWith(color: AppColors.primary)),
                ])),
              ).toList()),
            ]),
          ),
        );
      },
    );
  }

  Widget _chip(String status) {
    Color c; switch (status) {
      case 'delivered': c = AppColors.success; break;
      case 'pending': c = AppColors.warning; break;
      case 'processing': c = AppColors.info; break;
      default: c = AppColors.error;
    }
    return Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), decoration: BoxDecoration(color: c.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(20), border: Border.all(color: c.withValues(alpha: 0.4))), child: Text(status.toUpperCase(), style: TextStyle(color: c, fontWeight: FontWeight.w700, fontSize: 11)));
  }

  Widget _card(BuildContext context, String title, List<Widget> rows) {
    return Container(width: double.infinity, padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: AppTextStyles.titleSmall), const SizedBox(height: 12), ...rows]));
  }

  Widget _row(String label, String value) {
    return Padding(padding: const EdgeInsets.symmetric(vertical: 3), child: Row(children: [SizedBox(width: 120, child: Text(label, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary))), Expanded(child: Text(value, style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w500)))]));
  }
}
