// ==============================================================================
// Quantum-INSPIRED classical simulation. No quantum hardware used.
// ==============================================================================

import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'pqc_hash_signature.dart';

/// A dual-layer hybrid signature combining classical HMAC-SHA256 and PQC Hash Signature.
class HybridPqcEnvelope {
  final String classicalSignature;
  final HashSignature pqcSignature;
  final String timestampIso;

  const HybridPqcEnvelope({
    required this.classicalSignature,
    required this.pqcSignature,
    required this.timestampIso,
  });

  Map<String, dynamic> toJson() => {
        'classicalSignature': classicalSignature,
        'pqcSignature': pqcSignature.toJson(),
        'timestampIso': timestampIso,
      };
}

/// Hybrid Post-Quantum Cryptographic Envelope Signer & Verifier.
///
/// Quantum-INSPIRED classical simulation. No quantum hardware used.
/// Implements NIST SP 800-227 recommended defense-in-depth:
/// requires BOTH classical cryptography AND post-quantum hash signatures to be valid.
class HybridPqcSecurity {
  final String classicalKey;
  final PqcHashSignatureEngine pqcEngine;

  HybridPqcSecurity({
    required this.classicalKey,
    required String pqcSeed,
  }) : pqcEngine = PqcHashSignatureEngine(seedKey: pqcSeed);

  /// Signs payload with both classical HMAC and PQC hash signature.
  HybridPqcEnvelope sign(String payload) {
    final timestamp = DateTime.now().toIso8601String();
    final messageWithTime = '$payload|$timestamp';

    // 1. Classical HMAC-SHA256
    final hmac = Hmac(sha256, utf8.encode(classicalKey));
    final classicalSig = hmac.convert(utf8.encode(messageWithTime)).toString();

    // 2. Post-Quantum Hash Signature
    final pqcSig = pqcEngine.sign(messageWithTime);

    return HybridPqcEnvelope(
      classicalSignature: classicalSig,
      pqcSignature: pqcSig,
      timestampIso: timestamp,
    );
  }

  /// Verifies both classical and post-quantum signatures.
  static bool verify({
    required String payload,
    required HybridPqcEnvelope envelope,
    required String classicalKey,
  }) {
    final messageWithTime = '$payload|${envelope.timestampIso}';

    // 1. Verify classical HMAC
    final hmac = Hmac(sha256, utf8.encode(classicalKey));
    final expectedClassical = hmac.convert(utf8.encode(messageWithTime)).toString();
    if (envelope.classicalSignature != expectedClassical) {
      return false;
    }

    // 2. Verify Post-Quantum Hash Signature
    final pqcValid = PqcHashSignatureEngine.verify(
      message: messageWithTime,
      signature: envelope.pqcSignature,
    );

    return pqcValid;
  }
}
