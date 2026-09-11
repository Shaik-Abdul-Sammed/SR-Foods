import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:drift/drift.dart' as drift;

import '../../../../core/database/app_database.dart';
import '../../../../core/database/database_provider.dart';
import '../../../../core/theme/app_colors.dart';

class ProductFormScreen extends ConsumerStatefulWidget {
  final int? id;
  const ProductFormScreen({super.key, this.id});

  @override
  ConsumerState<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends ConsumerState<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _skuCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _piecesCtrl = TextEditingController(text: '10');
  final _weightCtrl = TextEditingController(text: '800');
  final _minStockCtrl = TextEditingController(text: '10');
  final _descCtrl = TextEditingController();
  String _category = 'General';
  bool _isActive = true;
  bool _isAvailable = true;
  bool _isLoading = false;

  final _categories = ['Parota', 'Chapathi', 'Pulka', 'Puri', 'General'];

  @override
  void initState() {
    super.initState();
    if (widget.id != null) _loadProduct();
  }

  Future<void> _loadProduct() async {
    final db = ref.read(databaseProvider);
    final product = await (db.select(db.products)
          ..where((p) => p.id.equals(widget.id!)))
        .getSingleOrNull();
    if (product != null && mounted) {
      _nameCtrl.text = product.name;
      _skuCtrl.text = product.sku;
      _priceCtrl.text = product.price.toString();
      _piecesCtrl.text = product.piecesPerPack.toString();
      _weightCtrl.text = product.weightGrams.toString();
      _minStockCtrl.text = product.minStock.toString();
      _descCtrl.text = product.description ?? '';
      setState(() {
        _category = product.category;
        _isActive = product.isActive;
        _isAvailable = product.isAvailable;
      });
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _skuCtrl.dispose();
    _priceCtrl.dispose();
    _piecesCtrl.dispose();
    _weightCtrl.dispose();
    _minStockCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final db = ref.read(databaseProvider);
      final companion = ProductsCompanion(
        name: drift.Value(_nameCtrl.text.trim()),
        sku: drift.Value(_skuCtrl.text.trim()),
        price: drift.Value(double.parse(_priceCtrl.text)),
        piecesPerPack: drift.Value(int.parse(_piecesCtrl.text)),
        weightGrams: drift.Value(double.parse(_weightCtrl.text)),
        minStock: drift.Value(int.parse(_minStockCtrl.text)),
        description: drift.Value(
            _descCtrl.text.isEmpty ? null : _descCtrl.text.trim()),
        category: drift.Value(_category),
        isActive: drift.Value(_isActive),
        isAvailable: drift.Value(_isAvailable),
        updatedAt: drift.Value(DateTime.now()),
      );
      if (widget.id == null) {
        final productId = await db.into(db.products).insert(companion);
        await db.into(db.inventory).insert(
              InventoryCompanion(
                productId: drift.Value(productId),
                openingStock: const drift.Value(0),
                currentStock: const drift.Value(0),
              ),
            );
      } else {
        await (db.update(db.products)
              ..where((p) => p.id.equals(widget.id!)))
            .write(companion);
      }
      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.id == null
                  ? 'Product created successfully'
                  : 'Product updated successfully',
            ),
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
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.id == null ? 'Add Product' : 'Edit Product'),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTextField(_nameCtrl, 'Product Name', isRequired: true),
              const SizedBox(height: 12),
              _buildTextField(_skuCtrl, 'SKU', isRequired: true),
              const SizedBox(height: 12),
              _buildTextField(_priceCtrl, 'Price (₹)',
                  isRequired: true,
                  keyboardType: TextInputType.number),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(_piecesCtrl, 'Pieces per Pack',
                        keyboardType: TextInputType.number),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildTextField(_weightCtrl, 'Weight (g)',
                        keyboardType: TextInputType.number),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildTextField(_minStockCtrl, 'Min Stock Alert',
                  keyboardType: TextInputType.number),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _category,
                decoration: const InputDecoration(labelText: 'Category'),
                items: _categories
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (val) => setState(() => _category = val!),
              ),
              const SizedBox(height: 12),
              _buildTextField(_descCtrl, 'Description',
                  maxLines: 3),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('Active'),
                value: _isActive,
                onChanged: (v) => setState(() => _isActive = v),
                contentPadding: EdgeInsets.zero,
              ),
              SwitchListTile(
                title: const Text('Available for Sale'),
                value: _isAvailable,
                onChanged: (v) => setState(() => _isAvailable = v),
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading ? null : _save,
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        widget.id == null ? 'Create Product' : 'Update Product'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label, {
    bool isRequired = false,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: InputDecoration(labelText: label),
      validator: isRequired
          ? (val) =>
              val == null || val.isEmpty ? '$label is required' : null
          : null,
    );
  }
}
