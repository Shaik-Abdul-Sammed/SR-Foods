import '../database/app_database.dart';
import '../patterns/result.dart';
import '../patterns/use_case.dart';
import '../services/bakery_scheduling_service.dart';

class ScheduleBakeryBatchParams {
  final AppDatabase db;
  final int productId;
  final int quantity;
  final DateTime deliveryDate;
  final String ovenId;
  final String ovenType;
  final int proofingMinutes;
  final int bakingMinutes;
  final int coolingMinutes;
  final int? batchId;
  final String? notes;

  const ScheduleBakeryBatchParams({
    required this.db,
    required this.productId,
    required this.quantity,
    required this.deliveryDate,
    this.ovenId = 'OVEN-01',
    this.ovenType = 'rotary',
    this.proofingMinutes = 45,
    this.bakingMinutes = 35,
    this.coolingMinutes = 60,
    this.batchId,
    this.notes,
  });
}

class ScheduleBakeryBatchUseCase implements UseCase<ScheduleBakeryBatchParams, OvenScheduleResult> {
  final BakerySchedulingService service;

  const ScheduleBakeryBatchUseCase({this.service = const BakerySchedulingService()});

  @override
  Future<Result<OvenScheduleResult, Object>> call(ScheduleBakeryBatchParams params) async {
    if (params.quantity <= 0) {
      return Result.err(ArgumentError('Batch bake quantity must be > 0: ${params.quantity}'));
    }

    try {
      final schedule = await service.scheduleBatch(
        db: params.db,
        productId: params.productId,
        quantity: params.quantity,
        deliveryDate: params.deliveryDate,
        ovenId: params.ovenId,
        ovenType: params.ovenType,
        proofingMinutes: params.proofingMinutes,
        bakingMinutes: params.bakingMinutes,
        coolingMinutes: params.coolingMinutes,
        batchId: params.batchId,
        notes: params.notes,
      );
      return Result.ok(schedule);
    } catch (e) {
      return Result.err(e);
    }
  }
}
