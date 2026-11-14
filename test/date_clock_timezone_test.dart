import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sr_foods/core/utils/clock_provider.dart';

void main() {
  setUpAll(() {
    ensureTimeZonesInitialized();
  });

  group('Injectable Clock and Timezone Date Formatter Tests', () {
    test('Clock injection allows deterministic time travel', () {
      final fixedInstant = DateTime.utc(2026, 11, 14, 10, 30, 0);
      final testClock = Clock(() => fixedInstant);

      final container = ProviderContainer(
        overrides: [
          clockProvider.overrideWithValue(testClock),
        ],
      );

      final clock = container.read(clockProvider);
      expect(clock.now(), fixedInstant);
    });

    test('Timezone conversion across Asia/Kolkata, UTC, and America/New_York', () {
      // 10:30 UTC = 16:00 IST (+5:30) = 05:30 EST (-5:00)
      final fixedInstant = DateTime.utc(2026, 11, 14, 10, 30, 0);
      final testClock = Clock(() => fixedInstant);

      final kolkataFormatter = InternationalDateFormatter(
        clock: testClock,
        timeZoneName: 'Asia/Kolkata',
        locale: 'en_IN',
      );
      final kolkataNow = kolkataFormatter.now();
      expect(kolkataNow.hour, 16);
      expect(kolkataNow.minute, 0);

      final nyFormatter = InternationalDateFormatter(
        clock: testClock,
        timeZoneName: 'America/New_York',
        locale: 'en_US',
      );
      final nyNow = nyFormatter.now();
      expect(nyNow.hour, 5);
      expect(nyNow.minute, 30);

      final utcFormatter = InternationalDateFormatter(
        clock: testClock,
        timeZoneName: 'UTC',
        locale: 'en_GB',
      );
      final utcNow = utcFormatter.now();
      expect(utcNow.hour, 10);
      expect(utcNow.minute, 30);
    });

    test('Locale and Timezone test matrix (en-US, en-GB, ar-AE x UTC, Asia/Kolkata, America/New_York)', () {
      final instant = DateTime.utc(2026, 11, 14, 12, 0, 0);

      final locales = ['en_US', 'en_GB', 'ar_AE'];
      final timezones = ['UTC', 'Asia/Kolkata', 'America/New_York'];

      for (final locale in locales) {
        for (final tz in timezones) {
          final formatter = InternationalDateFormatter(
            timeZoneName: tz,
            locale: locale,
          );

          final iso = formatter.formatIsoDate(instant);
          expect(iso, contains('2026-11-14'));

          final formattedDate = formatter.formatDate(instant);
          expect(formattedDate.isNotEmpty, isTrue);

          final formattedDateTime = formatter.formatDateTime(instant);
          expect(formattedDateTime.isNotEmpty, isTrue);

          final expiry = formatter.formatExpiry(instant);
          expect(expiry, '14/11/2026');

          final batch = formatter.formatBatchTimestamp(instant);
          expect(batch.startsWith('20261114-'), isTrue);
        }
      }
    });
  });
}
