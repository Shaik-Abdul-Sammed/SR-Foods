import 'package:flutter/material.dart';

/// SR Foods Premium Color System
class AppColors {
  AppColors._();

  // === Primary - Deep Green ===
  static const Color primary = Color(0xFF1B5E20);
  static const Color primaryLight = Color(0xFF2E7D32);
  static const Color primaryMid = Color(0xFF388E3C);
  static const Color primaryDark = Color(0xFF1A4219);
  static const Color primaryContainer = Color(0xFFE8F5E9);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color onPrimaryContainer = Color(0xFF1B5E20);

  // === Secondary - Orange ===
  static const Color secondary = Color(0xFFE65100);
  static const Color secondaryLight = Color(0xFFFF6D00);
  static const Color secondaryDark = Color(0xFFBF360C);
  static const Color secondaryContainer = Color(0xFFFFF3E0);
  static const Color onSecondary = Color(0xFFFFFFFF);

  // === Accent - Gold ===
  static const Color accent = Color(0xFFFFB300);
  static const Color accentLight = Color(0xFFFFCA28);
  static const Color accentDark = Color(0xFFF57F17);
  static const Color accentContainer = Color(0xFFFFFDE7);

  // === Status Colors ===
  static const Color success = Color(0xFF2E7D32);
  static const Color successLight = Color(0xFFE8F5E9);
  static const Color successDark = Color(0xFF1B5E20);

  static const Color warning = Color(0xFFF57C00);
  static const Color warningLight = Color(0xFFFFF8E1);
  static const Color warningDark = Color(0xFFE65100);

  static const Color error = Color(0xFFB71C1C);
  static const Color errorLight = Color(0xFFFFEBEE);
  static const Color errorDark = Color(0xFF7F0000);

  static const Color info = Color(0xFF0277BD);
  static const Color infoLight = Color(0xFFE1F5FE);

  // === Neutral / Background ===
  static const Color background = Color(0xFFF5F6FA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFF0F4F0);
  static const Color cardBackground = Color(0xFFFFFFFF);

  // === Dark Theme ===
  static const Color darkBackground = Color(0xFF0D1117);
  static const Color darkSurface = Color(0xFF161B22);
  static const Color darkSurfaceVariant = Color(0xFF1E2631);
  static const Color darkCard = Color(0xFF1C2128);
  static const Color darkBorder = Color(0xFF30363D);

  // === Text Colors ===
  static const Color textPrimary = Color(0xFF0D1117);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textDisabled = Color(0xFFB0B7C3);
  static const Color textInverse = Color(0xFFFFFFFF);
  static const Color textOnDark = Color(0xFFE6EDF3);
  static const Color textSecondaryOnDark = Color(0xFF8B949E);

  // === Border / Divider ===
  static const Color border = Color(0xFFE5E7EB);
  static const Color divider = Color(0xFFF3F4F6);

  // === Gradient Presets ===
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF2E7D32), Color(0xFF1B5E20)],
  );

  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1B5E20), Color(0xFF388E3C), Color(0xFF2E7D32)],
  );

  static const LinearGradient orangeGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFE65100), Color(0xFFFF6D00)],
  );

  static const LinearGradient goldGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFFB300), Color(0xFFFFCA28)],
  );

  static const LinearGradient darkGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0D1117), Color(0xFF161B22)],
  );

  static const LinearGradient revenueGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1B5E20), Color(0xFF2E7D32)],
  );

  static const LinearGradient salesGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFE65100), Color(0xFFFF8F00)],
  );

  static const LinearGradient ordersGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0277BD), Color(0xFF0288D1)],
  );

  static const LinearGradient pendingGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF7B1FA2), Color(0xFF9C27B0)],
  );

  // Glass morphism
  static Color glassWhite = Colors.white.withValues(alpha: 0.15);
  static Color glassBorder = Colors.white.withValues(alpha: 0.3);
  static Color glassBlack = Colors.black.withValues(alpha: 0.1);
}
