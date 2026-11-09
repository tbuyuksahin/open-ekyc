import 'package:ekyc_demo/kyc/flow/kyc_flow_cubit.dart';
import 'package:ekyc_demo/kyc/flow/kyc_flow_state.dart';
import 'package:ekyc_demo/kyc/ui/consent_view.dart';
import 'package:ekyc_demo/kyc/ui/face_view.dart';
import 'package:ekyc_demo/kyc/ui/mrz_view.dart';
import 'package:ekyc_demo/kyc/ui/nfc_view.dart';
import 'package:ekyc_demo/kyc/ui/result_view.dart';
import 'package:ekyc_demo/kyc/ui/review_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Renders the current step of the flow.
class KycFlowPage extends StatelessWidget {
  const KycFlowPage({this.cameraAvailable = true, super.key});

  /// False in widget tests and on devices without a camera.
  final bool cameraAvailable;

  @override
  Widget build(BuildContext context) => BlocBuilder<KycFlowCubit, KycFlowState>(
    buildWhen: (a, b) => a.runtimeType != b.runtimeType || a != b,
    builder: (context, state) {
      final child = switch (state) {
        ConsentStep(:final loading) => ConsentView(loading: loading),
        MrzStep(:final prefill, :final error, :final isDemo) => MrzView(
          key: ValueKey(('mrz', error)),
          prefill: prefill,
          error: error,
          startWithCamera: cameraAvailable && !isDemo,
        ),
        ChipStep(:final key, :final step, :final progress) => NfcView(
          key: const ValueKey('nfc'),
          mrzKey: key,
          step: step,
          progress: progress,
        ),
        ChipErrorStep(:final key, :final error) => NfcView(
          key: const ValueKey('nfc'),
          mrzKey: key,
          error: error,
        ),
        FaceStep(:final sampleSelfie) => FaceView(
          sampleSelfie: sampleSelfie,
        ),
        final ReviewStep s => ReviewView(state: s),
        ResultStep(:final decision) => ResultView(decision: decision),
      };
      return AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: KeyedSubtree(
          key: ValueKey(child.key ?? state.runtimeType),
          child: child,
        ),
      );
    },
  );
}
