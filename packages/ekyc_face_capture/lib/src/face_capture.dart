import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:ekyc_camera/ekyc_camera.dart';
import 'package:ekyc_face_capture/src/face_challenge.dart';
import 'package:ekyc_face_capture/src/face_overlay.dart';
import 'package:ekyc_face_capture/src/face_quality.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:material_ui/material_ui.dart';

/// How the selfie is taken once the face is good.
enum FaceCaptureMode {
  /// Automatically, after a few good frames in a row.
  auto,

  /// When the user taps the shutter button.
  manual,
}

/// The selfie and how it was obtained.
@immutable
class FaceCaptureResult {
  /// Creates a result.
  const FaceCaptureResult({
    required this.image,
    this.challenges = const [],
  });

  /// JPEG bytes of the selfie.
  final Uint8List image;

  /// The challenges the user completed before the photo, in order; empty
  /// when none were asked.
  final List<FaceChallenge> challenges;

  /// Whether active challenges were asked and all completed.
  bool get challengesPassed => challenges.isNotEmpty;
}

/// Front camera with an oval guide that takes a selfie for face matching.
///
/// The flow has up to three phases:
/// 1. **Position**: the face is framed until [FaceQualityGate] accepts it.
///    Skipped when there are no [challenges].
/// 2. **Challenges**: the user turns their head, smiles or blinks as asked
///    by a [FaceChallengeSession].
/// 3. **Photo**: taken automatically or with the shutter button, depending
///    on [captureMode], from a frontal, good quality frame.
///
/// Face detection runs on the device. The photo file the camera plugin
/// writes is deleted as soon as it is read into memory.
class FaceCapture extends StatefulWidget {
  /// Creates a capture view.
  const FaceCapture({
    required this.onCaptured,
    required this.unavailableBuilder,
    this.hintText,
    this.challengeText,
    this.timeoutText,
    this.shutterLabel = 'Take photo',
    this.challenges = const [],
    this.challengeCount,
    this.randomOrder = true,
    this.challengeTimeout = const Duration(seconds: 8),
    this.maxAttempts = 3,
    this.thresholds = const FaceChallengeThresholds(),
    this.onChallengesFailed,
    this.captureMode = FaceCaptureMode.auto,
    this.manualRequiresGoodFrame = true,
    this.style = const FaceOverlayStyle(),
    this.gate,
    this.frameInterval = const Duration(milliseconds: 100),
    super.key,
  });

  /// Receives the selfie.
  final ValueChanged<FaceCaptureResult> onCaptured;

  /// Shown when there is no camera or permission was denied.
  final WidgetBuilder unavailableBuilder;

  /// Text for each framing hint; no hint when `null`.
  final String Function(FaceHint hint)? hintText;

  /// Text for each challenge, for example "Turn your head left".
  final String Function(FaceChallenge challenge)? challengeText;

  /// Shown briefly when a challenge timed out and the sequence restarts.
  final String? timeoutText;

  /// Screen reader label of the shutter button in manual mode.
  final String shutterLabel;

  /// Challenges to draw from; none means no challenge phase.
  final List<FaceChallenge> challenges;

  /// How many challenges to ask; all of [challenges] when `null`.
  final int? challengeCount;

  /// Whether to shuffle (and pick) challenges on every attempt.
  final bool randomOrder;

  /// Time allowed for each challenge.
  final Duration challengeTimeout;

  /// Attempts before [onChallengesFailed] is called.
  final int maxAttempts;

  /// Challenge detection thresholds.
  final FaceChallengeThresholds thresholds;

  /// Called when the user ran out of attempts. When `null` the challenges
  /// simply start over.
  final VoidCallback? onChallengesFailed;

  /// Automatic or manual photo.
  final FaceCaptureMode captureMode;

  /// In manual mode, whether the shutter only works on a good frame.
  final bool manualRequiresGoodFrame;

  /// Overlay style.
  final FaceOverlayStyle style;

  /// Quality thresholds; [FaceQualityGate] defaults when `null`.
  final FaceQualityGate? gate;

  /// Minimum time between analyzed frames.
  final Duration frameInterval;

  @override
  State<FaceCapture> createState() => _FaceCaptureState();
}

enum _Phase { position, challenges, photo, failed }

class _FaceCaptureState extends State<FaceCapture> {
  late final MlKitCamera _camera = MlKitCamera(
    lensDirection: CameraLensDirection.front,
    onFrame: _onFrame,
    frameInterval: widget.frameInterval,
  );
  final _detector = FaceDetector(
    options: FaceDetectorOptions(enableClassification: true),
  );
  late final FaceQualityGate _gate = widget.gate ?? FaceQualityGate();
  late final FaceChallengeSession? _session = widget.challenges.isEmpty
      ? null
      : FaceChallengeSession(
          pool: widget.challenges,
          count: widget.challengeCount,
          randomOrder: widget.randomOrder,
          timeout: widget.challengeTimeout,
          maxAttempts: widget.maxAttempts,
          thresholds: widget.thresholds,
        );
  late _Phase _phase = _session == null ? _Phase.photo : _Phase.position;
  FaceHint _hint = FaceHint.noFace;
  double _progress = 0;
  bool _captured = false;
  DateTime? _noticeUntil;
  List<FaceChallenge> _completed = const [];

  @override
  void initState() {
    super.initState();
    unawaited(_camera.start());
  }

  Future<void> _onFrame(InputImage input) async {
    if (_captured || _phase == _Phase.failed) return;
    final faces = await _detector.processImage(input);
    if (!mounted || _captured) return;
    final metadata = input.metadata!;
    // On Android ML Kit reports boxes in the rotated (upright) frame.
    final rotated =
        Platform.isAndroid &&
        (metadata.rotation == InputImageRotation.rotation90deg ||
            metadata.rotation == InputImageRotation.rotation270deg);
    final size = metadata.size;
    final upright = rotated ? Size(size.height, size.width) : size;
    final observations = [
      for (final f in faces)
        FaceObservation(
          box: f.boundingBox,
          imageSize: upright,
          yaw: f.headEulerAngleY,
          roll: f.headEulerAngleZ,
          pitch: f.headEulerAngleX,
          smiling: f.smilingProbability,
          leftEyeOpen: f.leftEyeOpenProbability,
          rightEyeOpen: f.rightEyeOpenProbability,
        ),
    ];
    switch (_phase) {
      case _Phase.position:
        _position(observations);
      case _Phase.challenges:
        _challenge(observations);
      case _Phase.photo:
        await _photo(observations);
      case _Phase.failed:
        break;
    }
  }

  void _position(List<FaceObservation> faces) {
    final hint = _gate.hintFor(faces);
    setState(() {
      _hint = hint;
      if (hint == FaceHint.holdStill) _phase = _Phase.challenges;
    });
  }

  void _challenge(List<FaceObservation> faces) {
    final session = _session!;
    final event = session.evaluate(faces, DateTime.now());
    setState(() {
      _hint = switch (faces.length) {
        0 => FaceHint.noFace,
        1 => FaceHint.holdStill,
        _ => FaceHint.multipleFaces,
      };
      switch (event) {
        case FaceChallengeEvent.completed:
          _completed = session.sequence;
          _gate.reset();
          _phase = _Phase.photo;
        case FaceChallengeEvent.timedOut:
          _noticeUntil = DateTime.now().add(const Duration(seconds: 2));
        case FaceChallengeEvent.failed:
          final failed = widget.onChallengesFailed;
          if (failed != null) {
            _phase = _Phase.failed;
            failed();
          } else {
            session.restart();
            _phase = _Phase.position;
          }
        case FaceChallengeEvent.waitingForFace ||
            FaceChallengeEvent.inProgress ||
            FaceChallengeEvent.stepCompleted:
          break;
      }
    });
  }

  Future<void> _photo(List<FaceObservation> faces) async {
    if (widget.captureMode == FaceCaptureMode.manual) {
      final hint = _gate.hintFor(faces);
      if (hint != _hint) setState(() => _hint = hint);
      return;
    }
    final hint = _gate.evaluate(faces);
    if (hint == null) {
      await _capture();
    } else if (hint != _hint || _gate.progress != _progress) {
      setState(() {
        _hint = hint;
        _progress = _gate.progress;
      });
    }
  }

  Future<void> _capture() async {
    if (_captured) return;
    setState(() => _captured = true);
    final bytes = await _camera.takePicture();
    if (!mounted) return;
    if (bytes == null) {
      _gate.reset();
      setState(() {
        _captured = false;
        _progress = 0;
      });
    } else {
      widget.onCaptured(
        FaceCaptureResult(image: bytes, challenges: _completed),
      );
    }
  }

  bool get _canShoot =>
      _phase == _Phase.photo &&
      !_captured &&
      (!widget.manualRequiresGoodFrame || _hint == FaceHint.holdStill);

  @override
  void dispose() {
    _camera.dispose();
    unawaited(_detector.close());
    super.dispose();
  }

  String? _hintText(FaceChallenge? challenge) {
    if (_captured || _phase == _Phase.failed) return null;
    final notice = _noticeUntil;
    if (notice != null &&
        DateTime.now().isBefore(notice) &&
        widget.timeoutText != null) {
      return widget.timeoutText;
    }
    if (challenge != null && _hint == FaceHint.holdStill) {
      return widget.challengeText?.call(challenge);
    }
    return widget.hintText?.call(_hint);
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;
    final challenge = _phase == _Phase.challenges ? session?.current : null;
    final state = challenge != null && _hint == FaceHint.holdStill
        ? FaceGuideState.challenge
        : FaceGuideState.of(_hint, captured: _captured);
    final manual = widget.captureMode == FaceCaptureMode.manual;
    return Stack(
      fit: StackFit.expand,
      children: [
        MlKitCameraView(
          camera: _camera,
          unavailableBuilder: widget.unavailableBuilder,
          overlay: FaceOverlay(
            state: state,
            progress: manual ? 0 : _progress,
            hint: _hintText(challenge),
            challenge: challenge,
            challengeCount: session?.sequence.length ?? 0,
            challengesDone: _phase == _Phase.challenges
                ? session!.completedCount
                : _completed.length,
            style: widget.style,
          ),
        ),
        if (manual && _phase == _Phase.photo)
          Positioned(
            left: 0,
            right: 0,
            bottom: 24,
            child: Center(
              child: ShutterButton(
                label: widget.shutterLabel,
                color: widget.style.readyColor,
                onPressed: _canShoot ? _capture : null,
              ),
            ),
          ),
      ],
    );
  }
}
