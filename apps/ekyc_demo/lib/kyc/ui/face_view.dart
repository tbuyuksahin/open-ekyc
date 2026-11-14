import 'dart:typed_data';

import 'package:ekyc_demo/kyc/flow/kyc_flow_cubit.dart';
import 'package:ekyc_demo/l10n/gen/app_localizations.dart';
import 'package:ekyc_sdk/ekyc_sdk.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

/// Demo mode selfie step: offers the specimen portrait instead of the
/// camera, so the flow runs without any personal data.
class SampleFaceView extends StatelessWidget {
  const SampleFaceView({required this.sampleSelfie, super.key});

  final Uint8List sampleSelfie;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final s = EkycStrings.of(Localizations.localeOf(context));
    final cubit = context.read<KycFlowCubit>();
    return Scaffold(
      appBar: ekycAppBar(
        s.faceTitle,
        onCancel: cubit.restart,
        cancelLabel: s.cancel,
      ),
      body: Center(
        child: FilledButton.icon(
          onPressed: () => cubit.faceCaptured(sampleSelfie),
          icon: const Icon(Icons.face_retouching_natural),
          label: Text(l.faceUseSample),
        ),
      ),
    );
  }
}
