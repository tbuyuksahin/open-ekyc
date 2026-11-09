import 'dart:typed_data';

import 'package:meta/meta.dart';

/// Sends raw command APDUs to a contactless chip and returns the raw
/// response, including the two status word bytes.
///
/// Implement this on top of your NFC plugin (`IsoDep.transceive` on
/// Android, `NFCISO7816Tag.sendCommand` on iOS). Keeping the transport
/// behind this interface lets the whole protocol run in unit tests.
// The single-method interface is deliberate: implementations wrap
// stateful NFC sessions, and a class reads better than a typedef there.
// ignore: one_member_abstracts
abstract interface class ApduTransceiver {
  /// Sends [command] and returns the response data followed by SW1 SW2.
  Future<Uint8List> transceive(Uint8List command);
}

/// An ISO 7816-4 command APDU (short length encoding).
@immutable
class CommandApdu {
  /// Creates a command. [ne] is the expected response length; 256 is
  /// encoded as `00`.
  CommandApdu({
    required this.cla,
    required this.ins,
    required this.p1,
    required this.p2,
    Uint8List? data,
    this.ne,
  }) : data = data ?? Uint8List(0) {
    if (this.data.length > 255) {
      throw ArgumentError('Extended length APDUs are not supported');
    }
    if (ne != null && (ne! < 1 || ne! > 256)) {
      throw ArgumentError.value(ne, 'ne', 'must be 1-256');
    }
  }

  /// Class byte.
  final int cla;

  /// Instruction byte.
  final int ins;

  /// Parameter 1.
  final int p1;

  /// Parameter 2.
  final int p2;

  /// Command data (may be empty).
  final Uint8List data;

  /// Expected response length, or `null` when no data is expected.
  final int? ne;

  /// The serialized APDU.
  Uint8List toBytes() => Uint8List.fromList([
    cla,
    ins,
    p1,
    p2,
    if (data.isNotEmpty) ...[data.length, ...data],
    if (ne != null) ne! & 0xFF,
  ]);
}

/// An ISO 7816-4 response APDU.
@immutable
class ResponseApdu {
  /// Creates a response from its parts.
  const ResponseApdu(this.data, this.sw);

  /// Splits raw bytes into data and status word.
  factory ResponseApdu.fromBytes(Uint8List bytes) {
    if (bytes.length < 2) {
      throw ArgumentError('A response needs at least two status bytes');
    }
    final n = bytes.length;
    return ResponseApdu(
      Uint8List.sublistView(bytes, 0, n - 2),
      (bytes[n - 2] << 8) | bytes[n - 1],
    );
  }

  /// Response data.
  final Uint8List data;

  /// Status word, for example `0x9000`.
  final int sw;

  /// Whether [sw] is `90 00`.
  bool get isSuccess => sw == StatusWord.success;
}

/// Status words used by eMRTD chips.
abstract final class StatusWord {
  /// Normal processing.
  static const success = 0x9000;

  /// End of file reached before reading Le bytes.
  static const endOfFile = 0x6282;

  /// Security status not satisfied (wrong key or SM required).
  static const securityStatusNotSatisfied = 0x6982;

  /// Authentication failed.
  static const authenticationFailed = 0x6300;

  /// Expected SM data objects missing.
  static const smObjectsMissing = 0x6987;

  /// SM data objects incorrect.
  static const smObjectsIncorrect = 0x6988;

  /// File or application not found.
  static const fileNotFound = 0x6A82;

  /// Wrong parameters P1-P2 (offset beyond the file).
  static const wrongParameters = 0x6B00;
}
