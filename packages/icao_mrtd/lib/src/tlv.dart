import 'dart:typed_data';

import 'package:icao_mrtd/src/errors.dart';
import 'package:meta/meta.dart';

/// A BER-TLV object, as used by ISO 7816-4, the ICAO LDS and DER.
///
/// [encoded] keeps the exact bytes of the object. Signatures are computed
/// over encodings, so they must never be re-serialized.
@immutable
class Tlv {
  const Tlv._(this.tag, this.value, this.encoded);

  /// Decodes the single object at the start of [bytes].
  ///
  /// Trailing bytes are ignored; use [decodeAll] to read a sequence.
  factory Tlv.decode(Uint8List bytes) => _decodeAt(bytes, 0).$1;

  /// The tag, including class and constructed bits, as an integer
  /// (for example `0x5F1F` or `0x30`).
  final int tag;

  /// The value bytes.
  final Uint8List value;

  /// The complete encoding: tag, length and value.
  final Uint8List encoded;

  /// Whether the constructed bit of the first tag byte is set.
  bool get isConstructed {
    var first = tag;
    while (first > 0xFF) {
      first >>= 8;
    }
    return first & 0x20 != 0;
  }

  /// Decodes the value of a constructed object into its children.
  List<Tlv> get children => decodeAll(value);

  /// The first child with [tag], or `null`.
  Tlv? child(int tag) {
    for (final c in children) {
      if (c.tag == tag) return c;
    }
    return null;
  }

  /// The first child with [tag]; throws an [LdsFormatException] if absent.
  Tlv require(int tag) =>
      child(tag) ??
      (throw LdsFormatException(
        'Missing tag ${tag.toRadixString(16)} in ${this.tag.toRadixString(16)}',
      ));

  /// Decodes every object in [bytes].
  static List<Tlv> decodeAll(Uint8List bytes) {
    final out = <Tlv>[];
    var offset = 0;
    while (offset < bytes.length) {
      // Some chips pad files with 0x00 or 0xFF after the last object.
      if (bytes[offset] == 0x00 || bytes[offset] == 0xFF) {
        offset++;
        continue;
      }
      final (tlv, next) = _decodeAt(bytes, offset);
      out.add(tlv);
      offset = next;
    }
    return out;
  }

  /// Returns the total encoded length of the object starting at [bytes], or
  /// `null` if [bytes] is too short to contain the tag and length.
  ///
  /// Used to learn the size of a file from its first few bytes.
  static int? encodedLength(Uint8List bytes) {
    try {
      final (_, afterTag) = _readTag(bytes, 0);
      final (length, afterLength) = _readLength(bytes, afterTag);
      return afterLength + length;
    } on LdsFormatException {
      return null;
    }
  }

  static (Tlv, int) _decodeAt(Uint8List bytes, int start) {
    final (tag, afterTag) = _readTag(bytes, start);
    final (length, valueStart) = _readLength(bytes, afterTag);
    final end = valueStart + length;
    if (end > bytes.length) {
      throw LdsFormatException(
        'Tag ${tag.toRadixString(16)} declares $length bytes but only '
        '${bytes.length - valueStart} remain',
      );
    }
    return (
      Tlv._(
        tag,
        Uint8List.sublistView(bytes, valueStart, end),
        Uint8List.sublistView(bytes, start, end),
      ),
      end,
    );
  }

  static (int, int) _readTag(Uint8List bytes, int start) {
    if (start >= bytes.length) {
      throw const LdsFormatException('Unexpected end of data in tag');
    }
    var tag = bytes[start];
    var i = start + 1;
    if (tag & 0x1F == 0x1F) {
      do {
        if (i >= bytes.length) {
          throw const LdsFormatException('Unexpected end of data in tag');
        }
        tag = (tag << 8) | bytes[i];
        i++;
      } while (bytes[i - 1] & 0x80 != 0);
    }
    return (tag, i);
  }

  static (int, int) _readLength(Uint8List bytes, int start) {
    if (start >= bytes.length) {
      throw const LdsFormatException('Unexpected end of data in length');
    }
    final first = bytes[start];
    if (first < 0x80) return (first, start + 1);
    final count = first & 0x7F;
    if (count == 0 || count > 4) {
      throw const LdsFormatException('Unsupported length encoding');
    }
    if (start + 1 + count > bytes.length) {
      throw const LdsFormatException('Unexpected end of data in length');
    }
    var length = 0;
    for (var i = 0; i < count; i++) {
      length = (length << 8) | bytes[start + 1 + i];
    }
    return (length, start + 1 + count);
  }

  @override
  String toString() => 'Tlv(${tag.toRadixString(16)}, ${value.length} bytes)';
}

/// Encodes a BER-TLV object with definite length.
Uint8List encodeTlv(int tag, List<int> value) {
  final tagBytes = <int>[];
  for (var t = tag; t > 0; t >>= 8) {
    tagBytes.insert(0, t & 0xFF);
  }
  if (tagBytes.isEmpty) tagBytes.add(0);
  return Uint8List.fromList([
    ...tagBytes,
    ...encodeLength(value.length),
    ...value,
  ]);
}

/// Encodes [length] as a BER definite length.
List<int> encodeLength(int length) {
  if (length < 0x80) return [length];
  final bytes = <int>[];
  for (var l = length; l > 0; l >>= 8) {
    bytes.insert(0, l & 0xFF);
  }
  return [0x80 | bytes.length, ...bytes];
}
