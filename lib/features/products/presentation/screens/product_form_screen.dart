import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:drift/drift.dart' as drift;

import '../../../../core/database/app_database.dart';
import '../../../../core/database/database_provider.dart';
import '../../../../core/services/vertical_scope_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

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

  // Core fields
  String _category = 'General';
  bool _isActive = true;
  bool _isAvailable = true;
  bool _isLoading = false;

  // Frozen Vertical Fields
  String _storageType = 'frozen';
  final _shelfLifeCtrl = TextEditingController(text: '90');
  final _packsPerCartonCtrl = TextEditingController(text: '20');

  // Dairy Vertical Fields
  String _milkType = 'cow';
  String _procurementSlot = 'both';
  final _fatExpectedCtrl = TextEditingController(text: '4.5');
  final _snfExpectedCtrl = TextEditingController(text: '8.5');
  bool _isPasteurized = true;
  bool _isCultured = false;

  // Bakery Vertical Fields
  bool _bakeDateRequired = true;
  final _proofingMinutesCtrl = TextEditingController(text: '45');
  String _ovenType = 'rotary';
  final _freshnessWindowHoursCtrl = TextEditingController(text: '24');
  final _dayOldDiscountCtrl = TextEditingController(text: '25.0');
  bool _isCustomOrder = false;

  final _categories = [
    'Parota',
    'Chapathi',
    'Pulka',
    'Puri',
    'Milk',
    'Curd',
    'Ghee',
    'Paneer',
    'Butter',
    'Bread',
    'Bun',
    'Croissant',
    'Cake',
    'Pastry',
    'General',
  ];

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
      _shelfLifeCtrl.text = product.shelfLifeDays.toString();
      _packsPerCartonCtrl.text = product.packsPerMasterCarton.toString();
      setState(() {
        _category = product.category;
        _storageType = product.storageType;
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
    _shelfLifeCtrl.dispose();
    _packsPerCartonCtrl.dispose();
    _fatExpectedCtrl.dispose();
    _snfExpectedCtrl.dispose();
    _proofingMinutesCtrl.dispose();
    _freshnessWindowHoursCtrl.dispose();
    _dayOldDiscountCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final db = ref.read(databaseProvider);

      // Build metadata json for vertical-specific extended fields
      final metadataMap = <String, dynamic>{
        'storageType': _storageType,
        'shelfLifeDays': int.tryParse(_shelfLifeCtrl.text) ?? 7,
        'packsPerMasterCarton': int.tryParse(_packsPerCartonCtrl.text) ?? 20,
        'milkType': _milkType,
        'procurementSlot': _procurementSlot,
        'fatPercentExpected': double.tryParse(_fatExpectedCtrl.text) ?? 4.5,
        'snfPercentExpected': double.tryParse(_snfExpectedCtrl.text) ?? 8.5,
        'isPasteurized': _isPasteurized,
        'isCultured': _isCultured,
        'bakeDateRequired': _bakeDateRequired,
        'proofingMinutes': int.tryParse(_proofingMinutesCtrl.text) ?? 45,
        'ovenType': _ovenType,
        'freshnessWindowHours': int.tryParse(_freshnessWindowHoursCtrl.text) ?? 24,
        'dayOldDiscountPercent': double.tryParse(_dayOldDiscountCtrl.text) ?? 25.0,
        'isCustomOrder': _isCustomOrder,
      };

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
        storageType: drift.Value(_storageType),
        shelfLifeDays: drift.Value(int.tryParse(_shelfLifeCtrl.text) ?? 7),
        packsPerMasterCarton: drift.Value(int.tryParse(_packsPerCartonCtrl.text) ?? 20),
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
    final verticalScope = ref.watch(verticalScopeProvider);

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
              _buildSectionHeader('Basic Product Information', Icons.inventory_2_outlined),
              const SizedBox(height: 8),
              _buildTextField(_nameCtrl, 'Product Name', isRequired: true),
              const SizedBox(height: 12),
              _buildTextField(_skuCtrl, 'SKU (e.g. SRF-PRT-001)', isRequired: true),
              const SizedBox(height: 12),
              _buildTextField(_priceCtrl, 'Wholesale Price (₹)',
                  isRequired: true,
                  keyboardType: TextInputType.number),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildTextField(_piecesCtrl, 'Pieces / Units per Pack',
                        keyboardType: TextInputType.number),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildTextField(_weightCtrl, 'Unit Weight / Volume (g/ml)',
                        keyboardType: TextInputType.number),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildTextField(_minStockCtrl, 'Min Stock Alert Level',
                  keyboardType: TextInputType.number),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _categories.contains(_category) ? _category : 'General',
                decoration: const InputDecoration(labelText: 'Product Category'),
                items: _categories
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (val) => setState(() => _category = val ?? 'General'),
              ),
              const SizedBox(height: 12),
              _buildTextField(_descCtrl, 'Description / Ingredient Notes',
                  maxLines: 2),

              // FROZEN FOOD VERTICAL SECTION
              if (verticalScope.isEnabled(Vertical.frozen)) ...[
                const SizedBox(height: 20),
                _buildSectionHeader('Frozen Food & Cold Chain Attributes', Icons.ac_unit_rounded,
                    color: const Color(0xFF0288D1)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _storageType,
                  decoration: const InputDecoration(labelText: 'Cold Storage Class'),
                  items: const [
                    DropdownMenuItem(value: 'frozen', child: Text('Blast Frozen (-18°C)')),
                    DropdownMenuItem(value: 'chilled', child: Text('Refrigerated Chilled (0°C to 4°C)')),
                    DropdownMenuItem(value: 'ambient', child: Text('Ambient Dry Storage')),
                  ],
                  onChanged: (val) => setState(() => _storageType = val ?? 'frozen'),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(_shelfLifeCtrl, 'Shelf Life (Days)',
                          keyboardType: TextInputType.number),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildTextField(_packsPerCartonCtrl, 'Packs per Master Carton',
                          keyboardType: TextInputType.number),
                    ),
                  ],
                ),
              ],

              // DAIRY VERTICAL SECTION
              if (verticalScope.isEnabled(Vertical.dairy)) ...[
                const SizedBox(height: 20),
                _buildSectionHeader('Dairy Specialization Attributes', Icons.water_drop_rounded,
                    color: const Color(0xFF00897B)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _milkType,
                        decoration: const InputDecoration(labelText: 'Milk Source'),
                        items: const [
                          DropdownMenuItem(value: 'cow', child: Text('Cow Milk')),
                          DropdownMenuItem(value: 'buffalo', child: Text('Buffalo Milk')),
                          DropdownMenuItem(value: 'mixed', child: Text('Mixed Milk')),
                          DropdownMenuItem(value: 'goat', child: Text('Goat Milk')),
                        ],
                        onChanged: (val) => setState(() => _milkType = val ?? 'cow'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _procurementSlot,
                        decoration: const InputDecoration(labelText: 'Procurement Slot'),
                        items: const [
                          DropdownMenuItem(value: 'morning', child: Text('Morning Slot')),
                          DropdownMenuItem(value: 'evening', child: Text('Evening Slot')),
                          DropdownMenuItem(value: 'both', child: Text('Both Slots')),
                        ],
                        onChanged: (val) => setState(() => _procurementSlot = val ?? 'both'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(_fatExpectedCtrl, 'Expected Fat %',
                          keyboardType: const TextInputType.numberWithOptions(decimal: true)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildTextField(_snfExpectedCtrl, 'Expected SNF %',
                          keyboardType: const TextInputType.numberWithOptions(decimal: true)),
                    ),
                  ],
                ),
                SwitchListTile(
                  title: const Text('Pasteurized Milk / Product'),
                  subtitle: const Text('Complies with FSSAI pasteurization thermal standards'),
                  value: _isPasteurized,
                  onChanged: (v) => setState(() => _isPasteurized = v),
                  contentPadding: EdgeInsets.zero,
                ),
                SwitchListTile(
                  title: const Text('Cultured / Fermented Product'),
                  subtitle: const Text('Curd, Yogurt, Buttermilk, Paneer, or Cheese'),
                  value: _isCultured,
                  onChanged: (v) => setState(() => _isCultured = v),
                  contentPadding: EdgeInsets.zero,
                ),
              ],

              // BAKERY VERTICAL SECTION
              if (verticalScope.isEnabled(Vertical.bakery)) ...[
                const SizedBox(height: 20),
                _buildSectionHeader('Bakery Production & Freshness Attributes', Icons.bakery_dining_rounded,
                    color: const Color(0xFFE65100)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _ovenType,
                        decoration: const InputDecoration(labelText: 'Target Oven Type'),
                        items: const [
                          DropdownMenuItem(value: 'rotary', child: Text('Rotary Rack Oven')),
                          DropdownMenuItem(value: 'deck', child: Text('Deck Oven')),
                          DropdownMenuItem(value: 'convection', child: Text('Convection Oven')),
                          DropdownMenuItem(value: 'wood-fired', child: Text('Wood-Fired Hearth')),
                        ],
                        onChanged: (val) => setState(() => _ovenType = val ?? 'rotary'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildTextField(_proofingMinutesCtrl, 'Proofing (Mins)',
                          keyboardType: TextInputType.number),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(_freshnessWindowHoursCtrl, 'Freshness Window (Hrs)',
                          keyboardType: TextInputType.number),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildTextField(_dayOldDiscountCtrl, 'Day-Old Discount %',
                          keyboardType: const TextInputType.numberWithOptions(decimal: true)),
                    ),
                  ],
                ),
                SwitchListTile(
                  title: const Text('Bake Date Labeling Required'),
                  subtitle: const Text('Print mandatory time/date of baking on pack label'),
                  value: _bakeDateRequired,
                  onChanged: (v) => setState(() => _bakeDateRequired = v),
                  contentPadding: EdgeInsets.zero,
                ),
                SwitchListTile(
                  title: const Text('Custom Made-to-Order SKU'),
                  subtitle: const Text('Specialized birthday, anniversary, or catering custom cake'),
                  value: _isCustomOrder,
                  onChanged: (v) => setState(() => _isCustomOrder = v),
                  contentPadding: EdgeInsets.zero,
                ),
              ],

              const SizedBox(height: 16),
              _buildSectionHeader('Availability & Status', Icons.toggle_on_outlined),
              SwitchListTile(
                title: const Text('Active SKU'),
                value: _isActive,
                onChanged: (v) => setState(() => _isActive = v),
                contentPadding: EdgeInsets.zero,
              ),
              SwitchListTile(
                title: const Text('Available for Immediate Sale'),
                value: _isAvailable,
                onChanged: (v) => setState(() => _isAvailable = v),
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
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
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, {Color? color}) {
    final c = color ?? AppColors.primary;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: c.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: c, size: 18),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: AppTextStyles.titleSmall.copyWith(fontWeight: FontWeight.w700, color: c),
        ),
      ],
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
