import 'package:sr_foods/core/services/qr_verifier.dart';

enum PickScanStatus {
  matchSuccess, // Green flash
  skuMismatch,  // Red buzz
  expiredLot,   // Red buzz
  invalidQr,    // Red buzz
  alreadyPicked,// Amber
}

class WarehousePickingScanResult {
  final PickScanStatus status;
  final String message;
  final String? matchedSku;
  final String? lotNumber;
  final String? expiryDate;
  final bool isGreenFlash;
  final bool isRedBuzz;

  const WarehousePickingScanResult({
    required this.status,
    required this.message,
    this.matchedSku,
    this.lotNumber,
    this.expiryDate,
    required this.isGreenFlash,
    required this.isRedBuzz,
  });

  factory WarehousePickingScanResult.success({
    required String sku,
    required String lot,
    required String expiry,
  }) {
    return WarehousePickingScanResult(
      status: PickScanStatus.matchSuccess,
      message: 'MATCH: Carton ($sku, Lot: $lot) verified for order line.',
      matchedSku: sku,
      lotNumber: lot,
      expiryDate: expiry,
      isGreenFlash: true,
      isRedBuzz: false,
    );
  }

  factory WarehousePickingScanResult.error({
    required PickScanStatus status,
    required String message,
    String? lot,
  }) {
    return WarehousePickingScanResult(
      status: status,
      message: message,
      lotNumber: lot,
      isGreenFlash: false,
      isRedBuzz: true,
    );
  }
}

class WarehousePickingService {
  WarehousePickingService._();
  static final WarehousePickingService instance = WarehousePickingService._();

  WarehousePickingScanResult verifyCartonScan({
    required String scannedQr,
    required List<String> expectedSkus,
    DateTime? checkDate,
  }) {
    final verification = QrVerifier.instance.verifyQr(scannedQr);
    if (!verification.isValid || verification.type != QrPayloadType.gs1DataMatrix) {
      return WarehousePickingScanResult.error(
        status: PickScanStatus.invalidQr,
        message: 'INVALID: Scanned code is not an authentic SR Foods GS1 DataMatrix (${verification.reason ?? "Unknown"})',
      );
    }

    final gtin = verification.payload['gtin'] as String? ?? '';
    final lot = verification.payload['lot'] as String? ?? '';
    final expStr = verification.payload['expiry'] as String? ?? '';

    // Check expiry (YYMMDD format)
    if (expStr.length == 6) {
      final now = checkDate ?? DateTime.now();
      final yy = int.tryParse(expStr.substring(0, 2)) ?? 0;
      final mm = int.tryParse(expStr.substring(2, 4)) ?? 1;
      final dd = int.tryParse(expStr.substring(4, 6)) ?? 1;
      final expDate = DateTime(2000 + yy, mm, dd);

      if (now.isAfter(expDate)) {
        return WarehousePickingScanResult.error(
          status: PickScanStatus.expiredLot,
          message: 'EXPIRED LOT REJECTED: Lot $lot expired on $dd/$mm/20$yy. Do not pack!',
          lot: lot,
        );
      }
    }

    // Match GTIN or SKU
    bool matched = false;
    String matchedSkuName = '';
    for (final expected in expectedSkus) {
      // expected could be SKU like SRF-BRD-001 or GTIN
      final cleanExpected = expected.replaceAll(RegExp(r'[^0-9]'), '');
      if (gtin.contains(cleanExpected) || expected.contains(gtin)) {
        matched = true;
        matchedSkuName = expected;
        break;
      }
    }

    if (!matched) {
      return WarehousePickingScanResult.error(
        status: PickScanStatus.skuMismatch,
        message: 'WRONG PRODUCT: Scanned GTIN $gtin does not match any pending line on this order!',
        lot: lot,
      );
    }

    return WarehousePickingScanResult.success(
      sku: matchedSkuName,
      lot: lot,
      expiry: expStr,
    );
  }
}
