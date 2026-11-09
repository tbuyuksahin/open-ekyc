import 'dart:typed_data';

import 'package:ekyc_face_capture/ekyc_face_capture.dart';
import 'package:ekyc_mrz_scanner/ekyc_mrz_scanner.dart';
import 'package:ekyc_nfc_reader/ekyc_nfc_reader.dart';
import 'package:ekyc_sdk/src/strings.dart';
import 'package:flutter/material.dart';

/// A step of the verification flow.
enum EkycStep {
  /// Scan or type the MRZ key that opens the chip.
  mrz,

  /// Read and verify the chip over NFC.
  nfc,

  /// Take a selfie.
  face,
}

/// Overlay styles of the three steps.
@immutable
class EkycTheme {
  /// Creates a theme from individual overlay styles.
  const EkycTheme({
    this.mrz = const MrzOverlayStyle(),
    this.nfc = const NfcOverlayStyle(),
    this.face = const FaceOverlayStyle(),
  });

  /// A theme that uses [primary] for guidance and [success] for completed
  /// states in every overlay.
  factory EkycTheme.brand({
    required Color primary,
    Color success = const Color(0xFF34C759),
  }) => EkycTheme(
    mrz: MrzOverlayStyle(accentColor: primary, successColor: success),
    nfc: NfcOverlayStyle(accentColor: primary, successColor: success),
    face: FaceOverlayStyle(challengeColor: primary, readyColor: success),
  );

  /// MRZ scanner overlay.
  final MrzOverlayStyle mrz;

  /// NFC illustration.
  final NfcOverlayStyle nfc;

  /// Selfie overlay.
  final FaceOverlayStyle face;
}

/// How the selfie step behaves.
@immutable
class EkycFaceOptions {
  /// Creates options; by default the photo is automatic with no
  /// movement challenges.
  const EkycFaceOptions({
    this.challenges = const [],
    this.challengeCount,
    this.randomOrder = true,
    this.challengeTimeout = const Duration(seconds: 8),
    this.maxAttempts = 3,
    this.captureMode = FaceCaptureMode.auto,
    this.allowModeSwitch = false,
  });

  /// Movements to draw from; none skips the challenge phase.
  final List<FaceChallenge> challenges;

  /// How many movements to ask; all of [challenges] when `null`.
  final int? challengeCount;

  /// Whether to shuffle (and pick) movements on every attempt.
  final bool randomOrder;

  /// Time allowed for each movement.
  final Duration challengeTimeout;

  /// Attempts before the movements start over.
  final int maxAttempts;

  /// Automatic or manual photo.
  final FaceCaptureMode captureMode;

  /// Whether the user can switch between automatic and manual capture.
  final bool allowModeSwitch;
}

/// What to run and how it looks.
@immutable
class EkycConfig {
  /// Creates a configuration; the default runs all three steps.
  const EkycConfig({
    this.steps = EkycStep.values,
    this.strings,
    this.theme = const EkycTheme(),
    this.face = const EkycFaceOptions(),
    this.trustStore,
    this.nfcSession = const FlutterNfcSession(),
    this.liveness = const NoLivenessCheck(),
    this.mrzKey,
    this.startWithCamera = true,
  });

  /// The steps to run, in the order MRZ, NFC, selfie.
  final List<EkycStep> steps;

  /// Texts; the built-in ones for the app's locale when `null`.
  final EkycStrings? strings;

  /// Overlay styles.
  final EkycTheme theme;

  /// Selfie options.
  final EkycFaceOptions face;

  /// Trusted CSCA certificates for Passive Authentication. Without them a
  /// genuine chip is reported as `untrusted`, not `verified`.
  final CscaStore? trustStore;

  /// The NFC transport; replace it with a `VirtualNfcSession` in tests
  /// and demos.
  final NfcSession nfcSession;

  /// Liveness provider called with the selfie.
  final LivenessCheck liveness;

  /// The chip access key. Required when [steps] has [EkycStep.nfc]
  /// without [EkycStep.mrz]; otherwise it prefills the MRZ form.
  final MrzKey? mrzKey;

  /// Whether the MRZ step opens the camera first, rather than the form.
  final bool startWithCamera;

  /// Whether [step] is part of the flow.
  bool has(EkycStep step) => steps.contains(step);

  /// A copy with the given values replaced.
  EkycConfig copyWith({
    List<EkycStep>? steps,
    EkycStrings? strings,
    EkycTheme? theme,
    EkycFaceOptions? face,
    CscaStore? trustStore,
    NfcSession? nfcSession,
    LivenessCheck? liveness,
    MrzKey? mrzKey,
    bool? startWithCamera,
  }) => EkycConfig(
    steps: steps ?? this.steps,
    strings: strings ?? this.strings,
    theme: theme ?? this.theme,
    face: face ?? this.face,
    trustStore: trustStore ?? this.trustStore,
    nfcSession: nfcSession ?? this.nfcSession,
    liveness: liveness ?? this.liveness,
    mrzKey: mrzKey ?? this.mrzKey,
    startWithCamera: startWithCamera ?? this.startWithCamera,
  );
}

/// What a finished flow collected.
///
/// Holds personal and biometric data. Keep it in memory only and call
/// [wipe] as soon as you have sent it to your server.
class EkycResult {
  /// Creates a result.
  EkycResult({
    this.mrzKey,
    this.document,
    this.selfie,
    this.challenges = const [],
    this.liveness = LivenessOutcome.notPerformed,
  });

  /// The chip access key from the MRZ step.
  final MrzKey? mrzKey;

  /// The verified chip data from the NFC step, including the raw files
  /// your server must re-verify.
  final DocumentData? document;

  /// JPEG bytes of the selfie.
  final Uint8List? selfie;

  /// Movements the user completed before the selfie.
  final List<FaceChallenge> challenges;

  /// Liveness outcome. Completed movements are reported as
  /// [LivenessOutcome.challengesPassed], never as live.
  final LivenessOutcome liveness;

  /// Overwrites the chip data and the selfie with zeros.
  void wipe() {
    document?.wipe();
    final bytes = selfie;
    if (bytes != null) bytes.fillRange(0, bytes.length, 0);
  }

  @override
  String toString() => 'EkycResult(<redacted>)';
}
