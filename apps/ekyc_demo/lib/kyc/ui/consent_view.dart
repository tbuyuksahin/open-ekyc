import 'package:ekyc_demo/kyc/flow/kyc_flow_cubit.dart';
import 'package:ekyc_demo/l10n/gen/app_localizations.dart';
import 'package:ekyc_sdk/ekyc_sdk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ConsentView extends StatefulWidget {
  const ConsentView({required this.loading, super.key});

  final bool loading;

  @override
  State<ConsentView> createState() => _ConsentViewState();
}

class _ConsentViewState extends State<ConsentView> {
  bool _accepted = false;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cubit = context.read<KycFlowCubit>();
    final enabled = _accepted && !widget.loading;
    return EkycStepScaffold(
      title: l.consentTitle,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.consentIntro, style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 16),
          EkycInfoRow(icon: Icons.text_fields, text: l.consentItemMrz),
          EkycInfoRow(icon: Icons.nfc, text: l.consentItemChip),
          EkycInfoRow(icon: Icons.face, text: l.consentItemFace),
          EkycInfoRow(
            icon: Icons.delete_sweep_outlined,
            text: l.consentRetention,
          ),
          const SizedBox(height: 8),
          CheckboxListTile(
            value: _accepted,
            onChanged: (v) => setState(() => _accepted = v ?? false),
            title: Text(l.consentCheckbox),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
          ),
        ],
      ),
      actions: [
        FilledButton(
          onPressed: enabled ? () => cubit.start(demo: false) : null,
          child: widget.loading
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(l.consentStart),
        ),
        OutlinedButton(
          onPressed: enabled ? () => cubit.start(demo: true) : null,
          child: Text(l.consentDemo),
        ),
        Text(
          l.consentDemoHint,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
