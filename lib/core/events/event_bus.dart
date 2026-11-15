import 'dart:async';
import 'domain_event.dart';

/// Subscription token allowing clean unsubscription from the EventBus
typedef Unsubscribe = void Function();

/// In-memory synchronous & asynchronous enterprise EventBus with strong typing and subscriber isolation
class EventBus {
  static final EventBus _instance = EventBus._internal();
  factory EventBus() => _instance;
  EventBus._internal();

  final StreamController<DomainEvent> _controller = StreamController<DomainEvent>.broadcast();
  final List<DomainEvent> _eventLog = [];
  final Map<Type, List<void Function(DomainEvent)>> _syncListeners = {};

  /// Streams events matching type [T] or all DomainEvents if [T] is [DomainEvent]
  Stream<T> on<T extends DomainEvent>() {
    if (T == DomainEvent) {
      return _controller.stream.cast<T>();
    }
    return _controller.stream.where((event) => event is T).cast<T>();
  }

  /// Synchronously registers a listener callback for events of type [T]
  Unsubscribe subscribe<T extends DomainEvent>(void Function(T event) listener) {
    _syncListeners.putIfAbsent(T, () => []);
    void wrapper(DomainEvent event) {
      if (event is T) {
        listener(event);
      }
    }

    _syncListeners[T]!.add(wrapper);

    return () {
      _syncListeners[T]?.remove(wrapper);
      if (_syncListeners[T]?.isEmpty ?? false) {
        _syncListeners.remove(T);
      }
    };
  }

  /// Publishes a [DomainEvent] to all registered synchronous subscribers and the reactive stream
  void publish(DomainEvent event) {
    _eventLog.add(event);

    // 1. Notify sync subscribers of exact type and base types
    for (final entry in _syncListeners.entries) {
      if (entry.key == DomainEvent || entry.key == event.runtimeType) {
        for (final listener in List.of(entry.value)) {
          try {
            listener(event);
          } catch (_) {
            // Fault tolerance: isolate one failing subscriber from breaking others
          }
        }
      }
    }

    // 2. Broadcast via StreamController
    if (!_controller.isClosed) {
      _controller.add(event);
    }
  }

  /// Read-only snapshot of published events since initialization or last clear
  List<DomainEvent> get eventLog => List.unmodifiable(_eventLog);

  /// Total count of published events
  int get eventCount => _eventLog.length;

  /// Clears subscriber listeners and recorded event history (ideal for test teardown)
  void reset() {
    _eventLog.clear();
    _syncListeners.clear();
  }

  /// Disposes stream controller
  Future<void> dispose() async {
    reset();
    await _controller.close();
  }
}
