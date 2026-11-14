import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/database_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/services/delivery_route_service.dart';

final deliveryRoutesProvider = FutureProvider.autoDispose<List<DeliveryRouteSummary>>((ref) async {
  final db = ref.watch(databaseProvider);
  return DeliveryRouteService.instance.getActiveRoutes(db);
});

class DriverRouteScreen extends ConsumerStatefulWidget {
  const DriverRouteScreen({super.key});

  @override
  ConsumerState<DriverRouteScreen> createState() => _DriverRouteScreenState();
}

class _DriverRouteScreenState extends ConsumerState<DriverRouteScreen> {
  int _selectedRouteIndex = 0;

  void _showDeliveryDialog(BuildContext context, RouteDeliveryStop stop) {
    final cashCtrl = TextEditingController(text: stop.pendingAmount.toStringAsFixed(0));
    final noteCtrl = TextEditingController();
    String method = 'cash';

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Confirm Delivery Drop', style: AppTextStyles.titleMedium),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  Text(stop.shopName, style: AppTextStyles.titleSmall.copyWith(color: AppColors.primary)),
                  Text('Order: ${stop.orderNumber} • Total: ${CurrencyFormatter.format(stop.grandTotal)}', style: AppTextStyles.bodySmall),
                  const Divider(height: 24),
                  TextFormField(
                    controller: cashCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Amount Collected Today (₹)',
                      prefixIcon: Icon(Icons.currency_rupee_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: method,
                    decoration: const InputDecoration(labelText: 'Payment Method'),
                    items: const [
                      DropdownMenuItem(value: 'cash', child: Text('Cash')),
                      DropdownMenuItem(value: 'upi', child: Text('UPI / QR Scanner')),
                      DropdownMenuItem(value: 'credit', child: Text('Credit (Add to Balance)')),
                    ],
                    onChanged: (v) {
                      if (v != null) setSheetState(() => method = v);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: noteCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Recipient Signature / Shop Handover Note',
                      hintText: 'e.g. Received by Subhan brother',
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () async {
                      final collected = double.tryParse(cashCtrl.text.trim()) ?? 0.0;
                      final db = ref.read(databaseProvider);
                      await DeliveryRouteService.instance.completeDeliveryDrop(
                        db: db,
                        stop: stop,
                        cashCollected: collected,
                        paymentMethod: method,
                        recipientNote: noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
                      );
                      if (ctx.mounted) Navigator.pop(ctx);
                      ref.invalidate(deliveryRoutesProvider);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Delivery recorded for ${stop.shopName}!'),
                            backgroundColor: AppColors.success,
                          ),
                        );
                      }
                    },
                    child: const Text('Mark Delivered & Collect'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final routesAsync = ref.watch(deliveryRoutesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Delivery Van Route'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.invalidate(deliveryRoutesProvider),
          ),
        ],
      ),
      body: routesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (routes) {
          if (routes.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.local_shipping_outlined, size: 64, color: AppColors.textSecondary.withValues(alpha: 0.4)),
                  const SizedBox(height: 16),
                  Text('No active delivery routes today', style: AppTextStyles.titleMedium),
                  const SizedBox(height: 8),
                  Text('Orders created in the app will automatically group here.', style: AppTextStyles.bodySmall),
                ],
              ),
            );
          }

          final currentRoute = routes[_selectedRouteIndex.clamp(0, routes.length - 1)];

          return Column(
            children: [
              // Route Selector Tabs
              Container(
                height: 50,
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: routes.length,
                  itemBuilder: (context, i) {
                    final r = routes[i];
                    final isSelected = i == _selectedRouteIndex;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        selected: isSelected,
                        label: Text('${r.routeName} (${r.completedStops}/${r.totalStops})'),
                        onSelected: (_) => setState(() => _selectedRouteIndex = i),
                      ),
                    );
                  },
                ),
              ),

              // Route Overview Card
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(currentRoute.routeName, style: AppTextStyles.titleMedium.copyWith(color: Colors.white)),
                        Text('${currentRoute.completedStops}/${currentRoute.totalStops} Drops', style: AppTextStyles.titleSmall.copyWith(color: Colors.white)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: currentRoute.totalStops > 0 ? (currentRoute.completedStops / currentRoute.totalStops) : 0.0,
                      backgroundColor: Colors.white.withValues(alpha: 0.3),
                      valueColor: const AlwaysStoppedAnimation(Colors.white),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Cash to Collect on Route:', style: AppTextStyles.bodySmall.copyWith(color: Colors.white.withValues(alpha: 0.9))),
                        Text(CurrencyFormatter.format(currentRoute.totalCashToCollect), style: AppTextStyles.titleSmall.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
              ),

              // Stops List
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: currentRoute.stops.length,
                  itemBuilder: (context, index) {
                    final stop = currentRoute.stops[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: stop.isDelivered
                              ? AppColors.success.withValues(alpha: 0.5)
                              : Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                          width: stop.isDelivered ? 1.5 : 1.0,
                        ),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(14),
                        leading: CircleAvatar(
                          backgroundColor: stop.isDelivered
                              ? AppColors.success.withValues(alpha: 0.15)
                              : AppColors.primary.withValues(alpha: 0.15),
                          child: Icon(
                            stop.isDelivered ? Icons.check_circle_rounded : Icons.store_rounded,
                            color: stop.isDelivered ? AppColors.success : AppColors.primary,
                          ),
                        ),
                        title: Row(
                          children: [
                            Expanded(child: Text(stop.shopName, style: AppTextStyles.titleSmall)),
                            if (stop.isDelivered)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.success.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text('DELIVERED', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.success)),
                              ),
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text('Contact: ${stop.ownerName} (${stop.phone})', style: AppTextStyles.bodySmall),
                            if (stop.address != null && stop.address!.isNotEmpty)
                              Text(stop.address!, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Order Total: ${CurrencyFormatter.format(stop.grandTotal)}', style: AppTextStyles.bodySmall),
                                Text(
                                  stop.pendingAmount > 0 ? 'Due: ${CurrencyFormatter.format(stop.pendingAmount)}' : 'PAID',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: stop.pendingAmount > 0 ? AppColors.error : AppColors.success,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        trailing: stop.isDelivered
                            ? null
                            : ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  visualDensity: VisualDensity.compact,
                                ),
                                onPressed: () => _showDeliveryDialog(context, stop),
                                child: const Text('Drop'),
                              ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
