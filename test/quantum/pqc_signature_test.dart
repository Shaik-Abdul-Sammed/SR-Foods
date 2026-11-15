// ==============================================================================
// Quantum-INSPIRED classical simulation. No quantum hardware used.
// ==============================================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:sr_foods/core/quantum/pqc_hash_signature.dart';
import 'package:sr_foods/core/quantum/pqc_hybrid.dart';

void main() {
  group('PQC Hash Signature & Hybrid Security Tests (Quantum-Inspired Classical)', () {
    const testSeed = 'sr-foods-quantum-vault-seed-2026';
    const testClassicalKey = 'classical-enterprise-secret-key-42';

    test('1. PqcHashSignatureEngine generates deterministic public key', () {
      final engine1 = PqcHashSignatureEngine(seedKey: testSeed);
      final engine2 = PqcHashSignatureEngine(seedKey: testSeed);

      final pub1 = engine1.generatePublicKey();
      final pub2 = engine2.generatePublicKey();

      expect(pub1, equals(pub2));
      expect(pub1.length, equals(64)); // SHA-256 hex string
    });

    test('2. Valid message signature verifies successfully against public key', () {
      final engine = PqcHashSignatureEngine(seedKey: testSeed);
      const message = 'INVOICE:INV-2026-001|AMOUNT:50000.00|VENDOR:MEDCHAL_DAIRY';

      final sig = engine.sign(message);
      final isValid = PqcHashSignatureEngine.verify(
        message: message,
        signature: sig,
      );

      expect(isValid, isTrue);
    });

    test('3. Tampered message fails verification', () {
      final engine = PqcHashSignatureEngine(seedKey: testSeed);
      const originalMessage = 'TRANSFER:500L_MILK_TO_CHILLER_2';
      const tamperedMessage = 'TRANSFER:5000L_MILK_TO_CHILLER_2';

      final sig = engine.sign(originalMessage);
      final isValid = PqcHashSignatureEngine.verify(
        message: tamperedMessage,
        signature: sig,
      );

      expect(isValid, isFalse);
    });

    test('4. Tampered signature chains fail verification', () {
      final engine = PqcHashSignatureEngine(seedKey: testSeed);
      const message = 'AUDIT_LOG_APPROVED';

      final sig = engine.sign(message);
      final corruptedChains = List<String>.from(sig.revealedChains);
      corruptedChains[0] = '0000000000000000000000000000000000000000000000000000000000000000';

      final corruptedSig = HashSignature(
        revealedChains: corruptedChains,
        merklePath: sig.merklePath,
        publicKey: sig.publicKey,
      );

      final isValid = PqcHashSignatureEngine.verify(
        message: message,
        signature: corruptedSig,
      );

      expect(isValid, isFalse);
    });

    test('5. HybridPqcSecurity signs and verifies dual envelope successfully', () {
      final hybrid = HybridPqcSecurity(
        classicalKey: testClassicalKey,
        pqcSeed: testSeed,
      );
      const payload = 'DISPATCH_FLEET_BATCH_B-101';

      final envelope = hybrid.sign(payload);
      final isValid = HybridPqcSecurity.verify(
        payload: payload,
        envelope: envelope,
        classicalKey: testClassicalKey,
      );

      expect(isValid, isTrue);
      expect(envelope.classicalSignature, isNotEmpty);
      expect(envelope.pqcSignature.publicKey, isNotEmpty);
    });

    test('6. Tampering with classical signature breaks hybrid envelope', () {
      final hybrid = HybridPqcSecurity(
        classicalKey: testClassicalKey,
        pqcSeed: testSeed,
      );
      const payload = 'DISPATCH_FLEET_BATCH_B-102';

      final envelope = hybrid.sign(payload);
      final corruptedEnvelope = HybridPqcEnvelope(
        classicalSignature: 'bad-classical-hmac',
        pqcSignature: envelope.pqcSignature,
        timestampIso: envelope.timestampIso,
      );

      final isValid = HybridPqcSecurity.verify(
        payload: payload,
        envelope: corruptedEnvelope,
        classicalKey: testClassicalKey,
      );

      expect(isValid, isFalse);
    });
  });
}
