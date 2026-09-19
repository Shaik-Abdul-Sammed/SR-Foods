import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:drift/drift.dart' as drift;

import '../../../../core/database/app_database.dart';
import '../../../../core/database/database_provider.dart';
import '../../../../core/services/whatsapp_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/formatters.dart';

/// Stream of active products for public catalog
final catalogProductsProvider = StreamProvider<List<Product>>((ref) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.products)
        ..where((p) => p.isActive.equals(true))
        ..orderBy([(p) => drift.OrderingTerm.asc(p.name)]))
      .watch();
});

/// Public Digital Storefront / Web Catalog for SR Foods.
/// Customers can browse food products, add to cart, and place orders directly
/// to the manager's WhatsApp with 1 tap - ZERO login or app installation required!
class PublicCatalogScreen extends ConsumerStatefulWidget {
  const PublicCatalogScreen({super.key});

  @override
  ConsumerState<PublicCatalogScreen> createState() => _PublicCatalogScreenState();
}

class _PublicCatalogScreenState extends ConsumerState<PublicCatalogScreen> {
  // Cart: Map<productId, quantity>
  final Map<int, int> _cart = {};
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String? _selectedCategory;

  // Manager contact number for receiving WhatsApp orders
  static const String _defaultManagerPhone = '9440067933';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _increment(int productId) {
    setState(() {
      _cart[productId] = (_cart[productId] ?? 0) + 1;
    });
  }

  void _decrement(int productId) {
    setState(() {
      final current = _cart[productId] ?? 0;
      if (current <= 1) {
        _cart.remove(productId);
      } else {
        _cart[productId] = current - 1;
      }
    });
  }

  double _calculateTotal(List<Product> products) {
    double total = 0;
    for (final entry in _cart.entries) {
      final product = products.where((p) => p.id == entry.key).firstOrNull;
      if (product != null) {
        total += product.price * entry.value;
      }
    }
    return total;
  }

  int get _totalItemCount => _cart.values.fold(0, (sum, count) => sum + count);

  void _showCheckoutDialog(BuildContext context, List<Product> products, double grandTotal) {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(ctx).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 48,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('Confirm WhatsApp Order', style: AppTextStyles.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    'Your order will be sent directly to the SR Foods manager on WhatsApp.',
                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Shop / Your Name *',
                      prefixIcon: Icon(Icons.store_rounded),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter your shop/name' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: phoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Contact Phone Number *',
                      prefixIcon: Icon(Icons.phone_rounded),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter your phone number' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: notesCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Delivery Address / Notes (Optional)',
                      prefixIcon: Icon(Icons.location_on_outlined),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Total Order Value:', style: AppTextStyles.bodyMedium),
                        Text(
                          CurrencyFormatter.format(grandTotal),
                          style: AppTextStyles.titleMedium.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF25D366),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: () {
                        if (!formKey.currentState!.validate()) return;
                        Navigator.pop(ctx);

                        final cartItems = <Map<String, dynamic>>[];
                        for (final entry in _cart.entries) {
                          final product = products.where((p) => p.id == entry.key).firstOrNull;
                          if (product != null) {
                            cartItems.add({
                              'name': product.name,
                              'quantity': entry.value,
                              'price': product.price,
                              'total': product.price * entry.value,
                            });
                          }
                        }

                        WhatsAppService.sendOrderToManager(
                          context: context,
                          managerPhone: _defaultManagerPhone,
                          customerName: nameCtrl.text.trim(),
                          customerPhone: phoneCtrl.text.trim(),
                          addressOrNotes: notesCtrl.text.trim(),
                          cartItems: cartItems,
                          grandTotal: grandTotal,
                        );

                        setState(() {
                          _cart.clear();
                        });
                      },
                      icon: const Icon(Icons.send_rounded, color: Colors.white),
                      label: const Text(
                        'Send Order via WhatsApp',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<Product>> productsAsync = ref.watch(catalogProductsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.restaurant_menu_rounded, color: AppColors.primary, size: 22),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('SR Foods', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                Text(
                  'Fresh Food Menu & Online Orders',
                  style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ],
        ),
      ),
      body: productsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object e, StackTrace? _) => Center(child: Text('Error loading products: $e')),
        data: (List<Product> products) {
          final categories = products.map((Product p) => p.category).toSet().toList();

          final filtered = products.where((Product p) {
            final matchesQuery = p.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                p.sku.toLowerCase().contains(_searchQuery.toLowerCase());
            final matchesCategory = _selectedCategory == null || p.category == _selectedCategory;
            return matchesQuery && matchesCategory;
          }).toList();

          return Column(
            children: [
              // Search & Filter Header
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: TextField(
                  controller: _searchController,
                  onChanged: (String v) => setState(() => _searchQuery = v),
                  decoration: InputDecoration(
                    hintText: 'Search food items, sweets, snacks...',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),

              // Category chips
              if (categories.isNotEmpty)
                SizedBox(
                  height: 44,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: const Text('All'),
                          selected: _selectedCategory == null,
                          onSelected: (_) => setState(() => _selectedCategory = null),
                        ),
                      ),
                      ...categories.map((String cat) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: FilterChip(
                              label: Text(cat),
                              selected: _selectedCategory == cat,
                              onSelected: (_) => setState(() {
                                _selectedCategory = _selectedCategory == cat ? null : cat;
                              }),
                            ),
                          )),
                    ],
                  ),
                ),

              const SizedBox(height: 8),

              // Product Grid / List
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.fastfood_outlined, size: 64, color: AppColors.textSecondary.withValues(alpha: 0.4)),
                            const SizedBox(height: 12),
                            Text('No products found', style: AppTextStyles.titleSmall),
                            const SizedBox(height: 4),
                            Text('Try searching for another food item', style: AppTextStyles.bodySmall),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                        itemCount: filtered.length,
                        itemBuilder: (BuildContext context, int index) {
                          final product = filtered[index];
                          final qtyInCart = _cart[product.id] ?? 0;

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(
                                color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.15),
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  // Product Icon Placeholder
                                  Container(
                                    width: 68,
                                    height: 68,
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: const Center(
                                      child: Icon(
                                        Icons.fastfood_rounded,
                                        color: AppColors.primary,
                                        size: 32,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 14),

                                  // Details
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          product.name,
                                          style: AppTextStyles.titleSmall.copyWith(fontWeight: FontWeight.bold),
                                        ),
                                        if (product.description != null && product.description!.isNotEmpty) ...[
                                          const SizedBox(height: 2),
                                          Text(
                                            product.description!,
                                            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                        const SizedBox(height: 6),
                                        Row(
                                          children: [
                                            Text(
                                              CurrencyFormatter.format(product.price),
                                              style: AppTextStyles.titleMedium.copyWith(
                                                color: AppColors.primary,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                            if (product.unit.isNotEmpty)
                                              Text(
                                                ' / ${product.unit}',
                                                style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary),
                                              ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Cart Counter Button
                                  if (qtyInCart == 0)
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.primary,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      ),
                                      onPressed: () => _increment(product.id),
                                      child: const Text('ADD +', style: TextStyle(fontWeight: FontWeight.bold)),
                                    )
                                  else
                                    Container(
                                      decoration: BoxDecoration(
                                        color: AppColors.primary.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          IconButton(
                                            icon: const Icon(Icons.remove_rounded, size: 18, color: AppColors.primary),
                                            onPressed: () => _decrement(product.id),
                                            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                                            padding: EdgeInsets.zero,
                                          ),
                                          Text(
                                            '$qtyInCart',
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                          ),
                                          IconButton(
                                            icon: const Icon(Icons.add_rounded, size: 18, color: AppColors.primary),
                                            onPressed: () => _increment(product.id),
                                            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                                            padding: EdgeInsets.zero,
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
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

      // Bottom Checkout Bar when items are selected
      bottomNavigationBar: _totalItemCount > 0
          ? SafeArea(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 10,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$_totalItemCount items in cart',
                          style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary),
                        ),
                        Text(
                          productsAsync.maybeWhen(
                            data: (List<Product> p) => CurrencyFormatter.format(_calculateTotal(p)),
                            orElse: () => '',
                          ),
                          style: AppTextStyles.titleMedium.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF25D366),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 2,
                      ),
                      onPressed: () {
                        productsAsync.whenData((List<Product> products) {
                          _showCheckoutDialog(context, products, _calculateTotal(products));
                        });
                      },
                      icon: const Icon(Icons.send_rounded, color: Colors.white),
                      label: const Text(
                        'Order on WhatsApp',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ).animate().slideY(begin: 1, end: 0, duration: 250.ms, curve: Curves.easeOutQuad)
          : null,
    );
  }
}
