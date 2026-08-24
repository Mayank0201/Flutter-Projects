import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

/// Verifies that a Google Play purchase receipt was really signed by Google.
///
/// ## What this defends against, and what it does not
///
/// Before this existed, `PurchaseManager._grant` ran the moment the plugin
/// reported `PurchaseStatus.purchased`. Nothing checked *who said so*. A
/// repackaged APK, or an off-the-shelf tool that intercepts the billing
/// response, could claim any purchase and be believed.
///
/// Play signs every purchase receipt with an RSA private key it never shares.
/// The matching **public** key is in Play Console → Monetise → Monetisation
/// setup → Licensing, and is meant to be embedded in the app — Google's own
/// licensing library does exactly this. It is not a secret.
///
/// **Be honest about the limit.** This check runs on the device, using a key
/// that ships inside the app. Anyone who can modify the APK to fake a purchase
/// can also swap this key or delete the call. It is a speed bump, not a lock —
/// the only real fix is verifying server-side, which needs a backend this app
/// deliberately does not have (see `md/DECISIONS.md`).
///
/// What it *does* stop is the common case: generic patching tools that forge a
/// billing response without targeting this app specifically. They cannot forge
/// a signature, so they fail here. That is most of the realistic exposure.
///
/// ## The algorithm
///
/// RSASSA-PKCS1-v1_5 with SHA-1, which is what Play uses. Verification is
/// `sig^e mod n`, then a check that the result has the exact PKCS#1 v1.5
/// structure ending in the DigestInfo for SHA-1 and the receipt's own hash.
/// Dart's `BigInt` does the modular arithmetic, so this needs **no new
/// package** — only `crypto`, which the project already depends on.
class PurchaseSignature {
  /// The Play Console licensing public key for `com.mayank.cogniq`.
  ///
  /// Public by design; safe in source control. If it is ever wrong or empty,
  /// [verify] returns false and every purchase is rejected — see
  /// [isConfigured], which callers must consult so a misconfiguration cannot
  /// silently lock paying customers out.
  static const String playPublicKeyBase64 =
      'MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA+KCR7fhrD1R2xCi7yGPLoge9'
      '5oulem1SFg8GlkLCgrHmjogSaQ1UfEpYTxsiyUqwZSVLzyALZhz2l/w6KjB+rbXONa8j'
      'h/AHDUu/2RR/uWuN0eZ2/tms3DocA3H24ePm7rXvsEjPSt1T7PQB7JFfLN4Pa05r6o1g'
      'AsA9HaCMrLUsd218bqCLR4nGqDGmwwIBFzZ1OU7v1G1f1M3HLaANsQWdBX66qnWkljiD'
      'rZNu2uy/nKGx40YxesCRnzJYv2aneZW7mpqwgOljqsG2z5e/QYM4XWmZ2pvIozGPhe8V'
      'SwcJKT7wokVHp25EGoQSyBS/IBu+BPTdnFE6vVinrK0QvwIDAQAB';

  /// Test-only key override.
  ///
  /// Exists so the algorithm can be proved against a keypair whose private half
  /// we hold. Without it, only the negative path is testable — and a verifier
  /// that rejects EVERYTHING passes every negative test while silently breaking
  /// real purchases. Never set outside tests.
  @visibleForTesting
  static String? debugKeyOverride;

  /// True when a key is present and parses. Callers use this to decide whether
  /// a failed verification means "forged" or "we cannot tell".
  static bool get isConfigured => _key != null;

  static _RsaPublicKey? _cachedKey;
  static bool _parseAttempted = false;

  static _RsaPublicKey? get _key {
    final override = debugKeyOverride;
    if (override != null) {
      try {
        return _parsePublicKey(override);
      } catch (_) {
        return null;
      }
    }
    if (!_parseAttempted) {
      _parseAttempted = true;
      try {
        _cachedKey = _parsePublicKey(playPublicKeyBase64);
      } catch (e) {
        // Never throw out of a purchase path.
        debugPrint('PurchaseSignature: public key failed to parse: $e');
        _cachedKey = null;
      }
    }
    return _cachedKey;
  }

  /// True when [signature] is a valid Play signature over [signedData].
  ///
  /// [signedData] is the receipt exactly as Google produced it — the original
  /// JSON string, byte for byte. Re-encoding or pretty-printing it changes the
  /// hash and the check will fail.
  ///
  /// Returns false on any malformed input rather than throwing: a purchase flow
  /// must never crash on a bad receipt.
  static bool verify(String signedData, String signature) {
    final key = _key;
    if (key == null) return false;
    if (signedData.isEmpty || signature.isEmpty) return false;

    try {
      final Uint8List sigBytes = base64.decode(signature);
      if (sigBytes.isEmpty) return false;

      // sig^e mod n
      final BigInt sig = _bytesToBigInt(sigBytes);
      if (sig >= key.modulus) return false;
      final BigInt decoded = sig.modPow(key.exponent, key.modulus);

      // The encoded message is the modulus length in bytes, left-padded.
      final int emLen = (key.modulus.bitLength + 7) >> 3;
      final Uint8List em = _bigIntToBytes(decoded, emLen);

      // Expected: 0x00 0x01 0xFF...0xFF 0x00 || DigestInfo(SHA-1) || hash
      final List<int> hash = sha1.convert(utf8.encode(signedData)).bytes;
      final List<int> expected = <int>[
        0x00, 0x01,
        // padding filled in below
      ];
      const List<int> sha1DigestInfo = <int>[
        0x30, 0x21, 0x30, 0x09, 0x06, 0x05, 0x2b, 0x0e,
        0x03, 0x02, 0x1a, 0x05, 0x00, 0x04, 0x14,
      ];
      final int padLen = emLen - 3 - sha1DigestInfo.length - hash.length;
      if (padLen < 8) return false; // PKCS#1 requires at least 8 padding bytes
      expected
        ..addAll(List<int>.filled(padLen, 0xFF))
        ..add(0x00)
        ..addAll(sha1DigestInfo)
        ..addAll(hash);

      if (expected.length != em.length) return false;
      // Constant-time compare. Overkill for a public-key check, but free.
      var diff = 0;
      for (var i = 0; i < em.length; i++) {
        diff |= em[i] ^ expected[i];
      }
      return diff == 0;
    } catch (e) {
      debugPrint('PurchaseSignature: verification threw, treating as invalid: $e');
      return false;
    }
  }

  // ---------------------------------------------------------------- internals

  /// Parses an X.509 SubjectPublicKeyInfo DER blob into (modulus, exponent).
  ///
  /// Deliberately a minimal DER walk rather than a general ASN.1 parser — the
  /// structure of an RSA public key is fixed, and a smaller reader is easier to
  /// convince yourself is correct.
  static _RsaPublicKey _parsePublicKey(String base64Key) {
    final Uint8List der = base64.decode(base64Key.replaceAll(RegExp(r'\s'), ''));
    final r = _DerReader(der);

    r.expect(0x30); // SEQUENCE  SubjectPublicKeyInfo
    r.readLength();
    r.expect(0x30); // SEQUENCE  AlgorithmIdentifier
    r.skip(r.readLength());
    r.expect(0x03); // BIT STRING
    final int bitLen = r.readLength();
    if (r.readByte() != 0x00) {
      throw const FormatException('unexpected unused-bits value in BIT STRING');
    }

    final inner = _DerReader(r.readBytes(bitLen - 1));
    inner.expect(0x30); // SEQUENCE  RSAPublicKey
    inner.readLength();
    inner.expect(0x02); // INTEGER   modulus
    final BigInt n = _bytesToBigInt(inner.readBytes(inner.readLength()));
    inner.expect(0x02); // INTEGER   publicExponent
    final BigInt e = _bytesToBigInt(inner.readBytes(inner.readLength()));

    if (n.sign <= 0 || e.sign <= 0) {
      throw const FormatException('non-positive modulus or exponent');
    }
    return _RsaPublicKey(n, e);
  }

  static BigInt _bytesToBigInt(List<int> bytes) {
    var result = BigInt.zero;
    for (final b in bytes) {
      result = (result << 8) | BigInt.from(b & 0xff);
    }
    return result;
  }

  static Uint8List _bigIntToBytes(BigInt value, int length) {
    final out = Uint8List(length);
    var v = value;
    final mask = BigInt.from(0xff);
    for (var i = length - 1; i >= 0; i--) {
      out[i] = (v & mask).toInt();
      v = v >> 8;
    }
    return out;
  }
}

class _RsaPublicKey {
  final BigInt modulus;
  final BigInt exponent;
  const _RsaPublicKey(this.modulus, this.exponent);
}

class _DerReader {
  final Uint8List _data;
  int _pos = 0;
  _DerReader(this._data);

  int readByte() {
    if (_pos >= _data.length) throw const FormatException('DER: out of bounds');
    return _data[_pos++];
  }

  void expect(int tag) {
    final actual = readByte();
    if (actual != tag) {
      throw FormatException('DER: expected tag $tag, found $actual');
    }
  }

  /// Reads a DER length, short or long form.
  int readLength() {
    final first = readByte();
    if (first < 0x80) return first;
    final count = first & 0x7f;
    if (count == 0 || count > 4) {
      throw const FormatException('DER: unsupported length encoding');
    }
    var len = 0;
    for (var i = 0; i < count; i++) {
      len = (len << 8) | readByte();
    }
    return len;
  }

  Uint8List readBytes(int n) {
    if (n < 0 || _pos + n > _data.length) {
      throw const FormatException('DER: length runs past end of data');
    }
    final out = Uint8List.sublistView(_data, _pos, _pos + n);
    _pos += n;
    return out;
  }

  void skip(int n) => readBytes(n);
}
