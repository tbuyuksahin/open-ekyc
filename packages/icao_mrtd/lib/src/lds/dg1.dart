import 'dart:typed_data';

import 'package:icao_mrtd/src/errors.dart';
import 'package:icao_mrtd/src/lds/lds_file.dart';
import 'package:icao_mrtd/src/tlv.dart';
import 'package:icao_mrz/icao_mrz.dart';

/// Parses DG1, which stores the MRZ as one string without line breaks.
Mrz parseDg1(Uint8List bytes) {
  final root = Tlv.decode(bytes);
  if (root.tag != LdsFile.dg1.tag) {
    throw const LdsFormatException('DG1 must start with tag 61');
  }
  final text = String.fromCharCodes(root.require(0x5F1F).value);
  final format = switch (text.length) {
    90 => MrzFormat.td1,
    72 => MrzFormat.td2,
    88 => MrzFormat.td3,
    _ => throw LdsFormatException('DG1 MRZ has ${text.length} characters'),
  };
  try {
    return Mrz.parse([
      for (var i = 0; i < format.lineCount; i++)
        text.substring(i * format.lineLength, (i + 1) * format.lineLength),
    ]);
  } on FormatException {
    throw const LdsFormatException('DG1 does not contain a valid MRZ');
  }
}
