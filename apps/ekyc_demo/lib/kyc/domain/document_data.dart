import 'dart:typed_data';

import 'package:icao_mrtd/icao_mrtd.dart';
import 'package:icao_mrz/icao_mrz.dart';

/// Everything read from the chip, plus the on-device verification result.
///
/// Holds special category personal data (KVKK md. 6, GDPR art. 9: the
/// portrait is biometric). Keep it in memory only and call [wipe] as soon
/// as it is no longer needed.
class DocumentData {
  DocumentData({
    required this.mrz,
    required this.face,
    required this.passiveAuth,
    required this.rawFiles,
    this.dg11,
  });

  /// The MRZ from DG1 (authoritative over the scanned MRZ).
  final Mrz mrz;

  /// The portrait from DG2.
  final FaceImage face;

  /// Additional personal details, if the chip has DG11.
  final Dg11? dg11;

  /// On-device Passive Authentication. Advisory only: the server must
  /// repeat it with [rawFiles] because the client can be tampered with.
  final PassiveAuthResult passiveAuth;

  /// The raw LDS files, for server-side verification.
  final Map<LdsFile, Uint8List> rawFiles;

  /// Surname, preferring the full Unicode form from DG11.
  String get surname {
    final fromDg11 = dg11?.primaryIdentifier;
    return fromDg11 != null && fromDg11.isNotEmpty
        ? fromDg11
        : mrz.primaryIdentifier;
  }

  /// Given names, preferring the full Unicode form from DG11.
  String get givenNames {
    final fromDg11 = dg11?.secondaryIdentifier;
    return fromDg11 != null && fromDg11.isNotEmpty
        ? fromDg11
        : mrz.secondaryIdentifier;
  }

  bool _wiped = false;

  /// Whether [wipe] has run.
  bool get isWiped => _wiped;

  /// Overwrites the biometric and raw chip data with zeros.
  ///
  /// Dart strings are immutable and cannot be cleared; dropping every
  /// reference to this object lets the GC reclaim them.
  void wipe() {
    face.bytes.fillRange(0, face.bytes.length, 0);
    for (final bytes in rawFiles.values) {
      bytes.fillRange(0, bytes.length, 0);
    }
    _wiped = true;
  }

  @override
  String toString() => 'DocumentData(<redacted>)';
}
