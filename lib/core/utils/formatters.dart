import 'package:intl/intl.dart';
import '../config/app_config.dart';

/// Currency & Number formatting utilities
class CurrencyFormatter {
  CurrencyFormatter._();

  static final _currencyFormat = NumberFormat.currency(
    locale: 'en_IN',
    symbol: AppConfig.currencySymbol,
    decimalDigits: 2,
  );

  static final _compactFormat = NumberFormat.compactCurrency(
    locale: 'en_IN',
    symbol: AppConfig.currencySymbol,
    decimalDigits: 1,
  );

  static final _numberFormat = NumberFormat('#,##,###', 'en_IN');

  static String format(double amount) => _currencyFormat.format(amount);

  static String compact(double amount) => _compactFormat.format(amount);

  static String formatNumber(int number) => _numberFormat.format(number);

  static String formatNoDecimal(double amount) {
    final format = NumberFormat.currency(
      locale: 'en_IN',
      symbol: AppConfig.currencySymbol,
      decimalDigits: 0,
    );
    return format.format(amount);
  }
}

/// Date formatting utilities
class DateFormatter {
  DateFormatter._();

  static final _dateFormat = DateFormat('dd/MM/yyyy');
  static final _dateTimeFormat = DateFormat('dd/MM/yyyy HH:mm');
  static final _timeFormat = DateFormat('HH:mm');
  static final _invoiceDateFormat = DateFormat('dd MMM yyyy');
  static final _monthYearFormat = DateFormat('MMM yyyy');
  static final _fullDateFormat = DateFormat('EEEE, dd MMMM yyyy');
  static final _dayMonthFormat = DateFormat('dd MMM');

  static String toDate(DateTime date) => _dateFormat.format(date);
  static String toDateTime(DateTime date) => _dateTimeFormat.format(date);
  static String toTime(DateTime date) => _timeFormat.format(date);
  static String toInvoiceDate(DateTime date) => _invoiceDateFormat.format(date);
  static String toMonthYear(DateTime date) => _monthYearFormat.format(date);
  static String toFullDate(DateTime date) => _fullDateFormat.format(date);
  static String toDayMonth(DateTime date) => _dayMonthFormat.format(date);

  static String relative(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return toDate(date);
  }

  static bool isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  static DateTime startOfDay(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  static DateTime endOfDay(DateTime date) =>
      DateTime(date.year, date.month, date.day, 23, 59, 59);

  static DateTime startOfMonth(DateTime date) =>
      DateTime(date.year, date.month, 1);

  static DateTime endOfMonth(DateTime date) =>
      DateTime(date.year, date.month + 1, 0, 23, 59, 59);
}

/// ID & Code generators
class IdGenerator {
  IdGenerator._();

  static String generateOrderNumber() {
    final now = DateTime.now();
    final dateStr = DateFormat('yyyyMMdd').format(now);
    final timeStr = DateFormat('HHmmssSSS').format(now); // include milliseconds to avoid collisions
    return 'ORD-$dateStr-$timeStr';
  }

  static String generateInvoiceNumber() {
    final now = DateTime.now();
    final yearMonth = DateFormat('yyyyMM').format(now);
    final ms = now.millisecondsSinceEpoch % 100000; // 5-digit unique suffix
    return '${AppConfig.invoicePrefix}-$yearMonth-${ms.toString().padLeft(5, '0')}';
  }

  static String generateBatchNumber(String productSku) {
    final now = DateTime.now();
    final dateStr = DateFormat('yyyyMMdd').format(now);
    final timeStr = DateFormat('HHmm').format(now);
    return '${AppConfig.batchPrefix}-$productSku-$dateStr-$timeStr';
  }

  static String generateCustomerCode() {
    final now = DateTime.now();
    return 'CUST-${now.millisecondsSinceEpoch.toString().substring(7)}';
  }

  static String generateReceiptNumber() {
    final now = DateTime.now();
    return 'RCP-${DateFormat('yyyyMMddHHmmss').format(now)}';
  }
}
