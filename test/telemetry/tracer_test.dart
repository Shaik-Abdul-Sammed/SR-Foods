import 'package:flutter_test/flutter_test.dart';
import 'package:sr_foods/core/telemetry/tracer.dart';

void main() {
  setUp(() {
    Tracer.instance.clearForTesting();
  });

  group('Tracer & Telemetry Tests', () {
    test('1. Start root span creates unique traceId and spanId', () {
      final span = Tracer.instance.startSpan('root_request');
      expect(span.context.traceId.length, 32);
      expect(span.context.spanId.length, 16);
      expect(span.context.parentSpanId, isNull);
    });

    test('2. Child span inherits parent traceId and sets parentSpanId', () {
      final root = Tracer.instance.startSpan('db_transaction');
      final child = Tracer.instance.startSpan('select_customers', parentContext: root.context);

      expect(child.context.traceId, root.context.traceId);
      expect(child.context.parentSpanId, root.context.spanId);
      expect(child.context.spanId, isNot(root.context.spanId));
    });

    test('3. Span records tags, events, status and duration correctly', () async {
      final span = Tracer.instance.startSpan('compute_invoice', initialTags: {'orderId': 'ORD-1'});
      span.setTag('amount', 500.0);
      span.addEvent('tax_applied', {'cgst': 25.0, 'sgst': 25.0});

      await Future<void>.delayed(const Duration(milliseconds: 20));
      Tracer.instance.finishSpan(span, status: SpanStatus.ok);

      expect(span.duration.inMilliseconds, greaterThanOrEqualTo(10));
      expect(span.tags['orderId'], 'ORD-1');
      expect(span.tags['amount'], 500.0);
      expect(span.events.length, 1);
      expect(span.events.first['name'], 'tax_applied');
      expect(span.status, SpanStatus.ok);
    });

    test('4. Baggage is propagated down the span hierarchy', () {
      final rootCtx = TraceContext(
        traceId: 'trace-123',
        spanId: 'span-001',
        baggage: {'userId': 'usr_42', 'tenant': 'hyderabad_dairy'},
      );

      final child = Tracer.instance.startSpan('process_milk', parentContext: rootCtx);
      expect(child.context.baggage['userId'], 'usr_42');
      expect(child.context.baggage['tenant'], 'hyderabad_dairy');
    });

    test('5. Tracer maintains ring buffer of finished spans and clear works', () {
      for (int i = 0; i < 10; i++) {
        final s = Tracer.instance.startSpan('job_$i');
        Tracer.instance.finishSpan(s);
      }
      expect(Tracer.instance.finishedSpans.length, 10);

      Tracer.instance.clearForTesting();
      expect(Tracer.instance.finishedSpans, isEmpty);
    });
  });
}
