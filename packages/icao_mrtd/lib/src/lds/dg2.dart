import 'dart:typed_data';

import 'package:icao_mrtd/src/errors.dart';
import 'package:icao_mrtd/src/lds/lds_file.dart';
import 'package:icao_mrtd/src/tlv.dart';
import 'package:meta/meta.dart';

/// Image encodings allowed for the portrait in DG2.
enum FaceImageFormat {
  /// JPEG (ISO/IEC 10918).
  jpeg,

  /// JPEG 2000 (ISO/IEC 15444). Flutter cannot display it without a
  /// decoder.
  jpeg2000,
}

/// The portrait stored in DG2.
@immutable
class FaceImage {
  /// Creates a portrait.
  const FaceImage({
    required this.bytes,
    required this.format,
    required this.width,
    required this.height,
  });

  /// The encoded image.
  final Uint8List bytes;

  /// The image encoding.
  final FaceImageFormat format;

  /// Width in pixels from the biometric header (0 if unknown).
  final int width;

  /// Height in pixels from the biometric header (0 if unknown).
  final int height;

  @override
  String toString() =>
      'FaceImage(${format.name}, ${width}x$height, ${bytes.length} bytes)';
}

/// Extracts the first portrait from DG2.
///
/// DG2 nests a CBEFF biometric information template (ICAO 9303-10) around
/// an ISO/IEC 19794-5 facial record. The image is located by walking the
/// record headers, not by searching for a byte pattern, so stray `0xFF`
/// bytes in the headers cannot corrupt it.
FaceImage parseDg2(Uint8List bytes) {
  final root = Tlv.decode(bytes);
  if (root.tag != LdsFile.dg2.tag) {
    throw const LdsFormatException('DG2 must start with tag 75');
  }
  final group = root.require(0x7F61);
  final instance = group.require(0x7F60);
  final block = instance.child(0x5F2E) ?? instance.require(0x7F2E);
  return _parseIso19794(block.value);
}

FaceImage _parseIso19794(Uint8List data) {
  final view = ByteData.sublistView(data);
  if (data.length < 46 ||
      String.fromCharCodes(data.sublist(0, 3)) != 'FAC' ||
      data[3] != 0) {
    throw const LdsFormatException(
      'Biometric block is not an ISO 19794-5 face',
    );
  }
  // General header: format id (4), version (4), record length (4),
  // number of faces (2).
  const recordStart = 14;
  final blockLength = view.getUint32(recordStart);
  final featurePoints = view.getUint16(recordStart + 4);
  // Facial information: block length (4), feature points (2), gender (1),
  // eye colour (1), hair colour (1), feature mask (3), expression (2),
  // pose angles (3), pose uncertainty (3) = 20 bytes, then 8 bytes per
  // feature point, then 12 bytes of image information.
  final imageInfo = recordStart + 20 + featurePoints * 8;
  final imageStart = imageInfo + 12;
  final recordEnd = recordStart + blockLength;
  if (imageStart >= data.length || recordEnd > data.length) {
    throw const LdsFormatException('Facial record is truncated');
  }
  final dataType = data[imageInfo + 1];
  final format = switch (dataType) {
    0 => FaceImageFormat.jpeg,
    1 => FaceImageFormat.jpeg2000,
    _ => throw LdsFormatException('Unknown face image data type $dataType'),
  };
  final image = Uint8List.fromList(data.sublist(imageStart, recordEnd));
  _checkSignature(image, format);
  return FaceImage(
    bytes: image,
    format: format,
    width: view.getUint16(imageInfo + 2),
    height: view.getUint16(imageInfo + 4),
  );
}

void _checkSignature(Uint8List image, FaceImageFormat format) {
  bool startsWith(List<int> prefix) =>
      image.length >= prefix.length &&
      Iterable<int>.generate(prefix.length).every((i) => image[i] == prefix[i]);
  final ok = switch (format) {
    FaceImageFormat.jpeg => startsWith(const [0xFF, 0xD8, 0xFF]),
    FaceImageFormat.jpeg2000 =>
      startsWith(const [0x00, 0x00, 0x00, 0x0C, 0x6A, 0x50, 0x20, 0x20]) ||
          startsWith(const [0xFF, 0x4F, 0xFF, 0x51]),
  };
  if (!ok) {
    throw LdsFormatException('Face image is not a valid ${format.name} file');
  }
}
