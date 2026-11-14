# SR Foods — Full Architectural, Release Engineering & Domain Audit

**Date:** 2026-11-02  
**Target Platform:** Android (Google Play Store Production) + Flutter Web  
**Application Category:** Food Manufacturing & Wholesale Distribution ERP  
**Auditor:** Senior Flutter Architect, Android Release Engineer & Food-Manufacturing Domain Consultant  

---

## 1. Executive Summary

This comprehensive audit inspected every source file, configuration, native Gradle/Android artifact, and test suite in the **SR Foods** repository. 

While the application features strong foundation work (Drift SQLite database, Riverpod architecture, customized WhatsApp workflows, and an algorithmic AI advisor), several **critical architectural vulnerabilities, data integrity gaps, and Google Play Store release blockers** were uncovered.

### Key Risk Categories:
1. **Play Store Release Blockers**:
   - `build.gradle.kts` uses debug signing configuration for release builds.
   - `compileSdk` and `targetSdk` inherit default settings rather than explicitly targeting API 35 (Android 15 requirement).
   - `AndroidManifest.xml` declares unused media permissions (`READ_MEDIA_VIDEO`, `READ_MEDIA_AUDIO`), which trigger automatic Google Play policy violations for non-media apps.
   - Missing `android:allowBackup="false"` and data extraction rules, exposing local SQLite customer PII and financial records to cloud backups.
   - Missing required compliance artifacts (`privacy_policy.md`, `data_safety_form.md`, play store listing metadata).
2. **Financial & Data Integrity Flaws**:
   - Currency is stored as IEEE 754 floating-point `double` (`RealColumn` in Drift), causing precision loss and rounding errors over cumulative multi-item orders, partial payments, and ledger balances.
   - Quantities lack typed unit safety (mixing packets, kilograms, grams, liters, and pieces as raw doubles/ints).
   - Lack of atomic database transactions in order creation screens (`order_form_screen.dart`), leaving orphan orders on partial write failures.
   - In-memory customer balance mutations subject to race conditions and balance corruption.
   - Inventory is dual-tracked (`products.currentStock` and `inventory.currentStock`) without synchronization constraints, and sales do not track batch-wise First-Expired, First-Out (FEFO) allocations.
3. **Architecture & State Management Leakage**:
   - `sharedPreferencesProvider` in `auth_repository.dart` throws `UnimplementedError` because it was never initialized or overridden in `ProviderScope` in `main.dart`. Any screen consuming `RoleGuard` crashes immediately.
   - Business role checks in `main_shell.dart` rely on hardcoded phone numbers (`'9440067933' || '9010150809'`) instead of the database user table or role provider.
   - Database restore in `backup_screen.dart` directly overwrites SQLite files while Drift connections are open in WAL mode, causing database corruption (`SQLITE_LOCKED`).
4. **Food Manufacturing & Indian Compliance Deficits**:
   - Missing Bill of Materials (BOM) linking product production to raw material stock deduction (Flour, Oil, Salt, Packaging).
   - Invoices lack GST compliance: missing HSN codes (e.g. 1905), GSTIN, Place of Supply, UPI QR code, and E-Way bill requirements for wholesale drops > ₹50,000.
   - No thermal printer (58mm/80mm ESC/POS roll) formatting for mobile delivery van dispatch.

---

## 2. Complete File Inventory & Risk Matrix

| File | Risk Detected | Severity | Proposed Fix |
|---|---|---|---|
| `android/app/build.gradle.kts` | Release builds signed with `debug` keystore; `targetSdk` & `compileSdk` not pinned to API 35. Missing release signing configuration via `key.properties`. | **CRITICAL** | Pin `compileSdk = 35`, `targetSdk = 35`, `minSdk = 23`. Configure `key.properties` loading with secure fallback. |
| `android/app/src/main/AndroidManifest.xml` | Declares `READ_MEDIA_VIDEO` and `READ_MEDIA_AUDIO` without media player capability (Play Store rejection blocker). Missing `android:allowBackup="false"` or strict `data_extraction_rules.xml`. | **CRITICAL** | Remove `READ_MEDIA_VIDEO` and `READ_MEDIA_AUDIO`. Add `android:allowBackup="false"` and `android:dataExtractionRules`. |
| `lib/main.dart` | `ProviderScope` does not override `sharedPreferencesProvider`. Any consumer of `authRepositoryProvider` or `RoleGuard` crashes with `UnimplementedError`. | **CRITICAL** | Pre-initialize `SharedPreferences` in `main()` before `runApp()` and pass via `ProviderScope(overrides: [sharedPreferencesProvider.overrideWithValue(...)])`. |
| `lib/core/repositories/auth_repository.dart` | Missing injection fallback for `SharedPreferences`; stores roles in plaintext prefs rather than synchronizing with Drift `Users` table. | **HIGH** | Wire `AuthRepository` with safe defaults and synchronize with `Users` table for biometric & PIN authentication. |
| `lib/core/widgets/main_shell.dart` | Hardcoded phone numbers (`9440067933`, `9010150809`) for Admin check in `_isAdmin` getter. | **HIGH** | Replace hardcoded string checks with `ref.watch(authRepositoryProvider).isOwner` and role-based permissions. |
| `lib/core/database/tables.dart` | Money stored as floating-point `RealColumn` (`price`, `subtotal`, `grandTotal`, `paidAmount`, `pendingAmount`, `currentBalance`). | **HIGH** | Migrate currency fields to integer paise (`IntColumn`) with type-safe currency value objects. |
| `lib/core/database/tables.dart` | Missing Bill of Materials (`Recipes`, `RecipeLines`), Batch Expiry Tracking, and `SyncQueue` tables for offline-first resilience. | **HIGH** | Introduce Drift schema v2 migration adding `Recipes`, `RecipeLines`, `MaterialStocks`, `SyncQueue`, and batch-level expiry fields. |
| `lib/core/database/app_database.dart` | Schema version pinned to 1; no migration strategy for upgrades (`onUpgrade` is empty stub). Missing indices on customer lookup, invoice dates, and batch numbers. | **HIGH** | Implement Drift schema migration strategy with index creation and data conversion handlers. |
| `lib/features/orders/presentation/screens/order_form_screen.dart` | Order creation executes raw multi-step database inserts without a transaction. Stock deduction does not update `inventory` table. Reads stale in-memory customer balance. | **CRITICAL** | Route order placement through `OrderRepository.createOrder()` with atomic Drift transaction, FEFO batch selection, and live balance locks. |
| `lib/features/production/presentation/screens/production_form_screen.dart` | Production recording does not deduct raw materials (BOM), does not calculate expiry date based on product shelf life, and lacks database transactions. | **HIGH** | Integrate BOM auto-deduction, auto-calculate `expiryDate` based on SKU shelf life, and wrap in `db.transaction()`. |
| `lib/features/backup/presentation/screens/backup_screen.dart` | Copies `sr_foods.db` without checkpointing SQLite WAL mode (`wal_checkpoint`). Restoring directly overwrites open DB file causing file locks & corruption. Plain unencrypted `.db` exports. | **HIGH** | Checkpoint WAL before backup. Introduce encrypted `.srbackup` archive (AES-256) and safe connection closing before restore. |
| `lib/features/billing/presentation/screens/invoice_detail_screen.dart` | Invoice PDF does not include Indian GST details: no HSN code (1905), no GSTIN, no Place of Supply, no UPI payment QR code, no 58mm/80mm thermal receipt option. | **HIGH** | Redesign invoice PDF with GST compliance (HSN, GSTIN, CGST/SGST/IGST breakdown), UPI payment QR code, and dedicated thermal roll layout. |
| `lib/features/inventory/presentation/screens/inventory_screen.dart` | `inventoryWithProductsProvider` bypasses `inventory` table entirely and only selects `products`. Does not show batch numbers, expiry dates, or allow stock adjustments. | **MEDIUM** | Query joined `inventory` and `productionBatches` tables. Display FEFO expiry horizons and damage/adjustment dialogs. |
| `lib/core/config/app_config.dart` | Package name discrepancy (`com.srfoods.app` vs Android `com.srfoods.sr_foods`). Hardcoded fallback encryption key. | **MEDIUM** | Align package identifier across Dart and Android. Generate secure device-bound encryption key via `flutter_secure_storage`. |
| `lib/core/services/whatsapp_service.dart` | WhatsApp URI string concatenation does not sanitize unencoded special characters in business address or notes. | **LOW** | Ensure all URL query parameters are encoded with `Uri.encodeComponent()`. |
| `lib/core/utils/formatters.dart` | Currency formatters format raw doubles. Lacks paise-to-rupees conversion utilities. | **MEDIUM** | Add `PaiseFormatter` and `Currency` conversion helpers. |
| `test/widget_test.dart` | Minimal single smoke test. Lacks test coverage for order creation, inventory deduction, BOM recipe costing, and credit scoring. | **HIGH** | Expand automated test suite covering unit math, FEFO picking, BOM yield, and role gating. |
| `pubspec.yaml` | Uses generic dependency versions. Missing CI workflow for automated linting, test suite execution, and APK artifact verification. | **MEDIUM** | Add GitHub Actions CI workflow (`.github/workflows/flutter_ci.yml`). |

---

## 3. Prioritized Fix Plan

```
┌────────────────────────────────────────────────────────────────────────┐
│ Phase 2: Play Store Production Readiness                               │
│  - TargetSdk 35, MinSdk 23, CompileSdk 35 in build.gradle.kts           │
│  - Release signingConfig via key.properties                            │
│  - Clean AndroidManifest.xml (remove READ_MEDIA_VIDEO/AUDIO)           │
│  - Strict backup_rules.xml & data_extraction_rules.xml                 │
│  - GitHub Actions CI workflow (.github/workflows/flutter_ci.yml)       │
│  - Play Store legal & compliance docs (docs/privacy_policy.md, etc.)   │
└────────────────────────────────────┬───────────────────────────────────┘
                                     │
┌────────────────────────────────────▼───────────────────────────────────┐
│ Phase 3: Real-World Robustness & Data Integrity                        │
│  - Fix main.dart SharedPreferences injection for RoleGuard             │
│  - Remove hardcoded phone numbers from main_shell.dart                 │
│  - Introduce integer paise Currency and Quantity Unit value objects    │
│  - Atomic Order & Production repository transactions                   │
│  - Secure, encrypted .srbackup export & restore                        │
│  - Indian GST invoice PDF with HSN 1905, GSTIN, UPI QR & Thermal 58mm  │
└────────────────────────────────────┬───────────────────────────────────┘
                                     │
┌────────────────────────────────────▼───────────────────────────────────┐
│ Phase 4: Production & Business Features (BOM, FEFO, FSSAI)             │
│  - BOM recipes & raw material auto-deduction                           │
│  - FEFO (First-Expired, First-Out) stock picking on dispatch           │
│  - Batch expiry alert radar & hygiene compliance log                   │
│  - Thermal label printing (batch code, mfg date, best-before, FSSAI)   │
└────────────────────────────────────┬───────────────────────────────────┘
                                     │
┌────────────────────────────────────▼───────────────────────────────────┐
│ Phase 5: AI Engine Upgrades (Seasonality, Shelf-Life, Costing)         │
│  - Day-of-week seasonality (Sunday Kirana peak) & Festival Uplift      │
│  - Raw material price trend tracker & margin guardrails                │
│  - Explainable AI strings on all production recommendations            │
└────────────────────────────────────┬───────────────────────────────────┘
                                     │
┌────────────────────────────────────▼───────────────────────────────────┐
│ Phase 6: Automated Verification & Test Green Flag                      │
│  - Unit tests for Money, Units, BOM, FEFO, and AI forecasting          │
│  - 0 issues on flutter analyze; all tests passing on flutter test      │
└────────────────────────────────────────────────────────────────────────┘
```

---

## 4. Phase Verification Checkpoints

Every subsequent phase will execute:
1. `flutter analyze` — confirming 0 errors and 0 warnings.
2. `flutter test` — verifying regression-free test passes.
3. Concise git diff and status summary before proceeding.
