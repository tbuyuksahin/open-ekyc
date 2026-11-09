import 'dart:math';
import 'dart:typed_data';

import 'package:icao_mrtd/src/apdu.dart';
import 'package:icao_mrtd/src/crypto/des.dart';
import 'package:icao_mrtd/src/errors.dart';
import 'package:icao_mrtd/src/secure_messaging.dart';
import 'package:icao_mrz/icao_mrz.dart';
import 'package:pointycastle/export.dart';

/// Source of random bytes. Defaults to [Random.secure].
typedef RandomBytes = Uint8List Function(int length);

/// Cryptographically secure random bytes.
Uint8List secureRandomBytes(int length) {
  final random = Random.secure();
  return Uint8List.fromList(List.generate(length, (_) => random.nextInt(256)));
}

/// The document basic access keys `K_Enc` and `K_MAC` derived from the MRZ.
class BacKeys {
  /// Creates keys from raw values.
  BacKeys(this.encryption, this.mac);

  /// Derives the keys from the MRZ fields (ICAO 9303-11, 4.3.2).
  factory BacKeys.fromMrzKey(MrzKey key) {
    final hash = SHA1Digest().process(
      Uint8List.fromList(key.information.codeUnits),
    );
    final seed = Uint8List.sublistView(hash, 0, 16);
    return BacKeys(
      deriveTdesKey(seed, kdfEncryption),
      deriveTdesKey(seed, kdfMac),
    );
  }

  /// `K_Enc`.
  final Uint8List encryption;

  /// `K_MAC`.
  final Uint8List mac;

  /// Overwrites both keys with zeros.
  void wipe() {
    encryption.fillRange(0, encryption.length, 0);
    mac.fillRange(0, mac.length, 0);
  }
}

/// Runs the Basic Access Control protocol (ICAO 9303-11, 4.3) and returns
/// a secure messaging session.
///
/// The eMRTD application must already be selected. Throws an
/// [AccessDeniedException] if the chip rejects the key, which means the
/// MRZ data used to derive it is wrong.
Future<SecureMessaging> performBac(
  ApduTransceiver transceiver,
  BacKeys keys, {
  RandomBytes randomBytes = secureRandomBytes,
}) async {
  final challenge = ResponseApdu.fromBytes(
    await transceiver.transceive(
      CommandApdu(cla: 0x00, ins: 0x84, p1: 0, p2: 0, ne: 8).toBytes(),
    ),
  );
  if (!challenge.isSuccess || challenge.data.length != 8) {
    throw ApduException(challenge.sw, 'GET CHALLENGE');
  }
  final rndIc = challenge.data;
  final rndIfd = randomBytes(8);
  final kIfd = randomBytes(16);

  final s = Uint8List.fromList([...rndIfd, ...rndIc, ...kIfd]);
  final eIfd = tdesEncrypt(keys.encryption, s);
  final mIfd = retailMac(keys.mac, eIfd);
  wipe(s);

  final response = ResponseApdu.fromBytes(
    await transceiver.transceive(
      CommandApdu(
        cla: 0x00,
        ins: 0x82,
        p1: 0,
        p2: 0,
        data: Uint8List.fromList([...eIfd, ...mIfd]),
        ne: 40,
      ).toBytes(),
    ),
  );
  if (response.sw == StatusWord.securityStatusNotSatisfied ||
      response.sw == StatusWord.authenticationFailed) {
    throw const AccessDeniedException(
      'The chip rejected the access key. Check the document number and dates.',
    );
  }
  if (!response.isSuccess || response.data.length != 40) {
    throw ApduException(response.sw, 'EXTERNAL AUTHENTICATE');
  }

  final eIc = Uint8List.sublistView(response.data, 0, 32);
  final mIc = Uint8List.sublistView(response.data, 32, 40);
  if (!constantTimeEquals(retailMac(keys.mac, eIc), mIc)) {
    throw const AccessDeniedException('The chip response MAC is invalid.');
  }
  final r = tdesDecrypt(keys.encryption, eIc);
  if (!constantTimeEquals(r.sublist(8, 16), rndIfd)) {
    throw const AccessDeniedException('The chip did not echo our challenge.');
  }
  final kIc = r.sublist(16, 32);
  final seed = Uint8List(16);
  for (var i = 0; i < 16; i++) {
    seed[i] = kIfd[i] ^ kIc[i];
  }
  final ssc = Uint8List.fromList([...rndIc.sublist(4), ...rndIfd.sublist(4)]);
  final session = SecureMessaging(
    encryptionKey: deriveTdesKey(seed, kdfEncryption),
    macKey: deriveTdesKey(seed, kdfMac),
    ssc: ssc,
  );
  [r, kIc, kIfd, seed].forEach(wipe);
  return session;
}
