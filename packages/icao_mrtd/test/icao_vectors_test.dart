// Worked example from ICAO Doc 9303 Part 11, Appendix D (BAC and secure
// messaging with 3DES). Every intermediate value is checked so that a
// regression points at the exact step that broke.
import 'dart:typed_data';

import 'package:icao_mrtd/icao_mrtd.dart';
import 'package:icao_mrtd/src/crypto/des.dart';
import 'package:icao_mrz/icao_mrz.dart';
import 'package:test/test.dart';

import 'hex.dart';

class _Replay implements ApduTransceiver {
  _Replay(this.exchanges);

  final List<(String, String)> exchanges;
  int _i = 0;

  @override
  Future<Uint8List> transceive(Uint8List command) async {
    final (expected, response) = exchanges[_i++];
    expect(toHex(command), expected, reason: 'command #$_i');
    return hex(response);
  }
}

void main() {
  final mrzKey = MrzKey(
    documentNumber: 'L898902C',
    dateOfBirth: const MrzDate('690806'),
    dateOfExpiry: const MrzDate('940623'),
  );

  test('derives K_Enc and K_MAC from the MRZ', () {
    final keys = BacKeys.fromMrzKey(mrzKey);
    expect(toHex(keys.encryption), 'AB94FDECF2674FDFB9B391F85D7F76F2');
    expect(toHex(keys.mac), '7962D9ECE03D1ACD4C76089DCE131543');
  });

  test('computes the retail MAC of E.IFD', () {
    final mac = retailMac(
      hex('7962D9ECE03D1ACD4C76089DCE131543'),
      hex(
        '72C29C2371CC9BDB65B779B8E8D37B29'
        'ECC154AA56A8799FAE2F498F76ED92F2',
      ),
    );
    expect(toHex(mac), '5F1448EEA8AD90A7');
  });

  test('runs BAC and protects the following commands', () async {
    final chip = _Replay([
      ('0084000008', '4608F919887022129000'),
      (
        '0082000028'
            '72C29C2371CC9BDB65B779B8E8D37B29ECC154AA56A8799FAE2F498F76ED92F2'
            '5F1448EEA8AD90A728',
        '46B9342A41396CD7386BF5803104D7CEDC122B9132139BAF2EEDC94EE178534F'
            '2F2D235D074D74499000',
      ),
    ]);
    final fixed = [
      hex('781723860C06C226'),
      hex('0B795240CB7049B01C19B33E32804F0B'),
    ];
    var call = 0;
    final sm = await performBac(
      chip,
      BacKeys.fromMrzKey(mrzKey),
      randomBytes: (_) => fixed[call++],
    );
    expect(toHex(sm.ssc), '887022120C06C226');

    // SELECT EF.COM
    final select = sm.protect(
      CommandApdu(
        cla: 0,
        ins: 0xA4,
        p1: 0x02,
        p2: 0x0C,
        data: hex('011E'),
      ),
    );
    expect(
      toHex(select.toBytes()),
      '0CA4020C158709016375432908C044F68E08BF8B92D635FF24F800',
    );
    final selectResponse = sm.unprotect(
      ResponseApdu.fromBytes(hex('990290008E08FA855A5D4C50A8ED9000')),
    );
    expect(selectResponse.sw, StatusWord.success);

    // READ BINARY, first four bytes
    final read = sm.protect(
      CommandApdu(cla: 0, ins: 0xB0, p1: 0, p2: 0, ne: 4),
    );
    expect(toHex(read.toBytes()), '0CB000000D9701048E08ED6705417E96BA5500');
    final readResponse = sm.unprotect(
      ResponseApdu.fromBytes(
        hex('8709019FF0EC34F9922651990290008E08AD55CC17140B2DED9000'),
      ),
    );
    expect(toHex(readResponse.data), '60145F01');

    // READ BINARY, remaining 18 bytes from offset 4
    final rest = sm.protect(
      CommandApdu(cla: 0, ins: 0xB0, p1: 0, p2: 4, ne: 0x12),
    );
    expect(toHex(rest.toBytes()), '0CB000040D9701128E082EA28A70F3C7B53500');
    final restResponse = sm.unprotect(
      ResponseApdu.fromBytes(
        hex(
          '871901FB9235F4E4037F2327DCC8964F1F9B8C30F42C8E2FFF224A'
          '990290008E08C8B2787EAEA07D749000',
        ),
      ),
    );
    expect(toHex(restResponse.data), '04303130365F36063034303030305C026175');
  });

  test('rejects a tampered response MAC', () async {
    final sm =
        SecureMessaging(
          encryptionKey: hex('979EC13B1CBFE9DCD01AB0FED307EAE5'),
          macKey: hex('F1CB1F1FB5ADF208806B89DC579DC1F8'),
          ssc: hex('887022120C06C226'),
        )..protect(
          CommandApdu(cla: 0, ins: 0xA4, p1: 2, p2: 0x0C, data: hex('011E')),
        );
    expect(
      () => sm.unprotect(
        ResponseApdu.fromBytes(hex('990290008E08FA855A5D4C50A8EE9000')),
      ),
      throwsA(isA<SecureMessagingException>()),
    );
  });
}
