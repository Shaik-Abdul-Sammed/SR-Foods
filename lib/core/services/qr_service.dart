import 'dart:convert';
import 'package:sr_foods/core/services/post_quantum_security.dart';

/// Comprehensive QR & GS1 Digital Link Generator Service
/// Implements 10 enterprise supply-chain traceability use cases
/// Every payload is HMAC-signed via PostQuantumSecurity for offline tamper detection.
class QrService {
  QrService._();
  static final QrService instance = QrService._();

  static const String pepper = 'SR_FOODS_QR_HMAC_KEY_2026';

  // 1. GS1 DataMatrix Digital Link for Cartons & Pallets
  String generateBatchGs1DataMatrix({
    required String gtin,
    required String lotNumber,
    required String serialNumber,
    required String expiryDateYymmdd,
    required String storageCode, // e.g., "-18C" or "CHILLED"
  }) {
    final rawPath = '01/$gtin/10/$lotNumber/21/$serialNumber?17=$expiryDateYymmdd&7003=$storageCode';
    final sig = PostQuantumSecurity.instance.computeTamperProofDigest(rawPath, pepper: pepper).substring(0, 16);
    return 'https://id.srfoods.in/$rawPath&sig=$sig';
  }

  // 2. Consumer Pack Traceability QR
  String generateConsumerPackQr({
    required String batchNumber,
    required String sku,
    required String productName,
    required String mfgDate,
    required String fssaiLicense,
    required List<String> allergens,
    required Map<String, dynamic> nutritionPer100g,
    required String heatingGuide,
  }) {
    final payloadMap = {
      'b': batchNumber,
      's': sku,
      'n': productName,
      'm': mfgDate,
      'f': fssaiLicense,
      'a': allergens,
      'nut': nutritionPer100g,
      'h': heatingGuide,
    };
    final jsonStr = jsonEncode(payloadMap);
    final b64 = base64UrlEncode(utf8.encode(jsonStr));
    final sig = PostQuantumSecurity.instance.computeTamperProofDigest(b64, pepper: pepper).substring(0, 16);
    return 'https://trace.srfoods.in/pack?d=$b64&sig=$sig';
  }

  // 3. Dynamic Multi-Currency Invoice Payment QR
  String generateInvoicePaymentQr({
    required String invoiceNumber,
    required double amount,
    required String currency,
    String upiId = '9440067933@ybl',
    String businessName = 'SR Foods',
  }) {
    final upperCurr = currency.toUpperCase();
    final amtStr = amount.toStringAsFixed(2);
    final basePayload = '$invoiceNumber:$amtStr:$upperCurr';
    final sig = PostQuantumSecurity.instance.computeTamperProofDigest(basePayload, pepper: pepper).substring(0, 16);

    switch (upperCurr) {
      case 'INR':
        final encodedName = Uri.encodeComponent(businessName);
        return 'upi://pay?pa=$upiId&pn=$encodedName&am=$amtStr&cu=INR&tn=Invoice%20$invoiceNumber&sig=$sig';
      case 'EUR':
        return 'BCD\n002\n1\nSCT\nSRFOODS\nSR Foods International\nEUR$amtStr\n\n\n$invoiceNumber\n$sig';
      case 'GBP':
        return 'peppol:pay?rem=$invoiceNumber&amt=$amtStr&cur=GBP&sig=$sig';
      case 'AED':
        return 'aani://pay?receiver=SRFOODS&amt=$amtStr&cur=AED&ref=$invoiceNumber&sig=$sig';
      default:
        return 'srfoods://pay?inv=$invoiceNumber&amt=$amtStr&cur=$upperCurr&sig=$sig';
    }
  }

  // 4. Proof of Delivery (PoD) Order Sign-Off QR
  String generatePodQr({
    required int orderId,
    required String orderNumber,
    required String driverId,
    required String customerCode,
    required DateTime expectedAt,
  }) {
    final expIso = expectedAt.toIso8601String();
    final raw = 'POD|$orderId|$orderNumber|$driverId|$customerCode|$expIso';
    final sig = PostQuantumSecurity.instance.computeTamperProofDigest(raw, pepper: pepper);
    final map = {
      'type': 'POD',
      'orderId': orderId,
      'orderNumber': orderNumber,
      'driverId': driverId,
      'customerCode': customerCode,
      'expectedAt': expIso,
      'hmac': sig,
    };
    return jsonEncode(map);
  }

  // 5. Customer Reorder Placard QR
  String generateReorderQr({
    required int customerId,
    required String customerCode,
    required DateTime validUntil,
  }) {
    final expMs = validUntil.millisecondsSinceEpoch;
    final raw = 'REORDER|$customerId|$customerCode|$expMs';
    final sig = PostQuantumSecurity.instance.computeTamperProofDigest(raw, pepper: pepper).substring(0, 16);
    return 'https://order.srfoods.in/reorder?cid=$customerId&code=$customerCode&exp=$expMs&sig=$sig';
  }

  // 6. Cold-Chain Custody Transfer QR
  String generateColdChainQr({
    required int batchId,
    required String batchNumber,
    required String handoffRole, // e.g. "factory_to_reefer", "reefer_to_distributor"
    required double outTempCelsius,
    required double inTempCelsius,
    required DateTime recordedAt,
  }) {
    final ts = recordedAt.toIso8601String();
    final raw = 'COLD_CHAIN|$batchId|$batchNumber|$handoffRole|$outTempCelsius|$inTempCelsius|$ts';
    final sig = PostQuantumSecurity.instance.computeTamperProofDigest(raw, pepper: pepper);
    return jsonEncode({
      'type': 'COLD_CHAIN',
      'batchId': batchId,
      'batchNumber': batchNumber,
      'handoffRole': handoffRole,
      'outTemp': outTempCelsius,
      'inTemp': inTempCelsius,
      'timestamp': ts,
      'hmac': sig,
    });
  }

  // 7. Customs & Reefer Container Inspection QR
  String generateCustomsQr({
    required int exportOrderId,
    required String containerNo,
    required String sealNo,
    required String hsCode,
    required String lutGstin,
  }) {
    final raw = 'CUSTOMS|$exportOrderId|$containerNo|$sealNo|$hsCode|$lutGstin';
    final sig = PostQuantumSecurity.instance.computeTamperProofDigest(raw, pepper: pepper);
    return jsonEncode({
      'type': 'CUSTOMS',
      'exportOrderId': exportOrderId,
      'containerNo': containerNo,
      'sealNo': sealNo,
      'hsCode': hsCode,
      'lutGstin': lutGstin,
      'hmac': sig,
    });
  }

  // 8. Return & Credit Note QR
  String generateReturnQr({
    required int returnId,
    required int creditNoteId,
    required int customerId,
    required int amountMinor,
    required String currency,
  }) {
    final raw = 'RETURN|$returnId|$creditNoteId|$customerId|$amountMinor|$currency';
    final sig = PostQuantumSecurity.instance.computeTamperProofDigest(raw, pepper: pepper);
    return jsonEncode({
      'type': 'RETURN',
      'returnId': returnId,
      'creditNoteId': creditNoteId,
      'customerId': customerId,
      'amountMinor': amountMinor,
      'currency': currency,
      'hmac': sig,
    });
  }

  // 9. Staff ID & Food Safety Hygiene Clearance QR
  String generateStaffIdQr({
    required String employeeId,
    required String name,
    required String fssaiFitnessStatus, // e.g. "FIT_MEDICALLY_CLEARED"
    required DateTime fitnessValidUntil,
  }) {
    final validIso = fitnessValidUntil.toIso8601String();
    final raw = 'STAFF|$employeeId|$name|$fssaiFitnessStatus|$validIso';
    final sig = PostQuantumSecurity.instance.computeTamperProofDigest(raw, pepper: pepper);
    return jsonEncode({
      'type': 'STAFF',
      'employeeId': employeeId,
      'name': name,
      'fitnessStatus': fssaiFitnessStatus,
      'validUntil': validIso,
      'hmac': sig,
    });
  }

  // 10. Statement & Overdue Receivables Settlement QR
  String generateStatementPayQr({
    required int customerId,
    required int overdueTotalMinor,
    required String currency,
    required DateTime asOfDate,
  }) {
    final asOfIso = asOfDate.toIso8601String();
    final raw = 'STATEMENT|$customerId|$overdueTotalMinor|$currency|$asOfIso';
    final sig = PostQuantumSecurity.instance.computeTamperProofDigest(raw, pepper: pepper);
    return jsonEncode({
      'type': 'STATEMENT_PAY',
      'customerId': customerId,
      'overdueTotalMinor': overdueTotalMinor,
      'currency': currency,
      'asOf': asOfIso,
      'hmac': sig,
    });
  }
}
