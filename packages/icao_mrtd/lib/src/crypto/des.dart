import 'dart:typed_data';

import 'package:pointycastle/export.dart';

/// Pads [data] with ISO/IEC 9797-1 method 2: `0x80` followed by zeros up to
/// a multiple of 8 bytes.
Uint8List padIso9797(List<int> data) {
  final out = Uint8List(((data.length ~/ 8) + 1) * 8)..setAll(0, data);
  out[data.length] = 0x80;
  return out;
}

/// Removes ISO/IEC 9797-1 method 2 padding.
///
/// Throws a [FormatException] if the padding is malformed.
Uint8List unpadIso9797(Uint8List data) {
  var i = data.length - 1;
  while (i >= 0 && data[i] == 0x00) {
    i--;
  }
  if (i < 0 || data[i] != 0x80) {
    throw const FormatException('Invalid ISO 9797-1 padding');
  }
  return Uint8List.sublistView(data, 0, i);
}

/// Sets the parity bit of every byte of a DES key (odd parity).
Uint8List adjustDesParity(Uint8List key) {
  final out = Uint8List.fromList(key);
  for (var i = 0; i < out.length; i++) {
    final b = out[i] & 0xFE;
    var ones = 0;
    for (var v = b; v != 0; v >>= 1) {
      ones += v & 1;
    }
    out[i] = ones.isEven ? b | 1 : b;
  }
  return out;
}

Uint8List _expandTwoKey(Uint8List key) {
  if (key.length == 24) return key;
  if (key.length != 16) {
    throw ArgumentError('3DES keys must be 16 or 24 bytes');
  }
  return Uint8List.fromList([...key, ...key.sublist(0, 8)]);
}

Uint8List _cbc(BlockCipher engine, Uint8List key, Uint8List data, bool enc) {
  if (data.length % 8 != 0) {
    throw ArgumentError('Data must be a multiple of 8 bytes');
  }
  final cipher = CBCBlockCipher(engine)
    ..init(enc, ParametersWithIV(KeyParameter(key), Uint8List(8)));
  final out = Uint8List(data.length);
  for (var i = 0; i < data.length; i += 8) {
    cipher.processBlock(data, i, out, i);
  }
  return out;
}

/// Encrypts block-aligned [data] with two-key 3DES in CBC mode and a zero
/// IV, as BAC and 3DES secure messaging require.
Uint8List tdesEncrypt(Uint8List key, Uint8List data) =>
    _cbc(DESedeEngine(), _expandTwoKey(key), data, true);

/// Decrypts block-aligned [data]; the inverse of [tdesEncrypt].
Uint8List tdesDecrypt(Uint8List key, Uint8List data) =>
    _cbc(DESedeEngine(), _expandTwoKey(key), data, false);

// Single DES expressed as 3DES with K1 = K2 = K3, because pointycastle
// only ships the triple variant.
Uint8List _single(Uint8List k) => Uint8List.fromList([...k, ...k, ...k]);

/// ISO/IEC 9797-1 MAC algorithm 3 ("retail MAC") with DES and padding
/// method 2, keyed with a 16-byte key.
///
/// [data] is padded internally.
Uint8List retailMac(Uint8List key, List<int> data) {
  if (key.length != 16) throw ArgumentError('MAC keys must be 16 bytes');
  final k1 = Uint8List.sublistView(key, 0, 8);
  final k2 = Uint8List.sublistView(key, 8, 16);
  final padded = padIso9797(data);
  final chained = _cbc(DESedeEngine(), _single(k1), padded, true);
  final last = Uint8List.sublistView(chained, chained.length - 8);
  final step2 = DESedeEngine()..init(false, KeyParameter(_single(k2)));
  final step3 = DESedeEngine()..init(true, KeyParameter(_single(k1)));
  final tmp = Uint8List(8);
  final mac = Uint8List(8);
  step2.processBlock(last, 0, tmp, 0);
  step3.processBlock(tmp, 0, mac, 0);
  return mac;
}

/// The ICAO 9303-11 key derivation function for 3DES keys: the first 16
/// bytes of `SHA-1(seed || counter)`, with DES parity adjusted.
Uint8List deriveTdesKey(Uint8List seed, int counter) {
  final input = Uint8List(seed.length + 4)
    ..setAll(0, seed)
    ..buffer.asByteData().setUint32(seed.length, counter);
  final hash = SHA1Digest().process(input);
  return adjustDesParity(Uint8List.sublistView(hash, 0, 16));
}

/// Key derivation counter for encryption keys.
const kdfEncryption = 1;

/// Key derivation counter for MAC keys.
const kdfMac = 2;

/// Compares two byte lists in constant time.
bool constantTimeEquals(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  var diff = 0;
  for (var i = 0; i < a.length; i++) {
    diff |= a[i] ^ b[i];
  }
  return diff == 0;
}

/// Overwrites [bytes] with zeros so that key material does not linger in
/// memory longer than needed.
void wipe(Uint8List bytes) => bytes.fillRange(0, bytes.length, 0);
