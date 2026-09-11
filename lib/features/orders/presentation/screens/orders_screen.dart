import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/database/database_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/formatters.dart';

// StreamProvider so orders list refreshes automatically after new orders are created
final ordersListProvider = StreamProvider<List<Map<String, dynamic>>>((ref) async* {
  final db = ref.watch(databaseProvider);
  await for (final _ in (db.select(db.orders)).watch()) {
    yield await db.getOrdersWithCustomers();
  }
});


final orderSearchProvider = NotifierProvider<OrderSearchNotifier, String>(OrderSearchNotifier.new);

class OrderSearchNotifier extends Notifier<String> {
  @override
  String build() => '';
  void update(String val) => state = val;
}

class OrdersScreen extends ConsumerStatefulWidget {
  const OrdersScreen({super.key});
  @override
  ConsumerState<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends ConsumerState<OrdersScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ordersAsync = ref.watch(ordersListProvider);
    final searchQuery = ref.watch(orderSearchProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Orders'),
        actions: [
          IconButton(
            onPressed: () => context.push('/orders/create'),
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              onChanged: (val) =>
                  ref.read(orderSearchProvider.notifier).update(val),
              decoration: InputDecoration(
                hintText: 'Search orders by # or customer...',
                prefixIcon: const Icon(Icons.search_rounded),
                filled: true,
                fillColor: AppColors.surfaceVariant,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                suffixIcon: searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () {
                          _searchController.clear();
                          ref.read(orderSearchProvider.notifier).update('');
                        },
                      )
                    : null,
              ),
            ),
          ),
          Expanded(
            child: ordersAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (orders) {
                final filtered = searchQuery.isEmpty
                    ? orders
                    : orders.where((o) {
                        final order = o['order'] as Order;
                        final customer = o['customer'] as Customer?;
                        final q = searchQuery.toLowerCase();
                        return order.orderNumber.toLowerCase().contains(q) ||
                            (customer?.shopName.toLowerCase().contains(q) ?? false);
                      }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.receipt_long_outlined,
                            size: 64,
                            color: AppColors.textSecondary.withValues(alpha: 0.4)),
                        const SizedBox(height: 16),
                        Text(
                            searchQuery.isEmpty
                                ? 'No orders yet'
                                : 'No orders found',
                            style: AppTextStyles.titleMedium
                                .copyWith(color: AppColors.textSecondary)),
                        const SizedBox(height: 16),
                        if (searchQuery.isEmpty)
                          ElevatedButton.icon(
                            onPressed: () => context.push('/orders/create'),
                            icon: const Icon(Icons.add_rounded),
                            label: const Text('Create Order'),
                          ),
                      ],
                    ),
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(ordersListProvider);
                    await Future<void>.delayed(const Duration(milliseconds: 500));
                  },
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics()),
                    itemCount: filtered.length,
                    itemBuilder: (context, i) {
                      final order = filtered[i]['order'] as Order;
                      final customer = filtered[i]['customer'] as Customer?;
                      Color statusColor;
                      switch (order.status) {
                        case 'delivered':
                          statusColor = AppColors.success;
                          break;
                        case 'pending':
                          statusColor = AppColors.warning;
                          break;
                        case 'processing':
                          statusColor = AppColors.info;
                          break;
                        default:
                          statusColor = AppColors.error;
                      }
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: Theme.of(context)
                                  .colorScheme
                                  .outline
                                  .withValues(alpha: 0.2)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.03),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => context.push('/orders/${order.id}'),
                            borderRadius: BorderRadius.circular(16),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Row(
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                        color: AppColors.primaryContainer,
                                        borderRadius: BorderRadius.circular(10)),
                                    child: const Icon(Icons.receipt_long_rounded,
                                        color: AppColors.primary, size: 20),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                            customer?.shopName ?? 'Unknown',
                                            style: AppTextStyles.titleSmall,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis),
                                        Text(order.orderNumber,
                                            style: AppTextStyles.bodySmall),
                                        Text(
                                            DateFormatter.toDate(
                                                order.orderDate),
                                            style: AppTextStyles.labelSmall
                                                .copyWith(
                                                    color: AppColors
                                                        .textSecondary)),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                          CurrencyFormatter.format(
                                              order.grandTotal),
                                          style: AppTextStyles.titleSmall
                                              .copyWith(
                                                  color: AppColors.primary,
                                                  fontWeight: FontWeight.w700)),
                                      Container(
                                        margin: const EdgeInsets.only(top: 4),
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                            color: statusColor
                                                .withValues(alpha: 0.1),
                                            borderRadius:
                                                BorderRadius.circular(20)),
                                        child: Text(
                                            order.status.toUpperCase(),
                                            style: AppTextStyles.badge.copyWith(
                                                color: statusColor,
                                                fontSize: 9)),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ).animate()
                       .fade(duration: 400.ms, delay: (i * 50).ms)
                       .slideX(begin: 0.1, end: 0, duration: 400.ms, curve: Curves.easeOutQuad);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/orders/create'),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New Order'),
      ),
    );
  }
}
