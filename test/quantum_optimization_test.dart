import 'package:flutter_test/flutter_test.dart';
import 'package:sr_foods/core/services/delivery_route_service.dart';
import 'package:sr_foods/core/services/quantum_optimization_engine.dart';
import 'package:sr_foods/core/services/post_quantum_security.dart';

void main() {
  group('QuantumOptimizationEngine Tests', () {
    test('Empty or single-stop route optimization returns immediately without error', () {
      final engine = QuantumOptimizationEngine.instance;

      final emptyResult = engine.optimizeDeliveryRoute([]);
      expect(emptyResult.optimizedStops, isEmpty);
      expect(emptyResult.distanceSavedKm, 0.0);

      final singleStop = [
        RouteDeliveryStop(
          orderId: 1,
          orderNumber: 'ORD-001',
          customerId: 1,
          shopName: 'Shop A',
          ownerName: 'Owner A',
          phone: '9876543210',
          address: 'Vijayanagar 4th Main',
          routeName: 'South Route',
          grandTotal: 1500.0,
          pendingAmount: 0.0,
          paymentStatus: 'paid',
          orderStatus: 'pending',
        ),
      ];

      final singleResult = engine.optimizeDeliveryRoute(singleStop);
      expect(singleResult.optimizedStops.length, 1);
      expect(singleResult.distanceSavedKm, 0.0);
    });

    test('Quantum Simulated Annealing (QSA) optimizes multi-stop delivery routes', () {
      final engine = QuantumOptimizationEngine.instance;

      // Realistic retail distribution stops in Bangalore food cluster
      final stops = [
        RouteDeliveryStop(
          orderId: 1,
          orderNumber: 'ORD-001',
          customerId: 101,
          shopName: 'A1 Kirana Vijayanagar',
          ownerName: 'Ramesh',
          phone: '9876543210',
          address: 'Vijayanagar Pipeline Road #12',
          routeName: 'West Route',
          grandTotal: 2500.0,
          pendingAmount: 500.0,
          paymentStatus: 'partial',
          orderStatus: 'pending',
        ),
        RouteDeliveryStop(
          orderId: 2,
          orderNumber: 'ORD-002',
          customerId: 102,
          shopName: 'Sri Balaji Foods Rajajinagar',
          ownerName: 'Suresh',
          phone: '9876543211',
          address: 'Rajajinagar 1st Block Main St',
          routeName: 'West Route',
          grandTotal: 4200.0,
          pendingAmount: 0.0,
          paymentStatus: 'paid',
          orderStatus: 'pending',
        ),
        RouteDeliveryStop(
          orderId: 3,
          orderNumber: 'ORD-003',
          customerId: 103,
          shopName: 'Modern Mart Malleshwaram',
          ownerName: 'Ganesh',
          phone: '9876543212',
          address: 'Malleshwaram 8th Cross',
          routeName: 'West Route',
          grandTotal: 1800.0,
          pendingAmount: 200.0,
          paymentStatus: 'partial',
          orderStatus: 'pending',
        ),
        RouteDeliveryStop(
          orderId: 4,
          orderNumber: 'ORD-004',
          customerId: 104,
          shopName: 'Super Bazaar Yeshwanthpur',
          ownerName: 'Venkatesh',
          phone: '9876543213',
          address: 'Yeshwanthpur APMC Yard Gate 2',
          routeName: 'West Route',
          grandTotal: 6000.0,
          pendingAmount: 1200.0,
          paymentStatus: 'pending',
          orderStatus: 'pending',
        ),
        RouteDeliveryStop(
          orderId: 5,
          orderNumber: 'ORD-005',
          customerId: 105,
          shopName: 'Annapurna Store Peenya',
          ownerName: 'Anil',
          phone: '9876543214',
          address: 'Peenya 2nd Stage Industrial Area',
          routeName: 'West Route',
          grandTotal: 3500.0,
          pendingAmount: 0.0,
          paymentStatus: 'paid',
          orderStatus: 'pending',
        ),
      ];

      final result = engine.optimizeDeliveryRoute(
        stops,
        maxIterations: 800,
        initialTransverseField: 3.0,
        dieselCostPerLiter: 92.0,
        vanMileageKmPerLiter: 8.5,
      );

      // Verify all stops are preserved in the result (permutation property)
      expect(result.optimizedStops.length, stops.length);
      final optimizedIds = result.optimizedStops.map((s) => s.orderId).toSet();
      expect(optimizedIds, equals({1, 2, 3, 4, 5}));

      // Verify distance and savings
      expect(result.optimizedDistanceKm, greaterThan(0.0));
      expect(result.distanceSavedKm, greaterThanOrEqualTo(0.0));
      expect(result.fuelSavedLiters, greaterThanOrEqualTo(0.0));
      expect(result.costSavedRupees, greaterThanOrEqualTo(0.0));
      expect(result.iterationsRun, 800);
      expect(result.executionTimeMs, greaterThanOrEqualTo(0));
      expect(result.efficiencyGainPercentage, inInclusiveRange(0.0, 100.0));
    });

    test('Quantum Knapsack Production Scheduler calculates hours, energy, and utilization', () {
      final engine = QuantumOptimizationEngine.instance;

      final demand = {
        'SRF-HBP-001': 400, // Parota (Semi-Auto Press)
        'SRF-WMC-002': 500, // Chapathi (Continuous Hot Press)
        'SRF-RFP-003': 300, // Pulka (Rotary Flame Puffing)
        'SRF-FSP-004': 200, // Puri (High-Speed Sheeter & Fryer)
      };

      final schedule = engine.optimizeProductionSchedule(
        demandPacksBySku: demand,
        shiftHours: 8,
      );

      expect(schedule.assignments.length, 4);
      expect(schedule.totalPacksScheduled, 1400);
      expect(schedule.totalProductionHours, greaterThan(0.0));
      expect(schedule.totalEnergyKwh, greaterThan(0.0));
      expect(schedule.overallMachineUtilizationPct, greaterThan(0.0));
      expect(schedule.scheduleSummary, contains('Scheduled 1400 packs across 4 dedicated machine lines'));

      // Verify machine assignments have valid shift labels and machine names
      for (final assignment in schedule.assignments) {
        expect(assignment.machineName, isNotEmpty);
        expect(assignment.productName, isNotEmpty);
        expect(assignment.estimatedHours, greaterThan(0.0));
        expect(assignment.energyKwh, greaterThan(0.0));
        expect(assignment.shift, contains('Shift'));
      }
    });

    test('Quantum Knapsack handles zero and empty demand cleanly', () {
      final engine = QuantumOptimizationEngine.instance;

      final schedule = engine.optimizeProductionSchedule(
        demandPacksBySku: {'SRF-HBP-001': 0},
        shiftHours: 8,
      );

      expect(schedule.assignments, isEmpty);
      expect(schedule.totalPacksScheduled, 0);
      expect(schedule.totalProductionHours, 0.0);
      expect(schedule.totalEnergyKwh, 0.0);
      expect(schedule.overallMachineUtilizationPct, 0.0);
    });
  });

  group('PostQuantumSecurity Tests', () {
    test('deriveQuantumHardenedKey produces deterministic 256-bit (32 byte) key', () {
      final pqc = PostQuantumSecurity.instance;

      final key1 = pqc.deriveQuantumHardenedKey('SecurePassphrase123!', 'salt_org_sr_foods', iterations: 100);
      final key2 = pqc.deriveQuantumHardenedKey('SecurePassphrase123!', 'salt_org_sr_foods', iterations: 100);

      expect(key1.length, 32); // 256 bits = 32 bytes
      expect(key1, equals(key2));

      // Different salt produces completely different key
      final key3 = pqc.deriveQuantumHardenedKey('SecurePassphrase123!', 'different_salt', iterations: 100);
      expect(key1, isNot(equals(key3)));
    });

    test('constantTimeEquals correctly validates string equality without early exit leakage', () {
      final pqc = PostQuantumSecurity.instance;

      expect(pqc.constantTimeEquals('super_secret_hash_value', 'super_secret_hash_value'), isTrue);
      expect(pqc.constantTimeEquals('super_secret_hash_value', 'super_secret_hash_valuE'), isFalse);
      expect(pqc.constantTimeEquals('short', 'longer_string'), isFalse);
      expect(pqc.constantTimeEquals('', ''), isTrue);
    });

    test('computeTamperProofDigest creates deterministic HMAC-SHA256 digest with avalanche effect', () {
      final pqc = PostQuantumSecurity.instance;

      final digest1 = pqc.computeTamperProofDigest('PRODUCTION_BATCH_SRF_20261114_001');
      final digest2 = pqc.computeTamperProofDigest('PRODUCTION_BATCH_SRF_20261114_001');

      expect(digest1, equals(digest2));
      expect(digest1.length, 64); // 64 hex characters = 256 bits

      // Changing one character alters the entire hash
      final digest3 = pqc.computeTamperProofDigest('PRODUCTION_BATCH_SRF_20261114_002');
      expect(digest1, isNot(equals(digest3)));
    });
  });
}
