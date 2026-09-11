import 'package:flutter_dotenv/flutter_dotenv.dart';

/// SR Foods Application Configuration
class AppConfig {
  AppConfig._();

  // App Info
  static const String appName = 'SR Foods';
  static const String appTagline = 'Smart Food Distribution & Business Management';
  static const String appVersion = '1.0.0';
  static const int appBuildNumber = 1;
  static const String packageName = 'com.srfoods.app';
  static const String ownerName = 'SM Subhani';
  static const String businessName = 'SR Foods';

  // Database
  static const String databaseName = 'sr_foods.db';
  static const int databaseVersion = 1;
  static String get encryptionKey => dotenv.env['ENCRYPTION_KEY'] ?? 'fallback_key_do_not_use';

  // Hive Boxes
  static const String settingsBox = 'settings_box';
  static const String authBox = 'auth_box';
  static const String cacheBox = 'cache_box';

  // SharedPreferences Keys
  static const String keyThemeMode = 'theme_mode';
  static const String keyLanguage = 'language';
  static const String keyPinHash = 'pin_hash';
  static const String keyBiometricEnabled = 'biometric_enabled';
  static const String keyAutoLockDuration = 'auto_lock_duration';
  static const String keyLastBackup = 'last_backup';
  static const String keyOnboardingDone = 'onboarding_done';
  static const String keyFirstRun = 'first_run';

  // Business Rules
  static const double defaultCreditLimit = 5000.0;
  static const int lowStockThreshold = 10;
  static const int sessionTimeoutMinutes = 30;
  static const int maxBackupFiles = 10;

  // Pagination
  static const int pageSize = 20;

  // Date Formats
  static const String dateFormat = 'dd/MM/yyyy';
  static const String timeFormat = 'HH:mm';
  static const String dateTimeFormat = 'dd/MM/yyyy HH:mm';
  static const String invoiceDateFormat = 'dd MMM yyyy';

  // Invoice
  static const String invoicePrefix = 'SRF';
  static const String batchPrefix = 'BATCH';

  // GST
  static const double gstRate = 0.0; // Optional for future

  // Currency
  static const String currencySymbol = '₹';
  static const String currencyCode = 'INR';

  // Notification Channels
  static const String lowStockChannel = 'low_stock';
  static const String paymentChannel = 'payment_reminder';
  static const String productionChannel = 'production_reminder';
  static const String backupChannel = 'backup_reminder';
}
