import 'package:ekyc_camera/ekyc_camera.dart';
import 'package:ekyc_document_capture/src/document_gate.dart';
import 'package:ekyc_document_capture/src/document_kind.dart';
import 'package:flutter/material.dart';

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
    this.borderWidth = 3,
    this.cornerRadius = 14,
    this.widthFactor = 0.9,
    this.alignment = const Alignment(0, -0.2),
    this.showTemplate = true,
    this.hintStyle,
    this.labelStyle,
  });

  /// Darkens the area outside the document.
  final Color scrimColor;

  /// Outline while searching.
  final Color frameColor;

  /// Outline while something needs fixing.
  final Color accentColor;

  /// Outline and progress while counting down to the photo.
  final Color readyColor;

  /// Outline and check mark once the photo is taken.
  final Color successColor;

  /// Placeholder portrait, text lines and MRZ band.
  final Color templateColor;

  /// Width of the outline.
  final double borderWidth;

  /// Corner radius of the outline.
  final double cornerRadius;

  /// Document width as a fraction of the overlay width.
  final double widthFactor;

  /// Where the document sits in the overlay.
  final Alignment alignment;

  /// Whether to draw the placeholder layout of the expected side while
  /// searching.
  final bool showTemplate;

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
    double? borderWidth,
    double? cornerRadius,
    double? widthFactor,
    Alignment? alignment,
    bool? showTemplate,
    TextStyle? hintStyle,
    TextStyle? labelStyle,
  }) => DocumentOverlayStyle(
    scrimColor: scrimColor ?? this.scrimColor,
    frameColor: frameColor ?? this.frameColor,
    accentColor: accentColor ?? this.accentColor,
    readyColor: readyColor ?? this.readyColor,
    successColor: successColor ?? this.successColor,
    templateColor: templateColor ?? this.templateColor,
    borderWidth: borderWidth ?? this.borderWidth,
    cornerRadius: cornerRadius ?? this.cornerRadius,
    widthFactor: widthFactor ?? this.widthFactor,
    alignment: alignment ?? this.alignment,
    showTemplate: showTemplate ?? this.showTemplate,
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
      other.borderWidth == borderWidth &&
      other.cornerRadius == cornerRadius &&
      other.widthFactor == widthFactor &&
      other.alignment == alignment &&
      other.showTemplate == showTemplate &&
      other.hintStyle == hintStyle &&
      other.labelStyle == labelStyle;

  @override
  int get hashCode => Object.hash(
    scrimColor,
    frameColor,
    accentColor,
    readyColor,
    successColor,
    templateColor,
    borderWidth,
    cornerRadius,
    widthFactor,
    alignment,
    showTemplate,
    hintStyle,
    labelStyle,
  );
}

/// A document-shaped capture guide over the camera preview.
///
/// Draws the outline of [kind] with a scrim outside it, the placeholder
/// layout of the expected [side] while searching, and a progress bar
/// while counting down to the photo. The outline color follows [state].
class DocumentOverlay extends StatelessWidget {
  /// Creates an overlay.
  const DocumentOverlay({
    this.kind = DocumentKind.idCard,
    this.side = DocumentSide.front,
    this.state = DocumentGuideState.searching,
    this.progress = 0,
    this.hint,
    this.label,
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final hintStyle =
        style.hintStyle ?? theme.titleMedium?.copyWith(color: Colors.white);
    final labelStyle =
        style.labelStyle ?? theme.labelLarge?.copyWith(color: Colors.white);
    final hint = this.hint;
    final label = this.label;
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        final doc = documentRect(size, kind, style);
        return Stack(
          fit: StackFit.expand,
          children: [
            TweenAnimationBuilder<Color?>(
              tween: ColorTween(end: style.frameColorFor(state)),
              duration: const Duration(milliseconds: 200),
              builder: (context, color, _) => CustomPaint(
                painter: DocumentOverlayPainter(
                  kind: kind,
                  side: side,
                  state: state,
                  progress: progress,
                  style: style,
                  frameColor: color ?? style.frameColor,
                ),
              ),
            ),
            if (state == DocumentGuideState.captured)
              Positioned.fromRect(
                rect: doc,
                child: Center(
                  child: Icon(
                    Icons.check_circle,
                    color: style.successColor,
                    size: doc.height * 0.35,
                  ),
                ),
              ),
            if (label != null)
              Positioned(
                left: 16,
                right: 16,
                bottom: size.height - doc.top + 12,
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: labelStyle,
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

/// Paints the scrim, outline, template and progress of a
/// [DocumentOverlay].
class DocumentOverlayPainter extends CustomPainter {
  /// Creates a painter.
  const DocumentOverlayPainter({
    required this.kind,
    required this.side,
    required this.state,
    required this.progress,
    required this.style,
    required this.frameColor,
  });

  /// The document shape.
  final DocumentKind kind;

  /// The side being captured.
  final DocumentSide side;

  /// Current guide state.
  final DocumentGuideState state;

  /// Countdown to the photo, 0 to 1.
  final double progress;

  /// Colors and sizes.
  final DocumentOverlayStyle style;

  /// The outline color, animated by the overlay.
  final Color frameColor;

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
    if (style.showTemplate && state == DocumentGuideState.searching) {
      _paintTemplate(canvas, doc);
    }
    canvas.drawRRect(
      outline,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = style.borderWidth
        ..color = frameColor,
    );
    if (state == DocumentGuideState.ready && progress > 0) {
      final track = Rect.fromLTWH(doc.left, doc.bottom + 10, doc.width, 4);
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
              track.width * progress.clamp(0, 1),
              track.height,
            ),
            radius,
          ),
          Paint()..color = style.readyColor,
        );
    }
  }

  void _paintTemplate(Canvas canvas, Rect doc) {
    final paint = Paint()..color = style.templateColor;
    final inset = doc.width * 0.06;
    final line = doc.height * 0.05;
    final radius = Radius.circular(line / 2);
    final hasMrz = kind.hasMrzOn(side);
    final mrzTop = doc.bottom - doc.height * 0.3;
    if (hasMrz) {
      for (var i = 0; i < 3; i++) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(
              doc.left + inset,
              mrzTop + i * line * 1.7,
              doc.width - inset * 2,
              line,
            ),
            radius,
          ),
          paint,
        );
      }
    }
    if (side == DocumentSide.front) {
      final bodyBottom = hasMrz ? mrzTop - inset * 0.6 : doc.bottom - inset;
      final photo = Rect.fromLTRB(
        doc.left + inset,
        doc.top + inset * 1.6,
        doc.left + inset + doc.width * 0.26,
        bodyBottom,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(photo, const Radius.circular(6)),
        paint,
      );
      final left = photo.right + inset;
      final lines = hasMrz ? 3 : 4;
      for (var i = 0; i < lines; i++) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(
              left,
              photo.top + i * line * 2.2,
              (doc.right - inset - left) * (i.isEven ? 0.9 : 0.6),
              line,
            ),
            radius,
          ),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(DocumentOverlayPainter oldDelegate) =>
      oldDelegate.kind != kind ||
      oldDelegate.side != side ||
      oldDelegate.state != state ||
      oldDelegate.progress != progress ||
      oldDelegate.style != style ||
      oldDelegate.frameColor != frameColor;
}
