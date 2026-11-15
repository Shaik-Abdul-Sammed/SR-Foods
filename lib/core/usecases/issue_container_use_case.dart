import '../database/app_database.dart';
import '../patterns/result.dart';
import '../patterns/use_case.dart';
import '../services/container_return_service.dart';

class IssueContainerParams {
  final AppDatabase db;
  final String containerCode;
  final int customerId;
  final int depositAmountMinor;
  final String containerType;
  final String? notes;

  const IssueContainerParams({
    required this.db,
    required this.containerCode,
    required this.customerId,
    required this.depositAmountMinor,
    this.containerType = 'crate',
    this.notes,
  });
}

class IssueContainerUseCase implements UseCase<IssueContainerParams, bool> {
  final ContainerReturnService service;

  const IssueContainerUseCase({this.service = const ContainerReturnService()});

  @override
  Future<Result<bool, Object>> call(IssueContainerParams params) async {
    if (params.containerCode.trim().isEmpty) {
      return Result.err(ArgumentError('Container code cannot be empty.'));
    }
    if (params.depositAmountMinor < 0) {
      return Result.err(ArgumentError('Deposit amount cannot be negative.'));
    }

    try {
      await service.issueContainer(
        db: params.db,
        containerCode: params.containerCode,
        customerId: params.customerId,
        depositAmountMinor: params.depositAmountMinor,
        containerType: params.containerType,
        notes: params.notes,
      );
      return const Result.ok(true);
    } catch (e) {
      return Result.err(e);
    }
  }
}
