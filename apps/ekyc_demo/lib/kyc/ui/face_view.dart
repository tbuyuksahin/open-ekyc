import 'dart:typed_data';

import 'package:ekyc_demo/kyc/flow/kyc_flow_cubit.dart';
import 'package:ekyc_demo/l10n/gen/app_localizations.dart';
import 'package:ekyc_face_capture/ekyc_face_capture.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Selfie step: randomized movement challenges, then an automatic or
/// manual photo.
class FaceView extends StatefulWidget {
  const FaceView({this.sampleSelfie, super.key});

  /// Demo mode: offered instead of the camera.
  final Uint8List? sampleSelfie;

  /// Movements the demo draws from; three are asked in random order.
  static const List<FaceChallenge> challenges = FaceChallenge.values;

  /// How many movements are asked.
  static const challengeCount = 3;

  @override
  State<FaceView> createState() => _FaceViewState();
}

class _FaceViewState extends State<FaceView> {
  FaceCaptureMode _mode = FaceCaptureMode.auto;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cubit = context.read<KycFlowCubit>();
    final sample = widget.sampleSelfie;
    return Scaffold(
      appBar: AppBar(
        title: Text(l.faceTitle),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            onPressed: cubit.restart,
            icon: const Icon(Icons.close),
            tooltip: l.cancel,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(l.faceInstruction),
          ),
          if (sample == null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SegmentedButton<FaceCaptureMode>(
                segments: [
                  ButtonSegment(
                    value: FaceCaptureMode.auto,
                    label: Text(l.faceModeAuto),
                    icon: const Icon(Icons.motion_photos_auto_outlined),
                  ),
                  ButtonSegment(
                    value: FaceCaptureMode.manual,
                    label: Text(l.faceModeManual),
                    icon: const Icon(Icons.camera_alt_outlined),
                  ),
                ],
                selected: {_mode},
                onSelectionChanged: (s) => setState(() => _mode = s.single),
              ),
            ),
          Expanded(
            child: sample != null
                ? Center(
                    child: FilledButton.icon(
                      onPressed: () => cubit.faceCaptured(sample),
                      icon: const Icon(Icons.face_retouching_natural),
                      label: Text(l.faceUseSample),
                    ),
                  )
                : FaceCapture(
                    // A new mode starts a new capture.
                    key: ValueKey(_mode),
                    captureMode: _mode,
                    challenges: FaceView.challenges,
                    challengeCount: FaceView.challengeCount,
                    onCaptured: (result) => cubit.faceCaptured(
                      result.image,
                      challenges: result.challenges,
                    ),
                    hintText: (hint) => _hint(l, hint),
                    challengeText: (challenge) => _challenge(l, challenge),
                    timeoutText: l.faceChallengeTimeout,
                    shutterLabel: l.faceShutter,
                    unavailableBuilder: (_) => Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(l.cameraUnavailable),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  static String _hint(AppLocalizations l, FaceHint hint) => switch (hint) {
    FaceHint.noFace => l.faceNoFace,
    FaceHint.multipleFaces => l.faceMultipleFaces,
    FaceHint.moveCloser => l.faceMoveCloser,
    FaceHint.center => l.faceCenter,
    FaceHint.lookStraight => l.faceLookStraight,
    FaceHint.openEyes => l.faceOpenEyes,
    FaceHint.holdStill => l.faceHoldStill,
  };

  static String _challenge(AppLocalizations l, FaceChallenge c) => switch (c) {
    FaceChallenge.turnLeft => l.faceChallengeTurnLeft,
    FaceChallenge.turnRight => l.faceChallengeTurnRight,
    FaceChallenge.lookUp => l.faceChallengeLookUp,
    FaceChallenge.lookDown => l.faceChallengeLookDown,
    FaceChallenge.smile => l.faceChallengeSmile,
    FaceChallenge.blink => l.faceChallengeBlink,
  };
}
