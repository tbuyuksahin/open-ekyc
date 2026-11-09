import 'dart:typed_data';

import 'package:icao_mrtd/icao_mrtd.dart';
import 'package:icao_mrtd/src/pa/algorithms.dart';
import 'package:icao_mrtd/src/pa/der.dart';
import 'package:icao_mrtd/src/testing/der_writer.dart';
import 'package:icao_mrtd/testing.dart';
import 'package:pointycastle/export.dart';
import 'package:test/test.dart';

final _random = FortunaRandom()..seed(KeyParameter(Uint8List(32)));

void main() {
  final message = Uint8List.fromList(List.generate(100, (i) => i));

  group('RSASSA-PSS', () {
    late AsymmetricKeyPair<RSAPublicKey, RSAPrivateKey> pair;
    setUpAll(() {
      final gen = RSAKeyGenerator()
        ..init(
          ParametersWithRandom(
            RSAKeyGeneratorParameters(BigInt.from(65537), 2048, 64),
            _random,
          ),
        );
      final p = gen.generateKeyPair();
      pair = AsymmetricKeyPair(p.publicKey, p.privateKey);
    });

    Uint8List sign(Digest digest, int salt) {
      final signer = PSSSigner(RSAEngine(), digest, digest)
        ..init(
          true,
          ParametersWithSaltConfiguration(
            PrivateKeyParameter<RSAPrivateKey>(pair.privateKey),
            _random,
            salt,
          ),
        );
      return signer.generateSignature(message).bytes;
    }

    AlgorithmIdentifier pss(String hashOid, int salt) => AlgorithmIdentifier(
      Oids.rsaPss,
      Tlv.decode(
        Der.seq([
          Der.explicit(0, Der.algorithm(hashOid)),
          Der.explicit(
            1,
            Der.algorithm(Oids.mgf1, Der.algorithm(hashOid)),
          ),
          Der.explicit(2, Der.smallInt(salt)),
        ]),
      ),
    );

    test('verifies SHA-256 with a 32 byte salt', () {
      final ok = verifySignature(
        algorithm: pss(HashAlgorithm.sha256.oid, 32),
        key: RsaPublicKeyInfo(pair.publicKey),
        message: message,
        signature: sign(SHA256Digest(), 32),
      );
      expect(ok, isTrue);
    });

    test('defaults to SHA-1 and a 20 byte salt without parameters', () {
      expect(
        verifySignature(
          algorithm: const AlgorithmIdentifier(Oids.rsaPss),
          key: RsaPublicKeyInfo(pair.publicKey),
          message: message,
          signature: sign(SHA1Digest(), 20),
        ),
        isTrue,
      );
    });

    test('fails for a different message', () {
      expect(
        verifySignature(
          algorithm: pss(HashAlgorithm.sha256.oid, 32),
          key: RsaPublicKeyInfo(pair.publicKey),
          message: Uint8List.fromList([1, 2, 3]),
          signature: sign(SHA256Digest(), 32),
        ),
        isFalse,
      );
    });
  });

  test('ECDSA accepts the plain r||s form of BSI TR-03111', () {
    final domain = ECDomainParameters('brainpoolp256r1');
    final gen = ECKeyGenerator()
      ..init(ParametersWithRandom(ECKeyGeneratorParameters(domain), _random));
    final pair = gen.generateKeyPair();
    final sig =
        (ECDSASigner(SHA256Digest())..init(
                  true,
                  ParametersWithRandom(
                    PrivateKeyParameter<ECPrivateKey>(pair.privateKey),
                    _random,
                  ),
                ))
                .generateSignature(message)
            as ECSignature;
    final plain = Uint8List.fromList([
      ...bigIntToBytes(sig.r, 32),
      ...bigIntToBytes(sig.s, 32),
    ]);
    final key = EcPublicKeyInfo(pair.publicKey);
    expect(
      verifySignature(
        algorithm: const AlgorithmIdentifier('0.4.0.127.0.7.1.1.4.1.3'),
        key: key,
        message: message,
        signature: plain,
      ),
      isTrue,
    );
    expect(
      verifySignature(
        algorithm: const AlgorithmIdentifier(Oids.ecPublicKey),
        key: key,
        message: message,
        signature: plain,
        digest: HashAlgorithm.sha256,
      ),
      isTrue,
    );
  });

  test('rejects unsupported algorithms and a key/algorithm mismatch', () {
    final pki = TestPki(cscaKey: TestKeyType.ecdsaP256);
    final key = pki.csca.certificate.publicKey;
    expect(
      () => verifySignature(
        algorithm: const AlgorithmIdentifier('1.2.3.4'),
        key: key,
        message: message,
        signature: Uint8List(64),
      ),
      throwsA(isA<LdsFormatException>()),
    );
    expect(
      () => verifySignature(
        algorithm: const AlgorithmIdentifier(Oids.rsaEncryption),
        key: key,
        message: message,
        signature: Uint8List(64),
      ),
      throwsA(isA<LdsFormatException>()),
    );
    expect(
      verifySignature(
        algorithm: const AlgorithmIdentifier('1.2.840.113549.1.1.11'),
        key: key,
        message: message,
        signature: Uint8List(64),
      ),
      isFalse,
    );
  });

  test('every hash algorithm round-trips through its OID', () {
    for (final h in HashAlgorithm.values) {
      expect(HashAlgorithm.forOid(h.oid), h);
      expect(h.hash(message), hasLength(h.create().digestSize));
    }
    expect(
      () => HashAlgorithm.forOid('1.2'),
      throwsA(isA<LdsFormatException>()),
    );
  });

  test('CscaStore reads an ICAO master list', () {
    final a = TestPki();
    final b = TestPki(cscaKey: TestKeyType.ecdsaP256);
    final list = Der.seq([
      Der.smallInt(0),
      Der.set([a.csca.certificate.encoded, b.csca.certificate.encoded]),
    ]);
    final signedData = Der.seq([
      Der.smallInt(3),
      Der.set([Der.algorithm(HashAlgorithm.sha256.oid)]),
      Der.seq([
        Der.oid(Oids.cscaMasterList),
        Der.explicit(0, Der.octets(list)),
      ]),
      Der.set([
        Der.seq([
          Der.smallInt(1),
          Der.seq([a.csca.certificate.issuer.encoded, Der.smallInt(1)]),
          Der.algorithm(HashAlgorithm.sha256.oid),
          Der.algorithm(Oids.rsaEncryption),
          Der.octets([0]),
        ]),
      ]),
    ]);
    final store = CscaStore.fromMasterList(
      Der.seq([Der.oid(Oids.signedData), Der.explicit(0, signedData)]),
    );
    expect(store.certificates, hasLength(2));
    expect(
      () => CscaStore.fromMasterList(
        Der.seq([Der.oid('1.2.3'), Der.explicit(0, signedData)]),
      ),
      throwsA(isA<LdsFormatException>()),
    );
  });

  test('DER time and OID helpers', () {
    expect(
      decodeTime(Tlv.decode(Der.utcTime(DateTime.utc(2049, 12, 31)))),
      DateTime.utc(2049, 12, 31),
    );
    expect(
      decodeTime(
        Tlv.decode(
          Uint8List.fromList([0x18, 15, ...'20510101120000Z'.codeUnits]),
        ),
      ),
      DateTime.utc(2051, 1, 1, 12),
    );
    expect(decodeOid(Tlv.decode(Der.oid('2.23.136.1.1.1'))), '2.23.136.1.1.1');
    expect(
      () => decodeTime(Tlv.decode(Der.octets([1]))),
      throwsA(isA<LdsFormatException>()),
    );
  });
}
