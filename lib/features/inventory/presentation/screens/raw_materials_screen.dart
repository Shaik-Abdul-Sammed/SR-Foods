import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/database_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/services/raw_material_service.dart';
import '../../../../core/services/whatsapp_service.dart';

final rawMaterialStatusProvider = FutureProvider.autoDispose<List<RawMaterialStatus>>((ref) async {
  final db = ref.watch(databaseProvider);
  return RawMaterialService.instance.getInventoryStatus(db);
});

class RawMaterialsScreen extends ConsumerStatefulWidget {
  const RawMaterialsScreen({super.key});

  @override
  ConsumerState<RawMaterialsScreen> createState() => _RawMaterialsScreenState();
}

class _RawMaterialsScreenState extends ConsumerState<RawMaterialsScreen> {
  void _showReceiveStockDialog(RawMaterialStatus item) {
    final qtyCtrl = TextEditingController();
    final rateCtrl = TextEditingController(text: item.lastPurchasePrice.toStringAsFixed(1));
    final vendorCtrl = TextEditingController(text: 'Sri Lakshmi Flour Mill');
    final invCtrl = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text('Receive ${item.name}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: qtyCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(labelText: 'Quantity Received (${item.unit})'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: rateCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(labelText: 'Rate per ${item.unit} (₹)'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: vendorCtrl,
                  decoration: const InputDecoration(labelText: 'Vendor / Supplier Name'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: invCtrl,
                  decoration: const InputDecoration(labelText: 'Vendor Invoice Ref (optional)'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final qty = double.tryParse(qtyCtrl.text.trim()) ?? 0.0;
                final rate = double.tryParse(rateCtrl.text.trim()) ?? item.lastPurchasePrice;
                if (qty <= 0) return;

                final db = ref.read(databaseProvider);
                await RawMaterialService.instance.recordInwardMaterial(
                  db: db,
                  materialId: item.id,
                  quantityReceived: qty,
                  unitPrice: rate,
                  vendorName: vendorCtrl.text.trim(),
                  invoiceRef: invCtrl.text.trim().isEmpty ? null : invCtrl.text.trim(),
                );

                if (ctx.mounted) Navigator.pop(ctx);
                ref.invalidate(rawMaterialStatusProvider);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Received +${qty.toStringAsFixed(1)} ${item.unit} of ${item.name}'),
                    backgroundColor: AppColors.success,
                  ),
                );
              },
              child: const Text('Receive Stock'),
            ),
          ],
        );
      },
    );
  }

  void _sharePurchaseOrder(List<RawMaterialStatus> items) {
    final lowItems = items.where((i) => i.isLowStock).toList();
    final itemsToOrder = lowItems.isNotEmpty ? lowItems : items;

    final poText = RawMaterialService.instance.generatePurchaseOrderDraft(
      itemsToOrder: itemsToOrder,
      supplierName: 'Sri Lakshmi Flour & Oil Suppliers',
    );

    WhatsAppService.shareCustomText(context, poText);
  }

  @override
  Widget build(BuildContext context) {
    final statusAsync = ref.watch(rawMaterialStatusProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Raw Materials & BOM'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_rounded),
            tooltip: 'Draft PO on WhatsApp',
            onPressed: () {
              statusAsync.whenData((items) => _sharePurchaseOrder(items));
            },
          ),
        ],
      ),
      body: statusAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (materials) {
          final lowCount = materials.where((m) => m.isLowStock).length;

          return Column(
            children: [
              if (lowCount > 0)
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('$lowCount Raw Materials Below Safety Level', style: AppTextStyles.titleSmall.copyWith(color: AppColors.error)),
                            Text('Draft PO to prevent mill stockout delays', style: AppTextStyles.bodySmall),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.error,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        onPressed: () => _sharePurchaseOrder(materials),
                        child: const Text('PO WhatsApp'),
                      ),
                    ],
                  ),
                ),

              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: materials.length,
                  itemBuilder: (context, i) {
                    final item = materials[i];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: item.isLowStock
                              ? AppColors.error.withValues(alpha: 0.4)
                              : Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                          width: item.isLowStock ? 1.5 : 1.0,
                        ),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: item.isLowStock
                                ? AppColors.error.withValues(alpha: 0.15)
                                : AppColors.primary.withValues(alpha: 0.15),
                            child: Icon(
                              item.category == 'flour'
                                  ? Icons.grain_rounded
                                  : (item.category == 'oil' ? Icons.water_drop_rounded : Icons.inventory_2_rounded),
                              color: item.isLowStock ? AppColors.error : AppColors.primary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item.name, style: AppTextStyles.titleSmall),
                                Text(
                                  'Current: ${item.currentStock.toStringAsFixed(1)} ${item.unit} • Min: ${item.minStock.toStringAsFixed(0)} ${item.unit}',
                                  style: AppTextStyles.bodySmall,
                                ),
                                Text(
                                  'Rate: ${CurrencyFormatter.format(item.lastPurchasePrice)} / ${item.unit}',
                                  style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: (item.isLowStock ? AppColors.error : AppColors.success).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  item.isLowStock ? 'REORDER' : 'HEALTHY',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: item.isLowStock ? AppColors.error : AppColors.success,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  visualDensity: VisualDensity.compact,
                                ),
                                onPressed: () => _showReceiveStockDialog(item),
                                child: const Text('+ Inward'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          statusAsync.whenData((items) => _sharePurchaseOrder(items));
        },
        icon: const Icon(Icons.shopping_cart_checkout_rounded),
        label: const Text('Draft Vendor PO'),
      ),
    );
  }
}
