/// Base contract for all Domain Events in SR Foods enterprise architecture
abstract class DomainEvent {
  final String eventId;
  final DateTime occurredAt;
  final String eventType;

  DomainEvent({
    String? eventId,
    DateTime? occurredAt,
    required this.eventType,
  })  : eventId = eventId ?? DateTime.now().microsecondsSinceEpoch.toString(),
        occurredAt = occurredAt ?? DateTime.now();

  Map<String, dynamic> toMap();

  @override
  String toString() => '$eventType($eventId @ ${occurredAt.toIso8601String()})';
}

/// Dispatched when a new customer sales order or custom cake order is placed
class OrderPlacedEvent extends DomainEvent {
  final int orderId;
  final int customerId;
  final int totalAmountMinor;
  final String vertical;

  OrderPlacedEvent({
    super.eventId,
    super.occurredAt,
    required this.orderId,
    required this.customerId,
    required this.totalAmountMinor,
    this.vertical = 'frozen',
  }) : super(eventType: 'OrderPlaced');

  @override
  Map<String, dynamic> toMap() => {
        'orderId': orderId,
        'customerId': customerId,
        'totalAmountMinor': totalAmountMinor,
        'vertical': vertical,
      };
}

/// Dispatched when an order is completed and delivered to customer
class OrderDeliveredEvent extends DomainEvent {
  final int orderId;
  final int? driverId;
  final DateTime deliveredAt;

  OrderDeliveredEvent({
    super.eventId,
    super.occurredAt,
    required this.orderId,
    this.driverId,
    DateTime? deliveredAt,
  })  : deliveredAt = deliveredAt ?? DateTime.now(),
        super(eventType: 'OrderDelivered');

  @override
  Map<String, dynamic> toMap() => {
        'orderId': orderId,
        'driverId': driverId,
        'deliveredAt': deliveredAt.toIso8601String(),
      };
}

/// Dispatched when raw milk is collected from a dairy farmer or chilling center
class MilkCollectedEvent extends DomainEvent {
  final String supplierId;
  final double quantityLiters;
  final double fatPercent;
  final double snfPercent;
  final int totalAmountMinor;

  MilkCollectedEvent({
    super.eventId,
    super.occurredAt,
    required this.supplierId,
    required this.quantityLiters,
    required this.fatPercent,
    required this.snfPercent,
    required this.totalAmountMinor,
  }) : super(eventType: 'MilkCollected');

  @override
  Map<String, dynamic> toMap() => {
        'supplierId': supplierId,
        'quantityLiters': quantityLiters,
        'fatPercent': fatPercent,
        'snfPercent': snfPercent,
        'totalAmountMinor': totalAmountMinor,
      };
}

/// Dispatched when cold chain telemetry detects temperature above compliance threshold
class ColdChainBreachDetectedEvent extends DomainEvent {
  final String sensorId;
  final double temperatureC;
  final double thresholdC;
  final String location;
  final String severity; // warning, critical

  ColdChainBreachDetectedEvent({
    super.eventId,
    super.occurredAt,
    required this.sensorId,
    required this.temperatureC,
    required this.thresholdC,
    required this.location,
    this.severity = 'critical',
  }) : super(eventType: 'ColdChainBreachDetected');

  @override
  Map<String, dynamic> toMap() => {
        'sensorId': sensorId,
        'temperatureC': temperatureC,
        'thresholdC': thresholdC,
        'location': location,
        'severity': severity,
      };
}

/// Dispatched when a returnable crate or can is issued to a customer
class ContainerIssuedEvent extends DomainEvent {
  final String containerCode;
  final int customerId;
  final int depositAmountMinor;
  final String containerType;

  ContainerIssuedEvent({
    super.eventId,
    super.occurredAt,
    required this.containerCode,
    required this.customerId,
    required this.depositAmountMinor,
    this.containerType = 'crate',
  }) : super(eventType: 'ContainerIssued');

  @override
  Map<String, dynamic> toMap() => {
        'containerCode': containerCode,
        'customerId': customerId,
        'depositAmountMinor': depositAmountMinor,
        'containerType': containerType,
      };
}

/// Dispatched when a returnable container is received back in warehouse or by driver
class ContainerReturnedEvent extends DomainEvent {
  final String containerCode;
  final int? driverId;
  final String condition; // good, damaged

  ContainerReturnedEvent({
    super.eventId,
    super.occurredAt,
    required this.containerCode,
    this.driverId,
    this.condition = 'good',
  }) : super(eventType: 'ContainerReturned');

  @override
  Map<String, dynamic> toMap() => {
        'containerCode': containerCode,
        'driverId': driverId,
        'condition': condition,
      };
}

/// Dispatched when a baking batch is locked into an oven time slot
class OvenScheduledEvent extends DomainEvent {
  final int scheduleId;
  final String ovenId;
  final int productId;
  final int quantity;
  final DateTime scheduledStart;
  final DateTime scheduledEnd;

  OvenScheduledEvent({
    super.eventId,
    super.occurredAt,
    required this.scheduleId,
    required this.ovenId,
    required this.productId,
    required this.quantity,
    required this.scheduledStart,
    required this.scheduledEnd,
  }) : super(eventType: 'OvenScheduled');

  @override
  Map<String, dynamic> toMap() => {
        'scheduleId': scheduleId,
        'ovenId': ovenId,
        'productId': productId,
        'quantity': quantity,
        'scheduledStart': scheduledStart.toIso8601String(),
        'scheduledEnd': scheduledEnd.toIso8601String(),
      };
}
