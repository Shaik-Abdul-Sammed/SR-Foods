import 'dart:math';

/// A lightweight distributed tracing and structured telemetry module.
class TraceContext {
  final String traceId;
  final String spanId;
  final String? parentSpanId;
  final Map<String, String> baggage;

  const TraceContext({
    required this.traceId,
    required this.spanId,
    this.parentSpanId,
    this.baggage = const {},
  });

  TraceContext copyWith({
    String? traceId,
    String? spanId,
    String? parentSpanId,
    Map<String, String>? baggage,
  }) {
    return TraceContext(
      traceId: traceId ?? this.traceId,
      spanId: spanId ?? this.spanId,
      parentSpanId: parentSpanId ?? this.parentSpanId,
      baggage: baggage ?? Map.unmodifiable(this.baggage),
    );
  }

  static String generateId([int length = 16]) {
    final rand = Random.secure();
    final chars = '0123456789abcdef';
    return List.generate(length, (_) => chars[rand.nextInt(chars.length)]).join();
  }
}

enum SpanStatus { ok, error }

class Span {
  final String name;
  final TraceContext context;
  final DateTime startTime;
  DateTime? endTime;
  SpanStatus status = SpanStatus.ok;
  final Map<String, Object> tags = {};
  final List<Map<String, Object>> events = [];

  Span({
    required this.name,
    required this.context,
    required this.startTime,
  });

  Duration get duration {
    final finish = endTime ?? DateTime.now();
    return finish.difference(startTime);
  }

  void setTag(String key, Object value) {
    tags[key] = value;
  }

  void addEvent(String name, [Map<String, Object>? attributes]) {
    events.add({
      'name': name,
      'timestamp': DateTime.now().toIso8601String(),
      ...?attributes,
    });
  }

  void finish({SpanStatus? status}) {
    endTime = DateTime.now();
    if (status != null) {
      this.status = status;
    }
  }
}

class Tracer {
  static final Tracer instance = Tracer._internal();
  Tracer._internal();

  final List<Span> _finishedSpans = [];

  List<Span> get finishedSpans => List.unmodifiable(_finishedSpans);

  Span startSpan(String name, {TraceContext? parentContext, Map<String, Object>? initialTags}) {
    final traceId = parentContext?.traceId ?? TraceContext.generateId(32);
    final parentSpanId = parentContext?.spanId;
    final spanId = TraceContext.generateId(16);

    final context = TraceContext(
      traceId: traceId,
      spanId: spanId,
      parentSpanId: parentSpanId,
      baggage: parentContext?.baggage ?? const {},
    );

    final span = Span(
      name: name,
      context: context,
      startTime: DateTime.now(),
    );

    if (initialTags != null) {
      initialTags.forEach((k, v) => span.setTag(k, v));
    }

    return span;
  }

  void finishSpan(Span span, {SpanStatus? status}) {
    span.finish(status: status);
    _finishedSpans.add(span);
    if (_finishedSpans.length > 500) {
      _finishedSpans.removeAt(0);
    }
  }

  void clearForTesting() {
    _finishedSpans.clear();
  }
}
