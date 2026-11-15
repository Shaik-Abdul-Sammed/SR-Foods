import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../../core/database/app_database.dart';
import '../../../../core/database/database_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/communication_utils.dart';
import '../../../../core/services/whatsapp_service.dart';
import 'package:drift/drift.dart' show Variable;
import '../../../../core/services/container_return_service.dart';
import 'hotel_360_screen.dart';

final customerDetailProvider =
    FutureProvider.family<Customer?, int>((ref, id) async {
  final db = ref.watch(databaseProvider);
  return (db.select(db.customers)..where((c) => c.id.equals(id)))
      .getSingleOrNull();
});

class CustomerDetailScreen extends ConsumerWidget {
  final int id;
  const CustomerDetailScreen({super.key, required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customerAsync = ref.watch(customerDetailProvider(id));
    return customerAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
      data: (customer) {
        if (customer == null) {
          return const Scaffold(
              body: Center(child: Text('Customer not found')));
        }
        return Scaffold(
          appBar: AppBar(
            title: Text(customer.shopName),
            actions: [
              IconButton(
                tooltip: 'Hotel 360° Intelligence',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(builder: (_) => Hotel360Screen(customerId: id)),
                ),
                icon: const Icon(Icons.analytics_outlined),
              ),
              IconButton(
                onPressed: () => context.push('/customers/$id/edit'),
                icon: const Icon(Icons.edit_outlined),
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 36,
                        backgroundColor: Colors.white.withValues(alpha: 0.2),
                        child: Text(customer.shopName[0].toUpperCase(),
                            style: AppTextStyles.headlineMedium
                                .copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
                      ),
                      const SizedBox(height: 12),
                      Text(customer.shopName,
                          style: AppTextStyles.headlineSmall
                              .copyWith(color: Colors.white, fontWeight: FontWeight.w700),
                          textAlign: TextAlign.center),
                      Text(customer.ownerName,
                          style: AppTextStyles.bodyMedium
                              .copyWith(color: Colors.white.withValues(alpha: 0.8))),
                      if (customer.currentBalance > 0) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.error.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: AppColors.error.withValues(alpha: 0.4)),
                          ),
                          child: Text(
                            'Outstanding: ${CurrencyFormatter.format(customer.currentBalance)}',
                            style: AppTextStyles.labelMedium.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF25D366),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 10),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                            elevation: 2,
                          ),
                          onPressed: () => WhatsAppService.sharePaymentReminder(
                            context: context,
                            customer: customer,
                          ),
                          icon: const Icon(Icons.send_rounded, size: 18, color: Colors.white),
                          label: const Text(
                            'Send WhatsApp Reminder',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _card(context, 'Contact Info', [
                  _contactRow(context, 'Phone', customer.phone),
                  if (customer.altPhone != null)
                    _contactRow(context, 'Alt Phone', customer.altPhone!),
                  if (customer.address != null)
                    _row('Address', customer.address!),
                  if (customer.area != null) _row('Area', customer.area!),
                  if (customer.route != null) _row('Route', customer.route!),
                ]),
                const SizedBox(height: 12),
                _card(context, 'Financial', [
                  _row('Credit Limit',
                      CurrencyFormatter.format(customer.creditLimit)),
                  _row('Opening Balance',
                      CurrencyFormatter.format(customer.openingBalance)),
                  _row('Current Balance',
                      CurrencyFormatter.format(customer.currentBalance)),
                ]),
                const SizedBox(height: 12),
                _containerTrackingCard(context, ref, id),
              ],
            ),
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => context.push('/orders/create'),
            icon: const Icon(Icons.add_rounded),
            label: const Text('New Order'),
          ),
        );
      },
    );
  }

  Widget _containerTrackingCard(BuildContext context, WidgetRef ref, int customerId) {
    final db = ref.watch(databaseProvider);

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: () async {
        try {
          final rows = await db.customSelect(
            'SELECT * FROM returnable_containers WHERE customer_id = ? AND status = ?',
            variables: [
              Variable.withInt(customerId),
              Variable.withString('with_customer'),
            ],
          ).get();
          return rows.map((r) => r.data).toList();
        } catch (_) {
          return <Map<String, dynamic>>[];
        }
      }(),
      builder: (ctx, snapshot) {
        final containers = snapshot.data ?? [];
        int totalDeposit = 0;
        for (final c in containers) {
          totalDeposit += (c['deposit_amount_minor'] as int? ?? 0);
        }

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.inventory_rounded, size: 18, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Text('Container Tracking', style: AppTextStyles.titleSmall),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${containers.length} With Customer',
                      style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _row(
                'Security Deposit Held',
                '₹${(totalDeposit / 100.0).toStringAsFixed(2)}',
              ),
              const SizedBox(height: 8),
              if (containers.isEmpty)
                Text(
                  'No active crates, milk cans, or bakery trays currently issued.',
                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                )
              else
                Column(
                  children: containers.map((c) {
                    final code = c['container_code'] ?? 'CRT-???';
                    final type = c['container_type'] ?? 'crate';
                    final dep = (c['deposit_amount_minor'] as int? ?? 0) / 100.0;

                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.move_to_inbox, size: 20, color: AppColors.secondary),
                      title: Text('$code (${type.toString().toUpperCase()})', style: AppTextStyles.bodyMedium),
                      subtitle: Text('Deposit: ₹${dep.toStringAsFixed(0)}'),
                      trailing: TextButton.icon(
                        icon: const Icon(Icons.assignment_return_outlined, size: 16),
                        label: const Text('Return'),
                        onPressed: () => _showMarkReturnedDialog(context, ref, code.toString()),
                      ),
                    );
                  }).toList(),
                ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 38),
                ),
                onPressed: () => _showMarkReturnedDialog(context, ref, null),
                icon: const Icon(Icons.qr_code_scanner, size: 18),
                label: const Text('Mark Container Returned'),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showMarkReturnedDialog(BuildContext context, WidgetRef ref, String? defaultCode) {
    final codeCtrl = TextEditingController(text: defaultCode ?? '');
    String condition = 'good';

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Scan / Return Container'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: codeCtrl,
              decoration: const InputDecoration(
                labelText: 'Container Barcode / Code',
                prefixIcon: Icon(Icons.qr_code_2),
                hintText: 'e.g. CRT-048 or CAN-102',
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: condition,
              decoration: const InputDecoration(labelText: 'Physical Condition'),
              items: const [
                DropdownMenuItem(value: 'good', child: Text('Good / Reusable')),
                DropdownMenuItem(value: 'damaged', child: Text('Damaged / Cracked')),
              ],
              onChanged: (v) => condition = v ?? 'good',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final code = codeCtrl.text.trim();
              if (code.isEmpty) return;
              Navigator.of(ctx).pop();

              try {
                final db = ref.read(databaseProvider);
                await const ContainerReturnService().returnContainer(
                  db: db,
                  containerCode: code,
                  condition: condition,
                );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Container $code marked as returned!'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
                  );
                }
              }
            },
            child: const Text('Mark Returned'),
          ),
        ],
      ),
    );
  }

  Widget _card(BuildContext context, String title, List<Widget> rows) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTextStyles.titleSmall),
          const SizedBox(height: 12),
          ...rows,
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
              width: 140,
              child: Text(label,
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textSecondary))),
          Expanded(
              child: Text(value,
                  style:
                      AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }

  Widget _contactRow(BuildContext context, String label, String value) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
              width: 140,
              child: Text(label,
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textSecondary))),
          Expanded(
              child: Text(value,
                  style:
                      AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w500))),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.phone_rounded, color: AppColors.primary, size: 20),
                onPressed: () => CommunicationUtils.launchPhone(context, value),
                style: IconButton.styleFrom(
                  padding: const EdgeInsets.all(6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                tooltip: 'Call $label',
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: SvgPicture.string(
                  '''<svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" fill="currentColor" viewBox="0 0 16 16">
  <path d="M13.601 2.326A7.85 7.85 0 0 0 7.994 0C3.627 0 .068 3.558.064 7.926c0 1.399.366 2.76 1.057 3.965L0 16l4.204-1.102a7.9 7.9 0 0 0 3.79.965h.004c4.368 0 7.926-3.558 7.93-7.93A7.9 7.9 0 0 0 13.6 2.326zM7.994 14.521a6.6 6.6 0 0 1-3.356-.92l-.24-.144-2.494.654.666-2.433-.156-.251a6.56 6.56 0 0 1-1.007-3.505c0-3.626 2.957-6.584 6.591-6.584a6.56 6.56 0 0 1 4.66 1.931 6.56 6.56 0 0 1 1.928 4.66c-.004 3.639-2.961 6.592-6.592 6.592m3.615-4.934c-.197-.099-1.17-.578-1.353-.646-.182-.065-.315-.099-.445.099-.133.197-.513.646-.627.775-.114.133-.232.148-.43.05-.197-.1-.836-.308-1.592-.985-.59-.525-.985-1.175-1.103-1.372-.114-.198-.011-.304.088-.403.087-.088.197-.232.296-.346.1-.114.133-.198.198-.33.065-.134.034-.248-.015-.347-.05-.099-.445-1.076-.612-1.47-.16-.389-.323-.335-.445-.34-.114-.007-.247-.007-.38-.007a.73.73 0 0 0-.529.247c-.182.198-.691.677-.691 1.654s.71 1.916.81 2.049c.098.133 1.394 2.132 3.383 2.992.47.205.84.326 1.129.418.475.152.904.129 1.246.08.38-.058 1.171-.48 1.338-.943.164-.464.164-.86.114-.943-.049-.084-.182-.133-.38-.232"/>
</svg>''',
                  colorFilter: const ColorFilter.mode(Colors.green, BlendMode.srcIn),
                  width: 20,
                  height: 20,
                ),
                onPressed: () => CommunicationUtils.launchWhatsApp(
                  context,
                  value,
                  message: 'Hello! This is from SR Foods.',
                ),
                style: IconButton.styleFrom(
                  padding: const EdgeInsets.all(6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                tooltip: 'WhatsApp $label',
              ),
            ],
          ),
        ],
      ),
    );
  }
}
