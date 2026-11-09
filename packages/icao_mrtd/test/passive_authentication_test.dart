import 'dart:convert';
import 'dart:typed_data';

import 'package:icao_mrtd/icao_mrtd.dart';
import 'package:icao_mrtd/testing.dart';
import 'package:test/test.dart';

import 'fixtures.dart';

void main() {
  final at = DateTime.utc(2026, 11, 9);

  Map<int, Uint8List> groups(Document d) => {
    1: d.files[LdsFile.dg1]!,
    2: d.files[LdsFile.dg2]!,
    11: d.files[LdsFile.dg11]!,
  };

  PassiveAuthResult verify(
    Document d, {
    Map<int, Uint8List>? dataGroups,
    CscaStore? store,
    Uint8List? sod,
    DateTime? when,
  }) => verifyPassiveAuthentication(
    sod: EfSod.parse(sod ?? d.files[LdsFile.sod]!),
    dataGroups: dataGroups ?? groups(d),
    trustStore: store ?? CscaStore([d.pki.csca.certificate]),
    at: when ?? at,
  );

  group('verifies documents signed with', () {
    for (final (csca, ds) in [
      (TestKeyType.rsa, TestKeyType.rsa),
      (TestKeyType.rsa, TestKeyType.ecdsaP256),
      (TestKeyType.ecdsaP256, TestKeyType.ecdsaBrainpoolExplicit),
    ]) {
      test('${csca.name} CSCA and ${ds.name} document signer', () {
        final d = Document(
          pki: TestPki(cscaKey: csca, signerKey: ds),
        );
        final result = verify(d);
        expect(result.status, PassiveAuthStatus.verified, reason: '$result');
        expect(result.dataGroups, {1: true, 2: true, 11: true});
        expect(result.trustAnchor, isNotNull);
        expect(result.signerCertificate?.subject.country, 'UT');
      });
    }
  });

  late Document doc;
  setUpAll(() => doc = Document());

  test('EF.SOD exposes its hashes and algorithm', () {
    final sod = EfSod.parse(doc.files[LdsFile.sod]!);
    expect(sod.hashAlgorithm, HashAlgorithm.sha256);
    expect(sod.dataGroupHashes.keys, unorderedEquals([1, 2, 11]));
    expect(sod.signedData.certificates, hasLength(1));
  });

  test('detects a modified data group', () {
    final dg1 = Uint8List.fromList(doc.files[LdsFile.dg1]!);
    dg1[10] ^= 0x01;
    final result = verify(doc, dataGroups: {...groups(doc), 1: dg1});
    expect(result.status, PassiveAuthStatus.failed);
    expect(result.failures, {PassiveAuthFailure.dataGroupHash});
    expect(result.dataGroups[1], isFalse);
    expect(result.dataGroups[2], isTrue);
  });

  test('detects a data group that EF.SOD does not cover', () {
    final result = verify(
      doc,
      dataGroups: {
        ...groups(doc),
        7: Uint8List.fromList([0x67, 0]),
      },
    );
    expect(result.failures, contains(PassiveAuthFailure.dataGroupNotInSod));
  });

  test('detects an invalid document signer signature', () {
    final sod = LdsBuilder.sod(
      dataGroups: groups(doc),
      signer: doc.pki.documentSigner,
      corruptSignature: true,
    );
    expect(
      verify(doc, sod: sod).failures,
      {PassiveAuthFailure.signature},
    );
  });

  test('detects a messageDigest that does not match the content', () {
    final sod = LdsBuilder.sod(
      dataGroups: groups(doc),
      signer: doc.pki.documentSigner,
      corruptMessageDigest: true,
    );
    expect(
      verify(doc, sod: sod).failures,
      contains(PassiveAuthFailure.messageDigest),
    );
  });

  test('is untrusted, not verified, without a CSCA', () {
    final result = verify(doc, store: CscaStore.empty());
    expect(result.status, PassiveAuthStatus.untrusted);
    expect(result.failures, {PassiveAuthFailure.trustAnchorMissing});
  });

  test('rejects a CSCA with the right name but the wrong key', () {
    final impostor = TestPki();
    final result = verify(
      doc,
      store: CscaStore([impostor.csca.certificate]),
    );
    expect(result.status, PassiveAuthStatus.failed);
    expect(result.failures, {PassiveAuthFailure.chainSignature});
  });

  test('checks certificate validity at the given time', () {
    expect(
      verify(doc, when: DateTime.utc(2041)).failures,
      {
        PassiveAuthFailure.signerCertificateExpired,
        PassiveAuthFailure.trustAnchorExpired,
      },
    );
  });

  test('accepts an external document signer certificate', () {
    final sod = LdsBuilder.sod(
      dataGroups: groups(doc),
      signer: doc.pki.documentSigner,
      includeCertificate: false,
    );
    expect(
      verify(doc, sod: sod).failures,
      {PassiveAuthFailure.signerCertificateMissing},
    );
    final result = verifyPassiveAuthentication(
      sod: EfSod.parse(sod),
      dataGroups: groups(doc),
      trustStore: CscaStore([doc.pki.csca.certificate]),
      signerCertificates: [doc.pki.documentSigner.certificate],
      at: at,
    );
    expect(result.status, PassiveAuthStatus.verified);
  });

  test('rejects malformed EF.SOD files', () {
    expect(
      () => EfSod.parse(Uint8List.fromList([0x77, 0x02, 0x30, 0x00])),
      throwsA(isA<LdsFormatException>()),
    );
    expect(
      () => EfSod.parse(doc.files[LdsFile.dg1]!),
      throwsA(isA<LdsFormatException>()),
    );
  });

  test('parses certificates from PEM', () {
    final der = doc.pki.csca.certificate.encoded;
    final b64 = base64.encode(der);
    final pem = '-----BEGIN CERTIFICATE-----\n$b64\n-----END CERTIFICATE-----';
    final certs = X509Certificate.fromPem(pem);
    expect(certs.single.subject, doc.pki.csca.certificate.subject);
    expect(certs.single.subject.toString(), contains('CN=Utopia Test CSCA'));
  });
}
