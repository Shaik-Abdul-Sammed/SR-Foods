import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

enum ExportMilestone {
  orderConfirmed('Order Confirmed'),
  packingCompleted('Packing & Reefer Staging'),
  customsCleared('Customs Cleared (ICEGATE)'),
  blIssued('Bill of Lading Issued'),
  onVessel('On Vessel / In Transit'),
  portArrival('Port of Discharge Arrival'),
  delivered('Delivered to Distributor');

  final String label;
  const ExportMilestone(this.label);
}

class ExportShipmentTrackerCard extends StatelessWidget {
  final String orderNumber;
  final String containerNumber;
  final String sealNumber;
  final String? vesselName;
  final String? voyageNumber;
  final String portOfLoading;
  final String portOfDischarge;
  final double targetTemperatureCelsius;
  final double? actualTemperatureCelsius;
  final ExportMilestone currentMilestone;
  final DateTime? etd;
  final DateTime? eta;

  const ExportShipmentTrackerCard({
    super.key,
    required this.orderNumber,
    required this.containerNumber,
    required this.sealNumber,
    this.vesselName,
    this.voyageNumber,
    required this.portOfLoading,
    required this.portOfDischarge,
    this.targetTemperatureCelsius = -18.0,
    this.actualTemperatureCelsius,
    required this.currentMilestone,
    this.etd,
    this.eta,
  });

  bool get isTemperatureBreached {
    if (actualTemperatureCelsius == null) return false;
    // For frozen foods (-18C target), temperature warmer than -15C or variance > 3C is critical breach
    return actualTemperatureCelsius! > (targetTemperatureCelsius + 3.0);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final df = DateFormat('dd MMM yyyy');

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Container & Order Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CONTAINER: $containerNumber',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Order: $orderNumber | Seal: $sealNumber',
                      style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                    ),
                  ],
                ),
                _buildTemperatureBadge(context),
              ],
            ),

            // Temperature Breach Warning Box
            if (isTemperatureBreached) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red[400]!),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'TEMPERATURE BREACH DETECTED!',
                            style: TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            'Container sensor recorded ${actualTemperatureCelsius!.toStringAsFixed(1)}°C (Target: ${targetTemperatureCelsius.toStringAsFixed(1)}°C). Cold-chain integrity compromised.',
                            style: TextStyle(color: Colors.red[900], fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const Divider(height: 24),

            // Vessel & Ports Route
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('ORIGIN', style: TextStyle(fontSize: 10, color: Colors.grey[600], fontWeight: FontWeight.bold)),
                      Text(portOfLoading, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                      if (etd != null) Text('ETD: ${df.format(etd!)}', style: const TextStyle(fontSize: 11)),
                    ],
                  ),
                ),
                const Icon(Icons.directions_boat, color: Colors.indigo, size: 24),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('DESTINATION', style: TextStyle(fontSize: 10, color: Colors.grey[600], fontWeight: FontWeight.bold)),
                      Text(portOfDischarge, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12), textAlign: TextAlign.end),
                      if (eta != null) Text('ETA: ${df.format(eta!)}', style: const TextStyle(fontSize: 11)),
                    ],
                  ),
                ),
              ],
            ),

            if (vesselName != null) ...[
              const SizedBox(height: 6),
              Center(
                child: Text(
                  'Vessel: $vesselName ${voyageNumber != null ? "• Voyage: $voyageNumber" : ""}',
                  style: TextStyle(fontSize: 11, color: Colors.grey[700], fontStyle: FontStyle.italic),
                ),
              ),
            ],

            const SizedBox(height: 16),

            // Milestone Timeline
            Text(
              'SHIPMENT MILESTONES',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey[700], letterSpacing: 0.5),
            ),
            const SizedBox(height: 8),
            _buildMilestoneTimeline(context),
          ],
        ),
      ),
    );
  }

  Widget _buildTemperatureBadge(BuildContext context) {
    if (actualTemperatureCelsius == null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(6)),
        child: const Text('Sensor Pending', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
      );
    }

    final isBreach = isTemperatureBreached;
    final color = isBreach ? Colors.red : Colors.teal;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.ac_unit, color: color, size: 16),
          const SizedBox(width: 4),
          Text(
            '${actualTemperatureCelsius!.toStringAsFixed(1)}°C',
            style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildMilestoneTimeline(BuildContext context) {
    final milestones = ExportMilestone.values;
    final currentIndex = milestones.indexOf(currentMilestone);

    return Column(
      children: List.generate(milestones.length, (index) {
        final m = milestones[index];
        final isPassed = index < currentIndex;
        final isCurrent = index == currentIndex;

        Color dotColor = Colors.grey[300]!;
        IconData icon = Icons.circle;
        if (isPassed) {
          dotColor = Colors.teal;
          icon = Icons.check_circle;
        } else if (isCurrent) {
          dotColor = Colors.indigo;
          icon = Icons.radio_button_checked;
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Column(
              children: [
                Icon(icon, color: dotColor, size: 16),
                if (index < milestones.length - 1)
                  Container(
                    width: 2,
                    height: 16,
                    color: isPassed ? Colors.teal : Colors.grey[300],
                  ),
              ],
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                m.label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                  color: isCurrent
                      ? Colors.indigo[900]
                      : isPassed
                          ? Colors.black87
                          : Colors.grey[500],
                ),
              ),
            ),
          ],
        );
      }),
    );
  }
}
