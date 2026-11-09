import 'dart:typed_data';

import 'package:ekyc_demo/kyc/domain/liveness.dart';
import 'package:ekyc_demo/kyc/domain/masking.dart';
import 'package:ekyc_demo/kyc/flow/kyc_flow_cubit.dart';
import 'package:ekyc_demo/kyc/flow/kyc_flow_state.dart';
import 'package:ekyc_demo/kyc/ui/error_text.dart';
import 'package:ekyc_demo/kyc/ui/step_scaffold.dart';
import 'package:ekyc_demo/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:icao_mrtd/icao_mrtd.dart';
import 'package:intl/intl.dart';

class ReviewView extends StatelessWidget {
  const ReviewView({required this.state, super.key});

  final ReviewStep state;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cubit = context.read<KycFlowCubit>();
    final doc = state.document;
    final dates = DateFormat.yMd(Localizations.localeOf(context).toString());
    String date(DateTime? d) => d == null ? '—' : dates.format(d);
    final error = state.error;
    return StepScaffold(
      title: l.reviewTitle,
      onCancel: state.submitting ? null : cubit.restart,
      cancelLabel: l.cancel,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            spacing: 12,
            children: [
              Expanded(
                child: _Portrait(
                  label: l.reviewChipPhoto,
                  bytes: doc.face.format == FaceImageFormat.jpeg
                      ? doc.face.bytes
                      : null,
                ),
              ),
              Expanded(
                child: _Portrait(label: l.reviewSelfie, bytes: state.selfie),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _Field(l.reviewName, '${doc.givenNames} ${doc.surname}'),
          _Field(l.reviewDocNumber, maskMiddle(doc.mrz.documentNumber)),
          _Field(
            l.reviewBirth,
            date(
              doc.dg11?.fullDateOfBirth ?? doc.mrz.dateOfBirth.asBirthDate(),
            ),
          ),
          _Field(l.reviewExpiry, date(doc.mrz.dateOfExpiry.asExpiryDate())),
          _Field(l.reviewNationality, doc.mrz.nationality),
          const SizedBox(height: 16),
          _Notice(
            icon: doc.passiveAuth.status == PassiveAuthStatus.verified
                ? Icons.verified_outlined
                : Icons.gpp_maybe_outlined,
            title: doc.passiveAuth.status == PassiveAuthStatus.verified
                ? l.paVerified
                : l.paUntrusted,
            body: doc.passiveAuth.status == PassiveAuthStatus.verified
                ? l.paVerifiedBody
                : l.paUntrustedBody,
          ),
          if (state.liveness == LivenessOutcome.notPerformed)
            _Notice(
              icon: Icons.info_outline,
              title: l.livenessNotPerformed,
              body: l.livenessNotPerformedBody,
            ),
          if (error != null)
            Card(
              color: Theme.of(context).colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(error.message(l)),
              ),
            ),
        ],
      ),
      actions: [
        FilledButton(
          onPressed: state.submitting ? null : cubit.submit,
          child: state.submitting
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(l.reviewSubmit),
        ),
        OutlinedButton(
          onPressed: state.submitting ? null : cubit.retakeFace,
          child: Text(l.reviewRetake),
        ),
      ],
    );
  }
}

class _Portrait extends StatelessWidget {
  const _Portrait({required this.label, required this.bytes});

  final String label;
  final Uint8List? bytes;

  @override
  Widget build(BuildContext context) {
    final image = bytes;
    return Column(
      children: [
        AspectRatio(
          aspectRatio: 3 / 4,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: image == null
                ? ColoredBox(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    child: const Icon(Icons.person_outline, size: 48),
                  )
                : Image.memory(
                    image,
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                    semanticLabel: label,
                    errorBuilder: (_, _, _) =>
                        const Icon(Icons.broken_image_outlined, size: 48),
                  ),
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: Theme.of(context).textTheme.labelMedium),
      ],
    );
  }
}

class _Field extends StatelessWidget {
  const _Field(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      children: [
        Expanded(
          child: Text(label, style: Theme.of(context).textTheme.bodySmall),
        ),
        Expanded(flex: 2, child: Text(value)),
      ],
    ),
  );
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.title, required this.body});

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(body),
    ),
  );
}
