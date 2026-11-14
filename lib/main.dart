import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'l10n/app_localizations.dart';

import 'core/logger.dart';
import 'core/repositories/auth_repository.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Safe dotenv load with graceful fallback
  try {
    await dotenv.load(fileName: '.env');
  } catch (e) {
    AppLogger.warning('Could not load .env file, utilizing environment defaults: $e');
  }

  // Pre-initialize SharedPreferences for instantaneous role gating & settings
  final prefs = await SharedPreferences.getInstance();

  // Global Error & Crash Handling with PII scrubbing
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    AppLogger.recordCrash(
      details.exception,
      details.stack,
      reason: details.exceptionAsString(),
      fatal: false,
    );
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    AppLogger.recordCrash(
      error,
      stack,
      reason: 'Uncaught PlatformDispatcher Exception',
      fatal: true,
    );
    return true;
  };

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'SR Foods ERP',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      routerConfig: router,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      localeResolutionCallback: (locale, supportedLocales) {
        if (locale == null) return supportedLocales.first;
        for (final supportedLocale in supportedLocales) {
          if (supportedLocale.languageCode == locale.languageCode) {
            return supportedLocale;
          }
        }
        return supportedLocales.first;
      },
    );
  }
}
