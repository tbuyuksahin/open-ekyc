import 'dart:async';

import 'package:ekyc_demo/kyc/camera/mrz_camera_view.dart';
import 'package:ekyc_demo/kyc/domain/chip_reader.dart';
import 'package:ekyc_demo/kyc/domain/kyc_error.dart';
import 'package:ekyc_demo/kyc/domain/mrz_input.dart';
import 'package:ekyc_demo/kyc/flow/kyc_flow_cubit.dart';
import 'package:ekyc_demo/kyc/ui/error_text.dart';
import 'package:ekyc_demo/kyc/ui/step_scaffold.dart';
import 'package:ekyc_demo/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:icao_mrz/icao_mrz.dart';

ChipReadMessages chipMessages(AppLocalizations l) => ChipReadMessages(
  prompt: l.nfcIosPrompt,
  reading: l.nfcIosReading,
  done: l.nfcIosDone,
  failed: l.nfcIosFailed,
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
              child: MrzCameraView(
                onDetected: (mrz) => _submit(mrz.key),
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
        error: widget.error,
        onSubmit: _submit,
        onScan: () => setState(() => _camera = true),
      ),
    );
  }
}

/// The three BAC fields with validation.
class ManualMrzForm extends StatefulWidget {
  const ManualMrzForm({
    required this.onSubmit,
    this.onScan,
    this.prefill,
    this.error,
    this.now,
    super.key,
  });

  final ValueChanged<MrzKey> onSubmit;
  final VoidCallback? onScan;
  final MrzKey? prefill;
  final KycError? error;

  /// Injected for tests.
  final DateTime? now;

  @override
  State<ManualMrzForm> createState() => _ManualMrzFormState();
}

class _ManualMrzFormState extends State<ManualMrzForm> {
  final _form = GlobalKey<FormState>();
  late final _number = TextEditingController(
    text: widget.prefill?.documentNumber.replaceAll('<', ''),
  );
  late final _dob = TextEditingController(
    text: _format(widget.prefill?.dateOfBirth.asBirthDate()),
  );
  late final _doe = TextEditingController(
    text: _format(widget.prefill?.dateOfExpiry.asExpiryDate()),
  );

  static String _format(DateTime? d) => d == null ? '' : MrzInput.formatDate(d);

  @override
  void dispose() {
    // Clear the fields so the values do not linger in the controllers.
    for (final c in [_number, _dob, _doe]) {
      c
        ..clear()
        ..dispose();
    }
    super.dispose();
  }

  void _submit() {
    if (!(_form.currentState?.validate() ?? false)) return;
    final key = MrzInput.toKey(
      documentNumber: _number.text,
      dateOfBirth: MrzInput.parseDate(_dob.text),
      dateOfExpiry: MrzInput.parseDate(_doe.text),
    );
    if (key != null) widget.onSubmit(key);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final now = widget.now ?? DateTime.now();
    final dateFormatter = FilteringTextInputFormatter.allow(RegExp('[0-9.]'));
    return Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 16,
        children: [
          if (widget.error != null)
            Card(
              color: Theme.of(context).colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(widget.error!.message(l)),
              ),
            ),
          Text(l.mrzManualHint),
          TextFormField(
            controller: _number,
            decoration: InputDecoration(labelText: l.mrzDocNumber),
            textCapitalization: TextCapitalization.characters,
            autocorrect: false,
            enableSuggestions: false,
            validator: (v) =>
                MrzInput.isValidNumber(v ?? '') ? null : l.mrzInvalidNumber,
          ),
          TextFormField(
            controller: _dob,
            decoration: InputDecoration(
              labelText: l.mrzDob,
              hintText: l.mrzDateHint,
            ),
            keyboardType: TextInputType.datetime,
            inputFormatters: [dateFormatter],
            enableSuggestions: false,
            validator: (v) {
              final date = MrzInput.parseDate(v ?? '');
              if (date == null) return l.mrzInvalidDate;
              if (date.isAfter(now)) return l.mrzBirthInFuture;
              return null;
            },
          ),
          TextFormField(
            controller: _doe,
            decoration: InputDecoration(
              labelText: l.mrzDoe,
              hintText: l.mrzDateHint,
            ),
            keyboardType: TextInputType.datetime,
            inputFormatters: [dateFormatter],
            enableSuggestions: false,
            validator: (v) {
              final date = MrzInput.parseDate(v ?? '');
              if (date == null) return l.mrzInvalidDate;
              final dob = MrzInput.parseDate(_dob.text);
              if (dob != null && !date.isAfter(dob)) {
                return l.mrzExpiryBeforeBirth;
              }
              return null;
            },
          ),
          FilledButton(onPressed: _submit, child: Text(l.mrzContinue)),
          if (widget.onScan != null)
            OutlinedButton.icon(
              onPressed: widget.onScan,
              icon: const Icon(Icons.document_scanner_outlined),
              label: Text(l.mrzScanCamera),
            ),
        ],
      ),
    );
  }
}
