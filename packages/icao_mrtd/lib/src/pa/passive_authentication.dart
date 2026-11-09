import 'dart:typed_data';

import 'package:icao_mrtd/src/crypto/des.dart';
import 'package:icao_mrtd/src/errors.dart';
import 'package:icao_mrtd/src/pa/algorithms.dart';
import 'package:icao_mrtd/src/pa/der.dart';
import 'package:icao_mrtd/src/pa/ef_sod.dart';
import 'package:icao_mrtd/src/pa/x509.dart';
import 'package:icao_mrtd/src/tlv.dart';
import 'package:meta/meta.dart';

/// Trusted Country Signing CA certificates.
///
/// Load the certificates of the states you accept, for example from the
/// ICAO PKD or a national master list. Without a trust anchor, Passive
/// Authentication can prove that the chip data is internally consistent
/// but not that a state issued it.
class CscaStore {
  /// Creates a store from [certificates].
  CscaStore(Iterable<X509Certificate> certificates)
    : certificates = List.unmodifiable(certificates);

  /// An empty store; every result will be [PassiveAuthStatus.untrusted]
  /// at best.
  CscaStore.empty() : certificates = const [];

  /// Extracts the CSCA certificates from an ICAO CSCA master list
  /// (ICAO 9303-12, 9).
  ///
  /// The master list signature is not verified here: verify the file's
  /// origin (for example its download channel or signer) before trusting
  /// it.
  factory CscaStore.fromMasterList(Uint8List bytes) {
    final signed = SignedData.parse(Tlv.decode(bytes));
    if (signed.contentType != Oids.cscaMasterList) {
      throw const LdsFormatException('Not a CSCA master list');
    }
    final list = Tlv.decode(signed.content).children;
    return CscaStore([
      for (final c in list[1].children) X509Certificate.fromDer(c.encoded),
    ]);
  }

  /// The trusted certificates.
  final List<X509Certificate> certificates;

  /// Certificates whose subject is [issuer], preferring a key identifier
  /// match when [keyId] is given.
  List<X509Certificate> candidatesFor(
    DistinguishedName issuer,
    Uint8List? keyId,
  ) {
    final byName = certificates.where((c) => c.subject == issuer).toList();
    if (keyId == null) return byName;
    return byName..sort((a, b) {
      bool matches(X509Certificate c) =>
          c.subjectKeyIdentifier != null &&
          bytesEqual(c.subjectKeyIdentifier!, keyId);
      return (matches(b) ? 1 : 0) - (matches(a) ? 1 : 0);
    });
  }
}

/// A reason Passive Authentication did not fully succeed.
enum PassiveAuthFailure {
  /// The signed attributes do not declare an LDS security object.
  contentType,

  /// The messageDigest attribute does not match the LDS security object.
  messageDigest,

  /// No certificate in EF.SOD or in the supplied list matches the signer.
  signerCertificateMissing,

  /// The Document Signer signature over EF.SOD is invalid.
  signature,

  /// A data group read from the chip does not match its hash in EF.SOD.
  dataGroupHash,

  /// A data group was read but EF.SOD holds no hash for it.
  dataGroupNotInSod,

  /// The Document Signer certificate is outside its validity period.
  signerCertificateExpired,

  /// No trusted CSCA certificate matches the Document Signer's issuer.
  trustAnchorMissing,

  /// No matching CSCA key verifies the Document Signer certificate.
  chainSignature,

  /// The CSCA certificate is outside its validity period.
  trustAnchorExpired,
}

/// The overall outcome of Passive Authentication.
enum PassiveAuthStatus {
  /// Data groups, signature and certificate chain are all valid.
  verified,

  /// The chip data is consistent and correctly signed, but the signer
  /// could not be traced to a trusted CSCA. Do not treat it as proof of
  /// authenticity.
  untrusted,

  /// The data or its signature is invalid. Treat the document as forged
  /// or damaged.
  failed,
}

/// The result of [verifyPassiveAuthentication].
@immutable
class PassiveAuthResult {
  const PassiveAuthResult._(
    this.failures,
    this.dataGroups,
    this.signerCertificate,
    this.trustAnchor,
  );

  /// Every failed check. Empty when the document is verified.
  final Set<PassiveAuthFailure> failures;

  /// Hash check result for each data group that was supplied.
  final Map<int, bool> dataGroups;

  /// The Document Signer certificate, when found.
  final X509Certificate? signerCertificate;

  /// The CSCA certificate that issued it, when found and valid.
  final X509Certificate? trustAnchor;

  /// The summary status.
  PassiveAuthStatus get status {
    if (failures.isEmpty) return PassiveAuthStatus.verified;
    const trustOnly = {
      PassiveAuthFailure.trustAnchorMissing,
      PassiveAuthFailure.trustAnchorExpired,
    };
    return failures.every(trustOnly.contains)
        ? PassiveAuthStatus.untrusted
        : PassiveAuthStatus.failed;
  }

  @override
  String toString() => 'PassiveAuthResult(${status.name}, $failures)';
}

/// Performs Passive Authentication (ICAO 9303-11, 5.1).
///
/// [dataGroups] maps data group numbers to the raw files read from the
/// chip. Every supplied group must be listed in EF.SOD and match its hash;
/// groups in EF.SOD that were not read are not required.
///
/// The Document Signer certificate is taken from EF.SOD, or from
/// [signerCertificates] for states that do not embed it. Validity is
/// checked at [at] (default: now). Certificate revocation is not checked.
PassiveAuthResult verifyPassiveAuthentication({
  required EfSod sod,
  required Map<int, Uint8List> dataGroups,
  required CscaStore trustStore,
  Iterable<X509Certificate> signerCertificates = const [],
  DateTime? at,
}) {
  final now = (at ?? DateTime.now()).toUtc();
  final failures = <PassiveAuthFailure>{};
  final signer = sod.signedData.signerInfos.first;

  // 1. Data group hashes.
  final dgResults = <int, bool>{};
  for (final MapEntry(key: number, value: bytes) in dataGroups.entries) {
    final expected = sod.dataGroupHashes[number];
    if (expected == null) {
      failures.add(PassiveAuthFailure.dataGroupNotInSod);
      dgResults[number] = false;
      continue;
    }
    final ok = constantTimeEquals(sod.hashAlgorithm.hash(bytes), expected);
    dgResults[number] = ok;
    if (!ok) failures.add(PassiveAuthFailure.dataGroupHash);
  }

  // 2. Signed attributes bind the signature to the LDS security object.
  final contentType = signer.signedAttributes[Oids.contentType];
  if (contentType == null || decodeOid(contentType) != Oids.ldsSecurityObject) {
    failures.add(PassiveAuthFailure.contentType);
  }
  final digest = signer.signedAttributes[Oids.messageDigest];
  if (digest == null ||
      !constantTimeEquals(
        signer.digestAlgorithm.hash(sod.signedData.content),
        digest.value,
      )) {
    failures.add(PassiveAuthFailure.messageDigest);
  }

  // 3. Document Signer signature.
  final candidates = [...sod.signedData.certificates, ...signerCertificates];
  X509Certificate? ds;
  for (final c in candidates) {
    if (signer.identifies(c)) {
      ds = c;
      break;
    }
  }
  if (ds == null) {
    failures.add(PassiveAuthFailure.signerCertificateMissing);
    return PassiveAuthResult._(
      Set.unmodifiable(failures),
      Map.unmodifiable(dgResults),
      null,
      null,
    );
  }
  final signedBytes = signer.signedAttributesDer ?? sod.signedData.content;
  if (!verifySignature(
    algorithm: signer.signatureAlgorithm,
    key: ds.publicKey,
    message: signedBytes,
    signature: signer.signature,
    digest: signer.digestAlgorithm,
  )) {
    failures.add(PassiveAuthFailure.signature);
  }
  if (!ds.isValidAt(now)) {
    failures.add(PassiveAuthFailure.signerCertificateExpired);
  }

  // 4. Certificate chain to a trusted CSCA.
  X509Certificate? anchor;
  final cscas = trustStore.candidatesFor(ds.issuer, ds.authorityKeyIdentifier);
  if (cscas.isEmpty) {
    failures.add(PassiveAuthFailure.trustAnchorMissing);
  } else {
    for (final csca in cscas) {
      if (ds.isSignedBy(csca)) {
        anchor = csca;
        break;
      }
    }
    if (anchor == null) {
      failures.add(PassiveAuthFailure.chainSignature);
    } else if (!anchor.isValidAt(now)) {
      failures.add(PassiveAuthFailure.trustAnchorExpired);
    }
  }

  return PassiveAuthResult._(
    Set.unmodifiable(failures),
    Map.unmodifiable(dgResults),
    ds,
    anchor,
  );
}
