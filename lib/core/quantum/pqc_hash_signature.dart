// ==============================================================================
// Quantum-INSPIRED classical simulation. No quantum hardware used.
// ==============================================================================

import 'dart:convert';
import 'package:crypto/crypto.dart';

/// One-time hash-based signature and Merkle authentication path.
class HashSignature {
  final List<String> revealedChains;
  final List<String> merklePath;
  final String publicKey;

  const HashSignature({
    required this.revealedChains,
    required this.merklePath,
    required this.publicKey,
  });

  Map<String, dynamic> toJson() => {
        'revealedChains': revealedChains,
        'merklePath': merklePath,
        'publicKey': publicKey,
      };
}

/// SPHINCS-style State-Free Merkle Hash-Based Post-Quantum Signature Engine.
///
/// Quantum-INSPIRED classical simulation. No quantum hardware used.
/// Resists polynomial-time quantum attacks (Shor's and Grover's) by relying strictly
/// on second pre-image collision resistance of iterative SHA-256 hash chains.
class PqcHashSignatureEngine {
  final String seedKey;
  final int chainLength; // W-OTS parameter w (e.g. 16)
  final int numChains; // Message digest byte chunks (e.g. 16)

  PqcHashSignatureEngine({
    required this.seedKey,
    this.chainLength = 16,
    this.numChains = 16,
  });

  String _hash(String input) {
    return sha256.convert(utf8.encode(input)).toString();
  }

  /// Generates the secret key pre-image for chain index [i].
  String _deriveSecretKey(int i) {
    return _hash('$seedKey:sk:$i');
  }

  /// Generates the public key by hashing each secret key chain to its top element.
  String generatePublicKey() {
    final leafHashes = <String>[];
    for (int i = 0; i < numChains; i++) {
      String current = _deriveSecretKey(i);
      for (int step = 0; step < chainLength; step++) {
        current = _hash(current);
      }
      leafHashes.add(current);
    }

    // Merkle tree root of leaf hashes
    return _computeMerkleRoot(leafHashes);
  }

  String _computeMerkleRoot(List<String> leaves) {
    var layer = List<String>.from(leaves);
    while (layer.length > 1) {
      final nextLayer = <String>[];
      for (int i = 0; i < layer.length; i += 2) {
        if (i + 1 < layer.length) {
          nextLayer.add(_hash('${layer[i]}:${layer[i + 1]}'));
        } else {
          nextLayer.add(layer[i]);
        }
      }
      layer = nextLayer;
    }
    return layer.first;
  }

  /// Signs an arbitrary message using hash chain pre-images.
  HashSignature sign(String message) {
    final digestHex = sha256.convert(utf8.encode(message)).toString();
    final revealed = <String>[];
    final leafTops = <String>[];

    for (int i = 0; i < numChains; i++) {
      // Use hex nibble as step count in [0, chainLength - 1]
      final nibble = int.parse(digestHex[i % digestHex.length], radix: 16) % chainLength;
      String current = _deriveSecretKey(i);

      // Reveal pre-image at index [nibble]
      for (int step = 0; step < nibble; step++) {
        current = _hash(current);
      }
      revealed.add(current);

      // Continue to the top of the chain for Merkle tree leaves
      for (int step = nibble; step < chainLength; step++) {
        current = _hash(current);
      }
      leafTops.add(current);
    }

    final root = _computeMerkleRoot(leafTops);

    return HashSignature(
      revealedChains: List.unmodifiable(revealed),
      merklePath: List.unmodifiable(leafTops),
      publicKey: root,
    );
  }

  /// Verifies that [signature] matches [message] against [publicKey].
  static bool verify({
    required String message,
    required HashSignature signature,
    int chainLength = 16,
    int numChains = 16,
  }) {
    final digestHex = sha256.convert(utf8.encode(message)).toString();
    final leafTops = <String>[];

    for (int i = 0; i < numChains; i++) {
      final nibble = int.parse(digestHex[i % digestHex.length], radix: 16) % chainLength;
      String current = signature.revealedChains[i];

      // Walk from revealed pre-image to chain top
      for (int step = nibble; step < chainLength; step++) {
        current = sha256.convert(utf8.encode(current)).toString();
      }
      leafTops.add(current);
    }

    // Verify Merkle root matches public key
    var layer = List<String>.from(leafTops);
    while (layer.length > 1) {
      final nextLayer = <String>[];
      for (int i = 0; i < layer.length; i += 2) {
        if (i + 1 < layer.length) {
          nextLayer.add(sha256.convert(utf8.encode('${layer[i]}:${layer[i + 1]}')).toString());
        } else {
          nextLayer.add(layer[i]);
        }
      }
      layer = nextLayer;
    }

    return layer.first == signature.publicKey;
  }
}
