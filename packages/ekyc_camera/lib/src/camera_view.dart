import 'package:camera/camera.dart';
import 'package:ekyc_camera/src/ml_kit_camera.dart';
import 'package:flutter/material.dart';

/// Shows an [MlKitCamera] filling its box, with an [overlay] on top.
class MlKitCameraView extends StatelessWidget {
  /// Creates a view of [camera].
  const MlKitCameraView({
    required this.camera,
    required this.unavailableBuilder,
    this.overlay,
    this.loadingBuilder,
    super.key,
  });

  /// The camera to show.
  final MlKitCamera camera;

  /// Drawn over the preview, for example a capture guide.
  final Widget? overlay;

  /// Shown when there is no camera or permission was denied.
  final WidgetBuilder unavailableBuilder;

  /// Shown while the camera opens; a spinner by default.
  final WidgetBuilder? loadingBuilder;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: camera,
    builder: (context, _) {
      final controller = camera.controller;
      switch (camera.status) {
        case MlKitCameraStatus.unavailable:
          return unavailableBuilder(context);
        case MlKitCameraStatus.starting:
        case MlKitCameraStatus.ready
            when controller == null || !controller.value.isInitialized:
          return loadingBuilder?.call(context) ??
              const Center(child: CircularProgressIndicator());
        case MlKitCameraStatus.ready:
          return Stack(
            fit: StackFit.expand,
            children: [
              CoverPreview(child: CameraPreview(controller!)),
              ?overlay,
            ],
          );
      }
    },
  );
}

/// Scales a portrait camera preview to cover its box, cropping the edges
/// instead of letterboxing.
class CoverPreview extends StatelessWidget {
  /// Creates a cover-fit preview of [child].
  const CoverPreview({required this.child, this.previewSize, super.key});

  /// The preview widget.
  final Widget child;

  /// The sensor size (landscape); read from the nearest [CameraPreview]'s
  /// controller when omitted.
  final Size? previewSize;

  @override
  Widget build(BuildContext context) {
    final preview = child;
    final size =
        previewSize ??
        (preview is CameraPreview
            ? preview.controller.value.previewSize
            : null);
    return ClipRect(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          // Sensor sizes are landscape; the preview is shown portrait.
          width: size?.height ?? 1,
          height: size?.width ?? 1,
          child: child,
        ),
      ),
    );
  }
}

/// Darkens everything except [cutout], so the eye goes to the capture area.
class ScrimPainter extends CustomPainter {
  /// Creates a scrim with a [cutout] in [color].
  const ScrimPainter({required this.cutout, required this.color});

  /// The clear area, in the painter's coordinates.
  final Path cutout;

  /// The scrim color, usually translucent black.
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final scrim = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addPath(cutout, Offset.zero);
    canvas.drawPath(scrim, Paint()..color = color);
  }

  @override
  bool shouldRepaint(ScrimPainter oldDelegate) =>
      oldDelegate.cutout != cutout || oldDelegate.color != color;
}
