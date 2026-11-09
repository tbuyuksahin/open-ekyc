import 'dart:async';

import 'package:ekyc_demo/kyc/domain/kyc_error.dart';
import 'package:ekyc_demo/kyc/flow/kyc_flow_cubit.dart';
import 'package:ekyc_demo/kyc/ui/error_text.dart';
import 'package:ekyc_demo/kyc/ui/step_scaffold.dart';
import 'package:ekyc_demo/l10n/gen/app_localizations.dart';
import 'package:ekyc_mrz_scanner/ekyc_mrz_scanner.dart';
import 'package:ekyc_nfc_reader/ekyc_nfc_reader.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

ChipReadMessages chipMessages(AppLocalizations l) => ChipReadMessages(
  prompt: l.nfcIosPrompt,
  reading: l.nfcIosReading,
  done: l.nfcIosDone,
  failed: l.nfcIosFailed,
);

MrzFormLabels mrzFormLabels(AppLocalizations l) => MrzFormLabels(
  instructions: l.mrzManualHint,
  documentNumber: l.mrzDocNumber,
  dateOfBirth: l.mrzDob,
  dateOfExpiry: l.mrzDoe,
  dateHint: l.mrzDateHint,
  invalidNumber: l.mrzInvalidNumber,
  invalidDate: l.mrzInvalidDate,
  birthInFuture: l.mrzBirthInFuture,
  expiryBeforeBirth: l.mrzExpiryBeforeBirth,
  submit: l.mrzContinue,
  scanWithCamera: l.mrzScanCamera,
);

/// MRZ entry: camera scan or manual form.
class MrzView extends StatefulWidget {
  const MrzView({
    this.prefill,
    this.error,
    this.startWithCamera = true,
    super.key,
  });

  final MrzKey? prefill;
  final KycError? error;
  final bool startWithCamera;

  @override
  State<MrzView> createState() => _MrzViewState();
}

class _MrzViewState extends State<MrzView> {
  late bool _camera =
      widget.startWithCamera && widget.prefill == null && widget.error == null;

  void _submit(MrzKey key) {
    final l = AppLocalizations.of(context);
    unawaited(context.read<KycFlowCubit>().readChip(key, chipMessages(l)));
  }

  static String _status(AppLocalizations l, MrzScanStatus status) =>
      switch (status) {
        MrzScanStatus.searching => l.mrzStatusSearching,
        MrzScanStatus.confirming => l.mrzStatusConfirming,
        MrzScanStatus.detected => l.mrzStatusDetected,
      };

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cubit = context.read<KycFlowCubit>();
    if (_camera) {
      return Scaffold(
        appBar: AppBar(
          title: Text(l.mrzTitle),
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
              child: Text(l.mrzScanHint),
            ),
            Expanded(
              child: MrzScanner(
                onDetected: (mrz) => _submit(mrz.key),
                hintText: (status) => _status(l, status),
                unavailableBuilder: (_) => Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(l.cameraUnavailable),
                ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => setState(() => _camera = false),
                    icon: const Icon(Icons.keyboard),
                    label: Text(l.mrzEnterManually),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }
    return StepScaffold(
      title: l.mrzTitle,
      onCancel: cubit.restart,
      cancelLabel: l.cancel,
      body: ManualMrzForm(
        prefill: widget.prefill,
        errorText: widget.error?.message(l),
        labels: mrzFormLabels(l),
        onSubmit: _submit,
        onScan: () => setState(() => _camera = true),
      ),
    );
  }
}
