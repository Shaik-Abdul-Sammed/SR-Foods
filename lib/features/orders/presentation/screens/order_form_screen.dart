import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:drift/drift.dart' as drift;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/database/database_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/formatters.dart';
import '../../../customers/presentation/screens/customers_screen.dart';
import '../../../products/presentation/screens/products_screen.dart';

class _OrderItem {
  final Product product;
  int quantity;
  double discount;
  _OrderItem({required this.product}) : quantity = 1, discount = 0.0;
  double get total => (product.price - discount) * quantity;
}

class OrderFormScreen extends ConsumerStatefulWidget {
  const OrderFormScreen({super.key});
  @override
  ConsumerState<OrderFormScreen> createState() => _OrderFormScreenState();
}

class _OrderFormScreenState extends ConsumerState<OrderFormScreen> {
  Customer? _selectedCustomer;
  final List<_OrderItem> _items = [];
  String _paymentMethod = 'credit';
  final _notesCtrl = TextEditingController();
  bool _isLoading = false;
  String _mobileNumber = '';

  final _paymentMethods = ['credit', 'cash', 'upi', 'bank'];

  @override
  void initState() {
    super.initState();
    _loadRole();
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadRole() async {
    const storage = FlutterSecureStorage();
    final mobile = await storage.read(key: 'mobile_number') ?? '';
    if (mounted) {
      setState(() => _mobileNumber = mobile);
      if (!_isAdmin && mobile.isNotEmpty) {
        final db = ref.read(databaseProvider);
        final customer = await (db.select(db.customers)..where((c) => c.phone.equals(mobile))).getSingleOrNull();
        if (customer != null && mounted) {
          setState(() => _selectedCustomer = customer);
        } else if (mounted) {
          final ownerName = await storage.read(key: 'owner_name') ?? 'Customer';
          final code = IdGenerator.generateCustomerCode();
          final id = await db.into(db.customers).insert(CustomersCompanion(
            shopName: drift.Value(ownerName),
            ownerName: drift.Value(ownerName),
            phone: drift.Value(mobile),
            code: drift.Value(code),
          ));
          final newCustomer = await (db.select(db.customers)..where((c) => c.id.equals(id))).getSingle();
          if (mounted) setState(() => _selectedCustomer = newCustomer);
        }
      }
    }
  }

  bool get _isAdmin => _mobileNumber == '9440067933' || _mobileNumber == '9010150809';

  double get _subtotal => _items.fold(0.0, (s, i) => s + i.total);
  double get _grandTotal => _subtotal;

  void _addProduct(Product p) {
    final existing = _items.where((i) => i.product.id == p.id);
    if (existing.isNotEmpty) {
      setState(() => existing.first.quantity++);
    } else {
      setState(() => _items.add(_OrderItem(product: p)));
    }
  }

  Future<void> _save() async {
    if (_selectedCustomer == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a customer')));
      return;
    }
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please add at least one product')));
      return;
    }
    setState(() => _isLoading = true);
    try {
      final db = ref.read(databaseProvider);
      final orderNumber = IdGenerator.generateOrderNumber();
      final notes = _notesCtrl.text.trim();

      // 1. Create order
      final orderId = await db.into(db.orders).insert(OrdersCompanion(
        orderNumber: drift.Value(orderNumber),
        customerId: drift.Value(_selectedCustomer!.id),
        status: const drift.Value('pending'),
        subtotal: drift.Value(_subtotal),
        grandTotal: drift.Value(_grandTotal),
        paidAmount: drift.Value(_paymentMethod == 'cash' ? _grandTotal : 0),
        pendingAmount: drift.Value(_paymentMethod == 'cash' ? 0 : _grandTotal),
        paymentMethod: drift.Value(_paymentMethod),
        paymentStatus: drift.Value(_paymentMethod == 'cash' ? 'paid' : 'pending'),
        notes: drift.Value(notes.isEmpty ? null : notes),
      ));


      // 2. Insert order items & reduce stock
      for (final item in _items) {
        await db.into(db.orderItems).insert(OrderItemsCompanion(
          orderId: drift.Value(orderId),
          productId: drift.Value(item.product.id),
          productName: drift.Value(item.product.name),
          price: drift.Value(item.product.price),
          quantity: drift.Value(item.quantity),
          discount: drift.Value(item.discount),
          total: drift.Value(item.total),
        ));
        // Decrease stock
        await (db.update(db.products)..where((p) => p.id.equals(item.product.id)))
            .write(ProductsCompanion(
          currentStock: drift.Value(item.product.currentStock - item.quantity),
          updatedAt: drift.Value(DateTime.now()),
        ));
      }

      // 3. Auto-generate invoice
      final invoiceNumber = IdGenerator.generateInvoiceNumber();
      final invoiceId = await db.into(db.invoices).insert(InvoicesCompanion(
        invoiceNumber: drift.Value(invoiceNumber),
        orderId: drift.Value(orderId),
        customerId: drift.Value(_selectedCustomer!.id),
        subtotal: drift.Value(_subtotal),
        grandTotal: drift.Value(_grandTotal),
        paidAmount: drift.Value(_paymentMethod == 'cash' ? _grandTotal : 0),
        pendingAmount: drift.Value(_paymentMethod == 'cash' ? 0 : _grandTotal),
        status: drift.Value(_paymentMethod == 'cash' ? 'paid' : 'pending'),
        invoiceDate: drift.Value(DateTime.now()),
      ));
      debugPrint('Invoice $invoiceId created: $invoiceNumber');

      // 4. Update customer's running balance
      final newBalance = _selectedCustomer!.currentBalance + (_paymentMethod == 'cash' ? 0 : _grandTotal);
      await (db.update(db.customers)..where((c) => c.id.equals(_selectedCustomer!.id)))
          .write(CustomersCompanion(
        currentBalance: drift.Value(newBalance),
        updatedAt: drift.Value(DateTime.now()),
      ));

      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Order $orderNumber created! Invoice: $invoiceNumber'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final customersAsync = ref.watch(customersProvider);
    final productsAsync = ref.watch(productsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('New Order')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (_isAdmin) ...[
            Text('CUSTOMER', style: AppTextStyles.overline.copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            customersAsync.when(
              loading: () => const CircularProgressIndicator(),
              error: (e, _) => Text('$e'),
              data: (customers) => DropdownButtonFormField<Customer>(
                initialValue: _selectedCustomer,
                hint: const Text('Select Customer'),
                decoration: const InputDecoration(prefixIcon: Icon(Icons.person_outline_rounded)),
                items: customers.map((c) => DropdownMenuItem(value: c, child: Text(c.shopName))).toList(),
                onChanged: (c) => setState(() => _selectedCustomer = c),
              ),
            ),
            const SizedBox(height: 16),
          ],
          // Payment method
          Text('PAYMENT METHOD', style: AppTextStyles.overline.copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _paymentMethod,
            decoration: const InputDecoration(prefixIcon: Icon(Icons.payment_rounded)),
            items: _paymentMethods.map((m) => DropdownMenuItem(
              value: m,
              child: Text(m == 'credit' ? 'Credit (Pay Later)' : m.toUpperCase()),
            )).toList(),
            onChanged: (v) => setState(() => _paymentMethod = v!),
          ),
          const SizedBox(height: 16),

          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('PRODUCTS', style: AppTextStyles.overline.copyWith(color: AppColors.textSecondary)),
            productsAsync.when(
              loading: () => const SizedBox(),
              error: (e, _) => const SizedBox(),
              data: (products) => TextButton.icon(
                onPressed: () => _showProductPicker(context, products),
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('Add Product'),
              ),
            ),
          ]),
          const SizedBox(height: 8),
          if (_items.isEmpty) Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: AppColors.surfaceVariant, borderRadius: BorderRadius.circular(12)),
            child: Center(child: Text('No products added', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary))),
          ),
          ..._items.map((item) => Dismissible(
            key: ValueKey(item.product.id),
            direction: DismissDirection.endToStart,
            background: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(color: AppColors.error, borderRadius: BorderRadius.circular(12)),
              alignment: Alignment.centerRight,
              child: const Icon(Icons.delete_outline, color: Colors.white),
            ),
            onDismissed: (_) {
              setState(() => _items.remove(item));
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${item.product.name} removed')));
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2)),
              ),
              child: Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(item.product.name, style: AppTextStyles.titleSmall),
                  Text('${CurrencyFormatter.format(item.product.price)} each', style: AppTextStyles.bodySmall),
                ])),
                Row(children: [
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline_rounded, size: 20),
                    onPressed: () { setState(() { if (item.quantity > 1) { item.quantity--; } else { _items.remove(item); } }); },
                  ),
                  Text('${item.quantity}', style: AppTextStyles.titleSmall),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline_rounded, size: 20),
                    onPressed: () => setState(() => item.quantity++),
                  ),
                ]),
                SizedBox(width: 60, child: Text(CurrencyFormatter.format(item.total), style: AppTextStyles.titleSmall.copyWith(color: AppColors.primary), textAlign: TextAlign.end)),
              ]),
            ),
          )),
          const SizedBox(height: 12),
          // Notes
          TextField(
            controller: _notesCtrl,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Notes (optional)',
              prefixIcon: Icon(Icons.notes_rounded),
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(gradient: AppColors.primaryGradient, borderRadius: BorderRadius.circular(16)),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('TOTAL', style: AppTextStyles.titleMedium.copyWith(color: Colors.white)),
              Text(CurrencyFormatter.format(_grandTotal), style: AppTextStyles.headlineSmall.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
            ]),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _isLoading ? null : _save,
            child: _isLoading
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Create Order'),
          ),
        ]),
      ),
    );
  }

  void _showProductPicker(BuildContext context, List<Product> products) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) {
        String searchQuery = '';
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filteredProducts = products
                .where((p) => p.isActive && p.name.toLowerCase().contains(searchQuery.toLowerCase()))
                .toList();
            return DraggableScrollableSheet(
              initialChildSize: 0.7, maxChildSize: 0.9, minChildSize: 0.5, expand: false,
              builder: (_, ctrl) => Column(children: [
                const SizedBox(height: 12),
                Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(children: [
                    Expanded(
                      child: Text('Select Products', style: AppTextStyles.titleMedium),
                    ),
                    IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(context)),
                  ]),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    autofocus: false,
                    decoration: InputDecoration(
                      hintText: 'Search Products...',
                      prefixIcon: const Icon(Icons.search_rounded),
                      filled: true,
                      fillColor: AppColors.surfaceVariant,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    ),
                    onChanged: (value) => setModalState(() => searchQuery = value),
                  ),
                ),
                const SizedBox(height: 8),
                if (filteredProducts.isEmpty)
                  Expanded(child: Center(child: Text('No products found', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary))))
                else
                  Expanded(child: ListView.builder(
                    controller: ctrl,
                    itemCount: filteredProducts.length,
                    itemBuilder: (_, i) {
                      final p = filteredProducts[i];
                      final alreadyAdded = _items.any((item) => item.product.id == p.id);
                      return ListTile(
                        leading: Container(
                          width: 40, height: 40,
                          decoration: BoxDecoration(gradient: AppColors.primaryGradient, borderRadius: BorderRadius.circular(10)),
                          child: const Icon(Icons.fastfood_rounded, color: Colors.white, size: 20),
                        ),
                        title: Text(p.name, style: AppTextStyles.titleSmall),
                        subtitle: Text(CurrencyFormatter.format(p.price), style: AppTextStyles.bodySmall),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('Stock: ${p.currentStock}', style: AppTextStyles.labelSmall.copyWith(color: p.currentStock <= 0 ? AppColors.error : AppColors.textSecondary)),
                            if (alreadyAdded) Text('Added', style: AppTextStyles.labelSmall.copyWith(color: AppColors.success)),
                          ],
                        ),
                        onTap: () {
                          _addProduct(p);
                          Navigator.pop(context);
                        },
                      );
                    },
                  )),
              ]),
            );
          },
        );
      },
    );
  }
}
