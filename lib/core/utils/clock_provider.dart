import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:timezone/data/latest_10y.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Global initialization flag for timezone database
bool _timeZonesInitialized = false;

void ensureTimeZonesInitialized() {
  if (!_timeZonesInitialized) {
    tz_data.initializeTimeZones();
    initializeDateFormatting();
    _timeZonesInitialized = true;
  }
}

/// Injectable Clock provider for deterministic time-travel in unit tests & simulations
final clockProvider = Provider<Clock>((ref) {
  return const Clock();
});

/// Timezone-aware date formatting utility for export trade documents and batch traceability
class InternationalDateFormatter {
  final Clock _clock;
  final String timeZoneName;
  final String locale;

  InternationalDateFormatter({
    Clock? clock,
    this.timeZoneName = 'Asia/Kolkata',
    this.locale = 'en_IN',
  }) : _clock = clock ?? const Clock() {
    ensureTimeZonesInitialized();
  }

  tz.Location _resolveLocation() {
    if (timeZoneName == 'UTC' || timeZoneName == 'Etc/UTC' || timeZoneName == 'Z') {
      return tz.UTC;
    }
    try {
      return tz.getLocation(timeZoneName);
    } catch (_) {
      return tz.UTC;
    }
  }

  /// Get current time in configured timezone
  tz.TZDateTime now() {
    return tz.TZDateTime.from(_clock.now(), _resolveLocation());
  }

  /// Convert any DateTime to configured target timezone
  tz.TZDateTime toTargetTimeZone(DateTime dateTime) {
    return tz.TZDateTime.from(dateTime, _resolveLocation());
  }

  /// Standard localized date (e.g. "14 Nov 2026", "Nov 14, 2026", "١٤ نوفمبر ٢٠٢٦")
  String formatDate(DateTime dateTime) {
    final target = toTargetTimeZone(dateTime);
    return DateFormat.yMMMd(locale).format(target);
  }

  /// Standard localized date with time (e.g. "14 Nov 2026, 11:30 AM")
  String formatDateTime(DateTime dateTime) {
    final target = toTargetTimeZone(dateTime);
    return DateFormat.yMMMd(locale).add_jm().format(target);
  }

  /// Standard ISO 8601 date string for exports & customs manifests (e.g. "2026-11-14")
  String formatIsoDate(DateTime dateTime) {
    final target = toTargetTimeZone(dateTime);
    return DateFormat('yyyy-MM-dd').format(target);
  }

  /// Expiry date formatting with day/month/year compliance
  String formatExpiry(DateTime dateTime) {
    final target = toTargetTimeZone(dateTime);
    return DateFormat('dd/MM/yyyy').format(target);
  }

  /// Batch code timestamp representation: YYYYMMDD-HHMM
  String formatBatchTimestamp(DateTime dateTime) {
    final target = toTargetTimeZone(dateTime);
    return DateFormat('yyyyMMdd-HHmm').format(target);
  }
}
