import 'package:ekyc_demo/kyc/domain/kyc_repository.dart';
import 'package:ekyc_demo/kyc/flow/kyc_flow_cubit.dart';
import 'package:ekyc_demo/l10n/gen/app_localizations.dart';
import 'package:ekyc_sdk/ekyc_sdk.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';

class ResultView extends StatelessWidget {
  const ResultView({required this.decision, super.key});

  final VerificationDecision decision;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final (icon, title, body) = switch (decision) {
      VerificationDecision.approved => (
        Icons.check_circle_outline,
        l.resultApproved,
        l.resultApprovedBody,
      ),
      VerificationDecision.rejected => (
        Icons.cancel_outlined,
        l.resultRejected,
        l.resultRejectedBody,
      ),
      VerificationDecision.manualReview => (
        Icons.hourglass_top,
        l.resultManualReview,
        l.resultManualReviewBody,
      ),
    };
    final theme = Theme.of(context);
    return EkycStepScaffold(
      title: l.appTitle,
      body: Column(
        children: [
          const SizedBox(height: 48),
          Icon(icon, size: 72, color: theme.colorScheme.primary),
          const SizedBox(height: 16),
          Text(title, style: theme.textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(body, textAlign: TextAlign.center),
          const SizedBox(height: 24),
          EkycInfoRow(icon: Icons.delete_outline, text: l.resultDataErased),
        ],
      ),
      actions: [
        FilledButton(
          onPressed: context.read<KycFlowCubit>().restart,
          child: Text(l.resultRestart),
        ),
      ],
    );
  }
}
