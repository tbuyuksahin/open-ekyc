import 'package:ekyc_document_capture/ekyc_document_capture.dart';
import 'package:ekyc_sdk/src/config.dart';
import 'package:ekyc_sdk/src/scaffold.dart';
import 'package:ekyc_sdk/src/strings.dart';
import 'package:material_ui/material_ui.dart';

/// The document photo step as a full screen: instructions, an optional
/// automatic/manual switch, and the capture view.
class EkycDocumentScreen extends StatefulWidget {
  /// Creates the screen.
  const EkycDocumentScreen({
    required this.strings,
    required this.onCaptured,
    this.onCancel,
    this.options = const EkycDocumentOptions(),
    this.style = const DocumentOverlayStyle(),
    super.key,
  });

  /// Texts.
  final EkycStrings strings;

  /// Receives the photos.
  final ValueChanged<DocumentCaptureResult> onCaptured;

  /// Shows a close button when set.
  final VoidCallback? onCancel;

  /// Document, sides and capture mode.
  final EkycDocumentOptions options;

  /// Overlay style.
  final DocumentOverlayStyle style;

  @override
  State<EkycDocumentScreen> createState() => _EkycDocumentScreenState();
}

class _EkycDocumentScreenState extends State<EkycDocumentScreen> {
  late DocumentCaptureMode _mode = widget.options.captureMode;

  @override
  Widget build(BuildContext context) {
    final s = widget.strings;
    final options = widget.options;
    return Scaffold(
      appBar: ekycAppBar(
        s.documentTitle,
        onCancel: widget.onCancel,
        cancelLabel: s.cancel,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(s.documentInstruction),
          ),
          if (options.allowModeSwitch)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SegmentedButton<DocumentCaptureMode>(
                segments: [
                  ButtonSegment(
                    value: DocumentCaptureMode.auto,
                    label: Text(s.faceModeAuto),
                    icon: const Icon(Icons.motion_photos_auto_outlined),
                  ),
                  ButtonSegment(
                    value: DocumentCaptureMode.manual,
                    label: Text(s.faceModeManual),
                    icon: const Icon(Icons.camera_alt_outlined),
                  ),
                ],
                selected: {_mode},
                onSelectionChanged: (m) => setState(() => _mode = m.single),
              ),
            ),
          Expanded(
            child: DocumentCapture(
              // A new mode starts a new capture.
              key: ValueKey(_mode),
              kind: options.kind,
              sides: options.sides,
              captureMode: _mode,
              onCaptured: widget.onCaptured,
              hintText: s.documentHint,
              sideLabel: s.documentSide,
              shutterLabel: s.documentShutter,
              style: widget.style,
              unavailableBuilder: (_) => Padding(
                padding: const EdgeInsets.all(24),
                child: Text(s.cameraUnavailable),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
