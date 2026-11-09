import 'package:ekyc_face_capture/ekyc_face_capture.dart';
import 'package:ekyc_sdk/src/config.dart';
import 'package:ekyc_sdk/src/scaffold.dart';
import 'package:ekyc_sdk/src/strings.dart';
import 'package:flutter/material.dart';

/// The selfie step as a full screen: instructions, an optional
/// automatic/manual switch, and the capture view.
class EkycFaceScreen extends StatefulWidget {
  /// Creates the screen.
  const EkycFaceScreen({
    required this.strings,
    required this.onCaptured,
    this.onCancel,
    this.options = const EkycFaceOptions(),
    this.style = const FaceOverlayStyle(),
    super.key,
  });

  /// Texts.
  final EkycStrings strings;

  /// Receives the selfie.
  final ValueChanged<FaceCaptureResult> onCaptured;

  /// Shows a close button when set.
  final VoidCallback? onCancel;

  /// Movements and capture mode.
  final EkycFaceOptions options;

  /// Overlay style.
  final FaceOverlayStyle style;

  @override
  State<EkycFaceScreen> createState() => _EkycFaceScreenState();
}

class _EkycFaceScreenState extends State<EkycFaceScreen> {
  late FaceCaptureMode _mode = widget.options.captureMode;

  @override
  Widget build(BuildContext context) {
    final s = widget.strings;
    final options = widget.options;
    return Scaffold(
      appBar: ekycAppBar(
        s.faceTitle,
        onCancel: widget.onCancel,
        cancelLabel: s.cancel,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(s.faceInstruction),
          ),
          if (options.allowModeSwitch)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SegmentedButton<FaceCaptureMode>(
                segments: [
                  ButtonSegment(
                    value: FaceCaptureMode.auto,
                    label: Text(s.faceModeAuto),
                    icon: const Icon(Icons.motion_photos_auto_outlined),
                  ),
                  ButtonSegment(
                    value: FaceCaptureMode.manual,
                    label: Text(s.faceModeManual),
                    icon: const Icon(Icons.camera_alt_outlined),
                  ),
                ],
                selected: {_mode},
                onSelectionChanged: (m) => setState(() => _mode = m.single),
              ),
            ),
          Expanded(
            child: FaceCapture(
              // A new mode starts a new capture.
              key: ValueKey(_mode),
              captureMode: _mode,
              challenges: options.challenges,
              challengeCount: options.challengeCount,
              randomOrder: options.randomOrder,
              challengeTimeout: options.challengeTimeout,
              maxAttempts: options.maxAttempts,
              onCaptured: widget.onCaptured,
              hintText: s.faceHint,
              challengeText: s.faceChallenge,
              timeoutText: s.faceChallengeTimeout,
              shutterLabel: s.faceShutter,
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
