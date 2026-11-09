import 'dart:convert';
import 'dart:typed_data';

import 'package:icao_mrtd/src/errors.dart';
import 'package:icao_mrtd/src/pa/algorithms.dart';
import 'package:icao_mrtd/src/pa/der.dart';
import 'package:icao_mrtd/src/tlv.dart';
import 'package:meta/meta.dart';

/// The parts of an X.509 certificate that Passive Authentication needs.
@immutable
class X509Certificate {
  const X509Certificate._({
    required this.encoded,
    required this.tbs,
    required this.signatureAlgorithm,
    required this.signature,
    required this.serialNumber,
    required this.issuer,
    required this.subject,
    required this.notBefore,
    required this.notAfter,
    required this.publicKey,
    this.subjectKeyIdentifier,
    this.authorityKeyIdentifier,
  });

  /// Parses a DER encoded certificate.
  factory X509Certificate.fromDer(Uint8List der) {
    try {
      return X509Certificate._fromTlv(Tlv.decode(der));
    } on LdsFormatException {
      rethrow;
    } on Object {
      throw const LdsFormatException('Malformed X.509 certificate');
    }
  }

  factory X509Certificate._fromTlv(Tlv cert) {
    final parts = expectTag(cert, DerTag.sequence, 'Certificate').children;
    final tbs = parts[0];
    var fields = tbs.children;
    if (fields.first.tag == DerTag.context(0)) fields = fields.sublist(1);
    final validity = fields[3].children;
    Uint8List? ski;
    Uint8List? aki;
    final extensions = fields.where((f) => f.tag == DerTag.context(3));
    if (extensions.isNotEmpty) {
      for (final ext in extensions.first.children.first.children) {
        final c = ext.children;
        final oid = decodeOid(c[0]);
        final value = Tlv.decode(c.last.value);
        if (oid == Oids.subjectKeyIdentifier) {
          ski = value.value;
        } else if (oid == Oids.authorityKeyIdentifier) {
          for (final a in value.children) {
            if (a.tag == 0x80) aki = a.value;
          }
        }
      }
    }
    return X509Certificate._(
      encoded: cert.encoded,
      tbs: tbs.encoded,
      signatureAlgorithm: AlgorithmIdentifier.parse(parts[1]),
      signature: decodeBitString(parts[2]),
      serialNumber: decodeInteger(fields[0]),
      issuer: DistinguishedName._(fields[2]),
      subject: DistinguishedName._(fields[4]),
      notBefore: decodeTime(validity[0]),
      notAfter: decodeTime(validity[1]),
      publicKey: PublicKeyInfo.parse(fields[5]),
      subjectKeyIdentifier: ski,
      authorityKeyIdentifier: aki,
    );
  }

  /// Parses every certificate in a PEM string.
  static List<X509Certificate> fromPem(String pem) {
    final matches = RegExp(
      '-----BEGIN CERTIFICATE-----([^-]+)-----END CERTIFICATE-----',
    ).allMatches(pem);
    return [
      for (final m in matches)
        X509Certificate.fromDer(
          base64.decode(m[1]!.replaceAll(RegExp(r'\s'), '')),
        ),
    ];
  }

  /// The complete DER encoding.
  final Uint8List encoded;

  /// The DER encoding of the signed `TBSCertificate`.
  final Uint8List tbs;

  /// The algorithm the issuer signed with.
  final AlgorithmIdentifier signatureAlgorithm;

  /// The issuer's signature.
  final Uint8List signature;

  /// The serial number.
  final BigInt serialNumber;

  /// The issuer name.
  final DistinguishedName issuer;

  /// The subject name.
  final DistinguishedName subject;

  /// Start of validity (UTC).
  final DateTime notBefore;

  /// End of validity (UTC).
  final DateTime notAfter;

  /// The subject public key.
  final PublicKeyInfo publicKey;

  /// The subject key identifier extension, if present.
  final Uint8List? subjectKeyIdentifier;

  /// The key identifier from the authority key identifier extension.
  final Uint8List? authorityKeyIdentifier;

  /// Whether [at] lies inside the validity period.
  bool isValidAt(DateTime at) =>
      !at.isBefore(notBefore) && !at.isAfter(notAfter);

  /// Whether [issuerCertificate]'s key verifies this certificate's
  /// signature.
  bool isSignedBy(X509Certificate issuerCertificate) => verifySignature(
    algorithm: signatureAlgorithm,
    key: issuerCertificate.publicKey,
    message: tbs,
    signature: signature,
  );

  @override
  String toString() => 'X509Certificate($subject)';
}

/// An X.501 distinguished name.
@immutable
class DistinguishedName {
  DistinguishedName._(Tlv name) : encoded = name.encoded {
    for (final rdn in name.children) {
      for (final atv in rdn.children) {
        final c = atv.children;
        _attributes.add((decodeOid(c[0]), _string(c[1])));
      }
    }
  }

  /// The DER encoding, used for exact matching.
  final Uint8List encoded;

  final List<(String, String)> _attributes = [];

  static const _short = {
    '2.5.4.3': 'CN',
    '2.5.4.5': 'SERIALNUMBER',
    '2.5.4.6': 'C',
    '2.5.4.7': 'L',
    '2.5.4.10': 'O',
    '2.5.4.11': 'OU',
  };

  static String _string(Tlv v) {
    try {
      return utf8.decode(v.value);
    } on FormatException {
      return latin1.decode(v.value);
    }
  }

  /// The value of the first attribute with [oid], for example `2.5.4.6`
  /// for the country.
  String? attribute(String oid) {
    for (final (o, v) in _attributes) {
      if (o == oid) return v;
    }
    return null;
  }

  /// The country code (`C`), if present.
  String? get country => attribute('2.5.4.6');

  @override
  bool operator ==(Object other) =>
      other is DistinguishedName && bytesEqual(other.encoded, encoded);

  @override
  int get hashCode => Object.hashAll(encoded);

  @override
  String toString() =>
      _attributes.map((a) => '${_short[a.$1] ?? a.$1}=${a.$2}').join(', ');
}

/// Whether [a] and [b] hold the same bytes.
bool bytesEqual(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
