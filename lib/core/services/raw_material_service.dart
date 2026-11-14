import 'package:drift/drift.dart';
import '../database/app_database.dart';

class RawMaterialStatus {
  final int id;
  final String name;
  final String category;
  final double currentStock;
  final String unit;
  final double minStock;
  final double lastPurchasePrice;
  final bool isLowStock;
  final double deficitQuantity;
  final double estimatedReorderCost;

  const RawMaterialStatus({
    required this.id,
    required this.name,
    required this.category,
    required this.currentStock,
    required this.unit,
    required this.minStock,
    required this.lastPurchasePrice,
    required this.isLowStock,
    required this.deficitQuantity,
    required this.estimatedReorderCost,
  });
}

class RawMaterialService {
  RawMaterialService._();
  static final RawMaterialService instance = RawMaterialService._();

  /// Scans raw material inventory and identifies items below minimum safety levels
  Future<List<RawMaterialStatus>> getInventoryStatus(AppDatabase db) async {
    final materials = await db.getAllRawMaterials();

    final List<RawMaterialStatus> results = [];
    for (final m in materials) {
      final isLow = m.currentStock <= m.minStock;
      final deficit = isLow ? (m.minStock * 2.0) - m.currentStock : 0.0;
      final reorderCost = deficit * m.lastPurchasePrice;

      results.add(RawMaterialStatus(
        id: m.id,
        name: m.name,
        category: m.category,
        currentStock: m.currentStock,
        unit: m.unit,
        minStock: m.minStock,
        lastPurchasePrice: m.lastPurchasePrice,
        isLowStock: isLow,
        deficitQuantity: double.parse(deficit.toStringAsFixed(1)),
        estimatedReorderCost: double.parse(reorderCost.toStringAsFixed(0)),
      ));
    }

    // Sort: low stock first
    results.sort((a, b) {
      if (a.isLowStock == b.isLowStock) {
        return a.name.compareTo(b.name);
      }
      return a.isLowStock ? -1 : 1;
    });

    return results;
  }

  /// Drafts an instant B2B Purchase Order message for WhatsApp
  String generatePurchaseOrderDraft({
    required List<RawMaterialStatus> itemsToOrder,
    String supplierName = 'Flour & Packaging Vendor',
  }) {
    final buffer = StringBuffer();
    buffer.writeln('*PURCHASE ORDER — SR FOODS*');
    buffer.writeln('Date: ${DateTime.now().toLocal().toString().split(' ')[0]}');
    buffer.writeln('To: $supplierName');
    buffer.writeln('--------------------------------');
    buffer.writeln('Please dispatch the following raw materials to our factory:');
    buffer.writeln('');

    double totalEstCost = 0.0;
    for (int i = 0; i < itemsToOrder.length; i++) {
      final item = itemsToOrder[i];
      final qty = item.deficitQuantity > 0 ? item.deficitQuantity : item.minStock;
      final cost = qty * item.lastPurchasePrice;
      totalEstCost += cost;
      buffer.writeln('${i + 1}. *${item.name}*: ${qty.toStringAsFixed(0)} ${item.unit} (Est: ₹${cost.toStringAsFixed(0)})');
    }

    buffer.writeln('--------------------------------');
    buffer.writeln('Est. Total: ₹${totalEstCost.toStringAsFixed(0)}');
    buffer.writeln('Delivery: Immediate / Next Morning Batch');
    buffer.writeln('Factory: SR Foods Manufacturing Facility');
    buffer.writeln('Confirm availability and delivery slot.');

    return buffer.toString();
  }

  /// Records raw material inward receipt: updates inventory stock, logs expense, and writes activity log
  Future<void> recordInwardMaterial({
    required AppDatabase db,
    required int materialId,
    required double quantityReceived,
    required double unitPrice,
    required String vendorName,
    String? invoiceRef,
  }) async {
    final material = await (db.select(db.rawMaterials)..where((r) => r.id.equals(materialId))).getSingle();
    final newStock = material.currentStock + quantityReceived;
    final totalAmount = quantityReceived * unitPrice;

    // 1. Update Raw Materials stock
    await (db.update(db.rawMaterials)..where((r) => r.id.equals(materialId))).write(
      RawMaterialsCompanion(
        currentStock: Value(newStock),
        lastPurchasePrice: Value(unitPrice),
        updatedAt: Value(DateTime.now()),
      ),
    );

    // 2. Insert into Expenses
    await db.into(db.expenses).insert(
      ExpensesCompanion.insert(
        category: material.category == 'flour' ? 'flour' : (material.category == 'oil' ? 'oil' : 'packaging'),
        description: 'Raw Material Inward: ${quantityReceived.toStringAsFixed(1)} ${material.unit} of ${material.name}',
        amount: totalAmount,
        vendorName: Value(vendorName),
        expenseDate: DateTime.now(),
        notes: Value(invoiceRef != null ? 'Ref Inv: $invoiceRef' : null),
      ),
    );

    // 3. Activity Log
    await db.logActivity(
      action: 'RAW_MATERIAL_RECEIVED',
      entityType: 'RawMaterial',
      entityId: materialId,
      details: 'Received ${quantityReceived.toStringAsFixed(1)} ${material.unit} of ${material.name} @ ₹$unitPrice/${material.unit}. Vendor: $vendorName',
    );
  }
}
