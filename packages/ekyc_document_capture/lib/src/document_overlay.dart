import 'package:ekyc_camera/ekyc_camera.dart';
import 'package:ekyc_document_capture/src/document_gate.dart';
import 'package:ekyc_document_capture/src/document_kind.dart';
import 'package:material_ui/material_ui.dart';

/// What the capture guide shows.
enum DocumentGuideState {
  /// The expected side is not in view.
  searching,

  /// The side is in view but something needs fixing.
  adjusting,

  /// The frame is good; counting down to the photo.
  ready,

  /// The photo was taken.
  captured;

  /// The state for [hint].
  static DocumentGuideState of(DocumentHint hint, {bool captured = false}) {
    if (captured) return DocumentGuideState.captured;
    return switch (hint) {
      DocumentHint.noDocument => DocumentGuideState.searching,
      DocumentHint.wrongSide ||
      DocumentHint.tooDark ||
      DocumentHint.glare ||
      DocumentHint.blurry => DocumentGuideState.adjusting,
      DocumentHint.holdStill => DocumentGuideState.ready,
    };
  }
}

/// Colors, sizes and behavior of [DocumentOverlay].
@immutable
class DocumentOverlayStyle {
  /// Creates a style; every value has a default that reads well over a
  /// camera preview.
  const DocumentOverlayStyle({
    this.scrimColor = const Color(0x99000000),
    this.frameColor = Colors.white,
    this.accentColor = const Color(0xFFFFC857),
    this.readyColor = const Color(0xFF4FC3F7),
    this.successColor = const Color(0xFF34C759),
    this.templateColor = const Color(0x55FFFFFF),
    this.mrzBandColor = const Color(0x26FFFFFF),
    this.borderWidth = 2,
    this.cornerWidth = 5,
    this.cornerLength = 28,
    this.cornerRadius = 12,
    this.widthFactor = 0.9,
    this.alignment = const Alignment(0, -0.15),
    this.showTemplate = true,
    this.showScanLine = true,
    this.animateFlip = true,
    this.scanDuration = const Duration(milliseconds: 1800),
    this.flipDuration = const Duration(milliseconds: 600),
    this.hintStyle,
    this.labelStyle,
  });

  /// Darkens the area outside the document.
  final Color scrimColor;

  /// Outline while searching.
  final Color frameColor;

  /// Outline while something needs fixing.
  final Color accentColor;

  /// Outline, scan line and progress while the frame is good.
  final Color readyColor;

  /// Outline, MRZ band and check mark once the photo is taken.
  final Color successColor;

  /// Placeholder portrait, text lines and MRZ characters.
  final Color templateColor;

  /// Fill of the MRZ band on the side that has one.
  final Color mrzBandColor;

  /// Width of the document outline.
  final double borderWidth;

  /// Width of the corner accents; 0 hides them.
  final double cornerWidth;

  /// Length of each corner accent arm.
  final double cornerLength;

  /// Corner radius of the outline.
  final double cornerRadius;

  /// Document width as a fraction of the overlay width.
  final double widthFactor;

  /// Where the document sits in the overlay.
  final Alignment alignment;

  /// Whether to draw the placeholder layout of the expected side.
  final bool showTemplate;

  /// Whether to sweep a scan line over the document while searching.
  final bool showScanLine;

  /// Whether to turn the template over when the side changes.
  final bool animateFlip;

  /// Time for one pass of the scan line.
  final Duration scanDuration;

  /// Time for the template to turn over.
  final Duration flipDuration;

  /// Hint text style; the theme's `titleMedium` in white by default.
  final TextStyle? hintStyle;

  /// Side label style; the theme's `labelLarge` in white by default.
  final TextStyle? labelStyle;

  /// The outline color for [state].
  Color frameColorFor(DocumentGuideState state) => switch (state) {
    DocumentGuideState.searching => frameColor,
    DocumentGuideState.adjusting => accentColor,
    DocumentGuideState.ready => readyColor,
    DocumentGuideState.captured => successColor,
  };

  /// A copy with the given values replaced.
  DocumentOverlayStyle copyWith({
    Color? scrimColor,
    Color? frameColor,
    Color? accentColor,
    Color? readyColor,
    Color? successColor,
    Color? templateColor,
    Color? mrzBandColor,
    double? borderWidth,
    double? cornerWidth,
    double? cornerLength,
    double? cornerRadius,
    double? widthFactor,
    Alignment? alignment,
    bool? showTemplate,
    bool? showScanLine,
    bool? animateFlip,
    Duration? scanDuration,
    Duration? flipDuration,
    TextStyle? hintStyle,
    TextStyle? labelStyle,
  }) => DocumentOverlayStyle(
    scrimColor: scrimColor ?? this.scrimColor,
    frameColor: frameColor ?? this.frameColor,
    accentColor: accentColor ?? this.accentColor,
    readyColor: readyColor ?? this.readyColor,
    successColor: successColor ?? this.successColor,
    templateColor: templateColor ?? this.templateColor,
    mrzBandColor: mrzBandColor ?? this.mrzBandColor,
    borderWidth: borderWidth ?? this.borderWidth,
    cornerWidth: cornerWidth ?? this.cornerWidth,
    cornerLength: cornerLength ?? this.cornerLength,
    cornerRadius: cornerRadius ?? this.cornerRadius,
    widthFactor: widthFactor ?? this.widthFactor,
    alignment: alignment ?? this.alignment,
    showTemplate: showTemplate ?? this.showTemplate,
    showScanLine: showScanLine ?? this.showScanLine,
    animateFlip: animateFlip ?? this.animateFlip,
    scanDuration: scanDuration ?? this.scanDuration,
    flipDuration: flipDuration ?? this.flipDuration,
    hintStyle: hintStyle ?? this.hintStyle,
    labelStyle: labelStyle ?? this.labelStyle,
  );

  @override
  bool operator ==(Object other) =>
      other is DocumentOverlayStyle &&
      other.scrimColor == scrimColor &&
      other.frameColor == frameColor &&
      other.accentColor == accentColor &&
      other.readyColor == readyColor &&
      other.successColor == successColor &&
      other.templateColor == templateColor &&
      other.mrzBandColor == mrzBandColor &&
      other.borderWidth == borderWidth &&
      other.cornerWidth == cornerWidth &&
      other.cornerLength == cornerLength &&
      other.cornerRadius == cornerRadius &&
      other.widthFactor == widthFactor &&
      other.alignment == alignment &&
      other.showTemplate == showTemplate &&
      other.showScanLine == showScanLine &&
      other.animateFlip == animateFlip &&
      other.scanDuration == scanDuration &&
      other.flipDuration == flipDuration &&
      other.hintStyle == hintStyle &&
      other.labelStyle == labelStyle;

  @override
  int get hashCode => Object.hashAll([
    scrimColor,
    frameColor,
    accentColor,
    readyColor,
    successColor,
    templateColor,
    mrzBandColor,
    borderWidth,
    cornerWidth,
    cornerLength,
    cornerRadius,
    widthFactor,
    alignment,
    showTemplate,
    showScanLine,
    animateFlip,
    scanDuration,
    flipDuration,
    hintStyle,
    labelStyle,
  ]);
}

/// A document-shaped capture guide over the camera preview.
///
/// Draws the outline of [kind] in its real proportions with corner
/// accents, a scrim outside it and the placeholder layout of the expected
/// [side]: portrait and text lines on the front, the machine readable zone
/// where the document has one. While searching, a scan line sweeps the
/// document. When [side] changes, the template turns over like the card
/// in the user's hand. Above the document, a label and dots show which
/// side of how many is wanted; below it, a progress bar counts down to the
/// photo. Motion stops when the platform asks for reduced animations.
class DocumentOverlay extends StatefulWidget {
  /// Creates an overlay.
  const DocumentOverlay({
    this.kind = DocumentKind.idCard,
    this.side = DocumentSide.front,
    this.state = DocumentGuideState.searching,
    this.progress = 0,
    this.hint,
    this.label,
    this.step = 0,
    this.stepCount = 1,
    this.style = const DocumentOverlayStyle(),
    super.key,
  });

  /// The document shape.
  final DocumentKind kind;

  /// The side being captured.
  final DocumentSide side;

  /// Current guide state.
  final DocumentGuideState state;

  /// Countdown to the photo, 0 to 1.
  final double progress;

  /// Guidance shown below the document, announced to screen readers.
  final String? hint;

  /// Short name of the side, shown above the document.
  final String? label;

  /// Index of the side being captured.
  final int step;

  /// Number of sides to capture; the step dots are hidden for one.
  final int stepCount;

  /// Colors and sizes.
  final DocumentOverlayStyle style;

  /// The document outline in an overlay of [size].
  static Rect documentRect(
    Size size,
    DocumentKind kind,
    DocumentOverlayStyle style,
  ) {
    final width = size.width * style.widthFactor;
    final docSize = Size(width, width / kind.aspectRatio);
    return style.alignment.inscribe(docSize, Offset.zero & size);
  }

  /// The machine readable zone inside [document], sized as in ICAO 9303.
  static Rect mrzRect(Rect document, DocumentKind kind) {
    final height = document.height * kind.mrzZoneHeight;
    final inset = document.width * 0.035;
    return Rect.fromLTRB(
      document.left + inset,
      document.bottom - height - inset * 0.5,
      document.right - inset,
      document.bottom - inset * 0.5,
    );
  }

  @override
  State<DocumentOverlay> createState() => _DocumentOverlayState();
}

class _DocumentOverlayState extends State<DocumentOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _scan = AnimationController(
    vsync: this,
    duration: widget.style.scanDuration,
  );
  late final AnimationController _flip = AnimationController(
    vsync: this,
    duration: widget.style.flipDuration,
    value: 1,
  );
  late DocumentSide _from = widget.side;

  bool get _reduceMotion =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  bool get _scanning =>
      widget.style.showScanLine &&
      widget.state == DocumentGuideState.searching &&
      !_reduceMotion;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(DocumentOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    _scan.duration = widget.style.scanDuration;
    _flip.duration = widget.style.flipDuration;
    if (oldWidget.side != widget.side) {
      _from = oldWidget.side;
      if (widget.style.animateFlip && !_reduceMotion) {
        _flip.forward(from: 0).ignore();
      } else {
        _flip.value = 1;
      }
    }
    _sync();
  }

  void _sync() {
    if (_scanning) {
      if (!_scan.isAnimating) _scan.repeat(reverse: true).ignore();
    } else {
      _scan.stop();
    }
  }

  @override
  void dispose() {
    _scan.dispose();
    _flip.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = widget.style;
    final theme = Theme.of(context).textTheme;
    final hintStyle =
        style.hintStyle ?? theme.titleMedium?.copyWith(color: Colors.white);
    final labelStyle =
        style.labelStyle ?? theme.labelLarge?.copyWith(color: Colors.white);
    final hint = widget.hint;
    final label = widget.label;
    final frameTarget = style.frameColorFor(widget.state);
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        final doc = DocumentOverlay.documentRect(size, widget.kind, style);
        return Stack(
          fit: StackFit.expand,
          children: [
            TweenAnimationBuilder<Color?>(
              tween: ColorTween(end: frameTarget),
              duration: const Duration(milliseconds: 250),
              builder: (context, color, _) => AnimatedBuilder(
                animation: Listenable.merge([_scan, _flip]),
                builder: (context, _) {
                  final turn = Curves.easeInOut.transform(_flip.value);
                  return CustomPaint(
                    painter: DocumentOverlayPainter(
                      kind: widget.kind,
                      side: turn < 0.5 ? _from : widget.side,
                      state: widget.state,
                      progress: widget.progress,
                      style: style,
                      frameColor: color ?? style.frameColor,
                      scanPosition: _scanning ? _scan.value : null,
                      templateScale: (turn - 0.5).abs() * 2,
                    ),
                  );
                },
              ),
            ),
            if (widget.state == DocumentGuideState.captured)
              Positioned.fromRect(
                rect: doc,
                child: Center(
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.6, end: 1),
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOutBack,
                    builder: (context, scale, child) =>
                        Transform.scale(scale: scale, child: child),
                    child: Icon(
                      Icons.check_circle,
                      color: style.successColor,
                      size: doc.height * 0.35,
                    ),
                  ),
                ),
              ),
            if (label != null || widget.stepCount > 1)
              Positioned(
                left: 16,
                right: 16,
                bottom: size.height - doc.top + 14,
                child: _SideHeader(
                  label: label,
                  step: widget.step,
                  count: widget.stepCount,
                  labelStyle: labelStyle,
                  activeColor: frameTarget,
                  doneColor: style.successColor,
                  idleColor: style.templateColor,
                ),
              ),
            if (hint != null)
              Positioned(
                left: 24,
                right: 24,
                top: doc.bottom + 28,
                child: Semantics(
                  liveRegion: true,
                  child: Text(
                    hint,
                    textAlign: TextAlign.center,
                    style: hintStyle,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _SideHeader extends StatelessWidget {
  const _SideHeader({
    required this.label,
    required this.step,
    required this.count,
    required this.labelStyle,
    required this.activeColor,
    required this.doneColor,
    required this.idleColor,
  });

  final String? label;
  final int step;
  final int count;
  final TextStyle? labelStyle;
  final Color activeColor;
  final Color doneColor;
  final Color idleColor;

  @override
  Widget build(BuildContext context) {
    final label = this.label;
    return Column(
      mainAxisSize: MainAxisSize.min,
      spacing: 8,
      children: [
        if (label != null)
          DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0x66000000),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              child: Text(label, style: labelStyle),
            ),
          ),
        if (count > 1)
          ExcludeSemantics(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 6,
              children: [
                for (var i = 0; i < count; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    width: i == step ? 22 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: i < step
                          ? doneColor
                          : i == step
                          ? activeColor
                          : idleColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Paints a [DocumentOverlay]; public so hosts can reuse it in their own
/// widgets.
class DocumentOverlayPainter extends CustomPainter {
  /// Creates a painter for one frame of the overlay.
  const DocumentOverlayPainter({
    required this.kind,
    required this.side,
    required this.state,
    required this.progress,
    required this.style,
    required this.frameColor,
    this.scanPosition,
    this.templateScale = 1,
  });

  /// The document shape.
  final DocumentKind kind;

  /// The side whose template is drawn.
  final DocumentSide side;

  /// Current guide state.
  final DocumentGuideState state;

  /// Countdown to the photo, 0 to 1.
  final double progress;

  /// Colors and sizes.
  final DocumentOverlayStyle style;

  /// The outline color, animated by the overlay.
  final Color frameColor;

  /// Scan line position over the document (0-1), or `null` for none.
  final double? scanPosition;

  /// Horizontal scale of the template (0-1), for the turn-over animation.
  final double templateScale;

  @override
  void paint(Canvas canvas, Size size) {
    final doc = DocumentOverlay.documentRect(size, kind, style);
    final outline = RRect.fromRectAndRadius(
      doc,
      Radius.circular(style.cornerRadius),
    );
    ScrimPainter(
      cutout: Path()..addRRect(outline),
      color: style.scrimColor,
    ).paint(canvas, size);

    canvas
      ..save()
      ..clipRRect(outline)
      ..translate(doc.center.dx, 0)
      ..scale(templateScale.clamp(0.0, 1.0), 1)
      ..translate(-doc.center.dx, 0);
    if (style.showTemplate) _paintTemplate(canvas, doc);
    if (kind.hasMrzOn(side)) _paintMrzBand(canvas, doc);
    canvas.restore();

    final scan = scanPosition;
    if (scan != null) {
      final area = kind.hasMrzOn(side)
          ? DocumentOverlay.mrzRect(doc, kind)
          : doc.deflate(doc.width * 0.035);
      GuidePainting.scanLine(canvas, area, scan, style.readyColor);
    }

    canvas.drawRRect(
      outline,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = style.borderWidth
        ..color = frameColor,
    );
    if (style.cornerWidth > 0) {
      GuidePainting.corners(
        canvas,
        doc,
        radius: style.cornerRadius,
        length: style.cornerLength,
        width: style.cornerWidth,
        color: frameColor,
      );
    }

    if (state == DocumentGuideState.ready && progress > 0) {
      final track = Rect.fromLTWH(doc.left, doc.bottom + 12, doc.width, 4);
      final radius = Radius.circular(track.height / 2);
      canvas
        ..drawRRect(
          RRect.fromRectAndRadius(track, radius),
          Paint()..color = style.templateColor,
        )
        ..drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(
              track.left,
              track.top,
              track.width * progress.clamp(0.0, 1.0),
              track.height,
            ),
            radius,
          ),
          Paint()..color = style.readyColor,
        );
    }
  }

  void _paintMrzBand(Canvas canvas, Rect doc) {
    final band = DocumentOverlay.mrzRect(doc, kind);
    canvas.drawRRect(
      RRect.fromRectAndRadius(band, const Radius.circular(6)),
      Paint()
        ..color = state == DocumentGuideState.captured
            ? style.successColor.withValues(alpha: 0.25)
            : style.mrzBandColor,
    );
    final format = kind.mrzFormat;
    GuidePainting.mrzCharacters(
      canvas,
      band,
      lines: format.lineCount,
      length: format.lineLength,
      color: style.templateColor,
    );
  }

  void _paintTemplate(Canvas canvas, Rect doc) {
    final paint = Paint()..color = style.templateColor;
    final unit = doc.height / 20;
    final hasMrz = kind.hasMrzOn(side);
    final bottom = hasMrz
        ? DocumentOverlay.mrzRect(doc, kind).top - unit
        : doc.bottom - unit * 2;
    final top = doc.top + unit * 2.5;
    void line(double left, double y, double width) => canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(left, y, width, unit * 0.9),
        Radius.circular(unit),
      ),
      paint,
    );

    if (side == DocumentSide.front) {
      final photo = Rect.fromLTWH(
        doc.left + doc.width * 0.04,
        top,
        doc.width * 0.26,
        bottom - top - unit,
      );
      GuidePainting.portrait(canvas, photo, style.templateColor);
      final left = photo.right + doc.width * 0.05;
      final width = doc.right - left - doc.width * 0.06;
      const lines = 5;
      for (var i = 0; i < lines; i++) {
        line(
          left,
          top + (bottom - top - unit) * i / lines,
          width * (i.isEven ? 0.8 : 0.55),
        );
      }
      return;
    }
    final left = doc.left + doc.width * 0.06;
    final width = doc.width * 0.88;
    final chip = Rect.fromLTWH(
      doc.right - doc.width * 0.06 - unit * 4,
      top,
      unit * 4,
      unit * 3,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(chip, Radius.circular(unit * 0.6)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = style.templateColor,
    );
    const lines = 3;
    for (var i = 0; i < lines; i++) {
      line(
        left,
        top + (bottom - top) * i / (lines + 1),
        (width - chip.width - unit) * (i.isEven ? 0.75 : 0.5),
      );
    }
  }

  @override
  bool shouldRepaint(DocumentOverlayPainter oldDelegate) =>
      oldDelegate.kind != kind ||
      oldDelegate.side != side ||
      oldDelegate.state != state ||
      oldDelegate.progress != progress ||
      oldDelegate.style != style ||
      oldDelegate.frameColor != frameColor ||
      oldDelegate.scanPosition != scanPosition ||
      oldDelegate.templateScale != templateScale;
}
