# Phase 0: Test Gap Baseline Analysis

## Baseline Diagnostics
- `flutter analyze`: 0 issues found (ran in 313.7s)
- `flutter test --reporter expanded`: 163/163 passed (all green)

## Untested Services from Vertical Specialization Run
| Service / Component | File Path | Status | Coverage Est. |
|---------------------|-----------|--------|---------------|
| `dairy_pricing_service` | `lib/core/services/dairy_pricing_service.dart` | Untested | 0% |
| `milk_procurement_service` | `lib/core/services/milk_procurement_service.dart` | Untested | 0% |
| `dairy_cold_chain` | `lib/core/services/cold_chain_telemetry_service.dart` | Partial | 25% |
| `bakery_scheduling_service` | `lib/core/services/bakery_scheduling_service.dart` | Untested | 0% |
| `freshness_window_service` | `lib/core/services/freshness_window_service.dart` | Untested | 0% |
| `custom_order_service` | `lib/core/services/custom_order_service.dart` | Untested | 0% |
| `container_return_service` | `lib/core/services/container_return_service.dart` | Untested | 0% |
| `vertical_scope_service` | `lib/core/services/vertical_scope_service.dart` | Untested | 0% |
| `dairy_kpi_service` | `lib/core/services/dairy_kpi_service.dart` | Untested | 0% |
| `bakery_kpi_service` | `lib/core/services/bakery_kpi_service.dart` | Untested | 0% |
| `dairy_label_generator` | `lib/core/services/pdf/dairy_label_generator.dart` | Untested | 0% |
| `bakery_label_generator` | `lib/core/services/pdf/bakery_label_generator.dart` | Untested | 0% |
| `label_dispatcher_service` | `lib/core/services/pdf/label_dispatcher_service.dart` | Untested | 0% |
| `migration_v5_to_v6` | `lib/core/database/app_database.dart` | Untested | 0% |
| `sku_master_validation` | `lib/core/database/catalog_seed_*.dart` (180 SKUs) | Untested | 0% |

## Untested Screens from Vertical Specialization Run
| Screen | File Path | Status |
|--------|-----------|--------|
| `milk_procurement_screen` | `lib/features/purchases/presentation/screens/milk_procurement_screen.dart` | Untested |
| `oven_schedule_screen` | `lib/features/production/presentation/screens/oven_schedule_screen.dart` | Untested |
| `custom_order_screen` | `lib/features/orders/presentation/screens/custom_order_screen.dart` | Untested |
| `analytics_screen` (vertical tabs) | `lib/features/analytics/presentation/screens/analytics_screen.dart` | Untested |
| `customer_detail_screen` (container pool) | `lib/features/customers/presentation/screens/customer_detail_screen.dart` | Untested |

## Required Phase 1 Deliverables
1. Migration test (v5 -> v6 data preservation)
2. Dairy pricing, procurement, and cold-chain test suite (>= 18 tests)
3. Bakery oven scheduling, freshness window, day-old pricing, custom order tests (>= 20 tests)
4. Container return pool lifecycle tests (>= 8 tests)
5. Vertical scope toggling and field visibility tests (>= 6 tests)
6. Dairy & Bakery operational KPI calculation tests (>= 10 tests)
7. Dairy & Bakery PDF label golden tests (>= 8 goldens)
8. 180-SKU schema completeness and unique constraint tests (>= 5 tests)
Total targeted new tests in Phase 1: >= 70 tests (taking total from 163 to >= 233).
