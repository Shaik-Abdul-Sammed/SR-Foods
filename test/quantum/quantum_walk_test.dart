// ==============================================================================
// Quantum-INSPIRED classical simulation. No quantum hardware used.
// ==============================================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:sr_foods/core/quantum/quantum_walk.dart';

void main() {
  group('ContinuousTimeQuantumWalkClustering Tests (Quantum-Inspired Classical)', () {
    final sampleNodes = [
      // Cluster 1: West Hyderabad (Hitech / Gachibowli)
      const DeliveryNode(id: 'N1', name: 'Hitech Retail 1', lat: 17.4483, lng: 78.3915, dailyDemandKg: 120.0),
      const DeliveryNode(id: 'N2', name: 'Gachibowli Store', lat: 17.4442, lng: 78.3618, dailyDemandKg: 150.0),
      const DeliveryNode(id: 'N3', name: 'Madhapur Mart', lat: 17.4400, lng: 78.3800, dailyDemandKg: 90.0),

      // Cluster 2: Central Hyderabad (Banjara / Jubilee Hills)
      const DeliveryNode(id: 'N4', name: 'Banjara Hills Rd 1', lat: 17.4156, lng: 78.4357, dailyDemandKg: 200.0),
      const DeliveryNode(id: 'N5', name: 'Jubilee Hills Rd 36', lat: 17.4319, lng: 78.4073, dailyDemandKg: 180.0),
      const DeliveryNode(id: 'N6', name: 'Somajiguda Outlet', lat: 17.4250, lng: 78.4550, dailyDemandKg: 110.0),

      // Cluster 3: North Hyderabad (Secunderabad / Begumpet)
      const DeliveryNode(id: 'N7', name: 'Begumpet Airport Rd', lat: 17.4447, lng: 78.4664, dailyDemandKg: 130.0),
      const DeliveryNode(id: 'N8', name: 'Paradise Circle', lat: 17.4410, lng: 78.4870, dailyDemandKg: 140.0),
      const DeliveryNode(id: 'N9', name: 'Marredpally Fresh', lat: 17.4520, lng: 78.5120, dailyDemandKg: 95.0),
    ];

    test('1. Clusters 9 regional nodes into 3 coherent delivery micro-hubs', () {
      final ctqw = ContinuousTimeQuantumWalkClustering(sampleNodes);
      final result = ctqw.cluster(kClusters: 3);

      expect(result.nodeCount, equals(9));
      expect(result.clusters.length, equals(3));
      expect(result.modularityScore, greaterThan(0.5));
    });

    test('2. Total demand across all clusters equals sum of node demands', () {
      final ctqw = ContinuousTimeQuantumWalkClustering(sampleNodes);
      final result = ctqw.cluster(kClusters: 3);

      double clusterDemandSum = 0.0;
      for (final c in result.clusters) {
        clusterDemandSum += c.totalDemandKg;
      }

      final expectedTotal = sampleNodes.map((n) => n.dailyDemandKg).reduce((a, b) => a + b);
      expect((clusterDemandSum - expectedTotal).abs(), lessThanOrEqualTo(0.5));
    });

    test('3. Computed cluster centroid coordinates lie within node bounding box', () {
      final ctqw = ContinuousTimeQuantumWalkClustering(sampleNodes);
      final result = ctqw.cluster(kClusters: 3);

      for (final c in result.clusters) {
        expect(c.centroidLat, inInclusiveRange(17.40, 17.50));
        expect(c.centroidLng, inInclusiveRange(78.35, 78.55));
      }
    });

    test('4. Degenerate case when nodes <= kClusters partitions into individual single-node hubs', () {
      final smallNodes = [
        const DeliveryNode(id: 'S1', name: 'Store A', lat: 17.4, lng: 78.4, dailyDemandKg: 50.0),
        const DeliveryNode(id: 'S2', name: 'Store B', lat: 17.5, lng: 78.5, dailyDemandKg: 60.0),
      ];

      final ctqw = ContinuousTimeQuantumWalkClustering(smallNodes);
      final result = ctqw.cluster(kClusters: 3);

      expect(result.clusters.length, equals(2));
      expect(result.clusters.first.memberNodes.length, equals(1));
    });

    test('5. Empty input nodes handled safely without crash', () {
      final ctqw = ContinuousTimeQuantumWalkClustering([]);
      final result = ctqw.cluster();

      expect(result.clusters, isEmpty);
      expect(result.nodeCount, equals(0));
    });
  });
}
