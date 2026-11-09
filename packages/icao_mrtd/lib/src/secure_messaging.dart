import 'dart:typed_data';

import 'package:icao_mrtd/src/apdu.dart';
import 'package:icao_mrtd/src/crypto/des.dart';
import 'package:icao_mrtd/src/errors.dart';
import 'package:icao_mrtd/src/tlv.dart';

/// A 3DES secure messaging session (ICAO 9303-11, 9.8).
///
/// Every command is encrypted and MACed, and every response is verified
/// before its data is returned. A response that fails verification throws
/// a [SecureMessagingException]; the session must then be discarded.
class SecureMessaging {
  /// Creates a session from the derived session keys and the initial send
  /// sequence counter.
  SecureMessaging({
    required Uint8List encryptionKey,
    required Uint8List macKey,
    required Uint8List ssc,
  }) : _kEnc = encryptionKey,
       _kMac = macKey,
       _ssc = Uint8List.fromList(ssc) {
    if (ssc.length != 8) throw ArgumentError('The SSC must be 8 bytes');
  }

  final Uint8List _kEnc;
  final Uint8List _kMac;
  final Uint8List _ssc;

  /// The current send sequence counter (a copy).
  Uint8List get ssc => Uint8List.fromList(_ssc);

  void _increment() {
    for (var i = _ssc.length - 1; i >= 0; i--) {
      _ssc[i] = (_ssc[i] + 1) & 0xFF;
      if (_ssc[i] != 0) return;
    }
  }

  /// Wraps [command] into a protected APDU.
  CommandApdu protect(CommandApdu command) {
    _increment();
    final cla = command.cla | 0x0C;
    final header = padIso9797([cla, command.ins, command.p1, command.p2]);
    final do87 = command.data.isEmpty
        ? Uint8List(0)
        : encodeTlv(0x87, [
            0x01,
            ...tdesEncrypt(_kEnc, padIso9797(command.data)),
          ]);
    final do97 = command.ne == null
        ? Uint8List(0)
        : encodeTlv(0x97, [command.ne! & 0xFF]);
    final mac = retailMac(_kMac, [..._ssc, ...header, ...do87, ...do97]);
    return CommandApdu(
      cla: cla,
      ins: command.ins,
      p1: command.p1,
      p2: command.p2,
      data: Uint8List.fromList([...do87, ...do97, ...encodeTlv(0x8E, mac)]),
      ne: 256,
    );
  }

  /// Verifies and decrypts a protected [response].
  ResponseApdu unprotect(ResponseApdu response) {
    _increment();
    if (response.data.isEmpty && !response.isSuccess) {
      // Some chips answer errors such as "file not found" without secure
      // messaging. The status word carries no data, so pass it through and
      // let the caller decide.
      return response;
    }
    if (response.data.isEmpty) {
      throw SecureMessagingException(
        'Unprotected response with SW '
        '${response.sw.toRadixString(16).padLeft(4, '0')}',
      );
    }
    final List<Tlv> objects;
    try {
      objects = Tlv.decodeAll(response.data);
    } on LdsFormatException {
      throw const SecureMessagingException('Malformed protected response');
    }
    Tlv? find(int tag) {
      for (final o in objects) {
        if (o.tag == tag) return o;
      }
      return null;
    }

    final do87 = find(0x87);
    final do99 = find(0x99);
    final do8e = find(0x8E);
    if (do99 == null || do8e == null || do99.value.length != 2) {
      throw const SecureMessagingException('Missing DO99 or DO8E');
    }
    final macInput = [
      ..._ssc,
      if (do87 != null) ...do87.encoded,
      ...do99.encoded,
    ];
    if (!constantTimeEquals(retailMac(_kMac, macInput), do8e.value)) {
      throw const SecureMessagingException('Response MAC is invalid');
    }
    var data = Uint8List(0);
    if (do87 != null) {
      if (do87.value.isEmpty || do87.value[0] != 0x01) {
        throw const SecureMessagingException('Unsupported DO87 padding');
      }
      try {
        data = unpadIso9797(
          tdesDecrypt(_kEnc, Uint8List.sublistView(do87.value, 1)),
        );
      } on FormatException {
        throw const SecureMessagingException('Response padding is invalid');
      }
    }
    return ResponseApdu(data, (do99.value[0] << 8) | do99.value[1]);
  }

  /// Overwrites the session keys with zeros. The session cannot be used
  /// afterwards.
  void close() {
    wipe(_kEnc);
    wipe(_kMac);
  }
}
