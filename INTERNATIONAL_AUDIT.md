# SR Foods — International Business & Compliance Audit (Phase 0)

**Date**: 2026-11-14  
**Audit Baseline**: Commit `8967939`  
**Static Analysis Baseline**: `flutter analyze` $\to$ **0 issues found**  
**Automated Test Baseline**: `flutter test` $\to$ **41/41 tests passing (100% green)**  
**Target Export Markets**: United Arab Emirates / GCC (AED, GSO, Halal, RTL Arabic), United Kingdom (GBP, FIC, VAT), United States (USD, FDA, Imperial units, MM/dd/yyyy), Canada (CAD/USD, CFIA, Bilingual EN/FR), Australia (AUD, FSANZ).

---

## 1. Codebase Assumptions Audit Table

| File & Line | Regional Assumption / Pattern | Countries & Regions Broken | Recommended Fix |
| :--- | :--- | :--- | :--- |
| `lib/core/config/app_config.dart:46-49` | Hardcoded `dd/MM/yyyy`, `dd/MM/yyyy HH:mm` date formats | **US, Canada** (require `MM/dd/yyyy` or ISO `yyyy-MM-dd`) | Provide locale-aware date formatting via `intl` DateFormat based on active `LocaleContext`. |
| `lib/core/config/app_config.dart:59-60` | Hardcoded `currencySymbol = '₹'`, `currencyCode = 'INR'` | **UAE, UK, US, Canada, Australia** (AED, GBP, USD, CAD, AUD) | Introduce multi-currency support with dynamic currency code, symbol, and formatters. |
| `lib/core/domain/money.dart:53-70` | Default currency symbol `'₹'`, INR paise assumptions | **All Non-India Markets** | Upgrade `Money` value object to hold `int amountMinor`, `Currency currency`, and optional FX rate. |
| `lib/core/logger.dart:19-23` | PII scrubber regex `r'\b([6-9]\d{1})\d{4}(\d{4})\b'` assumes Indian 10-digit mobile starting 6-9 | **US, UK, UAE, Australia, Canada** | Implement E.164 international phone number scrubber with international dialing code recognition. |
| `lib/core/utils/validators.dart:16-18` | Phone validator `r'^\+?[0-9]{10,13}$'` fails for varied international formats | **US/Canada** (+1 10-digit), **UK** (+44 11-digit), **UAE** (+971 9-digit) | Adopt flexible E.164 ITU-T compliant validation or country-aware prefix parsing. |
| `lib/core/utils/communication_utils.dart:37-40` | WhatsApp auto-prepends `'91'` for phone numbers without country code | **All International Importers / Distributors** | Store full E.164 formatted numbers with `+<country_code>` or prompt based on distributor's country. |
| `lib/core/services/ai_expert_engine.dart:61-105, 303-345` | Demand forecasting only checks Indian Hindu/national holidays (Diwali, Pongal, Dussehra, etc.) | **UAE** (Eid al-Fitr, Eid al-Adha, Ramadan), **US/Canada** (Thanksgiving, Christmas), **UK/Australia** (Bank Holidays, Diaspora Diwali peaks) | Add global multi-calendar festival engine parameterized by target export destination country. |
| `lib/core/services/quantum_optimization_engine.dart:20, 95-96` | Commercial diesel rate hardcoded to ₹92.0/L; fuel economy fixed at 8.5 km/L (metric) | **US** (Gallons, Miles/Gallon, USD), **UAE** (AED/Liter), **UK** (GBP/Liter) | Parameterize fuel cost and fuel economy units based on destination entity/fleet configuration. |
| `lib/core/services/fssai_hygiene_service.dart:1-120` | Assumes FSSAI Schedule 4 (India Food Safety) and Celsius temperatures | **US** (FDA FSMA / Fahrenheit), **UK** (FSA HACCP), **Gulf** (GSO 2233 & Halal), **Canada** (CFIA) | Abstract into `ComplianceProfile` engine supporting FDA, GSO, CFIA, FSANZ, and FSSAI. |
| `lib/core/services/gst_invoice_service.dart:1-360` | Hardcoded Indian GST Tax Invoice (CGST, SGST, IGST, HSN, State Code, UPI QR) and thermal receipts | **UAE** (5% VAT, TRN), **UK** (20% VAT, EORI), **US** (Zero-rated export / State sales tax), **Australia** (10% GST) | Add Export Invoicing module supporting Zero-Rated GST LUT, IEC/AD codes, Incoterms, and multi-tax. |
| `lib/core/database/app_database.dart:148` | App settings seeded with `currency_symbol = '₹'` | **All Foreign Entities** | Parameterize app settings by active Entity (`SR Foods India`, `SR Foods FZE Dubai`, `SR Foods LLC`). |
| `lib/features/orders/presentation/screens/driver_route_screen.dart:69, 214, 254` | Hardcoded `'₹'` and cash/UPI collection workflows | **Export Distributors** (wire transfer, Letter of Credit, net 30/60 days credit terms in foreign currency) | Abstract payment collection modes to support international commercial terms (LC, TT, Net-30). |
| `lib/features/dashboard/presentation/widgets/revenue_chart.dart:137` | Chart labels hardcoded with `'₹'` prefix | **Export Analytics** | Format charts dynamically using `CurrencyFormatter` with active entity's currency. |
| `lib/features/expenses/presentation/screens/expense_form_screen.dart:62` | Text labels and icons hardcoded with `'Amount (₹)'` and `Icons.currency_rupee_rounded` | **Global Branches / Entities** | Use localized labels and generic/contextual currency icons. |
| `lib/features/production/presentation/screens/hygiene_compliance_screen.dart:69` | Hardcoded `'Daily FSSAI Hygiene Audit'` title | **US, UK, Gulf, Canada** | Dynamic hygiene audit checklist conforming to destination country regulation. |
| Entire UI Layer (`lib/features/**/*.dart`) | Over 250+ hardcoded English strings, LTR `EdgeInsets.left`/`right`, no RTL padding | **UAE / GCC** (Arabic RTL reading order broken, flipped icons needed) | Implement `flutter_localizations`, ARB dictionary (`en`, `hi`, `ar`, `fr`, `es`), `EdgeInsetsDirectional`. |

---

## 2. Drift Database Multi-Currency, Multi-Country & Multi-Entity Audit

SR Foods currently defines 18 Drift tables. Below is the full evaluation of currency, regional, and entity isolation assumptions:

| Drift Table | Single-Currency Assumptions | Single-Country Assumptions | Single-Entity Assumptions | Required Schema Upgrades |
| :--- | :--- | :--- | :--- | :--- |
| **`Products`** | `price` and `costPrice` stored as naked `real()` assuming INR. | `taxCategory` assumes domestic GST slab. `weightGrams` assumes metric. | No `entity_id`. Product catalog is shared or global. | Add `INTEGER price_minor`, `INTEGER cost_price_minor`, `TEXT currency_code`, `TEXT hs_code`, `INTEGER entity_id`. |
| **`Customers`** | `creditLimit`, `openingBalance`, `currentBalance` stored as `real()` in INR. | `pincode` assumes 6-digit Indian Postal Code. No international country code or tax registration (TRN/VAT/EIN). | No `entity_id`. All customers belong to single factory. | Add `INTEGER balance_minor`, `TEXT currency_code`, `TEXT country_code`, `TEXT tax_id`, `INTEGER entity_id`, `TEXT credit_terms`. |
| **`Orders`** | `subtotal`, `discount`, `tax`, `grandTotal`, `paidAmount`, `pendingAmount` stored as `real()`. | `paymentMethod` assumes local Indian methods (`cash`, `upi`). | No `entity_id`. | Add `INTEGER total_minor`, `TEXT currency_code`, `REAL fx_rate_to_base`, `INTEGER entity_id`, `TEXT incoterm`, `TEXT destination_country`. |
| **`OrderItems`** | `price`, `discount`, `total` stored as `real()`. | None directly. | Bound to single order. | Add `INTEGER price_minor`, `INTEGER total_minor`, `TEXT currency_code`. |
| **`Invoices`** | `subtotal`, `discount`, `tax`, `grandTotal`, `paidAmount`, `pendingAmount` stored as `real()`. | Assumes Indian GST invoice with HSN and GSTIN. | No `entity_id`. | Add `INTEGER total_minor`, `TEXT currency_code`, `REAL fx_rate_to_base`, `INTEGER entity_id`, `TEXT invoice_type` (domestic/export), `TEXT lut_number`. |
| **`Payments`** | `amount` stored as `real()`. | `method` assumes cash, upi, bank. `upiTransactionId` India-specific. | No `entity_id`. | Add `INTEGER amount_minor`, `TEXT currency_code`, `REAL fx_rate_to_base`, `INTEGER entity_id`, `TEXT swift_ref`. |
| **`ProductionBatches`** | None (counts and dates). | `totalWeight` assumes kg (metric). | No `entity_id` (which production facility produced the batch). | Add `INTEGER entity_id`, `TEXT export_destination` (optional FEFO reservation). |
| **`Inventory`** | None (counts). | None. | No `entity_id` (single warehouse assumed). | Add `INTEGER entity_id`. |
| **`InventoryTransactions`**| None (counts). | None. | No `entity_id`. | Add `INTEGER entity_id`. |
| **`Expenses`** | `amount` stored as `real()` in INR. | `paymentMethod` assumes Indian domestic expense. | No `entity_id`. | Add `INTEGER amount_minor`, `TEXT currency_code`, `INTEGER entity_id`. |
| **`Users`** | None. | None. | Assumes single factory staff. | Add `INTEGER default_entity_id`, `TEXT allowed_locales`. |
| **`AppSettings`** | Stores global keys (`currency_symbol = '₹'`). | Assumes single jurisdiction. | Global singleton settings. | Add `INTEGER entity_id` to partition settings per company branch. |
| **`AppNotifications`** | None. | None. | Global. | Add `INTEGER entity_id`. |
| **`BackupHistory`** | None. | None. | Global. | None needed. |
| **`ActivityLogs`** | None. | None. | Single ledger. | Add `INTEGER entity_id`. |
| **`SyncQueue`** | Payload contains unpartitioned entities. | None. | Single endpoint. | Add `INTEGER entity_id`. |
| **`RawMaterials`** | `lastPurchasePrice` stored as `real()` in INR. | `unit` default 'kg' (metric). | Single factory stock. | Add `INTEGER price_minor`, `TEXT currency_code`, `INTEGER entity_id`. |
| **`HygieneLogs`** | None. | Specific to FSSAI Schedule 4. | Single factory plant. | Add `INTEGER entity_id`, `TEXT compliance_standard` (fssai/fda/gso). |

---

## 3. New Entities Required for International Trade (Phase 2 & 3)

To elevate SR Foods into an international export ERP without disrupting existing local operations, the following tables must be introduced:
1. **`Entities`**: `id`, `legal_name`, `country_code`, `currency_code`, `tax_number`, `iec_code`, `ad_code`, `port_of_loading`, `fssai_license`, `fda_facility_number`, `created_at`.
2. **`ExportOrders`**: `id`, `export_order_number`, `entity_id`, `consignee_id`, `destination_country`, `port_of_discharge`, `incoterm` (FOB/CIF/DDP), `currency_code`, `fx_rate`, `payment_terms`, `status`, `created_at`.
3. **`ExportLines`**: `id`, `export_order_id`, `product_id`, `hs_code`, `quantity_cartons`, `units_per_carton`, `unit_price_minor`, `total_price_minor`, `batch_references`.
4. **`ExportShipments`**: `id`, `export_order_id`, `shipping_line_or_airline`, `awb_or_bl_number`, `container_number`, `departure_date`, `eta`, `current_status` (booked $\to$ in-transit $\to$ customs $\to$ delivered).
5. **`ComplianceProfiles`**: `id`, `country_code`, `authority_name` (FDA/FSSAI/GSO/CFIA/FSANZ), `license_number`, `valid_until`, `nutrition_panel_type`, `allergen_declaration_type`.
6. **`Distributors`**: `id`, `entity_id`, `company_name`, `country_code`, `currency_code`, `contact_name`, `phone_e164`, `credit_limit_minor`, `payment_terms_days`, `ar_balance_minor`.
7. **`FxRatesCache`**: `currency_code`, `rate_to_base`, `as_of_date`, `is_manual`.

---

## 4. Phase 1 Roadmap & Next Actions (Upon User Confirmation)

1. **i18n & RTL Foundation**:
   - Add `flutter_localizations` & `intl` to `pubspec.yaml`.
   - Setup `l10n.yaml` and ARB files: `app_en.arb`, `app_hi.arb`, `app_ar.arb` (Arabic RTL), `app_fr.arb` (French Canada), `app_es.arb` (Spanish US).
   - Configure `MaterialApp.router` with RTL text direction and `supportedLocales`.
   - Replace direction-dependent paddings (`left`/`right`) with `EdgeInsetsDirectional`.
2. **Currency & Domain Units**:
   - Refactor `Money` value object: `amountMinor` (int), `Currency` enum (`INR`, `AED`, `USD`, `GBP`, `CAD`, `AUD`), formatting matrices, and FX conversion methods.
   - Refactor `Quantity` and create explicit `Weight`, `Volume`, and `Count` units preventing cross-unit operations.
3. **Drift Schema Migration v3 $\to$ v4**:
   - Add non-destructive migration script in `app_database.dart` preserving all existing 41/41 unit/integration test assertions.
   - Create migration verification test verifying that legacy integer/real data maps cleanly into international multi-currency structures.
