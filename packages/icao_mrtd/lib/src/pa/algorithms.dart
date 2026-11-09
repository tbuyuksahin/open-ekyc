import 'dart:typed_data';

import 'package:icao_mrtd/src/errors.dart';
import 'package:icao_mrtd/src/pa/der.dart';
import 'package:icao_mrtd/src/tlv.dart';
import 'package:meta/meta.dart';
import 'package:pointycastle/ecc/ecc_fp.dart' as fp;
import 'package:pointycastle/export.dart';

/// Object identifiers used in Passive Authentication.
abstract final class Oids {
  /// CMS signed-data content type.
  static const signedData = '1.2.840.113549.1.7.2';

  /// ICAO LDS security object content type.
  static const ldsSecurityObject = '2.23.136.1.1.1';

  /// ICAO CSCA master list content type.
  static const cscaMasterList = '2.23.136.1.1.2';

  /// CMS contentType signed attribute.
  static const contentType = '1.2.840.113549.1.9.3';

  /// CMS messageDigest signed attribute.
  static const messageDigest = '1.2.840.113549.1.9.4';

  /// RSA public keys and PKCS #1 v1.5 signatures with an external digest.
  static const rsaEncryption = '1.2.840.113549.1.1.1';

  /// RSASSA-PSS.
  static const rsaPss = '1.2.840.113549.1.1.10';

  /// MGF1 mask generation.
  static const mgf1 = '1.2.840.113549.1.1.8';

  /// EC public keys.
  static const ecPublicKey = '1.2.840.10045.2.1';

  /// Prime field type in explicit EC parameters.
  static const primeField = '1.2.840.10045.1.1';

  /// Subject key identifier extension.
  static const subjectKeyIdentifier = '2.5.29.14';

  /// Authority key identifier extension.
  static const authorityKeyIdentifier = '2.5.29.35';
}

/// A hash algorithm.
enum HashAlgorithm {
  /// SHA-1.
  sha1('1.3.14.3.2.26', '06052b0e03021a'),

  /// SHA-224.
  sha224('2.16.840.1.101.3.4.2.4', '0609608648016503040204'),

  /// SHA-256.
  sha256('2.16.840.1.101.3.4.2.1', '0609608648016503040201'),

  /// SHA-384.
  sha384('2.16.840.1.101.3.4.2.2', '0609608648016503040202'),

  /// SHA-512.
  sha512('2.16.840.1.101.3.4.2.3', '0609608648016503040203');

  const HashAlgorithm(this.oid, this._digestInfoOid);

  /// The algorithm OID.
  final String oid;
  final String _digestInfoOid;

  /// A fresh digest instance.
  Digest create() => switch (this) {
    sha1 => SHA1Digest(),
    sha224 => SHA224Digest(),
    sha256 => SHA256Digest(),
    sha384 => SHA384Digest(),
    sha512 => SHA512Digest(),
  };

  /// Hashes [data].
  Uint8List hash(Uint8List data) => create().process(data);

  /// The algorithm for [oid]; throws if unsupported.
  static HashAlgorithm forOid(String oid) => values.firstWhere(
    (h) => h.oid == oid,
    orElse: () => throw LdsFormatException('Unsupported hash algorithm $oid'),
  );
}

/// An X.509 `AlgorithmIdentifier`.
@immutable
class AlgorithmIdentifier {
  /// Creates an identifier.
  const AlgorithmIdentifier(this.oid, [this.parameters]);

  /// Parses a DER `AlgorithmIdentifier`.
  factory AlgorithmIdentifier.parse(Tlv tlv) {
    final c = expectTag(tlv, DerTag.sequence, 'AlgorithmIdentifier').children;
    if (c.isEmpty) throw const LdsFormatException('Empty AlgorithmIdentifier');
    final params = c.length > 1 && c[1].tag != DerTag.nullValue ? c[1] : null;
    return AlgorithmIdentifier(decodeOid(c[0]), params);
  }

  /// The algorithm OID.
  final String oid;

  /// The parameters, or `null` when absent or NULL.
  final Tlv? parameters;
}

/// A public key from a `SubjectPublicKeyInfo`.
@immutable
sealed class PublicKeyInfo {
  const PublicKeyInfo();

  /// Parses a DER `SubjectPublicKeyInfo`.
  factory PublicKeyInfo.parse(Tlv spki) {
    final c = expectTag(spki, DerTag.sequence, 'SubjectPublicKeyInfo').children;
    final alg = AlgorithmIdentifier.parse(c[0]);
    final key = decodeBitString(c[1]);
    switch (alg.oid) {
      case Oids.rsaEncryption || Oids.rsaPss:
        final seq = Tlv.decode(key).children;
        return RsaPublicKeyInfo(
          RSAPublicKey(decodeInteger(seq[0]), decodeInteger(seq[1])),
        );
      case Oids.ecPublicKey:
        final params = alg.parameters;
        if (params == null) {
          throw const LdsFormatException('EC key without domain parameters');
        }
        final domain = _ecDomain(params);
        final q = domain.curve.decodePoint(key);
        if (q == null) throw const LdsFormatException('Invalid EC point');
        return EcPublicKeyInfo(ECPublicKey(q, domain));
      default:
        throw LdsFormatException('Unsupported public key algorithm ${alg.oid}');
    }
  }
}

/// An RSA public key.
final class RsaPublicKeyInfo extends PublicKeyInfo {
  /// Wraps [key].
  const RsaPublicKeyInfo(this.key);

  /// The key.
  final RSAPublicKey key;
}

/// An elliptic curve public key.
final class EcPublicKeyInfo extends PublicKeyInfo {
  /// Wraps [key].
  const EcPublicKeyInfo(this.key);

  /// The key.
  final ECPublicKey key;
}

const _namedCurves = {
  '1.2.840.10045.3.1.7': 'secp256r1',
  '1.3.132.0.33': 'secp224r1',
  '1.3.132.0.34': 'secp384r1',
  '1.3.132.0.35': 'secp521r1',
  '1.3.36.3.3.2.8.1.1.1': 'brainpoolp160r1',
  '1.3.36.3.3.2.8.1.1.3': 'brainpoolp192r1',
  '1.3.36.3.3.2.8.1.1.5': 'brainpoolp224r1',
  '1.3.36.3.3.2.8.1.1.7': 'brainpoolp256r1',
  '1.3.36.3.3.2.8.1.1.9': 'brainpoolp320r1',
  '1.3.36.3.3.2.8.1.1.11': 'brainpoolp384r1',
  '1.3.36.3.3.2.8.1.1.13': 'brainpoolp512r1',
};

ECDomainParameters _ecDomain(Tlv params) {
  if (params.tag == DerTag.oid) {
    final oid = decodeOid(params);
    final name = _namedCurves[oid];
    if (name == null) throw LdsFormatException('Unsupported curve $oid');
    return ECDomainParameters(name);
  }
  // Many ePassports carry explicit parameters (RFC 3279 ECParameters)
  // instead of a curve OID.
  final c = expectTag(params, DerTag.sequence, 'ECParameters').children;
  final field = c[1].children;
  if (decodeOid(field[0]) != Oids.primeField) {
    throw const LdsFormatException('Only prime field curves are supported');
  }
  final p = decodeInteger(field[1]);
  final curveSeq = c[2].children;
  final curve = fp.ECCurve(
    p,
    bytesToBigInt(curveSeq[0].value),
    bytesToBigInt(curveSeq[1].value),
  );
  final g = curve.decodePoint(c[3].value);
  if (g == null) throw const LdsFormatException('Invalid EC base point');
  final n = decodeInteger(c[4]);
  final h = c.length > 5 ? decodeInteger(c[5]) : BigInt.one;
  return ECDomainParametersImpl('explicit', curve, g, n, h);
}

/// Verifies [signature] over [message].
///
/// [algorithm] is the signature algorithm. When it names only the key type
/// (`rsaEncryption`, `id-ecPublicKey`), as CMS signer infos often do,
/// [digest] supplies the hash.
bool verifySignature({
  required AlgorithmIdentifier algorithm,
  required PublicKeyInfo key,
  required Uint8List message,
  required Uint8List signature,
  HashAlgorithm? digest,
}) {
  try {
    final scheme = _scheme(algorithm, digest);
    return switch ((scheme, key)) {
      (_Pkcs1(:final hash), RsaPublicKeyInfo(:final key)) =>
        (RSASigner(hash.create(), hash._digestInfoOid)
              ..init(false, PublicKeyParameter<RSAPublicKey>(key)))
            .verifySignature(message, RSASignature(signature)),
      (
        _Pss(:final hash, :final mgfHash, :final saltLength),
        RsaPublicKeyInfo(:final key),
      ) =>
        _verifyPss(key, hash, mgfHash, saltLength, message, signature),
      (_Ecdsa(:final hash), EcPublicKeyInfo(:final key)) =>
        (ECDSASigner(hash.create())
              ..init(false, PublicKeyParameter<ECPublicKey>(key)))
            .verifySignature(message, _ecSignature(signature, key)),
      _ => false,
    };
  } on LdsFormatException {
    rethrow;
  } on Object {
    // Malformed signatures make pointycastle throw; that is a failed
    // verification, not a crash.
    return false;
  }
}

bool _verifyPss(
  RSAPublicKey key,
  HashAlgorithm hash,
  HashAlgorithm mgfHash,
  int saltLength,
  Uint8List message,
  Uint8List signature,
) {
  final random = FortunaRandom()..seed(KeyParameter(Uint8List(32)));
  final signer = PSSSigner(RSAEngine(), hash.create(), mgfHash.create())
    ..init(
      false,
      ParametersWithSaltConfiguration(
        PublicKeyParameter<RSAPublicKey>(key),
        random,
        saltLength,
      ),
    );
  return signer.verifySignature(message, PSSSignature(signature));
}

ECSignature _ecSignature(Uint8List signature, ECPublicKey key) {
  // X9.62 DER (SEQUENCE of r, s) or the plain r || s form of BSI TR-03111.
  if (signature.isNotEmpty && signature[0] == DerTag.sequence) {
    try {
      final c = Tlv.decode(signature).children;
      if (c.length == 2) {
        return ECSignature(decodeInteger(c[0]), decodeInteger(c[1]));
      }
    } on LdsFormatException {
      // Fall through to the plain form.
    }
  }
  final half = signature.length ~/ 2;
  return ECSignature(
    bytesToBigInt(signature.sublist(0, half)),
    bytesToBigInt(signature.sublist(half)),
  );
}

sealed class _Scheme {
  const _Scheme(this.hash);
  final HashAlgorithm hash;
}

final class _Pkcs1 extends _Scheme {
  const _Pkcs1(super.hash);
}

final class _Pss extends _Scheme {
  const _Pss(super.hash, this.mgfHash, this.saltLength);
  final HashAlgorithm mgfHash;
  final int saltLength;
}

final class _Ecdsa extends _Scheme {
  const _Ecdsa(super.hash);
}

const Map<String, HashAlgorithm> _pkcs1 = {
  '1.2.840.113549.1.1.5': HashAlgorithm.sha1,
  '1.2.840.113549.1.1.14': HashAlgorithm.sha224,
  '1.2.840.113549.1.1.11': HashAlgorithm.sha256,
  '1.2.840.113549.1.1.12': HashAlgorithm.sha384,
  '1.2.840.113549.1.1.13': HashAlgorithm.sha512,
};

const Map<String, HashAlgorithm> _ecdsa = {
  '1.2.840.10045.4.1': HashAlgorithm.sha1,
  '1.2.840.10045.4.3.1': HashAlgorithm.sha224,
  '1.2.840.10045.4.3.2': HashAlgorithm.sha256,
  '1.2.840.10045.4.3.3': HashAlgorithm.sha384,
  '1.2.840.10045.4.3.4': HashAlgorithm.sha512,
  // BSI TR-03111 ecdsa-plain-SHA*.
  '0.4.0.127.0.7.1.1.4.1.1': HashAlgorithm.sha1,
  '0.4.0.127.0.7.1.1.4.1.2': HashAlgorithm.sha224,
  '0.4.0.127.0.7.1.1.4.1.3': HashAlgorithm.sha256,
  '0.4.0.127.0.7.1.1.4.1.4': HashAlgorithm.sha384,
  '0.4.0.127.0.7.1.1.4.1.5': HashAlgorithm.sha512,
};

_Scheme _scheme(AlgorithmIdentifier alg, HashAlgorithm? digest) {
  HashAlgorithm needDigest() =>
      digest ??
      (throw LdsFormatException('${alg.oid} requires a digest algorithm'));
  if (_pkcs1[alg.oid] case final h?) return _Pkcs1(h);
  if (_ecdsa[alg.oid] case final h?) return _Ecdsa(h);
  return switch (alg.oid) {
    Oids.rsaEncryption => _Pkcs1(needDigest()),
    Oids.ecPublicKey => _Ecdsa(needDigest()),
    Oids.rsaPss => _pssParams(alg.parameters),
    _ => throw LdsFormatException('Unsupported signature algorithm ${alg.oid}'),
  };
}

_Pss _pssParams(Tlv? params) {
  var hash = HashAlgorithm.sha1;
  var mgfHash = HashAlgorithm.sha1;
  var salt = 20;
  for (final c in params?.children ?? const <Tlv>[]) {
    final inner = c.children.first;
    switch (c.tag) {
      case 0xA0:
        hash = HashAlgorithm.forOid(AlgorithmIdentifier.parse(inner).oid);
      case 0xA1:
        final mgf = AlgorithmIdentifier.parse(inner);
        if (mgf.oid != Oids.mgf1 || mgf.parameters == null) {
          throw const LdsFormatException('Only MGF1 is supported');
        }
        mgfHash = HashAlgorithm.forOid(
          AlgorithmIdentifier.parse(mgf.parameters!).oid,
        );
      case 0xA2:
        salt = decodeInteger(inner).toInt();
    }
  }
  return _Pss(hash, mgfHash, salt);
}
