import 'dart:typed_data';

import 'package:icao_mrtd/src/errors.dart';
import 'package:icao_mrtd/src/lds/lds_file.dart';
import 'package:icao_mrtd/src/tlv.dart';
import 'package:meta/meta.dart';

/// EF.COM: the LDS version and the data groups present on the chip.
///
/// EF.COM is not covered by the document security object. Use it only to
/// decide what to read, never as proof of what the document contains.
@immutable
class EfCom {
  const EfCom._(this.ldsVersion, this.unicodeVersion, this.dataGroups);

  /// Parses the raw contents of EF.COM.
  factory EfCom.parse(Uint8List bytes) {
    final root = Tlv.decode(bytes);
    if (root.tag != LdsFile.com.tag) {
      throw const LdsFormatException('EF.COM must start with tag 60');
    }
    final tags = root.require(0x5C).value;
    final groups = <LdsFile>[];
    for (final t in tags) {
      final file = LdsFile.forTag(t);
      if (file != null) groups.add(file);
    }
    return EfCom._(
      String.fromCharCodes(root.child(0x5F01)?.value ?? const []),
      String.fromCharCodes(root.child(0x5F36)?.value ?? const []),
      List.unmodifiable(groups),
    );
  }

  /// LDS version, for example `0107` for 1.7.
  final String ldsVersion;

  /// Unicode version, for example `040000`.
  final String unicodeVersion;

  /// Data groups listed as present (only those this package knows).
  final List<LdsFile> dataGroups;
}
