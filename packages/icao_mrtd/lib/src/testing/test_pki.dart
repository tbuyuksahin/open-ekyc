import 'dart:typed_data';

import 'package:icao_mrtd/src/pa/algorithms.dart';
import 'package:icao_mrtd/src/pa/der.dart';
import 'package:icao_mrtd/src/pa/x509.dart';
import 'package:icao_mrtd/src/testing/der_writer.dart';
import 'package:pointycastle/ecc/ecc_fp.dart' as fp;
import 'package:pointycastle/export.dart';

/// Key types supported by [TestPki].
enum TestKeyType {
  /// RSA 2048 with PKCS #1 v1.5 and SHA-256.
  rsa,

  /// ECDSA on P-256 with SHA-256, named curve.
  ecdsaP256,

  /// ECDSA on brainpoolP256r1 with SHA-256, explicit domain parameters as
  /// many real passports use.
  ecdsaBrainpoolExplicit,
}

/// A signing key with the matching certificate.
class TestIdentity {
  TestIdentity._(this.certificate, this._private, this.type);

  /// The certificate.
  final X509Certificate certificate;
  final PrivateKey _private;

  /// The key type.
  final TestKeyType type;

  /// The OID to put in SignerInfo.signatureAlgorithm.
  String get signatureOid =>
      type == TestKeyType.rsa ? '1.2.840.113549.1.1.11' : '1.2.840.10045.4.3.2';

  /// Signs [message] with SHA-256.
  Uint8List sign(Uint8List message) => _sign(_private, type, message);
}

final _random = FortunaRandom()
  ..seed(KeyParameter(Uint8List.fromList(List.generate(32, (i) => i * 7))));

/// A throw-away CSCA and Document Signer hierarchy for tests.
///
/// Nothing produced here is trusted by real verifiers.
class TestPki {
  /// Creates a CSCA and a Document Signer for country `UTO` (Utopia).
  factory TestPki({
    TestKeyType cscaKey = TestKeyType.rsa,
    TestKeyType signerKey = TestKeyType.ecdsaP256,
    DateTime? notBefore,
    DateTime? notAfter,
    DateTime? signerNotAfter,
  }) {
    final from = notBefore ?? DateTime.utc(2020);
    final to = notAfter ?? DateTime.utc(2040);
    final cscaName = Der.name(country: 'UT', cn: 'Utopia Test CSCA');
    final cscaPair = _generate(cscaKey);
    final cscaSki = Uint8List.fromList(List.generate(20, (i) => i + 1));
    final cscaCert = _certificate(
      serial: 1,
      issuer: cscaName,
      subject: cscaName,
      from: from,
      to: to,
      subjectKey: cscaPair.publicKey,
      subjectType: cscaKey,
      signerKey: cscaPair.privateKey,
      signerType: cscaKey,
      ski: cscaSki,
    );
    final dsPair = _generate(signerKey);
    final dsCert = _certificate(
      serial: 2,
      issuer: cscaName,
      subject: Der.name(country: 'UT', cn: 'Utopia Test Document Signer'),
      from: from,
      to: signerNotAfter ?? to,
      subjectKey: dsPair.publicKey,
      subjectType: signerKey,
      signerKey: cscaPair.privateKey,
      signerType: cscaKey,
      aki: cscaSki,
    );
    return TestPki._(
      TestIdentity._(cscaCert, cscaPair.privateKey, cscaKey),
      TestIdentity._(dsCert, dsPair.privateKey, signerKey),
    );
  }

  TestPki._(this.csca, this.documentSigner);

  /// The self-signed root.
  final TestIdentity csca;

  /// The Document Signer issued by [csca].
  final TestIdentity documentSigner;
}

AsymmetricKeyPair<PublicKey, PrivateKey> _generate(TestKeyType type) {
  if (type == TestKeyType.rsa) {
    final gen = RSAKeyGenerator()
      ..init(
        ParametersWithRandom(
          RSAKeyGeneratorParameters(BigInt.from(65537), 2048, 64),
          _random,
        ),
      );
    return gen.generateKeyPair();
  }
  final domain = ECDomainParameters(
    type == TestKeyType.ecdsaP256 ? 'secp256r1' : 'brainpoolp256r1',
  );
  final gen = ECKeyGenerator()
    ..init(ParametersWithRandom(ECKeyGeneratorParameters(domain), _random));
  return gen.generateKeyPair();
}

Uint8List _spki(PublicKey key, TestKeyType type) {
  switch (key) {
    case RSAPublicKey(:final modulus, :final exponent):
      return Der.seq([
        Der.algorithm(Oids.rsaEncryption, Der.nullValue),
        Der.bits(Der.seq([Der.integer(modulus!), Der.integer(exponent!)])),
      ]);
    case ECPublicKey(:final Q, :final parameters):
      final point = Q!.getEncoded(false);
      final List<int> params;
      if (type == TestKeyType.ecdsaP256) {
        params = Der.oid('1.2.840.10045.3.1.7');
      } else {
        final d = parameters!;
        final size = (d.curve.fieldSize + 7) ~/ 8;
        final p = (d.curve as fp.ECCurve).q!;
        params = Der.seq([
          Der.smallInt(1),
          Der.seq([Der.oid(Oids.primeField), Der.integer(p)]),
          Der.seq([
            Der.octets(bigIntToBytes(d.curve.a!.toBigInteger()!, size)),
            Der.octets(bigIntToBytes(d.curve.b!.toBigInteger()!, size)),
          ]),
          Der.octets(d.G.getEncoded(false)),
          Der.integer(d.n),
          Der.smallInt(1),
        ]);
      }
      return Der.seq([
        Der.algorithm(Oids.ecPublicKey, params),
        Der.bits(point),
      ]);
    default:
      throw ArgumentError('Unsupported key');
  }
}

Uint8List _sign(PrivateKey key, TestKeyType type, Uint8List message) {
  if (key is RSAPrivateKey) {
    final signer = RSASigner(SHA256Digest(), '0609608648016503040201')
      ..init(true, PrivateKeyParameter<RSAPrivateKey>(key));
    return signer.generateSignature(message).bytes;
  }
  final signer = ECDSASigner(SHA256Digest())
    ..init(
      true,
      ParametersWithRandom(
        PrivateKeyParameter<ECPrivateKey>(key as ECPrivateKey),
        _random,
      ),
    );
  final sig = signer.generateSignature(message) as ECSignature;
  return Der.seq([Der.integer(sig.r), Der.integer(sig.s)]);
}

X509Certificate _certificate({
  required int serial,
  required Uint8List issuer,
  required Uint8List subject,
  required DateTime from,
  required DateTime to,
  required PublicKey subjectKey,
  required TestKeyType subjectType,
  required PrivateKey signerKey,
  required TestKeyType signerType,
  Uint8List? ski,
  Uint8List? aki,
}) {
  final sigAlg = Der.algorithm(
    signerType == TestKeyType.rsa
        ? '1.2.840.113549.1.1.11'
        : '1.2.840.10045.4.3.2',
  );
  final extensions = [
    if (ski != null)
      Der.seq([
        Der.oid(Oids.subjectKeyIdentifier),
        Der.octets(Der.octets(ski)),
      ]),
    if (aki != null)
      Der.seq([
        Der.oid(Oids.authorityKeyIdentifier),
        Der.octets(Der.seq([encodeContext0(aki)])),
      ]),
  ];
  final tbs = Der.seq([
    Der.explicit(0, Der.smallInt(2)),
    Der.smallInt(serial),
    sigAlg,
    issuer,
    Der.seq([Der.utcTime(from), Der.utcTime(to)]),
    subject,
    _spki(subjectKey, subjectType),
    if (extensions.isNotEmpty) Der.explicit(3, Der.seq(extensions)),
  ]);
  final signature = _sign(signerKey, signerType, tbs);
  return X509Certificate.fromDer(
    Der.seq([tbs, sigAlg, Der.bits(signature)]),
  );
}

/// `[0] IMPLICIT OCTET STRING` as used in AuthorityKeyIdentifier.
Uint8List encodeContext0(List<int> value) =>
    Uint8List.fromList([0x80, value.length, ...value]);
