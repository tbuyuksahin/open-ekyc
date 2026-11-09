import 'dart:typed_data';

import 'package:icao_mrtd/src/apdu.dart';
import 'package:icao_mrtd/src/bac.dart';
import 'package:icao_mrtd/src/crypto/des.dart';
import 'package:icao_mrtd/src/lds/lds_file.dart';
import 'package:icao_mrtd/src/tlv.dart';
import 'package:icao_mrz/icao_mrz.dart';

/// Raised by [VirtualMrtd] to simulate the card leaving the NFC field.
class TagLostException implements Exception {
  @override
  String toString() => 'TagLostException';
}

/// A software eMRTD chip that speaks BAC and 3DES secure messaging.
///
/// Use it to test readers and apps without hardware. The chip-side
/// protocol is written independently of the reader so that tests compare
/// two implementations, not one implementation with itself.
class VirtualMrtd implements ApduTransceiver {
  /// Creates a chip holding [files] and protected by [key].
  VirtualMrtd({
    required MrzKey key,
    required Map<LdsFile, Uint8List> files,
    RandomBytes randomBytes = secureRandomBytes,
    this.loseTagAfter,
    this.corruptResponseMac = false,
  }) : _keys = BacKeys.fromMrzKey(key),
       _files = Map.of(files),
       _random = randomBytes;

  final BacKeys _keys;
  final Map<LdsFile, Uint8List> _files;
  final RandomBytes _random;

  /// Throw [TagLostException] after this many commands, if set.
  final int? loseTagAfter;

  /// Flip a bit in every protected response MAC.
  final bool corruptResponseMac;

  /// Number of commands received.
  int commandCount = 0;

  bool _appSelected = false;
  Uint8List? _rndIc;
  _Session? _session;
  LdsFile? _current;

  @override
  Future<Uint8List> transceive(Uint8List command) async {
    commandCount++;
    if (loseTagAfter != null && commandCount > loseTagAfter!) {
      throw TagLostException();
    }
    if (_session != null) return _secure(command);
    return _plain(command);
  }

  Uint8List _sw(int sw, [List<int> data = const []]) =>
      Uint8List.fromList([...data, sw >> 8, sw & 0xFF]);

  Uint8List _plain(Uint8List c) {
    final ins = c[1];
    if (ins == 0xA4 && c[2] == 0x04) {
      final aid = c.sublist(5, 5 + c[4]);
      _appSelected = bytesEqual(aid, mrtdApplicationIdBytes);
      return _sw(_appSelected ? 0x9000 : 0x6A82);
    }
    if (!_appSelected) return _sw(0x6982);
    if (ins == 0x84) {
      _rndIc = _random(8);
      return _sw(0x9000, _rndIc!);
    }
    if (ins == 0x82) return _externalAuthenticate(c.sublist(5, 5 + c[4]));
    return _sw(0x6982);
  }

  Uint8List _externalAuthenticate(Uint8List data) {
    final rndIc = _rndIc;
    if (rndIc == null || data.length != 40) return _sw(0x6700);
    final eIfd = data.sublist(0, 32);
    if (!bytesEqual(retailMac(_keys.mac, eIfd), data.sublist(32))) {
      return _sw(0x6300);
    }
    final s = tdesDecrypt(_keys.encryption, eIfd);
    final rndIfd = s.sublist(0, 8);
    if (!bytesEqual(s.sublist(8, 16), rndIc)) return _sw(0x6300);
    final kIfd = s.sublist(16, 32);
    final kIc = _random(16);
    final r = Uint8List.fromList([...rndIc, ...rndIfd, ...kIc]);
    final eIc = tdesEncrypt(_keys.encryption, r);
    final seed = Uint8List(16);
    for (var i = 0; i < 16; i++) {
      seed[i] = kIfd[i] ^ kIc[i];
    }
    _session = _Session(
      deriveTdesKey(seed, kdfEncryption),
      deriveTdesKey(seed, kdfMac),
      Uint8List.fromList([...rndIc.sublist(4), ...rndIfd.sublist(4)]),
    );
    return _sw(0x9000, [...eIc, ...retailMac(_keys.mac, eIc)]);
  }

  void _incrementSsc(Uint8List ssc) {
    for (var i = 7; i >= 0; i--) {
      ssc[i] = (ssc[i] + 1) & 0xFF;
      if (ssc[i] != 0) return;
    }
  }

  Uint8List _secure(Uint8List c) {
    final session = _session!;
    _incrementSsc(session.ssc);
    final objects = Tlv.decodeAll(c.sublist(5, 5 + c[4]));
    Tlv? find(int tag) {
      for (final o in objects) {
        if (o.tag == tag) return o;
      }
      return null;
    }

    final do87 = find(0x87);
    final do97 = find(0x97);
    final do8e = find(0x8E);
    final header = padIso9797(c.sublist(0, 4));
    final expected = retailMac(session.mac, [
      ...session.ssc,
      ...header,
      if (do87 != null) ...do87.encoded,
      if (do97 != null) ...do97.encoded,
    ]);
    if (do8e == null || !bytesEqual(expected, do8e.value)) {
      _session = null;
      return _sw(0x6988);
    }
    final data = do87 == null
        ? Uint8List(0)
        : unpadIso9797(tdesDecrypt(session.enc, do87.value.sublist(1)));
    var le = do97 == null ? 0 : do97.value[0];
    if (do97 != null && le == 0) le = 256;
    final (sw, out) = _process(c[1], c[2], c[3], data, le);
    return _protect(session, sw, out);
  }

  (int, Uint8List) _process(int ins, int p1, int p2, Uint8List data, int le) {
    if (ins == 0xA4 && p1 == 0x02) {
      final fid = (data[0] << 8) | data[1];
      _current = null;
      for (final f in _files.keys) {
        if (f.fileId == fid) _current = f;
      }
      return (_current == null ? 0x6A82 : 0x9000, Uint8List(0));
    }
    if (ins == 0xB0) {
      final file = _current;
      if (file == null) return (0x6986, Uint8List(0));
      final content = _files[file]!;
      final offset = (p1 << 8) | p2;
      if (offset >= content.length) return (0x6B00, Uint8List(0));
      final end = offset + le > content.length ? content.length : offset + le;
      return (
        end - offset < le ? 0x6282 : 0x9000,
        content.sublist(offset, end),
      );
    }
    return (0x6D00, Uint8List(0));
  }

  Uint8List _protect(_Session session, int sw, Uint8List data) {
    _incrementSsc(session.ssc);
    final do87 = data.isEmpty
        ? Uint8List(0)
        : encodeTlv(0x87, [
            0x01,
            ...tdesEncrypt(session.enc, padIso9797(data)),
          ]);
    final do99 = encodeTlv(0x99, [sw >> 8, sw & 0xFF]);
    final mac = retailMac(session.mac, [...session.ssc, ...do87, ...do99]);
    if (corruptResponseMac) mac[0] ^= 0x01;
    return _sw(sw, [...do87, ...do99, ...encodeTlv(0x8E, mac)]);
  }
}

class _Session {
  _Session(this.enc, this.mac, this.ssc);
  final Uint8List enc;
  final Uint8List mac;
  final Uint8List ssc;
}

/// The eMRTD AID, duplicated here to keep the simulator independent.
const mrtdApplicationIdBytes = [0xA0, 0x00, 0x00, 0x02, 0x47, 0x10, 0x01];

/// Whether [a] and [b] hold the same bytes.
bool bytesEqual(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
