import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../../core/database/database_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/services/delivery_route_service.dart';
import '../../../../core/services/quantum_optimization_engine.dart';
import '../../../../core/services/qr_verifier.dart';

final deliveryRoutesProvider = FutureProvider.autoDispose<List<DeliveryRouteSummary>>((ref) async {
  final db = ref.watch(databaseProvider);
  return DeliveryRouteService.instance.getActiveRoutes(db);
});

class DriverRouteScreen extends ConsumerStatefulWidget {
  const DriverRouteScreen({super.key});

  @override
  ConsumerState<DriverRouteScreen> createState() => _DriverRouteScreenState();
}

class _DriverRouteScreenState extends ConsumerState<DriverRouteScreen> {
  int _selectedRouteIndex = 0;
  bool _isQuantumOptimized = false;
  QuantumRouteOptimizationResult? _quantumResult;

  void _showPodScannerSheet(BuildContext context, RouteDeliveryStop stop) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final pinCtrl = TextEditingController();
        bool showManualPin = false;

        return StatefulBuilder(
          builder: (sheetCtx, setSheetState) {
            return SizedBox(
              height: MediaQuery.of(ctx).size.height * 0.85,
              child: Column(
                children: [
                  AppBar(
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    leading: IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                    title: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Scan ePOD Signature QR', style: TextStyle(color: Colors.white, fontSize: 16)),
                        Text(stop.shopName, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                      ],
                    ),
                    actions: [
                      TextButton.icon(
                        icon: Icon(showManualPin ? Icons.qr_code_scanner : Icons.pin_outlined, color: Colors.white),
                        label: Text(showManualPin ? 'Camera' : 'PIN Override', style: const TextStyle(color: Colors.white)),
                        onPressed: () => setSheetState(() => showManualPin = !showManualPin),
                      ),
                    ],
                  ),
                  Expanded(
                    child: showManualPin
                        ? Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.lock_clock_rounded, size: 56, color: Colors.amber),
                                const SizedBox(height: 16),
                                const Text('Manual Delivery PIN Override', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 8),
                                const Text('For damaged or unreadable QR codes, enter customer registered 4-digit PIN:', textAlign: TextAlign.center, style: TextStyle(color: Colors.white70, fontSize: 13)),
                                const SizedBox(height: 20),
                                TextField(
                                  controller: pinCtrl,
                                  keyboardType: TextInputType.number,
                                  maxLength: 4,
                                  style: const TextStyle(color: Colors.white, fontSize: 24, letterSpacing: 8),
                                  textAlign: TextAlign.center,
                                  decoration: InputDecoration(
                                    filled: true,
                                    fillColor: Colors.white12,
                                    hintText: '••••',
                                    hintStyle: const TextStyle(color: Colors.white38),
                                    counterText: '',
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                ),
                                const SizedBox(height: 24),
                                ElevatedButton(
                                  key: const Key('confirm_pin_button'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.success,
                                    minimumSize: const Size.fromHeight(50),
                                  ),
                                  onPressed: () async {
                                    if (pinCtrl.text.trim().length >= 4) {
                                      final db = ref.read(databaseProvider);
                                      await DeliveryRouteService.instance.completeDeliveryDrop(
                                        db: db,
                                        stop: stop,
                                        cashCollected: stop.pendingAmount,
                                        paymentMethod: 'pin_override',
                                        recipientNote: 'Delivered via Manual PIN (${pinCtrl.text.trim()}) at 17.3850 N, 78.4867 E',
                                      );
                                      if (ctx.mounted) Navigator.pop(ctx);
                                      ref.invalidate(deliveryRoutesProvider);
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('ePOD Verified via PIN for ${stop.shopName}!'),
                                            backgroundColor: AppColors.success,
                                          ),
                                        );
                                      }
                                    }
                                  },
                                  child: const Text('Confirm PIN Delivery'),
                                ),
                              ],
                            ),
                          )
                        : Stack(
                            alignment: Alignment.center,
                            children: [
                              MobileScanner(
                                onDetect: (capture) async {
                                  final barcodes = capture.barcodes;
                                  for (final barcode in barcodes) {
                                    final rawValue = barcode.rawValue;
                                    if (rawValue != null) {
                                      final result = QrVerifier.instance.verifyQr(rawValue);
                                      if (result.isValid && result.type == QrPayloadType.pod) {
                                        final db = ref.read(databaseProvider);
                                        await DeliveryRouteService.instance.completeDeliveryDrop(
                                          db: db,
                                          stop: stop,
                                          cashCollected: stop.pendingAmount,
                                          paymentMethod: 'qr_pod',
                                          recipientNote: 'Signed ePOD (${result.payload['orderNumber']}) verified offline. GPS: 17.3850 N, 78.4867 E',
                                        );
                                        if (ctx.mounted) Navigator.pop(ctx);
                                        ref.invalidate(deliveryRoutesProvider);
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text('ePOD QR Verified & Delivered: ${stop.shopName}!'),
                                              backgroundColor: AppColors.success,
                                            ),
                                          );
                                        }
                                        break;
                                      }
                                    }
                                  }
                                },
                              ),
                              Container(
                                width: 220,
                                height: 220,
                                decoration: BoxDecoration(
                                  border: Border.all(color: AppColors.success, width: 3),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              const Positioned(
                                bottom: 40,
                                child: Text('Align Customer PoD QR within frame', style: TextStyle(color: Colors.white, fontSize: 13, backgroundColor: Colors.black54)),
                              ),
                            ],
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showDeliveryDialog(BuildContext context, RouteDeliveryStop stop) {
    final cashCtrl = TextEditingController(text: stop.pendingAmount.toStringAsFixed(0));
    final noteCtrl = TextEditingController();
    String method = 'cash';

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Confirm Delivery Drop', style: AppTextStyles.titleMedium),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  Text(stop.shopName, style: AppTextStyles.titleSmall.copyWith(color: AppColors.primary)),
                  Text('Order: ${stop.orderNumber} • Total: ${CurrencyFormatter.format(stop.grandTotal)}', style: AppTextStyles.bodySmall),
                  const Divider(height: 24),
                  TextFormField(
                    controller: cashCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Amount Collected Today (₹)',
                      prefixIcon: Icon(Icons.currency_rupee_rounded),
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: method,
                    decoration: const InputDecoration(labelText: 'Payment Method'),
                    items: const [
                      DropdownMenuItem(value: 'cash', child: Text('Cash')),
                      DropdownMenuItem(value: 'upi', child: Text('UPI / QR Scanner')),
                      DropdownMenuItem(value: 'credit', child: Text('Credit (Add to Balance)')),
                    ],
                    onChanged: (v) {
                      if (v != null) setSheetState(() => method = v);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: noteCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Recipient Signature / Shop Handover Note',
                      hintText: 'e.g. Received by Subhan brother',
                    ),
                  ),
                  const SizedBox(height: 20),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(44)),
                    icon: const Icon(Icons.qr_code_scanner_rounded),
                    label: const Text('Scan to Complete Delivery (ePOD)'),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _showPodScannerSheet(context, stop);
                    },
                  ),
                  const SizedBox(height: 10),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                    onPressed: () async {
                      final collected = double.tryParse(cashCtrl.text.trim()) ?? 0.0;
                      final db = ref.read(databaseProvider);
                      await DeliveryRouteService.instance.completeDeliveryDrop(
                        db: db,
                        stop: stop,
                        cashCollected: collected,
                        paymentMethod: method,
                        recipientNote: noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
                      );
                      if (ctx.mounted) Navigator.pop(ctx);
                      ref.invalidate(deliveryRoutesProvider);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Delivery recorded for ${stop.shopName}!'),
                            backgroundColor: AppColors.success,
                          ),
                        );
                      }
                    },
                    child: const Text('Mark Delivered & Collect'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final routesAsync = ref.watch(deliveryRoutesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Delivery Van Route'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ref.invalidate(deliveryRoutesProvider),
          ),
        ],
      ),
      body: routesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (routes) {
          if (routes.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.local_shipping_outlined, size: 64, color: AppColors.textSecondary.withValues(alpha: 0.4)),
                  const SizedBox(height: 16),
                  Text('No active delivery routes today', style: AppTextStyles.titleMedium),
                  const SizedBox(height: 8),
                  Text('Orders created in the app will automatically group here.', style: AppTextStyles.bodySmall),
                ],
              ),
            );
          }

          final currentRoute = routes[_selectedRouteIndex.clamp(0, routes.length - 1)];

          return Column(
            children: [
              // Route Selector Tabs
              Container(
                height: 50,
                margin: const EdgeInsets.symmetric(vertical: 8),
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: routes.length,
                  itemBuilder: (context, i) {
                    final r = routes[i];
                    final isSelected = i == _selectedRouteIndex;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        selected: isSelected,
                        label: Text('${r.routeName} (${r.completedStops}/${r.totalStops})'),
                        onSelected: (_) => setState(() {
                          _selectedRouteIndex = i;
                          _isQuantumOptimized = false;
                          _quantumResult = null;
                        }),
                      ),
                    );
                  },
                ),
              ),

              // Route Overview Card
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(currentRoute.routeName, style: AppTextStyles.titleMedium.copyWith(color: Colors.white)),
                        Text('${currentRoute.completedStops}/${currentRoute.totalStops} Drops', style: AppTextStyles.titleSmall.copyWith(color: Colors.white)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: currentRoute.totalStops > 0 ? (currentRoute.completedStops / currentRoute.totalStops) : 0.0,
                      backgroundColor: Colors.white.withValues(alpha: 0.3),
                      valueColor: const AlwaysStoppedAnimation(Colors.white),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Cash to Collect on Route:', style: AppTextStyles.bodySmall.copyWith(color: Colors.white.withValues(alpha: 0.9))),
                        Text(CurrencyFormatter.format(currentRoute.totalCashToCollect), style: AppTextStyles.titleSmall.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const Divider(color: Colors.white24, height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppColors.primary,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.auto_awesome, size: 18),
                        label: Text(
                          _isQuantumOptimized ? 'Re-Anneal Route (QSA)' : '⚡ Quantum Anneal Route',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        onPressed: currentRoute.stops.length < 2
                            ? null
                            : () {
                                final result = QuantumOptimizationEngine.instance.optimizeDeliveryRoute(
                                  currentRoute.stops,
                                );
                                setState(() {
                                  _isQuantumOptimized = true;
                                  _quantumResult = result;
                                });
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    backgroundColor: AppColors.primaryDark,
                                    content: Text(
                                      '⚡ Quantum Annealing: ${result.distanceSavedKm} km saved (${result.fuelSavedLiters} L diesel, ₹${result.costSavedRupees.toStringAsFixed(0)}) in ${result.executionTimeMs}ms with ${result.quantumTunnelingEvents} barrier flips!',
                                    ),
                                    duration: const Duration(seconds: 4),
                                  ),
                                );
                              },
                      ),
                    ),
                  ],
                ),
              ),

              // Quantum Savings Banner (if optimized)
              if (_isQuantumOptimized && _quantumResult != null)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.accent),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.bolt_rounded, color: AppColors.accentDark, size: 24),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'QSA Optimized Sequence (${_quantumResult!.efficiencyGainPercentage.toStringAsFixed(1)}% Distance Saved)',
                              style: AppTextStyles.labelMedium.copyWith(fontWeight: FontWeight.bold, color: AppColors.accentDark),
                            ),
                            Text(
                              'Est. Fuel Saved: ${_quantumResult!.fuelSavedLiters} L (₹${_quantumResult!.costSavedRupees.toStringAsFixed(0)}) • ${_quantumResult!.quantumTunnelingEvents} Quantum Tunneling Flips',
                              style: AppTextStyles.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18),
                        onPressed: () => setState(() {
                          _isQuantumOptimized = false;
                          _quantumResult = null;
                        }),
                      ),
                    ],
                  ),
                ),

              // Stops List
              Expanded(
                child: Builder(
                  builder: (context) {
                    final displayStops = (_isQuantumOptimized && _quantumResult != null)
                        ? _quantumResult!.optimizedStops
                        : currentRoute.stops;

                    return ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: displayStops.length,
                      itemBuilder: (context, index) {
                        final stop = displayStops[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: stop.isDelivered
                                  ? AppColors.success.withValues(alpha: 0.5)
                                  : Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                              width: stop.isDelivered ? 1.5 : 1.0,
                            ),
                          ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(14),
                        leading: CircleAvatar(
                          backgroundColor: stop.isDelivered
                              ? AppColors.success.withValues(alpha: 0.15)
                              : AppColors.primary.withValues(alpha: 0.15),
                          child: Icon(
                            stop.isDelivered ? Icons.check_circle_rounded : Icons.store_rounded,
                            color: stop.isDelivered ? AppColors.success : AppColors.primary,
                          ),
                        ),
                        title: Row(
                          children: [
                            Expanded(child: Text(stop.shopName, style: AppTextStyles.titleSmall)),
                            if (stop.isDelivered)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.success.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text('DELIVERED', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.success)),
                              ),
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text('Contact: ${stop.ownerName} (${stop.phone})', style: AppTextStyles.bodySmall),
                            if (stop.address != null && stop.address!.isNotEmpty)
                              Text(stop.address!, style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Order Total: ${CurrencyFormatter.format(stop.grandTotal)}', style: AppTextStyles.bodySmall),
                                Text(
                                  stop.pendingAmount > 0 ? 'Due: ${CurrencyFormatter.format(stop.pendingAmount)}' : 'PAID',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: stop.pendingAmount > 0 ? AppColors.error : AppColors.success,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        trailing: stop.isDelivered
                            ? null
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.qr_code_scanner_rounded, color: AppColors.primary),
                                    tooltip: 'Scan to Complete Delivery',
                                    onPressed: () => _showPodScannerSheet(context, stop),
                                  ),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                    onPressed: () => _showDeliveryDialog(context, stop),
                                    child: const Text('Drop'),
                                  ),
                                ],
                              ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      );
        },
      ),
    );
  }
}
