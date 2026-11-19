import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:drift/drift.dart' as drift;
import '../../../../core/database/app_database.dart';
import '../../../../core/database/database_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/domain/recipe.dart';
import '../../../../core/services/yield_analytics_service.dart';
import '../../../products/presentation/screens/products_screen.dart';

class ProductionFormScreen extends ConsumerStatefulWidget {
  final int? initialProductId;
  final int? initialQuantity;
  const ProductionFormScreen({
    super.key,
    this.initialProductId,
    this.initialQuantity,
  });

  @override
  ConsumerState<ProductionFormScreen> createState() => _ProductionFormScreenState();
}

class _ProductionFormScreenState extends ConsumerState<ProductionFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _operatorCtrl = TextEditingController(text: 'Shift Lead');
  final _quantityCtrl = TextEditingController();
  final _flourUsedCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  Product? _selectedProduct;
  DateTime _mfgDate = DateTime.now();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialQuantity != null && widget.initialQuantity! > 0) {
      _quantityCtrl.text = widget.initialQuantity.toString();
    }
    if (widget.initialProductId != null) {
      _loadInitialProduct();
    }
  }

  Future<void> _loadInitialProduct() async {
    final db = ref.read(databaseProvider);
    final p = await (db.select(db.products)
          ..where((prod) => prod.id.equals(widget.initialProductId!)))
        .getSingleOrNull();
    if (p != null && mounted) {
      setState(() {
        _selectedProduct = p;
      });
      _autoFillFlour();
    }
  }

  void _autoFillFlour() {
    if (_selectedProduct != null && _quantityCtrl.text.isNotEmpty) {
      final qty = int.tryParse(_quantityCtrl.text.trim()) ?? 0;
      if (qty > 0) {
        final recipe = StandardRecipes.getRecipeFor(_selectedProduct!.sku);
        final materials = recipe.computeMaterialsFor(qty);
        // Find main flour
        final flourKey = materials.keys.firstWhere(
          (k) => k.contains('Flour') || k.contains('Atta'),
          orElse: () => materials.keys.first,
        );
        final flourAmount = materials[flourKey] ?? 0.0;
        _flourUsedCtrl.text = flourAmount.toStringAsFixed(1);
      }
    }
  }

  @override
  void dispose() {
    _operatorCtrl.dispose();
    _quantityCtrl.dispose();
    _flourUsedCtrl.dispose();
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
      final flourConsumed = double.tryParse(_flourUsedCtrl.text.trim()) ?? (qty * 0.55);
      final batchNumber = IdGenerator.generateBatchNumber(_selectedProduct!.sku);

      // Fetch fresh stock from DB (not the stale widget state)
      final freshProduct = await (db.select(db.products)..where((p) => p.id.equals(_selectedProduct!.id))).getSingleOrNull();
      if (freshProduct == null) throw Exception('Product not found');

      final recipe = StandardRecipes.getRecipeFor(_selectedProduct!.sku);
      final expiryDate = _mfgDate.add(Duration(days: recipe.shelfLifeDays));

      // 1. Yield Analysis
      final yieldResult = YieldAnalyticsService.instance.analyzeBatchYield(
        recipe: recipe,
        actualPacksProduced: qty,
        actualFlourKgConsumed: flourConsumed,
      );

      final notesWithYield = StringBuffer();
      if (_notesCtrl.text.isNotEmpty) {
        notesWithYield.writeln(_notesCtrl.text.trim());
      }
      notesWithYield.write('Yield: ${yieldResult.yieldPercentage}% (Var: ${yieldResult.variancePercentage}%). Machine: ${recipe.machineType}.');

      // 2. Insert Production Batch
      await db.into(db.productionBatches).insert(ProductionBatchesCompanion(
        batchNumber: drift.Value(batchNumber),
        productId: drift.Value(_selectedProduct!.id),
        operatorName: drift.Value(_operatorCtrl.text.trim()),
        quantityProduced: drift.Value(qty),
        manufacturingDate: drift.Value(_mfgDate),
        expiryDate: drift.Value(expiryDate),
        notes: drift.Value(notesWithYield.toString()),
      ));

      final newStock = freshProduct.currentStock + qty;

      // 3. Update finished goods stock in products and inventory
      await (db.update(db.products)..where((p) => p.id.equals(_selectedProduct!.id)))
          .write(ProductsCompanion(
        currentStock: drift.Value(newStock),
        updatedAt: drift.Value(DateTime.now()),
      ));

      await (db.update(db.inventory)..where((inv) => inv.productId.equals(_selectedProduct!.id)))
          .write(InventoryCompanion(
        currentStock: drift.Value(newStock),
        updatedAt: drift.Value(DateTime.now()),
      ));

      // 4. Record Inventory Transaction
      await db.into(db.inventoryTransactions).insert(
        InventoryTransactionsCompanion.insert(
          productId: _selectedProduct!.id,
          transactionType: 'production',
          quantity: qty,
          balanceAfter: newStock,
          referenceType: const drift.Value('production'),
          notes: drift.Value('Batch $batchNumber (${recipe.productName})'),
        ),
      );

      // 5. Deduct raw materials according to BOM
      final materialsNeeded = recipe.computeMaterialsFor(qty);
      final allRawMaterials = await db.getAllRawMaterials();
      for (final rm in allRawMaterials) {
        for (final entry in materialsNeeded.entries) {
          if (entry.key.toLowerCase().contains(rm.name.toLowerCase())) {
            final deductedStock = (rm.currentStock - entry.value).clamp(0.0, 999999.0);
            await db.updateRawMaterialStock(rm.id, deductedStock);
          }
        }
      }

      // 6. Audit Log
      await db.logActivity(
        action: 'BATCH_PRODUCED',
        entityType: 'ProductionBatch',
        details: 'Batch $batchNumber: +$qty packs of ${_selectedProduct!.name}. Expiry: ${DateFormatter.toDate(expiryDate)}. Yield: ${yieldResult.yieldPercentage}%',
      );

      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Batch $batchNumber recorded! +$qty packs. Expiry: ${DateFormatter.toDate(expiryDate)}'),
            backgroundColor: AppColors.success,
          ),
        );
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
    final recipe = _selectedProduct != null ? StandardRecipes.getRecipeFor(_selectedProduct!.sku) : null;
    final qty = int.tryParse(_quantityCtrl.text.trim()) ?? 0;
    final materialsNeeded = (recipe != null && qty > 0) ? recipe.computeMaterialsFor(qty) : null;

    return Scaffold(
      appBar: AppBar(title: const Text('Record Production Batch')),
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
                onChanged: (p) {
                  setState(() => _selectedProduct = p);
                  _autoFillFlour();
                },
                validator: (v) => v == null ? 'Please select a product' : null,
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _operatorCtrl,
              decoration: const InputDecoration(labelText: 'Operator Name'),
              validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _quantityCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Quantity Produced (packs)',
                helperText: 'e.g. 100 packs (500 pieces)',
              ),
              onChanged: (_) => setState(() => _autoFillFlour()),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Required';
                final q = int.tryParse(v.trim());
                if (q == null) return 'Enter a whole number (e.g. 50)';
                if (q <= 0) return 'Quantity must be greater than 0';
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _flourUsedCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Actual Flour / Atta Consumed (kg)',
                helperText: 'Used for yield % and wastage calculation',
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Manufacturing Date'),
              subtitle: Text(DateFormatter.toDate(_mfgDate)),
              trailing: const Icon(Icons.calendar_today_rounded),
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _mfgDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                );
                if (date != null) setState(() => _mfgDate = date);
              },
            ),
            if (recipe != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.receipt_long_rounded, size: 18, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Text('BOM Recipe: ${recipe.productName}', style: const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text('Machine: ${recipe.machineType}', style: const TextStyle(fontSize: 12)),
                    Text('Shelf Life: ${recipe.shelfLifeDays} days (Auto Expiry: ${DateFormatter.toDate(_mfgDate.add(Duration(days: recipe.shelfLifeDays)))})', style: const TextStyle(fontSize: 12)),
                    Text('Standard Yield: ${recipe.standardYieldPercent}%', style: const TextStyle(fontSize: 12)),
                    if (materialsNeeded != null && materialsNeeded.isNotEmpty) ...[
                      const Divider(height: 16),
                      const Text('Raw Materials to Deduct:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                      ...materialsNeeded.entries.map((e) => Text('• ${e.key}: ${e.value}', style: const TextStyle(fontSize: 12))),
                    ],
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            TextFormField(controller: _notesCtrl, maxLines: 2, decoration: const InputDecoration(labelText: 'Shift / Quality Notes')),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isLoading ? null : _save,
              child: _isLoading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Record Batch & Deduct Raw Materials'),
            ),
          ]),
        ),
      ),
    );
  }
}
