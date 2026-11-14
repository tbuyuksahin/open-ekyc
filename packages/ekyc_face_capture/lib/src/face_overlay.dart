import 'dart:math' as math;

import 'package:ekyc_camera/ekyc_camera.dart';
import 'package:ekyc_face_capture/src/face_challenge.dart';
import 'package:ekyc_face_capture/src/face_quality.dart';
import 'package:material_ui/material_ui.dart';

/// What [FaceOverlay] shows, derived from the gate's hint.
enum FaceGuideState {
  /// No usable face yet.
  idle,

  /// One face that needs adjusting.
  adjusting,

  /// A movement or expression is being asked.
  challenge,

  /// A good face; capture is counting down (or can be taken by hand).
  ready,

  /// The photo is being taken.
  captured;

  /// The state for [hint], or [captured] when [captured] is true.
  static FaceGuideState of(FaceHint? hint, {bool captured = false}) {
    if (captured || hint == null) return FaceGuideState.captured;
    if (hint == FaceHint.holdStill) return FaceGuideState.ready;
    return hint.isAdjustment ? FaceGuideState.adjusting : FaceGuideState.idle;
  }
}

/// Colors, sizes and behavior of [FaceOverlay].
@immutable
class FaceOverlayStyle {
  /// Creates a style; every value has a default that reads well over a
  /// camera preview.
  const FaceOverlayStyle({
    this.scrimColor = const Color(0xB3000000),
    this.idleColor = Colors.white,
    this.adjustColor = const Color(0xFFFFC107),
    this.challengeColor = const Color(0xFF4FC3F7),
    this.readyColor = const Color(0xFF34C759),
    this.strokeWidth = 3,
    this.progressStrokeWidth = 6,
    this.widthFactor = 0.72,
    this.aspectRatio = 1.3,
    this.alignment = const Alignment(0, -0.3),
    this.showProgress = true,
    this.pulse = true,
    this.pulseDuration = const Duration(milliseconds: 1400),
    this.hintStyle,
    this.hintBackgroundColor = const Color(0x8A000000),
  });

  /// Darkens the area outside the oval.
  final Color scrimColor;

  /// Oval color with no usable face.
  final Color idleColor;

  /// Oval color while the face needs adjusting.
  final Color adjustColor;

  /// Oval, arrows and step dots while a challenge is asked.
  final Color challengeColor;

  /// Oval and progress color for a good face, and completed step dots.
  final Color readyColor;

  /// Width of the oval outline.
  final double strokeWidth;

  /// Width of the capture progress arc.
  final double progressStrokeWidth;

  /// Oval width as a fraction of the overlay width.
  final double widthFactor;

  /// Oval height divided by width.
  final double aspectRatio;

  /// Where the oval sits in the overlay.
  final Alignment alignment;

  /// Whether to draw the capture progress along the oval.
  final bool showProgress;

  /// Whether the oval breathes while no face is in view, and the challenge
  /// arrows move.
  final bool pulse;

  /// One breath of the pulse, and one arrow movement.
  final Duration pulseDuration;

  /// Hint text style; the theme's `titleMedium` in white by default.
  final TextStyle? hintStyle;

  /// Background behind the hint, for legibility on bright scenes.
  final Color hintBackgroundColor;

  /// The oval color for [state].
  Color colorFor(FaceGuideState state) => switch (state) {
    FaceGuideState.idle => idleColor,
    FaceGuideState.adjusting => adjustColor,
    FaceGuideState.challenge => challengeColor,
    FaceGuideState.ready || FaceGuideState.captured => readyColor,
  };

  /// A copy with the given values replaced.
  FaceOverlayStyle copyWith({
    Color? scrimColor,
    Color? idleColor,
    Color? adjustColor,
    Color? challengeColor,
    Color? readyColor,
    double? strokeWidth,
    double? progressStrokeWidth,
    double? widthFactor,
    double? aspectRatio,
    Alignment? alignment,
    bool? showProgress,
    bool? pulse,
    Duration? pulseDuration,
    TextStyle? hintStyle,
    Color? hintBackgroundColor,
  }) => FaceOverlayStyle(
    scrimColor: scrimColor ?? this.scrimColor,
    idleColor: idleColor ?? this.idleColor,
    adjustColor: adjustColor ?? this.adjustColor,
    challengeColor: challengeColor ?? this.challengeColor,
    readyColor: readyColor ?? this.readyColor,
    strokeWidth: strokeWidth ?? this.strokeWidth,
    progressStrokeWidth: progressStrokeWidth ?? this.progressStrokeWidth,
    widthFactor: widthFactor ?? this.widthFactor,
    aspectRatio: aspectRatio ?? this.aspectRatio,
    alignment: alignment ?? this.alignment,
    showProgress: showProgress ?? this.showProgress,
    pulse: pulse ?? this.pulse,
    pulseDuration: pulseDuration ?? this.pulseDuration,
    hintStyle: hintStyle ?? this.hintStyle,
    hintBackgroundColor: hintBackgroundColor ?? this.hintBackgroundColor,
  );

  @override
  bool operator ==(Object other) =>
      other is FaceOverlayStyle &&
      other.scrimColor == scrimColor &&
      other.idleColor == idleColor &&
      other.adjustColor == adjustColor &&
      other.challengeColor == challengeColor &&
      other.readyColor == readyColor &&
      other.strokeWidth == strokeWidth &&
      other.progressStrokeWidth == progressStrokeWidth &&
      other.widthFactor == widthFactor &&
      other.aspectRatio == aspectRatio &&
      other.alignment == alignment &&
      other.showProgress == showProgress &&
      other.pulse == pulse &&
      other.pulseDuration == pulseDuration &&
      other.hintStyle == hintStyle &&
      other.hintBackgroundColor == hintBackgroundColor;

  @override
  int get hashCode => Object.hash(
    scrimColor,
    idleColor,
    adjustColor,
    challengeColor,
    readyColor,
    strokeWidth,
    progressStrokeWidth,
    widthFactor,
    aspectRatio,
    alignment,
    showProgress,
    pulse,
    pulseDuration,
    hintStyle,
    hintBackgroundColor,
  );
}

/// An oval face guide over the camera preview.
///
/// The oval is white with no face, amber while the face needs adjusting,
/// blue while a [challenge] is asked and green once the face is good, with
/// the capture countdown drawn along it. During challenges an arrow or an
/// icon shows what to do and dots show how many steps are done. Motion
/// stops when the platform asks for reduced animations.
class FaceOverlay extends StatefulWidget {
  /// Creates an overlay in [state].
  const FaceOverlay({
    required this.state,
    this.progress = 0,
    this.hint,
    this.challenge,
    this.challengeCount = 0,
    this.challengesDone = 0,
    this.style = const FaceOverlayStyle(),
    super.key,
  });

  /// What to show.
  final FaceGuideState state;

  /// Capture countdown (0-1) while [FaceGuideState.ready].
  final double progress;

  /// Guidance below the oval, announced to screen readers.
  final String? hint;

  /// The challenge being asked, if any.
  final FaceChallenge? challenge;

  /// Number of challenges in this attempt; 0 hides the step dots.
  final int challengeCount;

  /// Number of challenges completed.
  final int challengesDone;

  /// Colors and sizes.
  final FaceOverlayStyle style;

  /// The oval in an overlay of [size].
  static Rect ovalRect(Size size, FaceOverlayStyle style) {
    final width = size.width * style.widthFactor;
    final oval = Size(width, width * style.aspectRatio);
    return style.alignment.inscribe(oval, Offset.zero & size);
  }

  @override
  State<FaceOverlay> createState() => _FaceOverlayState();
}

class _FaceOverlayState extends State<FaceOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: widget.style.pulseDuration,
  );

  bool get _reduceMotion =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  bool get _animate =>
      widget.style.pulse &&
      !_reduceMotion &&
      (widget.state == FaceGuideState.idle || widget.challenge != null);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(FaceOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    _pulse.duration = widget.style.pulseDuration;
    _sync();
  }

  void _sync() {
    if (_animate) {
      if (!_pulse.isAnimating) _pulse.repeat(reverse: true).ignore();
    } else {
      _pulse
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = widget.style;
    final hint = widget.hint;
    final hintStyle =
        style.hintStyle ??
        Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(color: Colors.white);
    return LayoutBuilder(
      builder: (context, constraints) {
        final oval = FaceOverlay.ovalRect(constraints.biggest, style);
        final challenge = widget.challenge;
        return Stack(
          fit: StackFit.expand,
          children: [
            TweenAnimationBuilder<Color?>(
              tween: ColorTween(end: style.colorFor(widget.state)),
              duration: const Duration(milliseconds: 250),
              builder: (context, color, _) => TweenAnimationBuilder<double>(
                tween: Tween(end: widget.progress.clamp(0, 1)),
                duration: const Duration(milliseconds: 150),
                builder: (context, progress, _) => AnimatedBuilder(
                  animation: _pulse,
                  builder: (context, _) => CustomPaint(
                    painter: FaceOverlayPainter(
                      style: style,
                      color: color ?? style.idleColor,
                      progress: switch (widget.state) {
                        FaceGuideState.ready => progress,
                        FaceGuideState.captured => 1,
                        _ => 0,
                      },
                      pulse: widget.state == FaceGuideState.idle
                          ? Curves.easeInOut.transform(_pulse.value)
                          : 0,
                    ),
                  ),
                ),
              ),
            ),
            if (widget.challengeCount > 0)
              Positioned(
                left: 0,
                right: 0,
                top: math.max(0, oval.top - 32),
                child: _StepDots(
                  count: widget.challengeCount,
                  done: widget.challengesDone,
                  style: style,
                ),
              ),
            if (challenge != null) ..._challengeGuide(challenge, oval, style),
            if (hint != null)
              Positioned(
                left: 24,
                right: 24,
                top: oval.bottom + 24,
                child: Center(
                  child: Semantics(
                    liveRegion: true,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: style.hintBackgroundColor,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: Text(
                          hint,
                          textAlign: TextAlign.center,
                          style: hintStyle,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  // Arrows sit outside the oval on the side to move to; the preview of the
  // front camera is mirrored, so the user's left is on the screen's left.
  List<Widget> _challengeGuide(
    FaceChallenge challenge,
    Rect oval,
    FaceOverlayStyle style,
  ) {
    const size = 56.0;
    final (icon, center, direction) = switch (challenge) {
      FaceChallenge.turnLeft => (
        Icons.keyboard_double_arrow_left,
        Offset(oval.left - size * 0.35, oval.center.dy),
        const Offset(-1, 0),
      ),
      FaceChallenge.turnRight => (
        Icons.keyboard_double_arrow_right,
        Offset(oval.right + size * 0.35, oval.center.dy),
        const Offset(1, 0),
      ),
      FaceChallenge.lookUp => (
        Icons.keyboard_double_arrow_up,
        Offset(oval.center.dx, oval.top + size * 0.7),
        const Offset(0, -1),
      ),
      FaceChallenge.lookDown => (
        Icons.keyboard_double_arrow_down,
        Offset(oval.center.dx, oval.bottom - size * 0.7),
        const Offset(0, 1),
      ),
      FaceChallenge.smile => (
        Icons.sentiment_very_satisfied,
        Offset(oval.center.dx, oval.top),
        Offset.zero,
      ),
      FaceChallenge.blink => (
        Icons.visibility_off_outlined,
        Offset(oval.center.dx, oval.top),
        Offset.zero,
      ),
    };
    final badge = direction == Offset.zero;
    return [
      Positioned(
        left: center.dx - size / 2,
        top: center.dy - size / 2,
        width: size,
        height: size,
        child: ExcludeSemantics(
          child: AnimatedBuilder(
            animation: _pulse,
            builder: (context, child) {
              final t = Curves.easeInOut.transform(_pulse.value);
              return Transform.translate(
                offset: direction * 10 * t,
                child: Transform.scale(
                  scale: badge ? 1 + 0.12 * t : 1,
                  child: child,
                ),
              );
            },
            child: badge
                ? DecoratedBox(
                    decoration: BoxDecoration(
                      color: style.challengeColor,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, color: Colors.white, size: size * 0.6),
                  )
                : Icon(icon, color: style.challengeColor, size: size),
          ),
        ),
      ),
    ];
  }
}

class _StepDots extends StatelessWidget {
  const _StepDots({
    required this.count,
    required this.done,
    required this.style,
  });

  final int count;
  final int done;
  final FaceOverlayStyle style;

  @override
  Widget build(BuildContext context) => Semantics(
    label: '$done / $count',
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      spacing: 8,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: i == done ? 22 : 10,
            height: 10,
            decoration: BoxDecoration(
              color: i < done
                  ? style.readyColor
                  : i == done
                  ? style.challengeColor
                  : Colors.white38,
              borderRadius: BorderRadius.circular(5),
            ),
          ),
      ],
    ),
  );
}

/// Paints [FaceOverlay]; public so hosts can reuse it.
class FaceOverlayPainter extends CustomPainter {
  /// Creates a painter for one frame.
  const FaceOverlayPainter({
    required this.style,
    required this.color,
    this.progress = 0,
    this.pulse = 0,
  });

  /// Style.
  final FaceOverlayStyle style;

  /// Current oval color.
  final Color color;

  /// Capture progress drawn along the oval (0-1).
  final double progress;

  /// Pulse phase (0-1); grows the oval slightly.
  final double pulse;

  @override
  void paint(Canvas canvas, Size size) {
    final base = FaceOverlay.ovalRect(size, style);
    final oval = base.inflate(base.width * 0.015 * pulse);
    ScrimPainter(
      cutout: Path()..addOval(oval),
      color: style.scrimColor,
    ).paint(canvas, size);
    canvas.drawOval(
      oval,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = style.strokeWidth
        ..color = color.withValues(alpha: 1 - 0.4 * pulse),
    );
    if (style.showProgress && progress > 0) {
      canvas.drawArc(
        oval.inflate(style.progressStrokeWidth),
        -math.pi / 2,
        2 * math.pi * progress,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = style.progressStrokeWidth
          ..strokeCap = StrokeCap.round
          ..color = style.readyColor,
      );
    }
  }

  @override
  bool shouldRepaint(FaceOverlayPainter oldDelegate) =>
      oldDelegate.style != style ||
      oldDelegate.color != color ||
      oldDelegate.progress != progress ||
      oldDelegate.pulse != pulse;
}
