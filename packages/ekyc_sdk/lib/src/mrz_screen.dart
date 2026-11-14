import 'package:ekyc_mrz_scanner/ekyc_mrz_scanner.dart';
import 'package:ekyc_sdk/src/scaffold.dart';
import 'package:ekyc_sdk/src/strings.dart';
import 'package:material_ui/material_ui.dart';

/// The MRZ step as a full screen: camera scanner with a switch to the
/// manual form.
class EkycMrzScreen extends StatefulWidget {
  /// Creates the screen.
  const EkycMrzScreen({
    required this.strings,
    required this.onSubmit,
    this.onCancel,
    this.prefill,
    this.errorText,
    this.startWithCamera = true,
    this.style = const MrzOverlayStyle(),
    super.key,
  });

  /// Texts.
  final EkycStrings strings;

  /// Receives the key from the camera or the form.
  final ValueChanged<MrzKey> onSubmit;

  /// Shows a close button when set.
  final VoidCallback? onCancel;

  /// Values to start the form with; opens the form instead of the camera.
  final MrzKey? prefill;

  /// An error shown above the form; opens the form instead of the camera.
  final String? errorText;

  /// Whether to open the camera first.
  final bool startWithCamera;

  /// Scanner overlay style.
  final MrzOverlayStyle style;

  @override
  State<EkycMrzScreen> createState() => _EkycMrzScreenState();
}

class _EkycMrzScreenState extends State<EkycMrzScreen> {
  late bool _camera =
      widget.startWithCamera &&
      widget.prefill == null &&
      widget.errorText == null;

  @override
  Widget build(BuildContext context) {
    final s = widget.strings;
    if (!_camera) {
      return EkycStepScaffold(
        title: s.mrzTitle,
        onCancel: widget.onCancel,
        cancelLabel: s.cancel,
        body: ManualMrzForm(
          prefill: widget.prefill,
          errorText: widget.errorText,
          labels: s.formLabels,
          onSubmit: widget.onSubmit,
          onScan: () => setState(() => _camera = true),
        ),
      );
    }
    return Scaffold(
      appBar: ekycAppBar(
        s.mrzTitle,
        onCancel: widget.onCancel,
        cancelLabel: s.cancel,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(s.mrzScanHint),
          ),
          Expanded(
            child: MrzScanner(
              onDetected: (mrz) => widget.onSubmit(mrz.key),
              hintText: s.mrzStatus,
              style: widget.style,
              unavailableBuilder: (_) => Padding(
                padding: const EdgeInsets.all(24),
                child: Text(s.cameraUnavailable),
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
                  label: Text(s.mrzEnterManually),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
