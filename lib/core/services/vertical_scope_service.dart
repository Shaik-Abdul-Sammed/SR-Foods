import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/database_provider.dart';

/// Business verticals supported by SR Foods
enum Vertical {
  frozen,
  dairy,
  bakery;

  String get label {
    switch (this) {
      case Vertical.frozen:
        return 'Frozen Food';
      case Vertical.dairy:
        return 'Dairy';
      case Vertical.bakery:
        return 'Bakery';
    }
  }

  static Vertical fromString(String val) {
    switch (val.toLowerCase().trim()) {
      case 'dairy':
        return Vertical.dairy;
      case 'bakery':
        return Vertical.bakery;
      case 'frozen':
      default:
        return Vertical.frozen;
    }
  }
}

/// Scope defining currently active business verticals and resulting field visibility
class VerticalScope {
  final Set<Vertical> enabledVerticals;
  final Vertical primaryVertical;

  const VerticalScope({
    this.enabledVerticals = const {Vertical.frozen},
    this.primaryVertical = Vertical.frozen,
  });

  bool isEnabled(Vertical v) => enabledVerticals.contains(v);

  Set<Vertical> activeVerticals() => Set.unmodifiable(enabledVerticals);

  /// Extra form fields visible depending on active verticals
  List<String> visibleProductFields() {
    final fields = <String>[];
    if (isEnabled(Vertical.frozen)) {
      fields.addAll([
        'storageType',
        'shelfLifeDays',
        'fssaiCategoryCode',
        'nutritionPer100gJson',
        'allergens',
        'unitsPerInnerPack',
        'packsPerMasterCarton',
      ]);
    }
    if (isEnabled(Vertical.dairy)) {
      fields.addAll([
        'milkType',
        'fatPercentExpected',
        'snfPercentExpected',
        'procurementSlot',
        'isPasteurized',
        'isCultured',
      ]);
    }
    if (isEnabled(Vertical.bakery)) {
      fields.addAll([
        'bakeDateRequired',
        'proofingMinutes',
        'ovenType',
        'freshnessWindowHours',
        'dayOldDiscountPercent',
        'isCustomOrder',
      ]);
    }
    return fields;
  }

  /// Dashboard layout mapping active KPI cards and metrics
  Map<String, dynamic> defaultDashboardLayout() {
    final cards = <String>[];
    if (isEnabled(Vertical.frozen)) {
      cards.addAll([
        'cold_chain_telemetry',
        'fefo_allocation_radar',
        'blast_freezer_runtime',
        'export_fob_margin',
      ]);
    }
    if (isEnabled(Vertical.dairy)) {
      cards.addAll([
        'milk_procurement_yield',
        'chilling_center_temp',
        'fat_snf_variance',
        'milk_spoilage_rate',
      ]);
    }
    if (isEnabled(Vertical.bakery)) {
      cards.addAll([
        'oven_utilization_rate',
        'freshness_window_adherence',
        'day_old_discount_loss',
        'custom_order_pipeline',
      ]);
    }
    return {
      'primary': primaryVertical.name,
      'enabled': enabledVerticals.map((e) => e.name).toList(),
      'kpiCards': cards,
    };
  }

  VerticalScope copyWith({
    Set<Vertical>? enabledVerticals,
    Vertical? primaryVertical,
  }) {
    return VerticalScope(
      enabledVerticals: enabledVerticals ?? this.enabledVerticals,
      primaryVertical: primaryVertical ?? this.primaryVertical,
    );
  }
}

class VerticalScopeNotifier extends Notifier<VerticalScope> {
  bool _isInitialized = false;

  @override
  VerticalScope build() {
    return const VerticalScope();
  }

  Future<void> loadFromDatabase() async {
    if (_isInitialized) return;
    try {
      final db = ref.read(databaseProvider);
      final allSettings = await db.select(db.appSettings).get();
      final map = {for (final s in allSettings) s.key: s.value};

      final verticalsRaw = map['active_verticals'];
      final primaryRaw = map['primary_vertical'];

      Set<Vertical> active = {Vertical.frozen};
      if (verticalsRaw != null && verticalsRaw.isNotEmpty) {
        try {
          final decoded = jsonDecode(verticalsRaw);
          if (decoded is List) {
            active = decoded.map((e) => Vertical.fromString(e.toString())).toSet();
          }
        } catch (_) {}
      }

      if (active.isEmpty) {
        active = {Vertical.frozen};
      }

      Vertical primary = Vertical.frozen;
      if (primaryRaw != null && primaryRaw.isNotEmpty) {
        primary = Vertical.fromString(primaryRaw);
      }
      if (!active.contains(primary)) {
        primary = active.first;
      }

      state = VerticalScope(
        enabledVerticals: active,
        primaryVertical: primary,
      );
      _isInitialized = true;
    } catch (_) {
      // Gracefully maintain defaults
    }
  }

  Future<void> setActive(Set<Vertical> verticals, {Vertical? primary}) async {
    if (verticals.isEmpty) {
      throw ArgumentError('At least one vertical must remain enabled.');
    }
    _isInitialized = true;
    final primaryV = primary ?? (verticals.contains(state.primaryVertical) ? state.primaryVertical : verticals.first);
    state = VerticalScope(
      enabledVerticals: verticals,
      primaryVertical: primaryV,
    );

    try {
      final db = ref.read(databaseProvider);
      final list = verticals.map((v) => v.name).toList();
      final jsonStr = jsonEncode(list);

      await db.customStatement(
        "INSERT INTO app_settings (key, value, type) VALUES ('active_verticals', ?, 'json') "
        'ON CONFLICT(key) DO UPDATE SET value = excluded.value, updated_at = CURRENT_TIMESTAMP',
        [jsonStr],
      );

      await db.customStatement(
        "INSERT INTO app_settings (key, value, type) VALUES ('primary_vertical', ?, 'string') "
        'ON CONFLICT(key) DO UPDATE SET value = excluded.value, updated_at = CURRENT_TIMESTAMP',
        [primaryV.name],
      );
    } catch (_) {
      // Fallback in case of DB lock or in-memory testing
    }
  }
}

final verticalScopeProvider =
    NotifierProvider<VerticalScopeNotifier, VerticalScope>(
  () => VerticalScopeNotifier(),
);
