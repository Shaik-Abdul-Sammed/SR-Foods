import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:drift/drift.dart' as drift;
import '../../../../core/database/app_database.dart';
import '../../../../core/database/database_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../products/presentation/screens/products_screen.dart';

class ProductionFormScreen extends ConsumerStatefulWidget {
  const ProductionFormScreen({super.key});
  @override
  ConsumerState<ProductionFormScreen> createState() => _ProductionFormScreenState();
}

class _ProductionFormScreenState extends ConsumerState<ProductionFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _operatorCtrl = TextEditingController();
  final _quantityCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  Product? _selectedProduct;
  DateTime _mfgDate = DateTime.now();
  bool _isLoading = false;

  @override
  void dispose() {
    _operatorCtrl.dispose();
    _quantityCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _selectedProduct == null) {
      if (_selectedProduct == null) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a product')));
      return;
    }
    setState(() => _isLoading = true);
    try {
      final db = ref.read(databaseProvider);
      final qty = int.parse(_quantityCtrl.text.trim());
      final batchNumber = IdGenerator.generateBatchNumber(_selectedProduct!.sku);

      // Fetch fresh stock from DB (not the stale widget state)
      final freshProduct = await (db.select(db.products)..where((p) => p.id.equals(_selectedProduct!.id))).getSingleOrNull();
      if (freshProduct == null) throw Exception('Product not found');

      await db.into(db.productionBatches).insert(ProductionBatchesCompanion(
        batchNumber: drift.Value(batchNumber),
        productId: drift.Value(_selectedProduct!.id),
        operatorName: drift.Value(_operatorCtrl.text.trim()),
        quantityProduced: drift.Value(qty),
        manufacturingDate: drift.Value(_mfgDate),
        notes: drift.Value(_notesCtrl.text.isEmpty ? null : _notesCtrl.text),
      ));

      final newStock = freshProduct.currentStock + qty;

      // Update products table
      await (db.update(db.products)..where((p) => p.id.equals(_selectedProduct!.id)))
          .write(ProductsCompanion(
        currentStock: drift.Value(newStock),
        updatedAt: drift.Value(DateTime.now()),
      ));

      // Update inventory table to match
      await (db.update(db.inventory)..where((inv) => inv.productId.equals(_selectedProduct!.id)))
          .write(InventoryCompanion(
        currentStock: drift.Value(newStock),
        updatedAt: drift.Value(DateTime.now()),
      ));

      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Batch $batchNumber recorded! +$qty units')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }


  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Record Production')),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            productsAsync.when(
              loading: () => const CircularProgressIndicator(),
              error: (e,_) => Text('$e'),
              data: (products) => DropdownButtonFormField<Product>(
                initialValue: _selectedProduct,
                hint: const Text('Select Product'),
                decoration: const InputDecoration(labelText: 'Product'),
                items: products.map((p) => DropdownMenuItem(value: p, child: Text(p.name))).toList(),
                onChanged: (p) => setState(() => _selectedProduct = p),
                validator: (v) => v == null ? 'Please select a product' : null,
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(controller: _operatorCtrl, decoration: const InputDecoration(labelText: 'Operator Name'), validator: (v) => (v == null || v.isEmpty) ? 'Required' : null),
            const SizedBox(height: 12),
            TextFormField(controller: _quantityCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Quantity Produced (packs)'), validator: (v) {
              if (v == null || v.isEmpty) return 'Required';
              final qty = int.tryParse(v.trim());
              if (qty == null) return 'Enter a whole number (e.g. 50)';
              if (qty <= 0) return 'Quantity must be greater than 0';
              return null;
            }),

            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Manufacturing Date'),
              subtitle: Text(DateFormatter.toDate(_mfgDate)),
              trailing: const Icon(Icons.calendar_today_rounded),
              onTap: () async {
                final date = await showDatePicker(context: context, initialDate: _mfgDate, firstDate: DateTime(2020), lastDate: DateTime.now());
                if (date != null) setState(() => _mfgDate = date);
              },
            ),
            const SizedBox(height: 12),
            TextFormField(controller: _notesCtrl, maxLines: 3, decoration: const InputDecoration(labelText: 'Notes')),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isLoading ? null : _save,
              child: _isLoading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Record Production'),
            ),
          ]),
        ),
      ),
    );
  }
}
