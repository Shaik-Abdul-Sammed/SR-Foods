import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:drift/drift.dart' as drift;
import '../../../../core/database/app_database.dart';
import '../../../../core/database/database_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';

class ExpenseFormScreen extends ConsumerStatefulWidget {
  const ExpenseFormScreen({super.key});
  @override
  ConsumerState<ExpenseFormScreen> createState() => _ExpenseFormScreenState();
}

class _ExpenseFormScreenState extends ConsumerState<ExpenseFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String _category = 'flour';
  String _paymentMethod = 'cash';
  DateTime _date = DateTime.now();
  bool _isLoading = false;
  final _categories = ['flour', 'oil', 'gas', 'electricity', 'salary', 'transport', 'packaging', 'maintenance', 'miscellaneous'];

  @override
  void dispose() { _descCtrl.dispose(); _amountCtrl.dispose(); _notesCtrl.dispose(); super.dispose(); }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final db = ref.read(databaseProvider);
      await db.into(db.expenses).insert(ExpensesCompanion(
        category: drift.Value(_category),
        description: drift.Value(_descCtrl.text.trim()),
        amount: drift.Value(double.parse(_amountCtrl.text)),
        paymentMethod: drift.Value(_paymentMethod),
        notes: drift.Value(_notesCtrl.text.isEmpty ? null : _notesCtrl.text),
        expenseDate: drift.Value(_date),
      ));
      if (mounted) { context.pop(); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Expense recorded!'))); }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error));
    } finally { if (mounted) setState(() => _isLoading = false); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Record Expense')),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            DropdownButtonFormField<String>(initialValue: _category, decoration: const InputDecoration(labelText: 'Category'), items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c.toUpperCase()))).toList(), onChanged: (v) => setState(() => _category = v!)),
            const SizedBox(height: 12),
            TextFormField(controller: _descCtrl, decoration: const InputDecoration(labelText: 'Description'), validator: (v) => (v == null || v.isEmpty) ? 'Required' : null),
            const SizedBox(height: 12),
            TextFormField(controller: _amountCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Amount (₹)', prefixIcon: Icon(Icons.currency_rupee_rounded)), validator: (v) {
              if (v == null || v.isEmpty) return 'Required';
              final parsed = double.tryParse(v.trim());
              if (parsed == null) return 'Enter a valid number';
              if (parsed <= 0) return 'Amount must be greater than 0';
              return null;
            }),

            const SizedBox(height: 12),
            DropdownButtonFormField<String>(initialValue: _paymentMethod, decoration: const InputDecoration(labelText: 'Payment Method'), items: ['cash','upi','bank'].map((m) => DropdownMenuItem(value: m, child: Text(m.toUpperCase()))).toList(), onChanged: (v) => setState(() => _paymentMethod = v!)),
            const SizedBox(height: 12),
            ListTile(contentPadding: EdgeInsets.zero, title: const Text('Date'), subtitle: Text(DateFormatter.toDate(_date)), trailing: const Icon(Icons.calendar_today_rounded),

              onTap: () async {
                final d = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime(2020), lastDate: DateTime.now());
                if (d != null) setState(() => _date = d);
              }),
            const SizedBox(height: 12),
            TextFormField(controller: _notesCtrl, maxLines: 2, decoration: const InputDecoration(labelText: 'Notes')),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isLoading ? null : _save,
              child: _isLoading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Record Expense'),
            ),
          ]),
        ),
      ),
    );
  }
}
