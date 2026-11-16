import 'dart:async';

import 'package:ekyc_document_capture/ekyc_document_capture.dart';
import 'package:ekyc_nfc_reader/ekyc_nfc_reader.dart';
import 'package:ekyc_sdk/src/config.dart';
import 'package:ekyc_sdk/src/controller.dart';
import 'package:ekyc_sdk/src/document_screen.dart';
import 'package:ekyc_sdk/src/face_screen.dart';
import 'package:ekyc_sdk/src/mrz_screen.dart';
import 'package:ekyc_sdk/src/nfc_screen.dart';
import 'package:ekyc_sdk/src/strings.dart';
import 'package:material_ui/material_ui.dart';

/// The verification flow as a widget, for embedding in your own page or
/// navigation.
///
/// Runs the steps of [config] and calls [onCompleted] with what was
/// collected. If it is removed before completing, collected data is
/// wiped.
class EkycFlow extends StatefulWidget {
  /// Creates the flow.
  const EkycFlow({
    required this.onCompleted,
    this.onCancelled,
    this.config = const EkycConfig(),
    super.key,
  });

  /// Receives the result once, after the last step.
  final ValueChanged<EkycResult> onCompleted;

  /// Shows a close button on every step when set.
  final VoidCallback? onCancelled;

  /// What to run and how it looks.
  final EkycConfig config;

  @override
  State<EkycFlow> createState() => _EkycFlowState();
}

class _EkycFlowState extends State<EkycFlow> {
  late final EkycFlowController _controller = EkycFlowController(
    widget.config,
  )..addListener(_onChanged);
  bool _started = false;
  bool _completed = false;

  EkycStrings get _strings =>
      widget.config.strings ?? EkycStrings.of(Localizations.localeOf(context));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller.messages = _strings.chipMessages;
    if (!_started) {
      _started = true;
      unawaited(_controller.start());
    }
  }

  void _onChanged() {
    final stage = _controller.stage;
    if (stage is EkycDoneStage && !_completed) {
      _completed = true;
      widget.onCompleted(stage.result);
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_onChanged)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = _strings;
    final config = widget.config;
    final cancel = widget.onCancelled;
    final stage = _controller.stage;
    final child = switch (stage) {
      EkycDocumentStage() => EkycDocumentScreen(
        key: const ValueKey('document'),
        strings: s,
        options: config.document,
        style: config.theme.document,
        onCaptured: _controller.documentCaptured,
        onCancel: cancel,
      ),
      EkycMrzStage(:final prefill, :final error) => EkycMrzScreen(
        key: ValueKey(('mrz', error)),
        strings: s,
        prefill: prefill,
        errorText: error == null ? null : s.error(error),
        startWithCamera: config.startWithCamera,
        style: config.theme.mrz,
        onSubmit: _controller.submitMrz,
        onCancel: cancel,
      ),
      EkycChipStage(:final step, :final progress, :final error) =>
        EkycNfcScreen(
          key: const ValueKey('nfc'),
          strings: s,
          step: step,
          progress: progress,
          errorText: error == null ? null : s.error(error),
          onRetry: error != null && error.isRetryable
              ? _controller.retryChip
              : null,
          onEditDetails: config.has(EkycStep.mrz) ? _controller.editMrz : null,
          style: config.theme.nfc,
          onCancel: cancel,
        ),
      EkycFaceStage() => EkycFaceScreen(
        key: const ValueKey('face'),
        strings: s,
        options: config.face,
        style: config.theme.face,
        onCaptured: _controller.faceCaptured,
        onCancel: cancel,
      ),
      // The host usually navigates away in onCompleted.
      EkycDoneStage() => const Scaffold(
        key: ValueKey('done'),
        body: Center(child: Icon(Icons.check_circle_outline, size: 72)),
      ),
    };
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: child,
    );
  }
}

/// One-call entry points. Each opens a full screen route and completes
/// when the user finishes or cancels (`null`).
///
/// ```dart
/// final result = await Ekyc.start(context);
/// if (result != null) {
///   await upload(result.document!.rawFiles, result.selfie!);
///   result.wipe();
/// }
/// ```
abstract final class Ekyc {
  /// Runs the steps of [config]: by default MRZ, NFC, then selfie.
  static Future<EkycResult?> start(
    BuildContext context, {
    EkycConfig config = const EkycConfig(),
  }) => Navigator.of(context).push<EkycResult>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (route) => EkycFlow(
        config: config,
        onCompleted: (result) => Navigator.of(route).pop(result),
        onCancelled: () => Navigator.of(route).pop(),
      ),
    ),
  );

  /// Only the document photo step: returns the photos, the text read on
  /// the front and the MRZ when it was in view.
  static Future<DocumentCaptureResult?> captureDocument(
    BuildContext context, {
    EkycConfig config = const EkycConfig(),
  }) async {
    final result = await start(
      context,
      config: config.copyWith(steps: const [EkycStep.document]),
    );
    return result?.documentPhotos;
  }

  /// Only the MRZ step: returns the chip access key from the camera or
  /// the manual form.
  static Future<MrzKey?> scanMrz(
    BuildContext context, {
    EkycConfig config = const EkycConfig(),
  }) async {
    final result = await start(
      context,
      config: config.copyWith(steps: const [EkycStep.mrz]),
    );
    return result?.mrzKey;
  }

  /// Only the NFC step: reads and verifies the chip that [mrzKey] opens.
  static Future<DocumentData?> readChip(
    BuildContext context, {
    required MrzKey mrzKey,
    EkycConfig config = const EkycConfig(),
  }) async {
    final result = await start(
      context,
      config: config.copyWith(steps: const [EkycStep.nfc], mrzKey: mrzKey),
    );
    return result?.document;
  }

  /// Only the selfie step: the result has the selfie, the completed
  /// movements and the liveness outcome.
  static Future<EkycResult?> captureSelfie(
    BuildContext context, {
    EkycConfig config = const EkycConfig(),
  }) => start(context, config: config.copyWith(steps: const [EkycStep.face]));
}
