import 'dart:typed_data';

import 'package:ekyc_demo/kyc/camera/face_camera_view.dart';
import 'package:ekyc_demo/kyc/domain/face_quality.dart';
import 'package:ekyc_demo/kyc/flow/kyc_flow_cubit.dart';
import 'package:ekyc_demo/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class FaceView extends StatelessWidget {
  const FaceView({this.sampleSelfie, super.key});

  /// Demo mode: offered instead of the camera.
  final Uint8List? sampleSelfie;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cubit = context.read<KycFlowCubit>();
    final sample = sampleSelfie;
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
            padding: const EdgeInsets.all(16),
            child: Text(l.faceInstruction),
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
                : FaceCameraView(
                    onCaptured: cubit.faceCaptured,
                    hintText: (hint) => _hint(l, hint),
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
}
