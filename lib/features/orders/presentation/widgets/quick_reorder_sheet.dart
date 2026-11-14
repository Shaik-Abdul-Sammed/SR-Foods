import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

class QuickReorderSheet extends StatefulWidget {
  final String hotelName;
  final List<Map<String, dynamic>> favoriteItems; // [{name: 'Parota', qty: 50, price: 45.0}]
  final ValueChanged<int>? onConfirmReorder;

  const QuickReorderSheet({
    super.key,
    required this.hotelName,
    required this.favoriteItems,
    this.onConfirmReorder,
  });

  @override
  State<QuickReorderSheet> createState() => _QuickReorderSheetState();
}

class _QuickReorderSheetState extends State<QuickReorderSheet> {
  late List<Map<String, dynamic>> _items;
  bool _isPlacing = false;

  @override
  void initState() {
    super.initState();
    _items = widget.favoriteItems.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  double get _totalPrice => _items.fold<double>(
        0.0,
        (sum, item) => sum + ((item['qty'] as int) * (item['price'] as double)),
      );

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('10-SECOND QUICK REORDER', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary)),
                  Text(widget.hotelName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text('Standard Daily Morning Breakfast Crate Basket:', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          const SizedBox(height: 8),

          ..._items.map((item) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text('${item['name']} (₹${item['price']}/pack)', style: const TextStyle(fontSize: 12)),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline, size: 20),
                        onPressed: () {
                          if ((item['qty'] as int) > 10) {
                            setState(() => item['qty'] = (item['qty'] as int) - 10);
                          }
                        },
                      ),
                      Text('${item['qty']} pk', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline, size: 20),
                        onPressed: () {
                          setState(() => item['qty'] = (item['qty'] as int) + 10);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),

          const Divider(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Estimated Morning Total:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              Text('₹${_totalPrice.toStringAsFixed(0)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primary)),
            ],
          ),
          const SizedBox(height: 14),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isPlacing
                  ? null
                  : () async {
                      setState(() => _isPlacing = true);
                      await Future<void>.delayed(const Duration(milliseconds: 300));
                      if (context.mounted) {
                        widget.onConfirmReorder?.call(_totalPrice.round());
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Order Confirmed for 06:00 AM Morning Route!'),
                            backgroundColor: Colors.green,
                          ),
                        );
                        if (Navigator.canPop(context)) {
                          Navigator.pop(context);
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: _isPlacing
                  ? const Text('Placing Order...', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold))
                  : const Text('Confirm for Tomorrow 06:00 AM Drop', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}
