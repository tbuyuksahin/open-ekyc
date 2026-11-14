import 'package:ekyc_nfc_reader/ekyc_nfc_reader.dart';
import 'package:ekyc_sdk/src/scaffold.dart';
import 'package:ekyc_sdk/src/strings.dart';
import 'package:material_ui/material_ui.dart';

/// The NFC step as a full screen: where to hold the document, read
/// progress, and a retryable error.
///
/// This screen only shows state; the read itself is driven by its owner
/// (for example `EkycFlow`).
class EkycNfcScreen extends StatelessWidget {
  /// Creates the screen.
  const EkycNfcScreen({
    required this.strings,
    this.step = ChipReadStep.waitingForCard,
    this.progress = 0,
    this.errorText,
    this.onRetry,
    this.onEditDetails,
    this.onCancel,
    this.style = const NfcOverlayStyle(),
    super.key,
  });

  /// Texts.
  final EkycStrings strings;

  /// Current read step.
  final ChipReadStep step;

  /// Overall progress (0-1).
  final double progress;

  /// Set when the read failed.
  final String? errorText;

  /// Shows a retry button with the error when set.
  final VoidCallback? onRetry;

  /// Shows a "check document details" button with the error when set.
  final VoidCallback? onEditDetails;

  /// Shows a close button when set.
  final VoidCallback? onCancel;

  /// Illustration style.
  final NfcOverlayStyle style;

  @override
  Widget build(BuildContext context) {
    final s = strings;
    final theme = Theme.of(context);
    final error = errorText;
    return EkycStepScaffold(
      title: s.nfcTitle,
      onCancel: onCancel,
      cancelLabel: s.cancel,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          NfcScanOverlay(
            status: NfcScanStatus.of(step, failed: error != null),
            progress: progress,
            semanticLabel: s.nfcIllustration,
            style: style,
          ),
          const SizedBox(height: 24),
          if (error == null)
            Semantics(
              liveRegion: true,
              value: step == ChipReadStep.waitingForCard
                  ? null
                  : '${(progress * 100).round()}%',
              child: Text(s.nfcStep(step), style: theme.textTheme.titleMedium),
            )
          else
            Card(
              color: theme.colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline),
                    const SizedBox(width: 12),
                    Expanded(child: Text(error)),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 16),
          EkycInfoRow(icon: Icons.badge_outlined, text: s.nfcInstructionCard),
          EkycInfoRow(
            icon: Icons.menu_book_outlined,
            text: s.nfcInstructionPassport,
          ),
          EkycInfoRow(icon: Icons.pan_tool_outlined, text: s.nfcHold),
        ],
      ),
      actions: [
        if (error != null && onRetry != null)
          FilledButton(onPressed: onRetry, child: Text(s.retry)),
        if (error != null && onEditDetails != null)
          OutlinedButton(
            onPressed: onEditDetails,
            child: Text(s.checkDetails),
          ),
      ],
    );
  }
}
