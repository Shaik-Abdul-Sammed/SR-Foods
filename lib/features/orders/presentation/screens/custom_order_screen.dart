import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/database_provider.dart';
import '../../../../core/domain/money.dart';
import '../../../../core/services/custom_order_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

class CustomOrderScreen extends ConsumerStatefulWidget {
  const CustomOrderScreen({super.key});

  @override
  ConsumerState<CustomOrderScreen> createState() => _CustomOrderScreenState();
}

class _CustomOrderScreenState extends ConsumerState<CustomOrderScreen> {
  final _service = const CustomOrderService();
  String _statusFilter = 'all';
  List<Map<String, dynamic>> _orders = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadCustomOrders();
  }

  Future<void> _loadCustomOrders() async {
    setState(() => _isLoading = true);
    try {
      final db = ref.read(databaseProvider);
      final query = _statusFilter == 'all'
          ? 'SELECT co.*, c.shop_name, c.owner_name, c.phone FROM custom_orders co LEFT JOIN customers c ON c.id = co.customer_id ORDER BY co.delivery_date ASC'
          : 'SELECT co.*, c.shop_name, c.owner_name, c.phone FROM custom_orders co LEFT JOIN customers c ON c.id = co.customer_id WHERE co.status = ? ORDER BY co.delivery_date ASC';

      final rows = await db.customSelect(
        query,
        variables: _statusFilter == 'all' ? [] : [Variable.withString(_statusFilter)],
      ).get();

      if (mounted) {
        setState(() {
          _orders = rows.map((r) => r.data).toList();
        });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showCreateOrderDialog() async {
    final cakeCtrl = TextEditingController(text: 'Belgian Truffle Cake (2 Tier, 2kg)');
    final notesCtrl = TextEditingController(text: 'Happy 50th Anniversary Hotel Grand! Red roses.');
    final totalCtrl = TextEditingController(text: '2200');
    final advanceCtrl = TextEditingController(text: '1000');
    DateTime deliveryDate = DateTime.now().add(const Duration(days: 2));

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Custom Cake Order'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: cakeCtrl,
                decoration: const InputDecoration(labelText: 'Cake Design / Variant'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: notesCtrl,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Decoration / Name Inscription'),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: totalCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Total Price (₹)'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: advanceCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Advance (₹)'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              try {
                final db = ref.read(databaseProvider);
                final total = double.parse(totalCtrl.text);
                final adv = double.parse(advanceCtrl.text);

                await _service.createCustomOrder(
                  db: db,
                  customerId: 1, // Demo/default customer
                  deliveryDate: deliveryDate,
                  cakeType: cakeCtrl.text.trim(),
                  decorationNotes: notesCtrl.text.trim(),
                  totalAmountMinor: Money.fromRupees(total).amountMinor,
                  advanceAmountMinor: Money.fromRupees(adv).amountMinor,
                );
                _loadCustomOrders();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Custom cake order booked!')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
                  );
                }
              }
            },
            child: const Text('Book Order'),
          ),
        ],
      ),
    );
  }

  Future<void> _advanceOrder(int orderId) async {
    try {
      final db = ref.read(databaseProvider);
      final next = await _service.advanceStatus(db: db, orderId: orderId);
      _loadCustomOrders();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Order advanced to $next!'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  Future<void> _viewWorkOrderTicket(int orderId) async {
    try {
      final db = ref.read(databaseProvider);
      final ticketText = await _service.generateCustomOrderTicket(db: db, orderId: orderId);

      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Kitchen Work Order Ticket'),
            content: SingleChildScrollView(
              child: SelectableText(
                ticketText,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ),
            actions: [
              TextButton.icon(
                icon: const Icon(Icons.copy),
                label: const Text('Copy Ticket'),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: ticketText));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Ticket copied to clipboard!')),
                  );
                },
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Close'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Custom Celebration Cakes'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadCustomOrders,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateOrderDialog,
        icon: const Icon(Icons.cake_outlined),
        label: const Text('New Custom Cake'),
      ),
      body: Column(
        children: [
          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _filterChip('all', 'All Orders'),
                _filterChip('enquiry', 'Enquiries'),
                _filterChip('confirmed', 'Confirmed'),
                _filterChip('in_production', 'Baking / Frosting'),
                _filterChip('ready', 'Ready for Pickup'),
                _filterChip('delivered', 'Delivered'),
              ],
            ),
          ),
          const Divider(height: 1),

          // Orders List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _orders.isEmpty
                    ? Center(
                        child: Text(
                          'No custom cake orders found in "$_statusFilter".',
                          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _orders.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (ctx, i) {
                          final o = _orders[i];
                          final id = o['id'] as int;
                          final cake = o['cake_type'] ?? 'Custom Cake';
                          final customer = o['shop_name'] ?? o['owner_name'] ?? 'Walk-in Client';
                          final status = o['status'] ?? 'enquiry';
                          final totalMinor = o['total_amount_minor'] as int? ?? 0;
                          final advMinor = o['advance_amount_minor'] as int? ?? 0;
                          final balMinor = totalMinor - advMinor;
                          final delDate = DateTime.tryParse(o['delivery_date'] ?? '') ?? DateTime.now();

                          return Card(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('#CK-$id', style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary)),
                                      Chip(
                                        label: Text(status.toString().toUpperCase()),
                                        backgroundColor: status == 'ready'
                                            ? AppColors.success.withValues(alpha: 0.15)
                                            : status == 'in_production'
                                                ? AppColors.warning.withValues(alpha: 0.15)
                                                : AppColors.primary.withValues(alpha: 0.15),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(cake.toString(), style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 4),
                                  Text('Client: $customer', style: AppTextStyles.bodyMedium),
                                  Text(
                                    'Delivery: ${delDate.day}/${delDate.month}/${delDate.year} at ${delDate.hour.toString().padLeft(2, '0')}:${delDate.minute.toString().padLeft(2, '0')}',
                                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Text(
                                        'Total: ${Money(amountMinor: totalMinor).format()}',
                                        style: AppTextStyles.titleSmall.copyWith(fontWeight: FontWeight.bold),
                                      ),
                                      const Spacer(),
                                      Text(
                                        'Bal Due: ${Money(amountMinor: balMinor).format()}',
                                        style: AppTextStyles.titleSmall.copyWith(
                                          color: balMinor > 0 ? AppColors.error : AppColors.success,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const Divider(height: 20),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      OutlinedButton.icon(
                                        onPressed: () => _viewWorkOrderTicket(id),
                                        icon: const Icon(Icons.receipt_outlined, size: 16),
                                        label: const Text('Kitchen Ticket'),
                                      ),
                                      const SizedBox(width: 8),
                                      FilledButton.icon(
                                        onPressed: status == 'delivered' ? null : () => _advanceOrder(id),
                                        icon: const Icon(Icons.arrow_forward, size: 16),
                                        label: Text(
                                          status == 'enquiry'
                                              ? 'Confirm'
                                              : status == 'confirmed'
                                                  ? 'Start Bake'
                                                  : status == 'in_production'
                                                      ? 'Mark Ready'
                                                      : 'Mark Delivered',
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String key, String label) {
    final isSelected = _statusFilter == key;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        selected: isSelected,
        label: Text(label),
        onSelected: (val) {
          setState(() => _statusFilter = key);
          _loadCustomOrders();
        },
      ),
    );
  }
}
