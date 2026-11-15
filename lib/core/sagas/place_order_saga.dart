import '../patterns/result.dart';
import 'saga.dart';

class OrderPlacementContext extends SagaContext {
  final String orderId;
  final String customerId;
  final double amount;
  bool inventoryReserved = false;
  bool paymentAuthorized = false;
  bool notificationDispatched = false;

  OrderPlacementContext({
    required this.orderId,
    required this.customerId,
    required this.amount,
  });
}

class ReserveInventoryStep extends SagaStep<OrderPlacementContext> {
  final bool shouldFail;
  ReserveInventoryStep({this.shouldFail = false});

  @override
  String get name => 'ReserveInventoryStep';

  @override
  Future<Result<void, Object>> execute(OrderPlacementContext context) async {
    if (shouldFail) {
      return Result.err(Exception('Insufficient stock for order ${context.orderId}'));
    }
    context.inventoryReserved = true;
    return const Result.ok(null);
  }

  @override
  Future<Result<void, Object>> compensate(OrderPlacementContext context) async {
    context.inventoryReserved = false;
    return const Result.ok(null);
  }
}

class AuthorizePaymentStep extends SagaStep<OrderPlacementContext> {
  final bool shouldFail;
  AuthorizePaymentStep({this.shouldFail = false});

  @override
  String get name => 'AuthorizePaymentStep';

  @override
  Future<Result<void, Object>> execute(OrderPlacementContext context) async {
    if (shouldFail) {
      return Result.err(Exception('Card declined or credit exceeded for ${context.customerId}'));
    }
    context.paymentAuthorized = true;
    return const Result.ok(null);
  }

  @override
  Future<Result<void, Object>> compensate(OrderPlacementContext context) async {
    context.paymentAuthorized = false;
    return const Result.ok(null);
  }
}

class DispatchOrderStep extends SagaStep<OrderPlacementContext> {
  final bool shouldFail;
  DispatchOrderStep({this.shouldFail = false});

  @override
  String get name => 'DispatchOrderStep';

  @override
  Future<Result<void, Object>> execute(OrderPlacementContext context) async {
    if (shouldFail) {
      return Result.err(Exception('Logistics hub allocation failed'));
    }
    context.notificationDispatched = true;
    return const Result.ok(null);
  }

  @override
  Future<Result<void, Object>> compensate(OrderPlacementContext context) async {
    context.notificationDispatched = false;
    return const Result.ok(null);
  }
}
