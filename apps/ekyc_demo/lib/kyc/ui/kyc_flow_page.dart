import 'dart:async';

import 'package:ekyc_demo/kyc/flow/kyc_flow_cubit.dart';
import 'package:ekyc_demo/kyc/flow/kyc_flow_state.dart';
import 'package:ekyc_demo/kyc/ui/consent_view.dart';
import 'package:ekyc_demo/kyc/ui/error_text.dart';
import 'package:ekyc_demo/kyc/ui/face_view.dart';
import 'package:ekyc_demo/kyc/ui/result_view.dart';
import 'package:ekyc_demo/kyc/ui/review_view.dart';
import 'package:ekyc_demo/l10n/gen/app_localizations.dart';
import 'package:ekyc_sdk/ekyc_sdk.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

/// Renders the current step of the flow.
///
/// Consent, review and result are this app's own screens. The document
/// photo, MRZ, NFC and selfie steps are the SDK's screens, driven by
/// [KycFlowCubit].
class KycFlowPage extends StatelessWidget {
  const KycFlowPage({this.cameraAvailable = true, super.key});

  /// False in widget tests and on devices without a camera.
  final bool cameraAvailable;

  /// Movements asked before the selfie: three of all, in random order.
  static const faceOptions = EkycFaceOptions(
    challenges: FaceChallenge.values,
    challengeCount: 3,
    allowModeSwitch: true,
  );

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final s = EkycStrings.of(Localizations.localeOf(context));
    final cubit = context.read<KycFlowCubit>();
    void read(MrzKey key) => unawaited(cubit.readChip(key, s.chipMessages));
    return BlocBuilder<KycFlowCubit, KycFlowState>(
      buildWhen: (a, b) => a.runtimeType != b.runtimeType || a != b,
      builder: (context, state) {
        final child = switch (state) {
          ConsentStep(:final loading) => ConsentView(loading: loading),
          DocumentStep() => EkycDocumentScreen(
            strings: s,
            options: const EkycDocumentOptions(allowModeSwitch: true),
            onCaptured: (result) =>
                unawaited(cubit.documentCaptured(result, s.chipMessages)),
            onCancel: cubit.restart,
          ),
          MrzStep(:final prefill, :final error, :final isDemo) => EkycMrzScreen(
            key: ValueKey(('mrz', error)),
            strings: s,
            prefill: prefill,
            errorText: error?.message(l),
            startWithCamera: cameraAvailable && !isDemo,
            onSubmit: read,
            onCancel: cubit.restart,
          ),
          ChipStep(:final step, :final progress) => EkycNfcScreen(
            key: const ValueKey('nfc'),
            strings: s,
            step: step,
            progress: progress,
            onCancel: cubit.restart,
          ),
          ChipErrorStep(:final key, :final error) => EkycNfcScreen(
            key: const ValueKey('nfc'),
            strings: s,
            errorText: error.message(l),
            onRetry: error.isRetryable ? () => read(key) : null,
            onEditDetails: cubit.editMrz,
            onCancel: cubit.restart,
          ),
          FaceStep(:final sampleSelfie?) => SampleFaceView(
            sampleSelfie: sampleSelfie,
          ),
          FaceStep() => EkycFaceScreen(
            strings: s,
            options: faceOptions,
            onCaptured: (result) => cubit.faceCaptured(
              result.image,
              challenges: result.challenges,
            ),
            onCancel: cubit.restart,
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
}
