import 'package:ekyc_demo/kyc/domain/kyc_error.dart';
import 'package:ekyc_demo/kyc/flow/kyc_flow_cubit.dart';
import 'package:ekyc_demo/kyc/ui/error_text.dart';
import 'package:ekyc_demo/kyc/ui/mrz_view.dart';
import 'package:ekyc_demo/kyc/ui/step_scaffold.dart';
import 'package:ekyc_demo/l10n/gen/app_localizations.dart';
import 'package:ekyc_nfc_reader/ekyc_nfc_reader.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:icao_mrz/icao_mrz.dart';

/// Chip reading progress, or a retryable error.
class NfcView extends StatelessWidget {
  const NfcView({
    required this.mrzKey,
    this.step,
    this.progress = 0,
    this.error,
    super.key,
  });

  final MrzKey mrzKey;
  final ChipReadStep? step;
  final double progress;
  final KycError? error;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cubit = context.read<KycFlowCubit>();
    final theme = Theme.of(context);
    final failed = error;
    final current = step ?? ChipReadStep.waitingForCard;
    return StepScaffold(
      title: l.nfcTitle,
      onCancel: cubit.restart,
      cancelLabel: l.cancel,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          NfcScanOverlay(
            status: NfcScanStatus.of(current, failed: failed != null),
            progress: progress,
            semanticLabel: l.nfcIllustration,
          ),
          const SizedBox(height: 24),
          if (failed == null) ...[
            Semantics(
              liveRegion: true,
              value: current == ChipReadStep.waitingForCard
                  ? null
                  : '${(progress * 100).round()}%',
              child: Text(
                _stepText(l, current),
                style: theme.textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: 16),
          ] else ...[
            Card(
              color: theme.colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline),
                    const SizedBox(width: 12),
                    Expanded(child: Text(failed.message(l))),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          InfoRow(icon: Icons.badge_outlined, text: l.nfcInstructionCard),
          InfoRow(
            icon: Icons.menu_book_outlined,
            text: l.nfcInstructionPassport,
          ),
          InfoRow(icon: Icons.pan_tool_outlined, text: l.nfcHold),
        ],
      ),
      actions: [
        if (failed != null && failed.isRetryable)
          FilledButton(
            onPressed: () => cubit.readChip(mrzKey, chipMessages(l)),
            child: Text(l.retry),
          ),
        if (failed != null)
          OutlinedButton(onPressed: cubit.editMrz, child: Text(l.editMrz)),
      ],
    );
  }

  static String _stepText(AppLocalizations l, ChipReadStep step) =>
      switch (step) {
        ChipReadStep.waitingForCard => l.nfcStepWaiting,
        ChipReadStep.authenticating => l.nfcStepAuthenticating,
        ChipReadStep.reading => l.nfcStepReading,
        ChipReadStep.verifying => l.nfcStepVerifying,
      };
}
