import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

/// Structured application logger with PII scrubbing and crash recording capability.
class AppLogger {
  AppLogger._();

  static final Logger _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 2,
      errorMethodCount: 8,
      lineLength: 90,
      colors: true,
      printEmojis: true,
      dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
    ),
  );

  /// Masks Indian 10-digit phone numbers and sensitive keywords
  static String scrubPii(String message) {
    // Mask 10-digit phone numbers (e.g., 9440067933 -> 94****7933)
    final phoneRegex = RegExp(r'\b([6-9]\d{1})\d{4}(\d{4})\b');
    var scrubbed = message.replaceAllMapped(phoneRegex, (m) => '${m[1]}****${m[2]}');
    
    // Mask PIN numbers if logged
    final pinRegex = RegExp(r'(pin[:=]\s*)(\d+)', caseSensitive: false);
    scrubbed = scrubbed.replaceAllMapped(pinRegex, (m) => '${m[1]}****');

    return scrubbed;
  }

  static void debug(dynamic message, [dynamic error, StackTrace? stackTrace]) {
    if (kDebugMode) {
      _logger.d(scrubPii(message.toString()), error: error, stackTrace: stackTrace);
    }
  }

  static void info(dynamic message, [dynamic error, StackTrace? stackTrace]) {
    _logger.i(scrubPii(message.toString()), error: error, stackTrace: stackTrace);
  }

  static void warning(dynamic message, [dynamic error, StackTrace? stackTrace]) {
    _logger.w(scrubPii(message.toString()), error: error, stackTrace: stackTrace);
  }

  static void error(dynamic message, [dynamic error, StackTrace? stackTrace]) {
    final scrubbed = scrubPii(message.toString());
    _logger.e(scrubbed, error: error, stackTrace: stackTrace);
    recordCrash(error ?? scrubbed, stackTrace, reason: scrubbed);
  }

  /// Extensible crash reporter Hook (Firebase Crashlytics / Sentry)
  static void recordCrash(dynamic exception, StackTrace? stack, {String? reason, bool fatal = false}) {
    // When Firebase is initialized, FirebaseCrashlytics.instance.recordError(...) is routed here.
    if (kDebugMode) {
      debugPrint('[CrashReporter] fatal=$fatal reason=$reason exception=$exception');
    }
  }
}
