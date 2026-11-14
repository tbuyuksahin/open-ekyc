import 'dart:math' as math;

import 'package:ekyc_camera/ekyc_camera.dart';
import 'package:icao_mrz/icao_mrz.dart';
import 'package:material_ui/material_ui.dart';

/// What the MRZ scanner is doing, for the overlay and the hint text.
enum MrzScanStatus {
  /// No valid MRZ in view yet.
  searching,

  /// A valid MRZ was read; waiting for an identical read to confirm it.
  confirming,

  /// The MRZ is confirmed.
  detected,
}

/// Colors, sizes and behavior of [MrzOverlay].
@immutable
class MrzOverlayStyle {
  /// Creates a style; every value has a default that reads well over a
  /// camera preview.
  const MrzOverlayStyle({
    this.scrimColor = const Color(0x99000000),
    this.frameColor = Colors.white,
    this.accentColor = const Color(0xFF4FC3F7),
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
    this.scanDuration = const Duration(milliseconds: 1800),
    this.hintStyle,
  });

  /// Darkens the area outside the document.
  final Color scrimColor;

  /// Document outline while searching.
  final Color frameColor;

  /// Scan line, and the outline while a read is being confirmed.
  final Color accentColor;

  /// Outline and MRZ band once the MRZ is confirmed.
  final Color successColor;

  /// Placeholder photo, text lines and MRZ characters.
  final Color templateColor;

  /// Fill of the MRZ band.
  final Color mrzBandColor;

  /// Width of the document outline.
  final double borderWidth;

  /// Width of the corner accents; 0 hides them.
  final double cornerWidth;

  /// Length of each corner accent arm.
  final double cornerLength;

  /// Corner radius of the document outline.
  final double cornerRadius;

  /// Document width as a fraction of the overlay width.
  final double widthFactor;

  /// Where the document sits in the overlay.
  final Alignment alignment;

  /// Whether to draw the document template (photo box and text lines).
  final bool showTemplate;

  /// Whether to animate a scan line over the MRZ band while searching.
  final bool showScanLine;

  /// Time for one pass of the scan line.
  final Duration scanDuration;

  /// Hint text style; the theme's `titleMedium` in white by default.
  final TextStyle? hintStyle;

  /// A copy with the given values replaced.
  MrzOverlayStyle copyWith({
    Color? scrimColor,
    Color? frameColor,
    Color? accentColor,
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
    Duration? scanDuration,
    TextStyle? hintStyle,
  }) => MrzOverlayStyle(
    scrimColor: scrimColor ?? this.scrimColor,
    frameColor: frameColor ?? this.frameColor,
    accentColor: accentColor ?? this.accentColor,
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
    scanDuration: scanDuration ?? this.scanDuration,
    hintStyle: hintStyle ?? this.hintStyle,
  );

  /// The outline color for [status].
  Color frameColorFor(MrzScanStatus status) => switch (status) {
    MrzScanStatus.searching => frameColor,
    MrzScanStatus.confirming => accentColor,
    MrzScanStatus.detected => successColor,
  };

  @override
  bool operator ==(Object other) =>
      other is MrzOverlayStyle &&
      other.scrimColor == scrimColor &&
      other.frameColor == frameColor &&
      other.accentColor == accentColor &&
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
      other.scanDuration == scanDuration &&
      other.hintStyle == hintStyle;

  @override
  int get hashCode => Object.hash(
    scrimColor,
    frameColor,
    accentColor,
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
    scanDuration,
    hintStyle,
  );
}

/// Physical document sizes and MRZ zone heights from ICAO 9303.
extension MrzFormatGeometry on MrzFormat {
  /// Width divided by height of the document (ID-1, ID-2 or the TD3
  /// passport data page).
  double get aspectRatio => switch (this) {
    MrzFormat.td1 => 85.6 / 53.98,
    MrzFormat.td2 => 105 / 74,
    MrzFormat.td3 => 125 / 88,
  };

  /// Height of the MRZ zone as a fraction of the document height.
  double get mrzZoneHeight => switch (this) {
    MrzFormat.td1 => 17.9 / 53.98,
    MrzFormat.td2 => 17.0 / 74,
    MrzFormat.td3 => 23.2 / 88,
  };
}

/// A document-shaped capture guide over the camera preview.
///
/// Draws the document outline for [format] with its MRZ band, a scrim
/// outside it and, while searching, a scan line over the band. The outline
/// turns [MrzOverlayStyle.accentColor] while a read is being confirmed and
/// [MrzOverlayStyle.successColor] once it is. Motion stops when the
/// platform asks for reduced animations.
class MrzOverlay extends StatefulWidget {
  /// Creates an overlay for [format] in [status].
  const MrzOverlay({
    this.format = MrzFormat.td1,
    this.status = MrzScanStatus.searching,
    this.hint,
    this.style = const MrzOverlayStyle(),
    super.key,
  });

  /// The document layout to draw.
  final MrzFormat format;

  /// Current scan status.
  final MrzScanStatus status;

  /// Guidance shown below the document, announced to screen readers.
  final String? hint;

  /// Colors and sizes.
  final MrzOverlayStyle style;

  /// The document outline in an overlay of [size].
  static Rect documentRect(Size size, MrzFormat format, MrzOverlayStyle style) {
    final width = size.width * style.widthFactor;
    final docSize = Size(width, width / format.aspectRatio);
    return style.alignment.inscribe(docSize, Offset.zero & size);
  }

  /// The MRZ band inside [document].
  static Rect mrzRect(Rect document, MrzFormat format) {
    final height = document.height * format.mrzZoneHeight;
    final inset = document.width * 0.035;
    return Rect.fromLTRB(
      document.left + inset,
      document.bottom - height - inset * 0.5,
      document.right - inset,
      document.bottom - inset * 0.5,
    );
  }

  @override
  State<MrzOverlay> createState() => _MrzOverlayState();
}

class _MrzOverlayState extends State<MrzOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scan = AnimationController(
    vsync: this,
    duration: widget.style.scanDuration,
  );

  bool get _animate =>
      widget.style.showScanLine &&
      widget.status != MrzScanStatus.detected &&
      !(MediaQuery.maybeDisableAnimationsOf(context) ?? false);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(MrzOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    _scan.duration = widget.style.scanDuration;
    _sync();
  }

  void _sync() {
    if (_animate) {
      if (!_scan.isAnimating) _scan.repeat(reverse: true).ignore();
    } else {
      _scan.stop();
    }
  }

  @override
  void dispose() {
    _scan.dispose();
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
        final size = constraints.biggest;
        final doc = MrzOverlay.documentRect(size, widget.format, style);
        return Stack(
          fit: StackFit.expand,
          children: [
            TweenAnimationBuilder<Color?>(
              tween: ColorTween(end: style.frameColorFor(widget.status)),
              duration: const Duration(milliseconds: 250),
              builder: (context, color, _) => AnimatedBuilder(
                animation: _scan,
                builder: (context, _) => CustomPaint(
                  painter: MrzOverlayPainter(
                    format: widget.format,
                    status: widget.status,
                    style: style,
                    frameColor: color ?? style.frameColor,
                    scanPosition: _animate ? _scan.value : null,
                  ),
                ),
              ),
            ),
            if (widget.status == MrzScanStatus.detected)
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
            if (hint != null)
              Positioned(
                left: 24,
                right: 24,
                top: doc.bottom + 24,
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

/// Paints [MrzOverlay]; public so hosts can reuse it in their own widgets.
class MrzOverlayPainter extends CustomPainter {
  /// Creates a painter for one frame of the overlay.
  const MrzOverlayPainter({
    required this.format,
    required this.status,
    required this.style,
    required this.frameColor,
    this.scanPosition,
  });

  /// Document layout.
  final MrzFormat format;

  /// Scan status.
  final MrzScanStatus status;

  /// Style.
  final MrzOverlayStyle style;

  /// Current outline color (animated between status colors).
  final Color frameColor;

  /// Scan line position over the MRZ band (0-1), or `null` for none.
  final double? scanPosition;

  @override
  void paint(Canvas canvas, Size size) {
    final doc = MrzOverlay.documentRect(size, format, style);
    final radius = Radius.circular(style.cornerRadius);
    final outline = RRect.fromRectAndRadius(doc, radius);
    ScrimPainter(
      cutout: Path()..addRRect(outline),
      color: style.scrimColor,
    ).paint(canvas, size);

    if (style.showTemplate) _paintTemplate(canvas, doc);

    final band = MrzOverlay.mrzRect(doc, format);
    final detected = status == MrzScanStatus.detected;
    canvas.drawRRect(
      RRect.fromRectAndRadius(band, const Radius.circular(6)),
      Paint()
        ..color = detected
            ? style.successColor.withValues(alpha: 0.25)
            : style.mrzBandColor,
    );
    _paintMrzText(canvas, band);

    final scan = scanPosition;
    if (scan != null) {
      final y = band.top + band.height * scan;
      final line = Rect.fromLTRB(band.left, y - 1.5, band.right, y + 1.5);
      canvas.drawRect(
        line,
        Paint()
          ..shader = LinearGradient(
            colors: [
              style.accentColor.withValues(alpha: 0),
              style.accentColor,
              style.accentColor.withValues(alpha: 0),
            ],
          ).createShader(line),
      );
    }

    canvas.drawRRect(
      outline,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = style.borderWidth
        ..color = frameColor,
    );
    if (style.cornerWidth > 0) _paintCorners(canvas, doc, frameColor);
  }

  void _paintTemplate(Canvas canvas, Rect doc) {
    final paint = Paint()..color = style.templateColor;
    final unit = doc.height / 20;
    final band = MrzOverlay.mrzRect(doc, format);
    // TD1 cards carry the MRZ on the back, which has no portrait.
    final hasPhoto = format != MrzFormat.td1;
    var textLeft = doc.left + doc.width * 0.06;
    if (hasPhoto) {
      final photo = Rect.fromLTWH(
        doc.left + doc.width * 0.04,
        doc.top + unit * 2.5,
        doc.width * 0.26,
        band.top - doc.top - unit * 4,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(photo, const Radius.circular(4)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = style.templateColor,
      );
      final head = Offset(photo.center.dx, photo.top + photo.height * 0.38);
      canvas
        ..drawCircle(head, photo.width * 0.2, paint)
        ..drawArc(
          Rect.fromCenter(
            center: Offset(photo.center.dx, photo.bottom),
            width: photo.width * 0.75,
            height: photo.height * 0.6,
          ),
          math.pi,
          math.pi,
          true,
          paint,
        );
      textLeft = photo.right + doc.width * 0.05;
    }
    final lines = hasPhoto ? 5 : 4;
    final available = band.top - doc.top - unit * 4;
    for (var i = 0; i < lines; i++) {
      final y = doc.top + unit * 2.5 + available * i / lines;
      final width =
          (doc.right - textLeft - doc.width * 0.06) * (i.isEven ? 0.8 : 0.55);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(textLeft, y, width, unit * 0.9),
          Radius.circular(unit),
        ),
        paint,
      );
    }
  }

  void _paintMrzText(Canvas canvas, Rect band) {
    final lineHeight = band.height / format.lineCount;
    final probe = TextPainter(
      text: const TextSpan(
        text: '<',
        style: TextStyle(fontFamily: 'monospace', fontSize: 10),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final fontSize = (band.width * 0.94 / format.lineLength) / probe.width * 10;
    probe.dispose();
    for (var i = 0; i < format.lineCount; i++) {
      final text = TextPainter(
        text: TextSpan(
          text: '<' * format.lineLength,
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: fontSize.clamp(4, lineHeight * 0.8),
            color: style.templateColor,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      text
        ..paint(
          canvas,
          Offset(
            band.center.dx - text.width / 2,
            band.top + lineHeight * i + (lineHeight - text.height) / 2,
          ),
        )
        ..dispose();
    }
  }

  void _paintCorners(Canvas canvas, Rect doc, Color color) {
    final r = style.cornerRadius;
    final l = style.cornerLength + r;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = style.cornerWidth
      ..strokeCap = StrokeCap.round
      ..color = color;
    final arc = Size.fromRadius(r);
    for (final (corner, start) in [
      (doc.topLeft, math.pi),
      (doc.topRight - Offset(2 * r, 0), -math.pi / 2),
      (doc.bottomRight - Offset(2 * r, 2 * r), 0.0),
      (doc.bottomLeft - Offset(0, 2 * r), math.pi / 2),
    ]) {
      final rect = corner & arc;
      final path = Path()..addArc(rect, start, math.pi / 2);
      canvas.drawPath(path, paint);
    }
    // Straight arms next to each rounded corner.
    final arms = [
      (doc.topLeft + Offset(r, 0), doc.topLeft + Offset(l, 0)),
      (doc.topLeft + Offset(0, r), doc.topLeft + Offset(0, l)),
      (doc.topRight - Offset(r, 0), doc.topRight - Offset(l, 0)),
      (doc.topRight + Offset(0, r), doc.topRight + Offset(0, l)),
      (doc.bottomRight - Offset(r, 0), doc.bottomRight - Offset(l, 0)),
      (doc.bottomRight - Offset(0, r), doc.bottomRight - Offset(0, l)),
      (doc.bottomLeft + Offset(r, 0), doc.bottomLeft + Offset(l, 0)),
      (doc.bottomLeft - Offset(0, r), doc.bottomLeft - Offset(0, l)),
    ];
    for (final (a, b) in arms) {
      canvas.drawLine(a, b, paint);
    }
  }

  @override
  bool shouldRepaint(MrzOverlayPainter oldDelegate) =>
      oldDelegate.format != format ||
      oldDelegate.status != status ||
      oldDelegate.style != style ||
      oldDelegate.frameColor != frameColor ||
      oldDelegate.scanPosition != scanPosition;
}
