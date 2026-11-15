class InboundShipment {
  final String shipmentId;
  final String originHubCode;
  final String productCode;
  final double quantityUnits;
  final String temperatureZone; // 'frozen', 'chilled', 'ambient'
  final DateTime expectedArrival;

  const InboundShipment({
    required this.shipmentId,
    required this.originHubCode,
    required this.productCode,
    required this.quantityUnits,
    required this.temperatureZone,
    required this.expectedArrival,
  });
}

class OutboundDeliveryVan {
  final String vanId;
  final String destinationRoute;
  final double availableCapacityUnits;
  final String supportedZone;
  final DateTime plannedDeparture;

  const OutboundDeliveryVan({
    required this.vanId,
    required this.destinationRoute,
    required this.availableCapacityUnits,
    required this.supportedZone,
    required this.plannedDeparture,
  });
}

class CrossDockTransfer {
  final String shipmentId;
  final String vanId;
  final double transferredUnits;
  final int transferWindowMinutes;
  final bool temperatureCompatible;

  const CrossDockTransfer({
    required this.shipmentId,
    required this.vanId,
    required this.transferredUnits,
    required this.transferWindowMinutes,
    required this.temperatureCompatible,
  });
}

class CrossDockPlanResult {
  final List<CrossDockTransfer> scheduledTransfers;
  final double totalTransferredUnits;
  final double unassignedInboundUnits;
  final bool hasTemperatureViolations;

  const CrossDockPlanResult({
    required this.scheduledTransfers,
    required this.totalTransferredUnits,
    required this.unassignedInboundUnits,
    required this.hasTemperatureViolations,
  });
}

/// Direct cross-dock transfer planner coordinating inbound deliveries and outbound distribution.
class CrossDockPlanner {
  const CrossDockPlanner();

  CrossDockPlanResult planTransfers({
    required List<InboundShipment> inbounds,
    required List<OutboundDeliveryVan> outboundVans,
    int maxDwellMinutes = 120, // Max 2 hours dwell time on cross-dock staging area
  }) {
    final transfers = <CrossDockTransfer>[];
    final remainingCapacity = <String, double>{};
    for (final van in outboundVans) {
      remainingCapacity[van.vanId] = van.availableCapacityUnits;
    }

    double totalTransferred = 0.0;
    double unassigned = 0.0;
    bool tempViolation = false;

    for (final inb in inbounds) {
      double needed = inb.quantityUnits;

      for (final van in outboundVans) {
        if (needed <= 0.0) break;
        final cap = remainingCapacity[van.vanId] ?? 0.0;
        if (cap <= 0.0) continue;

        // Check timing window: van must depart after shipment arrives within dwell limit
        final diffMin = van.plannedDeparture.difference(inb.expectedArrival).inMinutes;
        if (diffMin < 15 || diffMin > maxDwellMinutes) continue;

        // Check temperature compatibility
        final tempOk = (inb.temperatureZone == van.supportedZone) ||
            (van.supportedZone == 'frozen' && inb.temperatureZone == 'chilled');

        if (!tempOk) {
          tempViolation = true;
          continue;
        }

        final transferAmt = needed <= cap ? needed : cap;
        transfers.add(CrossDockTransfer(
          shipmentId: inb.shipmentId,
          vanId: van.vanId,
          transferredUnits: transferAmt,
          transferWindowMinutes: diffMin,
          temperatureCompatible: tempOk,
        ));

        needed -= transferAmt;
        remainingCapacity[van.vanId] = cap - transferAmt;
        totalTransferred += transferAmt;
      }

      if (needed > 0.0) {
        unassigned += needed;
      }
    }

    return CrossDockPlanResult(
      scheduledTransfers: List.unmodifiable(transfers),
      totalTransferredUnits: totalTransferred,
      unassignedInboundUnits: unassigned,
      hasTemperatureViolations: tempViolation,
    );
  }
}
