import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/communication_utils.dart';

enum OrderStage {
  mixing('Dough Mixing & Proofing', '04:00 AM', true),
  pressing('Parota Pressing & Griddle', '04:45 AM', true),
  packing('Blast Freezing & Packing', '05:20 AM', true),
  dispatch('Reefer Van Dispatched', '05:45 AM', false),
  delivered('Kitchen Drop Completed', '06:15 AM (Est)', false);

  final String title;
  final String timestamp;
  final bool isCompleted;
  const OrderStage(this.title, this.timestamp, this.isCompleted);
}

class DispatchLiveTrackerCard extends StatelessWidget {
  final String orderNumber;
  final String hotelName;
  final String driverName;
  final String driverPhone;
  final String vehicleNumber;
  final double reeferTemperature;
  final VoidCallback? onReorderTap;

  const DispatchLiveTrackerCard({
    super.key,
    required this.orderNumber,
    required this.hotelName,
    this.driverName = 'Ramesh Goud',
    this.driverPhone = '9440067933',
    this.vehicleNumber = 'TS 09 UA 4501 (Reefer Van)',
    this.reeferTemperature = -18.4,
    this.onReorderTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'LIVE DISPATCH RADAR',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primary, letterSpacing: 0.5),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    orderNumber,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.ac_unit, size: 14, color: Colors.blue),
                    const SizedBox(width: 4),
                    Text(
                      '${reeferTemperature.toStringAsFixed(1)}°C [Cold Chain OK]',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blue.shade900),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Milestone Timeline
          _buildMilestone(OrderStage.mixing, isFirst: true, isDone: true),
          _buildMilestone(OrderStage.pressing, isDone: true),
          _buildMilestone(OrderStage.packing, isDone: true),
          _buildMilestone(OrderStage.dispatch, isCurrent: true),
          _buildMilestone(OrderStage.delivered, isLast: true),

          const SizedBox(height: 14),

          // Driver Contact & Vehicle Bar
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 16,
                  backgroundColor: AppColors.primary,
                  child: Icon(Icons.local_shipping, size: 16, color: Colors.white),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$driverName • $vehicleNumber',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                      const Text(
                        'Estimated Drop: 06:15 AM (Kitchen Backdoor)',
                        style: TextStyle(fontSize: 10, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.phone, color: AppColors.primary, size: 20),
                  onPressed: () => CommunicationUtils.launchPhone(context, driverPhone),
                  tooltip: 'Call Van Driver',
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // 10-Second Quick Reorder Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onReorderTap,
              icon: const Icon(Icons.replay_rounded, size: 16),
              label: const Text('10-Sec Quick Reorder for Tomorrow', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMilestone(OrderStage stage, {bool isFirst = false, bool isLast = false, bool isDone = false, bool isCurrent = false}) {
    Color nodeColor = Colors.grey.shade300;
    if (isDone) nodeColor = Colors.green;
    if (isCurrent) nodeColor = AppColors.primary;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: nodeColor,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 22,
                color: isDone ? Colors.green : Colors.grey.shade300,
              ),
          ],
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                stage.title,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isCurrent || isDone ? FontWeight.bold : FontWeight.normal,
                  color: isCurrent ? AppColors.primary : (isDone ? Colors.black87 : Colors.grey.shade500),
                ),
              ),
              Text(
                stage.timestamp,
                style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
