import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:drift/drift.dart' as drift;
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/database_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/services/whatsapp_service.dart';

// Providers
final productsProvider = StreamProvider<List<Product>>((ref) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.products)
        ..where((p) => p.isActive.equals(true))
        ..orderBy([(p) => drift.OrderingTerm.asc(p.name)]))
      .watch();
});

final productSearchProvider = NotifierProvider<ProductSearchNotifier, String>(ProductSearchNotifier.new);

class ProductSearchNotifier extends Notifier<String> {
  @override
  String build() => '';
  void update(String val) => state = val;
}

class ProductsScreen extends ConsumerStatefulWidget {
  const ProductsScreen({super.key});

  @override
  ConsumerState<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends ConsumerState<ProductsScreen> {
  final _searchController = TextEditingController();
  String _mobileNumber = '';

  @override
  void initState() {
    super.initState();
    _loadRole();
  }

  Future<void> _loadRole() async {
    const storage = FlutterSecureStorage();
    final mobile = await storage.read(key: 'mobile_number') ?? '';
    if (mounted) {
      setState(() => _mobileNumber = mobile);
    }
  }

  bool get _isAdmin => _mobileNumber == '9440067933' || _mobileNumber == '9010150809';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsProvider);
    final searchQuery = ref.watch(productSearchProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Products'),
        actions: [
          IconButton(
            tooltip: 'Share Price List on WhatsApp',
            icon: const Icon(Icons.chat_bubble_outline_rounded, color: Color(0xFF25D366)),
            onPressed: () {
              productsAsync.whenData((products) {
                WhatsAppService.shareProductCatalog(
                  context: context,
                  products: products,
                );
              });
            },
          ),
          if (_isAdmin)
            IconButton(
              onPressed: () => context.push('/products/create'),
              icon: const Icon(Icons.add_rounded),
              tooltip: 'Add Product',
            ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              onChanged: (val) =>
                  ref.read(productSearchProvider.notifier).update(val),
              decoration: InputDecoration(
                hintText: 'Search products...',
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
                          ref.read(productSearchProvider.notifier).update('');
                        },
                      )
                    : null,
              ),
            ),
          ),
          Expanded(
            child: productsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (products) {
                final filtered = searchQuery.isEmpty
                    ? products
                    : products.where((p) {
                        final q = searchQuery.toLowerCase();
                        return p.name.toLowerCase().contains(q) ||
                            p.sku.toLowerCase().contains(q) ||
                            (p.category).toLowerCase().contains(q);
                      }).toList();

                if (filtered.isEmpty) {
                  return _buildEmptyState(context);
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  physics: const BouncingScrollPhysics(),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    return _ProductCard(product: filtered[index])
                        .animate()
                        .fade(duration: 400.ms, delay: (index * 50).ms)
                        .slideX(begin: 0.1, end: 0, duration: 400.ms, curve: Curves.easeOutQuad);
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: _mobileNumber.isEmpty ? null : FloatingActionButton.extended(
        onPressed: () => context.push(_isAdmin ? '/products/create' : '/orders/create'),
        icon: Icon(_isAdmin ? Icons.add_rounded : Icons.shopping_cart_checkout_rounded),
        label: Text(_isAdmin ? 'Add Product' : 'Place Order'),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inventory_2_outlined,
            size: 64,
            color: AppColors.textSecondary.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 16),
          Text(
            'No products found',
            style: AppTextStyles.titleMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            onPressed: () => context.push(_isAdmin ? '/products/create' : '/orders/create'),
            icon: Icon(_isAdmin ? Icons.add_rounded : Icons.shopping_cart_checkout_rounded),
            label: Text(_isAdmin ? 'Add First Product' : 'Place Order'),
          ),
        ],
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final Product product;
  const _ProductCard({required this.product});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
        ),
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
          onTap: () => context.push('/products/${product.id}'),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // Product icon/image
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.fastfood_rounded,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        style: AppTextStyles.titleSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${product.category} • ${product.piecesPerPack} pcs • ${product.weightGrams.toInt()}g',
                        style: AppTextStyles.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: product.currentStock <= product.minStock
                                  ? AppColors.warningLight
                                  : AppColors.successLight,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Stock: ${product.currentStock}',
                              style: AppTextStyles.badge.copyWith(
                                color: product.currentStock <= product.minStock
                                    ? AppColors.warningDark
                                    : AppColors.successDark,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      CurrencyFormatter.format(product.price),
                      style: AppTextStyles.titleSmall.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.textSecondary,
                      size: 18,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
