import 'package:flutter_test/flutter_test.dart';
import 'package:sr_foods/core/events/domain_event.dart';
import 'package:sr_foods/core/events/event_bus.dart';

void main() {
  late EventBus eventBus;

  setUp(() {
    eventBus = EventBus();
    eventBus.reset();
  });

  tearDown(() {
    eventBus.reset();
  });

  group('Domain EventBus Architecture Tests', () {
    test('1. publish notifies sync subscriber of exact matching event type', () {
      OrderPlacedEvent? capturedEvent;
      eventBus.subscribe<OrderPlacedEvent>((event) {
        capturedEvent = event;
      });

      final event = OrderPlacedEvent(
        orderId: 101,
        customerId: 5,
        totalAmountMinor: 450000,
        vertical: 'dairy',
      );
      eventBus.publish(event);

      expect(capturedEvent, isNotNull);
      expect(capturedEvent!.orderId, equals(101));
      expect(capturedEvent!.customerId, equals(5));
      expect(capturedEvent!.totalAmountMinor, equals(450000));
      expect(capturedEvent!.vertical, equals('dairy'));
    });

    test('2. publish enforces type isolation: unrelated subscribers are not notified', () {
      int milkEventsCount = 0;
      eventBus.subscribe<MilkCollectedEvent>((event) {
        milkEventsCount++;
      });

      // Publish OrderPlacedEvent instead
      eventBus.publish(
        OrderPlacedEvent(orderId: 102, customerId: 3, totalAmountMinor: 100000),
      );

      expect(milkEventsCount, equals(0));
    });

    test('3. subscribing to base DomainEvent captures all polymorphic event subtypes', () {
      final capturedTypes = <String>[];
      eventBus.subscribe<DomainEvent>((event) {
        capturedTypes.add(event.eventType);
      });

      eventBus.publish(OrderPlacedEvent(orderId: 1, customerId: 1, totalAmountMinor: 1000));
      eventBus.publish(MilkCollectedEvent(
        supplierId: 'SUP-01',
        quantityLiters: 50.0,
        fatPercent: 4.2,
        snfPercent: 8.5,
        totalAmountMinor: 200000,
      ));
      eventBus.publish(ContainerIssuedEvent(
        containerCode: 'CR-01',
        customerId: 1,
        depositAmountMinor: 15000,
      ));

      expect(capturedTypes, equals(['OrderPlaced', 'MilkCollected', 'ContainerIssued']));
    });

    test('4. Unsubscribe callback cancels future notifications', () {
      int callCount = 0;
      final unsubscribe = eventBus.subscribe<OrderDeliveredEvent>((event) {
        callCount++;
      });

      eventBus.publish(OrderDeliveredEvent(orderId: 501));
      expect(callCount, equals(1));

      // Unsubscribe
      unsubscribe();

      eventBus.publish(OrderDeliveredEvent(orderId: 502));
      expect(callCount, equals(1)); // Has not incremented
    });

    test('5. on<T>() reactive stream receives published events asynchronously', () async {
      final eventsFuture = eventBus.on<ColdChainBreachDetectedEvent>().take(2).toList();

      eventBus.publish(ColdChainBreachDetectedEvent(
        sensorId: 'TEMP-01',
        temperatureC: 6.2,
        thresholdC: 4.0,
        location: 'Chilled Vault 1',
      ));
      eventBus.publish(ColdChainBreachDetectedEvent(
        sensorId: 'TEMP-02',
        temperatureC: 7.5,
        thresholdC: 4.0,
        location: 'Reefer Van 4',
      ));

      final events = await eventsFuture;
      expect(events.length, equals(2));
      expect(events[0].sensorId, equals('TEMP-01'));
      expect(events[1].sensorId, equals('TEMP-02'));
    });

    test('6. Fault tolerance: one throwing subscriber does not break others', () {
      bool secondSubscriberRan = false;

      // Subscriber 1 throws
      eventBus.subscribe<ContainerReturnedEvent>((event) {
        throw Exception('Boom! Processing error in subscriber 1');
      });

      // Subscriber 2 should still run
      eventBus.subscribe<ContainerReturnedEvent>((event) {
        secondSubscriberRan = true;
      });

      eventBus.publish(ContainerReturnedEvent(containerCode: 'CAN-01'));
      expect(secondSubscriberRan, isTrue);
    });

    test('7. eventLog maintains ordered history and reset() wipes state', () {
      expect(eventBus.eventCount, equals(0));

      eventBus.publish(OrderPlacedEvent(orderId: 1, customerId: 1, totalAmountMinor: 100));
      eventBus.publish(OrderDeliveredEvent(orderId: 1));

      expect(eventBus.eventCount, equals(2));
      expect(eventBus.eventLog.first.eventType, equals('OrderPlaced'));
      expect(eventBus.eventLog.last.eventType, equals('OrderDelivered'));

      eventBus.reset();
      expect(eventBus.eventCount, equals(0));
      expect(eventBus.eventLog.isEmpty, isTrue);
    });

    test('8. OrderPlacedEvent & OrderDeliveredEvent serialize to Map properly', () {
      final placed = OrderPlacedEvent(
        orderId: 88,
        customerId: 12,
        totalAmountMinor: 250000,
        vertical: 'bakery',
      );
      final placedMap = placed.toMap();
      expect(placedMap['orderId'], equals(88));
      expect(placedMap['customerId'], equals(12));
      expect(placedMap['totalAmountMinor'], equals(250000));
      expect(placedMap['vertical'], equals('bakery'));

      final delivered = OrderDeliveredEvent(orderId: 88, driverId: 3);
      final deliveredMap = delivered.toMap();
      expect(deliveredMap['orderId'], equals(88));
      expect(deliveredMap['driverId'], equals(3));
      expect(deliveredMap['deliveredAt'], isNotNull);
    });

    test('9. MilkCollectedEvent & ColdChainBreachDetectedEvent serialize to Map properly', () {
      final milk = MilkCollectedEvent(
        supplierId: 'VILL-FARM-09',
        quantityLiters: 120.5,
        fatPercent: 4.8,
        snfPercent: 8.6,
        totalAmountMinor: 580000,
      );
      final milkMap = milk.toMap();
      expect(milkMap['supplierId'], equals('VILL-FARM-09'));
      expect(milkMap['quantityLiters'], equals(120.5));
      expect(milkMap['fatPercent'], equals(4.8));

      final breach = ColdChainBreachDetectedEvent(
        sensorId: 'BLE-TAG-402',
        temperatureC: 8.2,
        thresholdC: 4.0,
        location: 'Bay 3 Loading',
        severity: 'critical',
      );
      final breachMap = breach.toMap();
      expect(breachMap['sensorId'], equals('BLE-TAG-402'));
      expect(breachMap['temperatureC'], equals(8.2));
      expect(breachMap['severity'], equals('critical'));
    });

    test('10. Container & Oven scheduling events serialize to Map properly', () {
      final issued = ContainerIssuedEvent(
        containerCode: 'CR-101',
        customerId: 4,
        depositAmountMinor: 15000,
      );
      expect(issued.toMap()['containerCode'], equals('CR-101'));

      final returned = ContainerReturnedEvent(containerCode: 'CR-101', condition: 'damaged');
      expect(returned.toMap()['condition'], equals('damaged'));

      final start = DateTime(2026, 11, 20, 8, 0);
      final end = DateTime(2026, 11, 20, 9, 0);
      final oven = OvenScheduledEvent(
        scheduleId: 5,
        ovenId: 'OVEN-ROTARY-1',
        productId: 141,
        quantity: 50,
        scheduledStart: start,
        scheduledEnd: end,
      );
      final ovenMap = oven.toMap();
      expect(ovenMap['ovenId'], equals('OVEN-ROTARY-1'));
      expect(ovenMap['quantity'], equals(50));
      expect(ovenMap['scheduledStart'], equals(start.toIso8601String()));
    });
  });
}
