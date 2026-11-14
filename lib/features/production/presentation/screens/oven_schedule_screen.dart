import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/database_provider.dart';
import '../../../../core/services/bakery_scheduling_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

class OvenScheduleScreen extends ConsumerStatefulWidget {
  const OvenScheduleScreen({super.key});

  @override
  ConsumerState<OvenScheduleScreen> createState() => _OvenScheduleScreenState();
}

class _OvenScheduleScreenState extends ConsumerState<OvenScheduleScreen> {
  final _service = const BakerySchedulingService();
  String _selectedOven = 'OVEN-01';
  DateTime _selectedDate = DateTime.now();
  List<Map<String, dynamic>> _schedules = [];
  OvenCapacityResult? _capacity;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadSchedules();
  }

  Future<void> _loadSchedules() async {
    setState(() => _isLoading = true);
    try {
      final db = ref.read(databaseProvider);
      final cap = await _service.ovenCapacityCheck(
        db: db,
        ovenId: _selectedOven,
        date: _selectedDate,
      );

      final rows = await db.customSelect(
        'SELECT os.*, p.name as product_name '
        'FROM oven_schedules os '
        'LEFT JOIN products p ON p.id = os.product_id '
        'WHERE os.oven_id = ? '
        'ORDER BY os.scheduled_start ASC',
        variables: [Variable.withString(_selectedOven)],
      ).get();

      if (mounted) {
        setState(() {
          _capacity = cap;
          _schedules = rows.map((r) => r.data).toList();
        });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showScheduleDialog() async {
    final qtyCtrl = TextEditingController(text: '100');
    int selectedProduct = 1;
    final delivery = DateTime.now().add(const Duration(hours: 4));

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Schedule Baking Batch'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: qtyCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Batch Quantity (Units)'),
            ),
            const SizedBox(height: 12),
            Text(
              'Target Delivery: ${delivery.hour.toString().padLeft(2, '0')}:${delivery.minute.toString().padLeft(2, '0')}',
              style: AppTextStyles.bodyMedium,
            ),
            const SizedBox(height: 6),
            Text(
              'Proofing: 45 min | Bake: 35 min | Cool: 60 min',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
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
              Navigator.of(ctx).pop();
              try {
                final db = ref.read(databaseProvider);
                await _service.scheduleBatch(
                  db: db,
                  productId: selectedProduct,
                  quantity: int.tryParse(qtyCtrl.text) ?? 100,
                  deliveryDate: delivery,
                  ovenId: _selectedOven,
                );
                _loadSchedules();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Baking batch scheduled successfully!')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.error),
                  );
                }
              }
            },
            child: const Text('Schedule'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalBooked = _capacity?.totalBookedMinutes ?? 0;
    final utilizationPct = ((totalBooked / (18 * 60)) * 100).clamp(0, 100).toInt();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bakery Oven Schedules'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadSchedules,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showScheduleDialog,
        icon: const Icon(Icons.add),
        label: const Text('Schedule Bake'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Oven Selector
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedOven,
                    decoration: const InputDecoration(labelText: 'Active Oven Unit'),
                    items: const [
                      DropdownMenuItem(value: 'OVEN-01', child: Text('OVEN-01 (Rotary Rack - 30 Trays)')),
                      DropdownMenuItem(value: 'OVEN-02', child: Text('OVEN-02 (Stone Hearth Deck - 3 Decks)')),
                      DropdownMenuItem(value: 'OVEN-03', child: Text('OVEN-03 (High-Speed Convection)')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _selectedOven = val);
                        _loadSchedules();
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Capacity & Utilization Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Shift Capacity Utilization',
                        style: AppTextStyles.titleMedium.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '$utilizationPct% Booked',
                          style: AppTextStyles.labelSmall.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Booked: ${totalBooked ~/ 60}h ${totalBooked % 60}m of 18h daily operating window',
                    style: AppTextStyles.bodySmall.copyWith(color: Colors.white70),
                  ),
                  const SizedBox(height: 12),
                  LinearProgressIndicator(
                    value: utilizationPct / 100.0,
                    backgroundColor: Colors.white24,
                    valueColor: const AlwaysStoppedAnimation<Color>(AppColors.accent),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Schedules List
            Text('Scheduled Baking Batches', style: AppTextStyles.titleSmall.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            if (_isLoading)
              const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
            else if (_schedules.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                alignment: Alignment.center,
                child: Text(
                  'No batches scheduled for $_selectedOven today.\nTap "+ Schedule Bake" to reserve oven time.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _schedules.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (ctx, i) {
                  final item = _schedules[i];
                  final pName = item['product_name'] ?? 'Bakery Batch #${item['id']}';
                  final qty = item['quantity'];
                  final start = DateTime.tryParse(item['scheduled_start'] ?? '') ?? DateTime.now();
                  final end = DateTime.tryParse(item['scheduled_end'] ?? '') ?? DateTime.now();
                  final status = item['status'] ?? 'scheduled';

                  return Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE65100).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.bakery_dining_rounded, color: Color(0xFFE65100)),
                      ),
                      title: Text(pName.toString(), style: AppTextStyles.titleSmall.copyWith(fontWeight: FontWeight.bold)),
                      subtitle: Text(
                        'Time: ${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')} - '
                        '${end.hour.toString().padLeft(2, '0')}:${end.minute.toString().padLeft(2, '0')} | Qty: $qty',
                        style: AppTextStyles.bodySmall,
                      ),
                      trailing: Chip(
                        label: Text(status.toString().toUpperCase()),
                        backgroundColor: status == 'completed'
                            ? AppColors.success.withValues(alpha: 0.15)
                            : AppColors.primary.withValues(alpha: 0.15),
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
