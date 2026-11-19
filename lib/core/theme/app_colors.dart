import 'package:flutter/material.dart';

/// SR Foods Modern Enterprise Color System
/// Grounded in Google Material 3 Expressive Design and international food-tech ERP standards
/// (Sysco, Toast, Choco, SAP Fiori Supply Chain).
class AppColors {
  AppColors._();

  // === Primary - Enterprise Emerald (Food Freshness, Operational Assurance) ===
  static const Color primary = Color(0xFF059669); // Emerald 600
  static const Color primaryLight = Color(0xFF10B981); // Emerald 500
  static const Color primaryMid = Color(0xFF047857); // Emerald 700
  static const Color primaryDark = Color(0xFF064E3B); // Emerald 900
  static const Color primaryContainer = Color(0xFFECFDF5); // Emerald 50
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color onPrimaryContainer = Color(0xFF065F46); // Emerald 800

  // === Secondary - Warm Bakery & Production (Fresh Bakes, Sourdough) ===
  static const Color secondary = Color(0xFFEA580C); // Orange 600
  static const Color secondaryLight = Color(0xFFF97316); // Orange 500
  static const Color secondaryDark = Color(0xFFC2410C); // Orange 700
  static const Color secondaryContainer = Color(0xFFFFF7ED); // Orange 50
  static const Color onSecondary = Color(0xFFFFFFFF);

  // === Accent - Quality Gold & FSSAI Standards ===
  static const Color accent = Color(0xFFF59E0B); // Amber 500
  static const Color accentLight = Color(0xFFFBBF24); // Amber 400
  static const Color accentDark = Color(0xFFD97706); // Amber 600
  static const Color accentContainer = Color(0xFFFEF3C7); // Amber 100

  // === Cold Chain & Logistics (Chilled/Frozen Safety) ===
  static const Color coldChain = Color(0xFF0284C7); // Sky 600
  static const Color coldChainLight = Color(0xFFE0F2FE); // Sky 100
  static const Color coldChainFrozen = Color(0xFF4F46E5); // Indigo 600

  // === Status Colors ===
  static const Color success = Color(0xFF059669);
  static const Color successLight = Color(0xFFECFDF5);
  static const Color successDark = Color(0xFF064E3B);

  static const Color warning = Color(0xFFD97706);
  static const Color warningLight = Color(0xFFFFFBEB);
  static const Color warningDark = Color(0xFFB45309);

  static const Color error = Color(0xFFDC2626); // Red 600
  static const Color errorLight = Color(0xFFFEF2F2);
  static const Color errorDark = Color(0xFF991B1B);

  static const Color info = Color(0xFF0284C7);
  static const Color infoLight = Color(0xFFE0F2FE);

  // === Neutral / Light Theme (Clean Crisp Surfaces) ===
  static const Color background = Color(0xFFF8FAFC); // Slate 50
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFF1F5F9); // Slate 100
  static const Color cardBackground = Color(0xFFFFFFFF);

  // === Dark Theme (Deep Obsidian & Slate 900) ===
  static const Color darkBackground = Color(0xFF0B0F17); // Deep Obsidian
  static const Color darkSurface = Color(0xFF111827); // Slate 900
  static const Color darkSurfaceVariant = Color(0xFF1E293B); // Slate 800
  static const Color darkCard = Color(0xFF182234); // Slate 850
  static const Color darkBorder = Color(0xFF334155); // Slate 700

  // === Text Colors (WCAG AAA/AA Contrast) ===
  static const Color textPrimary = Color(0xFF0F172A); // Slate 900
  static const Color textSecondary = Color(0xFF64748B); // Slate 500
  static const Color textDisabled = Color(0xFF94A3B8); // Slate 400
  static const Color textInverse = Color(0xFFFFFFFF);
  static const Color textOnDark = Color(0xFFF8FAFC);
  static const Color textSecondaryOnDark = Color(0xFF94A3B8);

  // === Border / Divider ===
  static const Color border = Color(0xFFE2E8F0); // Slate 200
  static const Color divider = Color(0xFFF1F5F9); // Slate 100

  // === Modern Gradient Presets ===
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF059669), Color(0xFF047857)],
  );

  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF064E3B), Color(0xFF059669), Color(0xFF047857)],
  );

  static const LinearGradient orangeGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFEA580C), Color(0xFFF97316)],
  );

  static const LinearGradient goldGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF59E0B), Color(0xFFFBBF24)],
  );

  static const LinearGradient darkGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0B0F17), Color(0xFF111827)],
  );

  static const LinearGradient revenueGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF059669), Color(0xFF10B981)],
  );

  static const LinearGradient salesGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFEA580C), Color(0xFFF59E0B)],
  );

  static const LinearGradient ordersGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0284C7), Color(0xFF38BDF8)],
  );

  static const LinearGradient pendingGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF7C3AED), Color(0xFFA78BFA)],
  );

  // Glass morphism
  static Color glassWhite = Colors.white.withValues(alpha: 0.15);
  static Color glassBorder = Colors.white.withValues(alpha: 0.3);
  static Color glassBlack = Colors.black.withValues(alpha: 0.1);
}
