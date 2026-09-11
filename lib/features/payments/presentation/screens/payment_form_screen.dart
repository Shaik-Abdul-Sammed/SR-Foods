import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:drift/drift.dart' as drift;
import '../../../../core/database/app_database.dart';
import '../../../../core/database/database_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/formatters.dart';
import '../../../customers/presentation/screens/customers_screen.dart';

class PaymentFormScreen extends ConsumerStatefulWidget {
  const PaymentFormScreen({super.key});
  @override
  ConsumerState<PaymentFormScreen> createState() => _PaymentFormScreenState();
}

class _PaymentFormScreenState extends ConsumerState<PaymentFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  Customer? _selectedCustomer;
  String _method = 'cash';
  bool _isLoading = false;
  final _methods = ['cash', 'upi', 'bank', 'credit'];

  @override
  void dispose() {
    _amountCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCustomer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a customer')),
      );
      return;
    }
    setState(() => _isLoading = true);
    try {
      final db = ref.read(databaseProvider);
      final amount = double.parse(_amountCtrl.text.trim());

      // 1. Record the payment
      await db.into(db.payments).insert(PaymentsCompanion(
        receiptNumber: drift.Value(IdGenerator.generateReceiptNumber()),
        customerId: drift.Value(_selectedCustomer!.id),
        amount: drift.Value(amount),
        method: drift.Value(_method),
        notes: drift.Value(_notesCtrl.text.isEmpty ? null : _notesCtrl.text),
        paymentDate: drift.Value(DateTime.now()),
      ));

      // 2. Update customer balance (allow negative = credit balance)
      final newBalance = _selectedCustomer!.currentBalance - amount;
      await (db.update(db.customers)..where((c) => c.id.equals(_selectedCustomer!.id)))
          .write(CustomersCompanion(
        currentBalance: drift.Value(newBalance),
        updatedAt: drift.Value(DateTime.now()),
      ));

      // 3. Apply payment to oldest pending invoice for this customer
      final pendingInvoices = await (db.select(db.invoices)
            ..where((i) =>
                i.customerId.equals(_selectedCustomer!.id) &
                i.status.isIn(['pending', 'partial']))
            ..orderBy([(i) => drift.OrderingTerm.asc(i.invoiceDate)]))
          .get();

      double remaining = amount;
      for (final invoice in pendingInvoices) {
        if (remaining <= 0) break;
        final toPay = remaining < invoice.pendingAmount ? remaining : invoice.pendingAmount;
        final newPaid = invoice.paidAmount + toPay;
        final newPending = invoice.pendingAmount - toPay;
        final newStatus = newPending <= 0 ? 'paid' : 'partial';
        await (db.update(db.invoices)..where((i) => i.id.equals(invoice.id)))
            .write(InvoicesCompanion(
          paidAmount: drift.Value(newPaid),
          pendingAmount: drift.Value(newPending),
          status: drift.Value(newStatus),
        ));

        // Also update the corresponding order
        await (db.update(db.orders)..where((o) => o.id.equals(invoice.orderId)))
            .write(OrdersCompanion(
          paidAmount: drift.Value(newPaid),
          pendingAmount: drift.Value(newPending),
          paymentStatus: drift.Value(newStatus),
        ));

        remaining -= toPay;
      }

      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payment of ${CurrencyFormatter.format(amount)} recorded!'),
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
    return Scaffold(
      appBar: AppBar(title: const Text('Record Payment')),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Customer outstanding info
            if (_selectedCustomer != null && _selectedCustomer!.currentBalance > 0)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                ),
                child: Row(children: [
                  const Icon(Icons.info_outline_rounded, color: AppColors.error, size: 20),
                  const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Outstanding Balance', style: AppTextStyles.labelMedium.copyWith(color: AppColors.error, fontWeight: FontWeight.w700)),
                    Text(CurrencyFormatter.format(_selectedCustomer!.currentBalance), style: AppTextStyles.titleMedium.copyWith(color: AppColors.error, fontWeight: FontWeight.w800)),
                  ])),
                  TextButton(
                    onPressed: () => _amountCtrl.text = _selectedCustomer!.currentBalance.toStringAsFixed(0),
                    child: Text('Pay Full', style: AppTextStyles.labelMedium.copyWith(color: AppColors.error)),
                  ),
                ]),
              ),
            Text('CUSTOMER', style: AppTextStyles.overline.copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            customersAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('Error: $e'),
              data: (customers) => DropdownButtonFormField<Customer>(
                initialValue: _selectedCustomer,
                hint: const Text('Select Customer'),
                decoration: const InputDecoration(
                  labelText: 'Customer',
                  prefixIcon: Icon(Icons.person_outline_rounded),
                ),
                items: customers.map((c) => DropdownMenuItem(
                  value: c,
                  child: Row(children: [
                    Expanded(child: Text(c.shopName)),
                    if (c.currentBalance > 0) Text(
                      '₹${c.currentBalance.toStringAsFixed(0)}',
                      style: AppTextStyles.labelSmall.copyWith(color: AppColors.error),
                    ),
                  ]),
                )).toList(),
                onChanged: (c) => setState(() => _selectedCustomer = c),
                validator: (v) => v == null ? 'Please select a customer' : null,
              ),
            ),
            const SizedBox(height: 16),
            Text('PAYMENT DETAILS', style: AppTextStyles.overline.copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            TextFormField(
              controller: _amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Amount (₹)',
                prefixIcon: Icon(Icons.currency_rupee_rounded),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Amount is required';
                final parsed = double.tryParse(v.trim());
                if (parsed == null) return 'Enter a valid number';
                if (parsed <= 0) return 'Amount must be greater than 0';
                return null;
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _method,
              decoration: const InputDecoration(
                labelText: 'Payment Method',
                prefixIcon: Icon(Icons.payment_rounded),
              ),
              items: _methods.map((m) => DropdownMenuItem(
                value: m,
                child: Text(m.toUpperCase()),
              )).toList(),
              onChanged: (v) => setState(() => _method = v!),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notesCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                prefixIcon: Icon(Icons.notes_rounded),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isLoading ? null : _save,
              child: _isLoading
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Record Payment'),
            ),
          ]),
        ),
      ),
    );
  }
}
