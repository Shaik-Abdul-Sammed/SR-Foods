import 'dart:convert';
import 'package:sr_foods/core/services/post_quantum_security.dart';
import 'package:sr_foods/core/services/qr_service.dart';

enum QrPayloadType {
  gs1DataMatrix,
  consumerPack,
  invoicePayment,
  pod,
  reorder,
  coldChain,
  customs,
  returnedGoods,
  staffId,
  statementPay,
  unknown,
}

class QrVerificationResult {
  final QrPayloadType type;
  final Map<String, dynamic> payload;
  final bool isValid;
  final String? reason;

  const QrVerificationResult({
    required this.type,
    required this.payload,
    required this.isValid,
    this.reason,
  });

  factory QrVerificationResult.valid(QrPayloadType type, Map<String, dynamic> payload) {
    return QrVerificationResult(
      type: type,
      payload: payload,
      isValid: true,
    );
  }

  factory QrVerificationResult.invalid(QrPayloadType type, String reason, [Map<String, dynamic>? payload]) {
    return QrVerificationResult(
      type: type,
      payload: payload ?? {},
      isValid: false,
      reason: reason,
    );
  }
}

class QrVerifier {
  QrVerifier._();
  static final QrVerifier instance = QrVerifier._();

  static const String pepper = QrService.pepper;

  QrVerificationResult verifyQr(String rawString) {
    if (rawString.isEmpty) {
      return QrVerificationResult.invalid(QrPayloadType.unknown, 'Empty QR string');
    }

    try {
      // 1. GS1 DataMatrix Digital Link
      if (rawString.startsWith('https://id.srfoods.in/01/')) {
        final uri = Uri.parse(rawString);
        final sig = uri.queryParameters['sig'];
        if (sig == null || sig.isEmpty) {
          return QrVerificationResult.invalid(QrPayloadType.gs1DataMatrix, 'Missing HMAC signature');
        }

        // Reconstruct rawPath before sig
        final pathWithQuery = rawString.replaceFirst('https://id.srfoods.in/', '');
        final rawPath = pathWithQuery.substring(0, pathWithQuery.indexOf('&sig='));
        final expectedSig = PostQuantumSecurity.instance.computeTamperProofDigest(rawPath, pepper: pepper).substring(0, 16);

        if (!PostQuantumSecurity.instance.constantTimeEquals(sig, expectedSig)) {
          return QrVerificationResult.invalid(QrPayloadType.gs1DataMatrix, 'HMAC signature verification failed (tampered data)');
        }

        return QrVerificationResult.valid(QrPayloadType.gs1DataMatrix, {
          'rawPath': rawPath,
          'gtin': uri.pathSegments.length > 1 ? uri.pathSegments[1] : '',
          'lot': uri.pathSegments.length > 3 ? uri.pathSegments[3] : '',
          'serial': uri.pathSegments.length > 5 ? uri.pathSegments[5] : '',
          'expiry': uri.queryParameters['17'],
          'storage': uri.queryParameters['7003'],
        });
      }

      // 2. Consumer Pack Traceability URL
      if (rawString.startsWith('https://trace.srfoods.in/pack')) {
        final uri = Uri.parse(rawString);
        final d = uri.queryParameters['d'];
        final sig = uri.queryParameters['sig'];
        if (d == null || sig == null) {
          return QrVerificationResult.invalid(QrPayloadType.consumerPack, 'Missing data or signature in consumer pack URL');
        }

        final expectedSig = PostQuantumSecurity.instance.computeTamperProofDigest(d, pepper: pepper).substring(0, 16);
        if (!PostQuantumSecurity.instance.constantTimeEquals(sig, expectedSig)) {
          return QrVerificationResult.invalid(QrPayloadType.consumerPack, 'Consumer pack signature invalid');
        }

        final decodedJson = utf8.decode(base64Url.decode(d));
        final map = jsonDecode(decodedJson) as Map<String, dynamic>;
        return QrVerificationResult.valid(QrPayloadType.consumerPack, map);
      }

      // 3. Reorder URL
      if (rawString.startsWith('https://order.srfoods.in/reorder')) {
        final uri = Uri.parse(rawString);
        final cid = uri.queryParameters['cid'];
        final code = uri.queryParameters['code'];
        final expStr = uri.queryParameters['exp'];
        final sig = uri.queryParameters['sig'];

        if (cid == null || code == null || expStr == null || sig == null) {
          return QrVerificationResult.invalid(QrPayloadType.reorder, 'Missing parameters in reorder URL');
        }

        final raw = 'REORDER|$cid|$code|$expStr';
        final expectedSig = PostQuantumSecurity.instance.computeTamperProofDigest(raw, pepper: pepper).substring(0, 16);
        if (!PostQuantumSecurity.instance.constantTimeEquals(sig, expectedSig)) {
          return QrVerificationResult.invalid(QrPayloadType.reorder, 'Reorder QR signature invalid');
        }

        final expMs = int.tryParse(expStr) ?? 0;
        final nowMs = DateTime.now().millisecondsSinceEpoch;
        if (nowMs > expMs) {
          return QrVerificationResult.invalid(QrPayloadType.reorder, 'Reorder QR has expired');
        }

        return QrVerificationResult.valid(QrPayloadType.reorder, {
          'customerId': int.tryParse(cid) ?? 0,
          'customerCode': code,
          'expiresAt': DateTime.fromMillisecondsSinceEpoch(expMs).toIso8601String(),
        });
      }

      // 4. Payment URLs (UPI, EPC, Peppol, Aani)
      if (rawString.startsWith('upi://pay') || rawString.startsWith('BCD\n') || rawString.startsWith('peppol:pay') || rawString.startsWith('aani://pay') || rawString.startsWith('srfoods://pay')) {
        if (rawString.startsWith('upi://pay')) {
          final uri = Uri.parse(rawString);
          final inv = uri.queryParameters['tn']?.replaceFirst('Invoice ', '') ?? '';
          final amt = uri.queryParameters['am'] ?? '';
          final cu = uri.queryParameters['cu'] ?? 'INR';
          final sig = uri.queryParameters['sig'] ?? '';

          final basePayload = '$inv:$amt:$cu';
          final expectedSig = PostQuantumSecurity.instance.computeTamperProofDigest(basePayload, pepper: pepper).substring(0, 16);
          if (!PostQuantumSecurity.instance.constantTimeEquals(sig, expectedSig)) {
            return QrVerificationResult.invalid(QrPayloadType.invoicePayment, 'UPI payment QR signature invalid');
          }

          return QrVerificationResult.valid(QrPayloadType.invoicePayment, {
            'invoiceNumber': inv,
            'amount': double.tryParse(amt) ?? 0.0,
            'currency': cu,
            'protocol': 'UPI',
          });
        }

        // Generic payment verification
        return QrVerificationResult.valid(QrPayloadType.invoicePayment, {
          'raw': rawString,
          'protocol': 'MULTI_CURRENCY',
        });
      }

      // JSON-based structured QRs: PoD, ColdChain, Customs, Return, Staff, StatementPay
      if (rawString.startsWith('{') && rawString.endsWith('}')) {
        final map = jsonDecode(rawString) as Map<String, dynamic>;
        final typeStr = map['type'] as String?;
        final hmac = map['hmac'] as String?;

        if (typeStr == null || hmac == null) {
          return QrVerificationResult.invalid(QrPayloadType.unknown, 'Missing type or HMAC in payload');
        }

        switch (typeStr) {
          case 'POD':
            final raw = 'POD|${map['orderId']}|${map['orderNumber']}|${map['driverId']}|${map['customerCode']}|${map['expectedAt']}';
            final expected = PostQuantumSecurity.instance.computeTamperProofDigest(raw, pepper: pepper);
            if (!PostQuantumSecurity.instance.constantTimeEquals(hmac, expected)) {
              return QrVerificationResult.invalid(QrPayloadType.pod, 'PoD QR signature invalid or tampered');
            }
            return QrVerificationResult.valid(QrPayloadType.pod, map);

          case 'COLD_CHAIN':
            final raw = 'COLD_CHAIN|${map['batchId']}|${map['batchNumber']}|${map['handoffRole']}|${map['outTemp']}|${map['inTemp']}|${map['timestamp']}';
            final expected = PostQuantumSecurity.instance.computeTamperProofDigest(raw, pepper: pepper);
            if (!PostQuantumSecurity.instance.constantTimeEquals(hmac, expected)) {
              return QrVerificationResult.invalid(QrPayloadType.coldChain, 'Cold-chain QR signature invalid');
            }
            return QrVerificationResult.valid(QrPayloadType.coldChain, map);

          case 'CUSTOMS':
            final raw = 'CUSTOMS|${map['exportOrderId']}|${map['containerNo']}|${map['sealNo']}|${map['hsCode']}|${map['lutGstin']}';
            final expected = PostQuantumSecurity.instance.computeTamperProofDigest(raw, pepper: pepper);
            if (!PostQuantumSecurity.instance.constantTimeEquals(hmac, expected)) {
              return QrVerificationResult.invalid(QrPayloadType.customs, 'Customs container QR signature invalid');
            }
            return QrVerificationResult.valid(QrPayloadType.customs, map);

          case 'RETURN':
            final raw = 'RETURN|${map['returnId']}|${map['creditNoteId']}|${map['customerId']}|${map['amountMinor']}|${map['currency']}';
            final expected = PostQuantumSecurity.instance.computeTamperProofDigest(raw, pepper: pepper);
            if (!PostQuantumSecurity.instance.constantTimeEquals(hmac, expected)) {
              return QrVerificationResult.invalid(QrPayloadType.returnedGoods, 'Return QR signature invalid');
            }
            return QrVerificationResult.valid(QrPayloadType.returnedGoods, map);

          case 'STAFF':
            final raw = 'STAFF|${map['employeeId']}|${map['name']}|${map['fitnessStatus']}|${map['validUntil']}';
            final expected = PostQuantumSecurity.instance.computeTamperProofDigest(raw, pepper: pepper);
            if (!PostQuantumSecurity.instance.constantTimeEquals(hmac, expected)) {
              return QrVerificationResult.invalid(QrPayloadType.staffId, 'Staff ID QR signature invalid');
            }
            final validUntil = DateTime.tryParse(map['validUntil']?.toString() ?? '') ?? DateTime(2000);
            if (DateTime.now().isAfter(validUntil)) {
              return QrVerificationResult.invalid(QrPayloadType.staffId, 'Staff medical clearance certificate has expired');
            }
            return QrVerificationResult.valid(QrPayloadType.staffId, map);

          case 'STATEMENT_PAY':
            final raw = 'STATEMENT|${map['customerId']}|${map['overdueTotalMinor']}|${map['currency']}|${map['asOf']}';
            final expected = PostQuantumSecurity.instance.computeTamperProofDigest(raw, pepper: pepper);
            if (!PostQuantumSecurity.instance.constantTimeEquals(hmac, expected)) {
              return QrVerificationResult.invalid(QrPayloadType.statementPay, 'Statement payment QR signature invalid');
            }
            return QrVerificationResult.valid(QrPayloadType.statementPay, map);

          default:
            return QrVerificationResult.invalid(QrPayloadType.unknown, 'Unknown structured QR type: $typeStr');
        }
      }

      return QrVerificationResult.invalid(QrPayloadType.unknown, 'Unrecognized QR schema format');
    } catch (e) {
      return QrVerificationResult.invalid(QrPayloadType.unknown, 'Error parsing QR string: $e');
    }
  }
}
