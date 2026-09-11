import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:drift/drift.dart' as drift;
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/database/database_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/validators.dart';

class CustomerFormScreen extends ConsumerStatefulWidget {
  final int? id;
  const CustomerFormScreen({super.key, this.id});
  @override
  ConsumerState<CustomerFormScreen> createState() => _CustomerFormScreenState();
}

class _CustomerFormScreenState extends ConsumerState<CustomerFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _shopNameCtrl = TextEditingController();
  final _ownerNameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _altPhoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _areaCtrl = TextEditingController();
  final _routeCtrl = TextEditingController();
  final _creditLimitCtrl = TextEditingController(text: '5000');
  final _openingBalanceCtrl = TextEditingController(text: '0');
  final _notesCtrl = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.id != null) _load();
  }

  Future<void> _load() async {
    final db = ref.read(databaseProvider);
    final c = await (db.select(db.customers)
          ..where((x) => x.id.equals(widget.id!)))
        .getSingleOrNull();
    if (c != null && mounted) {
      _shopNameCtrl.text = c.shopName;
      _ownerNameCtrl.text = c.ownerName;
      _phoneCtrl.text = c.phone;
      _altPhoneCtrl.text = c.altPhone ?? '';
      _addressCtrl.text = c.address ?? '';
      _areaCtrl.text = c.area ?? '';
      _routeCtrl.text = c.route ?? '';
      _creditLimitCtrl.text = c.creditLimit.toString();
      _openingBalanceCtrl.text = c.openingBalance.toString();
      _notesCtrl.text = c.notes ?? '';
    }
  }

  @override
  void dispose() {
    for (final c in [
      _shopNameCtrl, _ownerNameCtrl, _phoneCtrl, _altPhoneCtrl,
      _addressCtrl, _areaCtrl, _routeCtrl, _creditLimitCtrl,
      _openingBalanceCtrl, _notesCtrl,
    ]) { c.dispose(); }
    super.dispose();
  }

  Future<void> _pickContact() async {
    if (await FlutterContacts.permissions.has(PermissionType.read) || 
        await FlutterContacts.permissions.request(PermissionType.read) == PermissionStatus.granted) {
      final contact = await FlutterContacts.native.showPicker(properties: {ContactProperty.phone});
      if (contact != null && mounted) {
        setState(() {
          _ownerNameCtrl.text = contact.displayName ?? '';
          if (contact.phones.isNotEmpty) {
            // keep only digits
            _phoneCtrl.text = contact.phones.first.number.replaceAll(RegExp(r'[^0-9]'), '');
          }
        });
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Contact permission denied')),
        );
      }
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final db = ref.read(databaseProvider);
      final code = widget.id == null ? IdGenerator.generateCustomerCode() : null;
      final opening = double.tryParse(_openingBalanceCtrl.text) ?? 0.0;
      final companion = CustomersCompanion(
        shopName: drift.Value(_shopNameCtrl.text.trim()),
        ownerName: drift.Value(_ownerNameCtrl.text.trim()),
        phone: drift.Value(_phoneCtrl.text.trim()),
        altPhone: drift.Value(_altPhoneCtrl.text.isEmpty ? null : _altPhoneCtrl.text.trim()),
        address: drift.Value(_addressCtrl.text.isEmpty ? null : _addressCtrl.text.trim()),
        area: drift.Value(_areaCtrl.text.isEmpty ? null : _areaCtrl.text.trim()),
        route: drift.Value(_routeCtrl.text.isEmpty ? null : _routeCtrl.text.trim()),
        creditLimit: drift.Value(double.tryParse(_creditLimitCtrl.text) ?? 5000),
        openingBalance: drift.Value(opening),
        currentBalance: widget.id == null ? drift.Value(opening) : const drift.Value.absent(),
        notes: drift.Value(_notesCtrl.text.isEmpty ? null : _notesCtrl.text.trim()),
        code: code != null ? drift.Value(code) : const drift.Value.absent(),
        updatedAt: drift.Value(DateTime.now()),
      );
      if (widget.id == null) {
        await db.into(db.customers).insert(companion);
      } else {
        await (db.update(db.customers)..where((c) => c.id.equals(widget.id!))).write(companion);
      }
      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(widget.id == null ? 'Customer created' : 'Customer updated'),
        ));
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
      appBar: AppBar(title: Text(widget.id == null ? 'Add Customer' : 'Edit Customer')),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _field(_shopNameCtrl, 'Shop Name', required: true).animate().fade(duration: 400.ms, delay: 50.ms).slideX(begin: 0.1, curve: Curves.easeOutQuad),
              const SizedBox(height: 12),
              _field(
                _ownerNameCtrl, 
                'Owner Name', 
                required: true,
                suffixIcon: IconButton(
                  icon: const Icon(Icons.contacts_rounded, color: AppColors.primary),
                  onPressed: _pickContact,
                  tooltip: 'Pick from contacts',
                ),
              ).animate().fade(duration: 400.ms, delay: 100.ms).slideX(begin: 0.1, curve: Curves.easeOutQuad),
              const SizedBox(height: 12),
              _field(_phoneCtrl, 'Phone', required: true, type: TextInputType.phone).animate().fade(duration: 400.ms, delay: 150.ms).slideX(begin: 0.1, curve: Curves.easeOutQuad),
              const SizedBox(height: 12),
              _field(_altPhoneCtrl, 'Alt Phone', type: TextInputType.phone).animate().fade(duration: 400.ms, delay: 200.ms).slideX(begin: 0.1, curve: Curves.easeOutQuad),
              const SizedBox(height: 12),
              _field(_addressCtrl, 'Address', maxLines: 2).animate().fade(duration: 400.ms, delay: 250.ms).slideX(begin: 0.1, curve: Curves.easeOutQuad),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: _field(_areaCtrl, 'Area')),
                const SizedBox(width: 12),
                Expanded(child: _field(_routeCtrl, 'Route')),
              ]).animate().fade(duration: 400.ms, delay: 300.ms).slideX(begin: 0.1, curve: Curves.easeOutQuad),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: _field(_creditLimitCtrl, 'Credit Limit', type: TextInputType.number)),
                const SizedBox(width: 12),
                Expanded(child: _field(_openingBalanceCtrl, 'Opening Balance', type: TextInputType.number)),
              ]).animate().fade(duration: 400.ms, delay: 350.ms).slideX(begin: 0.1, curve: Curves.easeOutQuad),
              const SizedBox(height: 12),
              _field(_notesCtrl, 'Notes', maxLines: 3).animate().fade(duration: 400.ms, delay: 400.ms).slideX(begin: 0.1, curve: Curves.easeOutQuad),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _save,
                  style: ElevatedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: _isLoading
                      ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                      : Text(
                          widget.id == null ? 'Create Customer' : 'Update Customer',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
              ).animate().fade(duration: 500.ms, delay: 500.ms).slideY(begin: 0.2, curve: Curves.easeOutBack),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String label, {
    bool required = false, TextInputType type = TextInputType.text, int maxLines = 1,
    Widget? suffixIcon,
  }) {
    return TextFormField(
      controller: ctrl,
      keyboardType: type,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        suffixIcon: suffixIcon,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: AppColors.border.withValues(alpha: 0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
      ),
      validator: required ? (v) => Validators.required(v, label) : null,
    );
  }
}
