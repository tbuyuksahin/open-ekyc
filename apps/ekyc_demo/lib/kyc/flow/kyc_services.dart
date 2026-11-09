import 'dart:typed_data';

import 'package:ekyc_demo/kyc/domain/chip_reader.dart';
import 'package:ekyc_demo/kyc/domain/kyc_repository.dart';
import 'package:ekyc_demo/kyc/domain/liveness.dart';
import 'package:icao_mrz/icao_mrz.dart';

/// The collaborators of one verification run.
class KycServices {
  const KycServices({
    required this.chipReader,
    required this.repository,
    this.liveness = const NoLivenessCheck(),
    this.demoKey,
    this.sampleSelfie,
  });

  final ChipReader chipReader;
  final KycRepository repository;
  final LivenessCheck liveness;

  /// In demo mode, the specimen MRZ key to prefill.
  final MrzKey? demoKey;

  /// In demo mode, a selfie to use instead of the camera.
  final Uint8List? sampleSelfie;

  bool get isDemo => demoKey != null;
}
