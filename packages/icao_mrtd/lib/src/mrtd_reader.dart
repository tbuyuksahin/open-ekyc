import 'dart:typed_data';

import 'package:icao_mrtd/src/apdu.dart';
import 'package:icao_mrtd/src/bac.dart';
import 'package:icao_mrtd/src/errors.dart';
import 'package:icao_mrtd/src/lds/lds_file.dart';
import 'package:icao_mrtd/src/secure_messaging.dart';
import 'package:icao_mrtd/src/tlv.dart';
import 'package:icao_mrz/icao_mrz.dart';

/// Reports progress while a file is read: bytes read so far and total.
typedef ReadProgress = void Function(int read, int total);

/// The AID of the ICAO eMRTD application.
final Uint8List mrtdApplicationId = Uint8List.fromList([
  0xA0, 0x00, 0x00, 0x02, 0x47, 0x10, 0x01, //
]);

/// Reads files from an eMRTD chip.
///
/// ```dart
/// final reader = MrtdReader(transceiver);
/// await reader.openSession(mrz.key);
/// final dg1 = await reader.readFile(LdsFile.dg1);
/// ```
class MrtdReader {
  /// Creates a reader that talks through the given transceiver.
  ///
  /// [maxReadLength] limits each READ BINARY; 223 bytes keeps protected
  /// responses inside a short APDU.
  MrtdReader(
    this._transceiver, {
    this.maxReadLength = 0xDF,
    RandomBytes randomBytes = secureRandomBytes,
  }) : _random = randomBytes;

  final ApduTransceiver _transceiver;
  final RandomBytes _random;

  /// Maximum number of bytes requested per READ BINARY.
  final int maxReadLength;

  SecureMessaging? _sm;

  /// Whether a secure messaging session is open.
  bool get hasSession => _sm != null;

  /// Selects the eMRTD application and performs Basic Access Control.
  Future<void> openSession(MrzKey key) async {
    await _send(
      CommandApdu(
        cla: 0,
        ins: 0xA4,
        p1: 0x04,
        p2: 0x0C,
        data: mrtdApplicationId,
      ),
      'SELECT eMRTD application',
    );
    final keys = BacKeys.fromMrzKey(key);
    try {
      _sm = await performBac(_transceiver, keys, randomBytes: _random);
    } finally {
      keys.wipe();
    }
  }

  /// Reads the complete contents of [file].
  ///
  /// Throws an [ApduException] with [StatusWord.fileNotFound] when the
  /// document does not contain the file.
  Future<Uint8List> readFile(LdsFile file, {ReadProgress? onProgress}) async {
    final fid = Uint8List.fromList([file.fileId >> 8, file.fileId & 0xFF]);
    await _send(
      CommandApdu(cla: 0, ins: 0xA4, p1: 0x02, p2: 0x0C, data: fid),
      'SELECT ${file.name}',
    );
    final header = await _readBinary(0, 8);
    final total = Tlv.encodedLength(header);
    if (total == null) {
      throw LdsFormatException('${file.name} does not start with a TLV');
    }
    final out = Uint8List(total)..setAll(0, header.take(total));
    var offset = header.length < total ? header.length : total;
    onProgress?.call(offset, total);
    while (offset < total) {
      final remaining = total - offset;
      final chunk = await _readBinary(
        offset,
        remaining < maxReadLength ? remaining : maxReadLength,
      );
      if (chunk.isEmpty) {
        throw LdsFormatException('${file.name} ended early');
      }
      out.setAll(offset, chunk.take(remaining));
      offset += chunk.length;
      onProgress?.call(offset < total ? offset : total, total);
    }
    return out;
  }

  Future<Uint8List> _readBinary(int offset, int length) async {
    if (offset > 0x7FFF) {
      throw const LdsFormatException('File is larger than 32 KB');
    }
    final response = await _exchange(
      CommandApdu(
        cla: 0,
        ins: 0xB0,
        p1: offset >> 8,
        p2: offset & 0xFF,
        ne: length,
      ),
    );
    if (response.sw != StatusWord.success &&
        response.sw != StatusWord.endOfFile) {
      throw ApduException(response.sw, 'READ BINARY');
    }
    return response.data;
  }

  Future<ResponseApdu> _exchange(CommandApdu command) async {
    final sm = _sm;
    final wire = sm == null ? command : sm.protect(command);
    final raw = ResponseApdu.fromBytes(
      await _transceiver.transceive(wire.toBytes()),
    );
    if (sm == null) return raw;
    try {
      final response = sm.unprotect(raw);
      if (response.sw == StatusWord.smObjectsMissing ||
          response.sw == StatusWord.smObjectsIncorrect) {
        throw const SecureMessagingException('The chip ended the session');
      }
      return response;
    } on SecureMessagingException {
      close();
      rethrow;
    }
  }

  Future<void> _send(CommandApdu command, String name) async {
    final response = await _exchange(command);
    if (!response.isSuccess) throw ApduException(response.sw, name);
  }

  /// Ends the session and wipes the session keys.
  void close() {
    _sm?.close();
    _sm = null;
  }
}
