import 'dart:typed_data';

import 'package:icao_mrtd/src/errors.dart';
import 'package:icao_mrtd/src/lds/lds_file.dart';
import 'package:icao_mrtd/src/pa/algorithms.dart';
import 'package:icao_mrtd/src/pa/der.dart';
import 'package:icao_mrtd/src/pa/x509.dart';
import 'package:icao_mrtd/src/tlv.dart';
import 'package:meta/meta.dart';

/// A CMS `SignedData` structure (RFC 5652), as used by EF.SOD and CSCA
/// master lists.
@immutable
class SignedData {
  const SignedData._({
    required this.contentType,
    required this.content,
    required this.certificates,
    required this.signerInfos,
  });

  /// Parses a DER `ContentInfo` holding signed data.
  factory SignedData.parse(Tlv contentInfo) {
    final ci = expectTag(contentInfo, DerTag.sequence, 'ContentInfo').children;
    if (decodeOid(ci[0]) != Oids.signedData) {
      throw const LdsFormatException('ContentInfo is not signed data');
    }
    final sd = expectTag(
      ci[1],
      DerTag.context(0),
      'ContentInfo content',
    ).children.first.children;
    final encap = sd[2].children;
    final eContent = expectTag(
      encap[1],
      DerTag.context(0),
      'eContent',
    ).children.first;
    final certs = <X509Certificate>[];
    var signerIndex = 3;
    if (sd[3].tag == DerTag.context(0)) {
      for (final c in sd[3].children) {
        if (c.tag == DerTag.sequence) {
          certs.add(X509Certificate.fromDer(c.encoded));
        }
      }
      signerIndex = 4;
    }
    if (sd[signerIndex].tag == DerTag.context(1)) signerIndex++;
    final signers = [
      for (final s in sd[signerIndex].children) SignerInfo._parse(s),
    ];
    if (signers.isEmpty) throw const LdsFormatException('No signer info');
    return SignedData._(
      contentType: decodeOid(encap[0]),
      content: expectTag(eContent, DerTag.octetString, 'eContent').value,
      certificates: List.unmodifiable(certs),
      signerInfos: List.unmodifiable(signers),
    );
  }

  /// The OID of the encapsulated content.
  final String contentType;

  /// The encapsulated content bytes (the signed payload).
  final Uint8List content;

  /// Certificates embedded in the structure.
  final List<X509Certificate> certificates;

  /// The signers.
  final List<SignerInfo> signerInfos;
}

/// A CMS `SignerInfo`.
@immutable
class SignerInfo {
  const SignerInfo._({
    required this.digestAlgorithm,
    required this.signatureAlgorithm,
    required this.signature,
    required this.signedAttributes,
    required this.signedAttributesDer,
    this.issuer,
    this.serialNumber,
    this.subjectKeyIdentifier,
  });

  factory SignerInfo._parse(Tlv tlv) {
    final c = tlv.children;
    final sid = c[1];
    var i = 2;
    final digest = AlgorithmIdentifier.parse(c[i++]);
    Tlv? attrs;
    if (c[i].tag == DerTag.context(0)) attrs = c[i++];
    final sigAlg = AlgorithmIdentifier.parse(c[i++]);
    final signature = expectTag(c[i], DerTag.octetString, 'signature').value;
    final attributes = <String, Tlv>{};
    for (final a in attrs?.children ?? const <Tlv>[]) {
      final parts = a.children;
      attributes[decodeOid(parts[0])] = parts[1].children.first;
    }
    return SignerInfo._(
      digestAlgorithm: HashAlgorithm.forOid(digest.oid),
      signatureAlgorithm: sigAlg,
      signature: signature,
      signedAttributes: Map.unmodifiable(attributes),
      // The signature covers the attributes encoded as a SET (tag 31), not
      // the implicit [0] tag they are stored under.
      signedAttributesDer: attrs == null
          ? null
          : (Uint8List.fromList(attrs.encoded)..[0] = DerTag.set),
      issuer: sid.tag == DerTag.sequence ? sid.children[0].encoded : null,
      serialNumber: sid.tag == DerTag.sequence
          ? decodeInteger(sid.children[1])
          : null,
      subjectKeyIdentifier: sid.tag == 0x80 ? sid.value : null,
    );
  }

  /// Digest algorithm for the content and signed attributes.
  final HashAlgorithm digestAlgorithm;

  /// Signature algorithm.
  final AlgorithmIdentifier signatureAlgorithm;

  /// The signature value.
  final Uint8List signature;

  /// Signed attributes by OID (first value of each).
  final Map<String, Tlv> signedAttributes;

  /// The DER bytes the signature covers, or `null` without attributes.
  final Uint8List? signedAttributesDer;

  /// Issuer name of the signer certificate (issuerAndSerialNumber form).
  final Uint8List? issuer;

  /// Serial number of the signer certificate.
  final BigInt? serialNumber;

  /// Subject key identifier of the signer certificate (SKI form).
  final Uint8List? subjectKeyIdentifier;

  /// Whether [certificate] is the one this signer identifies.
  bool identifies(X509Certificate certificate) {
    if (subjectKeyIdentifier case final ski?) {
      final certSki = certificate.subjectKeyIdentifier;
      return certSki != null && bytesEqual(certSki, ski);
    }
    return issuer != null &&
        bytesEqual(certificate.issuer.encoded, issuer!) &&
        certificate.serialNumber == serialNumber;
  }
}

/// EF.SOD: the document security object (ICAO 9303-10, 4.6.2).
@immutable
class EfSod {
  const EfSod._(
    this.encoded,
    this.signedData,
    this.hashAlgorithm,
    this.dataGroupHashes,
  );

  /// Parses the raw contents of EF.SOD.
  factory EfSod.parse(Uint8List bytes) {
    try {
      final root = Tlv.decode(bytes);
      if (root.tag != LdsFile.sod.tag) {
        throw const LdsFormatException('EF.SOD must start with tag 77');
      }
      final signed = SignedData.parse(root.children.first);
      if (signed.contentType != Oids.ldsSecurityObject) {
        throw const LdsFormatException('EF.SOD does not hold an LDS object');
      }
      final lds = Tlv.decode(signed.content).children;
      final hashes = <int, Uint8List>{};
      for (final entry in lds[2].children) {
        final c = entry.children;
        hashes[decodeInteger(c[0]).toInt()] = expectTag(
          c[1],
          DerTag.octetString,
          'dataGroupHashValue',
        ).value;
      }
      return EfSod._(
        bytes,
        signed,
        HashAlgorithm.forOid(AlgorithmIdentifier.parse(lds[1]).oid),
        Map.unmodifiable(hashes),
      );
    } on LdsFormatException {
      rethrow;
    } on Object {
      throw const LdsFormatException('Malformed EF.SOD');
    }
  }

  /// The raw file.
  final Uint8List encoded;

  /// The CMS structure.
  final SignedData signedData;

  /// Hash algorithm of the data group hashes.
  final HashAlgorithm hashAlgorithm;

  /// Expected hash of every data group, by number.
  final Map<int, Uint8List> dataGroupHashes;
}
