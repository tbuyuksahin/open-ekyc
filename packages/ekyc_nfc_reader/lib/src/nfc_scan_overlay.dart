import 'dart:math' as math;

import 'package:ekyc_nfc_reader/src/chip_reader.dart';
import 'package:flutter/material.dart';

/// What [NfcScanOverlay] shows.
enum NfcScanStatus {
  /// The document is not on the phone yet.
  waiting,

  /// The chip is being read.
  reading,

  /// The chip was read.
  success,

  /// The read failed.
  error;

  /// The status for a [ChipReader] step, or [error] when [failed].
  static NfcScanStatus of(ChipReadStep? step, {bool failed = false}) {
    if (failed) return error;
    return switch (step) {
      null || ChipReadStep.waitingForCard => waiting,
      ChipReadStep.authenticating || ChipReadStep.reading => reading,
      ChipReadStep.verifying => success,
    };
  }
}

/// The kind of document drawn by [NfcScanOverlay].
enum NfcDocumentKind {
  /// An ID-1 card (national ID, residence permit).
  card,

  /// A passport booklet.
  passport,
}

/// Colors, sizes and behavior of [NfcScanOverlay].
@immutable
class NfcOverlayStyle {
  /// Creates a style. Colors left `null` come from the theme.
  const NfcOverlayStyle({
    this.document = NfcDocumentKind.card,
    this.antennaAlignment = const Alignment(0, -0.45),
    this.height = 240,
    this.phoneColor,
    this.phoneOutlineColor,
    this.cardColor,
    this.chipColor = const Color(0xFFD4AF37),
    this.accentColor,
    this.successColor = const Color(0xFF2E7D32),
    this.errorColor,
    this.progressStrokeWidth = 6,
    this.showProgress = true,
    this.animationDuration = const Duration(milliseconds: 2200),
  });

  /// Card or passport.
  final NfcDocumentKind document;

  /// Where the NFC antenna is on the back of the phone, within the phone
  /// outline. Most phones have it in the upper half, around the cameras.
  final Alignment antennaAlignment;

  /// Height of the illustration.
  final double height;

  /// Phone body; `surfaceContainerHighest` by default.
  final Color? phoneColor;

  /// Phone outline and camera module; `outline` by default.
  final Color? phoneOutlineColor;

  /// Card or passport cover; `primaryContainer` by default.
  final Color? cardColor;

  /// The contact chip on the card.
  final Color chipColor;

  /// Waves and progress ring; `primary` by default.
  final Color? accentColor;

  /// Ring and check mark after a successful read.
  final Color successColor;

  /// Ring and mark after a failed read; `error` by default.
  final Color? errorColor;

  /// Width of the progress ring.
  final double progressStrokeWidth;

  /// Whether to draw the progress ring while reading.
  final bool showProgress;

  /// One cycle of the "bring the card closer" animation.
  final Duration animationDuration;

  /// A copy with the given values replaced.
  NfcOverlayStyle copyWith({
    NfcDocumentKind? document,
    Alignment? antennaAlignment,
    double? height,
    Color? phoneColor,
    Color? phoneOutlineColor,
    Color? cardColor,
    Color? chipColor,
    Color? accentColor,
    Color? successColor,
    Color? errorColor,
    double? progressStrokeWidth,
    bool? showProgress,
    Duration? animationDuration,
  }) => NfcOverlayStyle(
    document: document ?? this.document,
    antennaAlignment: antennaAlignment ?? this.antennaAlignment,
    height: height ?? this.height,
    phoneColor: phoneColor ?? this.phoneColor,
    phoneOutlineColor: phoneOutlineColor ?? this.phoneOutlineColor,
    cardColor: cardColor ?? this.cardColor,
    chipColor: chipColor ?? this.chipColor,
    accentColor: accentColor ?? this.accentColor,
    successColor: successColor ?? this.successColor,
    errorColor: errorColor ?? this.errorColor,
    progressStrokeWidth: progressStrokeWidth ?? this.progressStrokeWidth,
    showProgress: showProgress ?? this.showProgress,
    animationDuration: animationDuration ?? this.animationDuration,
  );

  @override
  bool operator ==(Object other) =>
      other is NfcOverlayStyle &&
      other.document == document &&
      other.antennaAlignment == antennaAlignment &&
      other.height == height &&
      other.phoneColor == phoneColor &&
      other.phoneOutlineColor == phoneOutlineColor &&
      other.cardColor == cardColor &&
      other.chipColor == chipColor &&
      other.accentColor == accentColor &&
      other.successColor == successColor &&
      other.errorColor == errorColor &&
      other.progressStrokeWidth == progressStrokeWidth &&
      other.showProgress == showProgress &&
      other.animationDuration == animationDuration;

  @override
  int get hashCode => Object.hash(
    document,
    antennaAlignment,
    height,
    phoneColor,
    phoneOutlineColor,
    cardColor,
    chipColor,
    accentColor,
    successColor,
    errorColor,
    progressStrokeWidth,
    showProgress,
    animationDuration,
  );
}

/// The colors of an [NfcOverlayStyle] with theme defaults filled in.
@immutable
class ResolvedNfcColors {
  /// Resolves [style] against [scheme].
  ResolvedNfcColors(NfcOverlayStyle style, ColorScheme scheme)
    : phone = style.phoneColor ?? scheme.surfaceContainerHighest,
      outline = style.phoneOutlineColor ?? scheme.outline,
      card = style.cardColor ?? scheme.primaryContainer,
      chip = style.chipColor,
      accent = style.accentColor ?? scheme.primary,
      success = style.successColor,
      error = style.errorColor ?? scheme.error;

  /// Phone body.
  final Color phone;

  /// Phone outline.
  final Color outline;

  /// Document.
  final Color card;

  /// Contact chip.
  final Color chip;

  /// Waves and progress.
  final Color accent;

  /// Success ring.
  final Color success;

  /// Error ring.
  final Color error;

  /// The ring color for [status].
  Color ringFor(NfcScanStatus status) => switch (status) {
    NfcScanStatus.waiting || NfcScanStatus.reading => accent,
    NfcScanStatus.success => success,
    NfcScanStatus.error => error,
  };

  @override
  bool operator ==(Object other) =>
      other is ResolvedNfcColors &&
      other.phone == phone &&
      other.outline == outline &&
      other.card == card &&
      other.chip == chip &&
      other.accent == accent &&
      other.success == success &&
      other.error == error;

  @override
  int get hashCode =>
      Object.hash(phone, outline, card, chip, accent, success, error);
}

/// Shows where to hold the document on the phone, and the read progress.
///
/// While [NfcScanStatus.waiting] the document moves towards the antenna
/// with radio waves around it; while reading it rests on the antenna with
/// a progress ring; success and error tint the ring. Motion stops when the
/// platform asks for reduced animations.
class NfcScanOverlay extends StatefulWidget {
  /// Creates an overlay in [status].
  const NfcScanOverlay({
    required this.status,
    this.progress = 0,
    this.style = const NfcOverlayStyle(),
    this.semanticLabel,
    super.key,
  });

  /// What to show.
  final NfcScanStatus status;

  /// Read progress (0-1), shown while [NfcScanStatus.reading].
  final double progress;

  /// Colors and sizes.
  final NfcOverlayStyle style;

  /// Describes the illustration to screen readers.
  final String? semanticLabel;

  @override
  State<NfcScanOverlay> createState() => _NfcScanOverlayState();
}

class _NfcScanOverlayState extends State<NfcScanOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _cycle = AnimationController(
    vsync: this,
    duration: widget.style.animationDuration,
  );

  bool get _animate =>
      (widget.status == NfcScanStatus.waiting ||
          widget.status == NfcScanStatus.reading) &&
      !(MediaQuery.maybeDisableAnimationsOf(context) ?? false);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(NfcScanOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    _cycle.duration = widget.style.animationDuration;
    _sync();
  }

  void _sync() {
    if (_animate) {
      if (!_cycle.isAnimating) _cycle.repeat().ignore();
    } else {
      _cycle.stop();
    }
  }

  @override
  void dispose() {
    _cycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = widget.style;
    final colors = ResolvedNfcColors(style, Theme.of(context).colorScheme);
    return Semantics(
      label: widget.semanticLabel,
      image: true,
      child: SizedBox(
        height: style.height,
        width: double.infinity,
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: widget.progress.clamp(0, 1)),
          duration: const Duration(milliseconds: 200),
          builder: (context, progress, _) => AnimatedBuilder(
            animation: _cycle,
            builder: (context, _) => CustomPaint(
              painter: NfcOverlayPainter(
                status: widget.status,
                progress: progress,
                style: style,
                colors: colors,
                cycle: _animate ? _cycle.value : null,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Paints [NfcScanOverlay]; public so hosts can reuse it.
class NfcOverlayPainter extends CustomPainter {
  /// Creates a painter for one frame.
  const NfcOverlayPainter({
    required this.status,
    required this.progress,
    required this.style,
    required this.colors,
    this.cycle,
  });

  /// What to show.
  final NfcScanStatus status;

  /// Read progress (0-1).
  final double progress;

  /// Style.
  final NfcOverlayStyle style;

  /// Resolved colors.
  final ResolvedNfcColors colors;

  /// Animation phase (0-1), or `null` when motion is off.
  final double? cycle;

  /// The phone outline in a canvas of [size].
  static Rect phoneRect(Size size) {
    final h = size.height * 0.92;
    return Rect.fromCenter(
      center: size.center(Offset.zero),
      width: h * 0.48,
      height: h,
    );
  }

  /// The antenna position in a canvas of [size].
  static Offset antenna(Size size, NfcOverlayStyle style) =>
      style.antennaAlignment.withinRect(phoneRect(size));

  @override
  void paint(Canvas canvas, Size size) {
    final phone = phoneRect(size);
    final center = antenna(size, style);
    final unit = phone.width / 10;
    _paintPhone(canvas, phone, unit);

    final t = cycle;
    if (status == NfcScanStatus.waiting || status == NfcScanStatus.reading) {
      _paintWaves(canvas, center, unit, t ?? 0.35);
    }

    // The document approaches from the lower right and rests with its chip
    // over the antenna; on error it slides back off.
    final docSize = style.document == NfcDocumentKind.card
        ? Size(unit * 8.5, unit * 8.5 / 1.586)
        : Size(unit * 6.2, unit * 6.2 * 125 / 88);
    final away = Offset(unit * 6, unit * 7);
    final approach = switch (status) {
      NfcScanStatus.waiting => _approach(t ?? 0.5),
      NfcScanStatus.reading || NfcScanStatus.success => 1.0,
      NfcScanStatus.error => 0.35,
    };
    final chipOffset = style.document == NfcDocumentKind.card
        ? Offset(docSize.width * 0.22, 0)
        : Offset.zero;
    final docCenter = center + chipOffset + away * (1 - approach);
    _paintDocument(
      canvas,
      Rect.fromCenter(
        center: docCenter,
        width: docSize.width,
        height: docSize.height,
      ),
    );

    _paintRing(canvas, center, unit);
  }

  // Ease in, hold on the antenna, then fade back for the next cycle.
  static double _approach(double t) {
    if (t < 0.55) return Curves.easeOutCubic.transform(t / 0.55);
    if (t < 0.85) return 1;
    return 1 - Curves.easeIn.transform((t - 0.85) / 0.15);
  }

  void _paintPhone(Canvas canvas, Rect phone, double unit) {
    final body = RRect.fromRectAndRadius(phone, Radius.circular(unit * 1.6));
    canvas
      ..drawRRect(body, Paint()..color = colors.phone)
      ..drawRRect(
        body,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = colors.outline,
      );
    // Camera module, top left as seen from the back.
    final module = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        phone.left + unit,
        phone.top + unit,
        unit * 3.6,
        unit * 3.6,
      ),
      Radius.circular(unit),
    );
    final lens = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = colors.outline;
    canvas
      ..drawRRect(module, lens)
      ..drawCircle(
        module.center.translate(-unit * 0.8, -unit * 0.8),
        unit * 0.6,
        lens,
      )
      ..drawCircle(
        module.center.translate(unit * 0.8, unit * 0.8),
        unit * 0.6,
        lens,
      );
  }

  void _paintWaves(Canvas canvas, Offset center, double unit, double t) {
    for (var i = 0; i < 3; i++) {
      final phase = (t + i / 3) % 1;
      canvas.drawCircle(
        center,
        unit * (1.2 + phase * 4),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = colors.accent.withValues(alpha: (1 - phase) * 0.6),
      );
    }
  }

  void _paintDocument(Canvas canvas, Rect doc) {
    final radius = Radius.circular(doc.shortestSide * 0.08);
    final rrect = RRect.fromRectAndRadius(doc, radius);
    canvas
      ..drawShadow(Path()..addRRect(rrect), Colors.black, 4, false)
      ..drawRRect(rrect, Paint()..color = colors.card.withValues(alpha: 0.95));
    final line = Paint()..color = colors.outline.withValues(alpha: 0.5);
    if (style.document == NfcDocumentKind.card) {
      final chip = Rect.fromLTWH(
        doc.left + doc.width * 0.08,
        doc.center.dy - doc.height * 0.14,
        doc.width * 0.16,
        doc.height * 0.28,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(chip, Radius.circular(chip.width * 0.15)),
        Paint()..color = colors.chip,
      );
      for (var i = 0; i < 3; i++) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(
              doc.left + doc.width * 0.32,
              doc.top + doc.height * (0.25 + i * 0.18),
              doc.width * (i.isEven ? 0.55 : 0.4),
              doc.height * 0.07,
            ),
            const Radius.circular(4),
          ),
          line,
        );
      }
    } else {
      // Passport cover: emblem and the ePassport chip symbol.
      canvas.drawCircle(
        doc.center.translate(0, -doc.height * 0.12),
        doc.width * 0.2,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = colors.chip,
      );
      final symbol = Rect.fromCenter(
        center: doc.center.translate(0, doc.height * 0.3),
        width: doc.width * 0.22,
        height: doc.width * 0.14,
      );
      final stroke = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..color = colors.chip;
      canvas
        ..drawRect(symbol, stroke)
        ..drawCircle(symbol.center, symbol.height * 0.28, stroke);
    }
  }

  void _paintRing(Canvas canvas, Offset center, double unit) {
    if (status == NfcScanStatus.waiting) return;
    final radius = unit * 1.8;
    final color = colors.ringFor(status);
    canvas.drawCircle(
      center,
      radius,
      Paint()..color = Colors.white.withValues(alpha: 0.9),
    );
    final rect = Rect.fromCircle(center: center, radius: radius);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = style.progressStrokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(
      center,
      radius,
      stroke..color = color.withValues(alpha: 0.2),
    );
    final sweep = switch (status) {
      NfcScanStatus.reading => style.showProgress ? progress : 0.0,
      _ => 1.0,
    };
    if (sweep > 0) {
      canvas.drawArc(
        rect,
        -math.pi / 2,
        2 * math.pi * sweep,
        false,
        stroke..color = color,
      );
    }
    final mark = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = style.progressStrokeWidth * 0.8
      ..strokeCap = StrokeCap.round
      ..color = color;
    final r = radius * 0.45;
    switch (status) {
      case NfcScanStatus.success:
        canvas.drawPath(
          Path()
            ..moveTo(center.dx - r, center.dy)
            ..lineTo(center.dx - r * 0.25, center.dy + r * 0.7)
            ..lineTo(center.dx + r, center.dy - r * 0.6),
          mark..style = PaintingStyle.stroke,
        );
      case NfcScanStatus.error:
        canvas
          ..drawLine(
            center.translate(0, -r),
            center.translate(0, r * 0.3),
            mark,
          )
          ..drawCircle(
            center.translate(0, r * 0.8),
            style.progressStrokeWidth * 0.5,
            Paint()..color = color,
          );
      case NfcScanStatus.waiting || NfcScanStatus.reading:
        break;
    }
  }

  @override
  bool shouldRepaint(NfcOverlayPainter oldDelegate) =>
      oldDelegate.status != status ||
      oldDelegate.progress != progress ||
      oldDelegate.style != style ||
      oldDelegate.colors != colors ||
      oldDelegate.cycle != cycle;
}
