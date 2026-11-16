import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

/// Drawing helpers shared by the document shaped capture guides.
abstract final class GuidePainting {
  /// Draws rounded corner accents with straight arms on [rect].
  static void corners(
    Canvas canvas,
    Rect rect, {
    required double radius,
    required double length,
    required double width,
    required Color color,
  }) {
    final r = radius;
    final l = length + r;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round
      ..color = color;
    final arc = Size.fromRadius(r);
    for (final (corner, start) in [
      (rect.topLeft, math.pi),
      (rect.topRight - Offset(2 * r, 0), -math.pi / 2),
      (rect.bottomRight - Offset(2 * r, 2 * r), 0.0),
      (rect.bottomLeft - Offset(0, 2 * r), math.pi / 2),
    ]) {
      canvas.drawPath(
        Path()..addArc(corner & arc, start, math.pi / 2),
        paint,
      );
    }
    for (final (a, b) in [
      (rect.topLeft + Offset(r, 0), rect.topLeft + Offset(l, 0)),
      (rect.topLeft + Offset(0, r), rect.topLeft + Offset(0, l)),
      (rect.topRight - Offset(r, 0), rect.topRight - Offset(l, 0)),
      (rect.topRight + Offset(0, r), rect.topRight + Offset(0, l)),
      (rect.bottomRight - Offset(r, 0), rect.bottomRight - Offset(l, 0)),
      (rect.bottomRight - Offset(0, r), rect.bottomRight - Offset(0, l)),
      (rect.bottomLeft + Offset(r, 0), rect.bottomLeft + Offset(l, 0)),
      (rect.bottomLeft - Offset(0, r), rect.bottomLeft - Offset(0, l)),
    ]) {
      canvas.drawLine(a, b, paint);
    }
  }

  /// Fills [band] with [lines] rows of [length] `<` characters, the look
  /// of an empty machine readable zone.
  static void mrzCharacters(
    Canvas canvas,
    Rect band, {
    required int lines,
    required int length,
    required Color color,
  }) {
    final lineHeight = band.height / lines;
    final probe = TextPainter(
      text: const TextSpan(
        text: '<',
        style: TextStyle(fontFamily: 'monospace', fontSize: 10),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final fontSize = (band.width * 0.94 / length) / probe.width * 10;
    probe.dispose();
    for (var i = 0; i < lines; i++) {
      final text = TextPainter(
        text: TextSpan(
          text: '<' * length,
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: fontSize.clamp(4, lineHeight * 0.8),
            color: color,
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

  /// Draws a head and shoulders placeholder inside the outline [photo].
  static void portrait(Canvas canvas, Rect photo, Color color) {
    final fill = Paint()..color = color;
    canvas
      ..drawRRect(
        RRect.fromRectAndRadius(photo, const Radius.circular(4)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = color,
      )
      ..save()
      ..clipRect(photo)
      ..drawCircle(
        Offset(photo.center.dx, photo.top + photo.height * 0.38),
        photo.width * 0.2,
        fill,
      )
      ..drawArc(
        Rect.fromCenter(
          center: Offset(photo.center.dx, photo.bottom),
          width: photo.width * 0.75,
          height: photo.height * 0.6,
        ),
        math.pi,
        math.pi,
        true,
        fill,
      )
      ..restore();
  }

  /// Draws a horizontal scan line across [area] at [position] (0 top, 1
  /// bottom), fading out at both ends.
  static void scanLine(
    Canvas canvas,
    Rect area,
    double position,
    Color color,
  ) {
    final y = area.top + area.height * position;
    final line = Rect.fromLTRB(area.left, y - 1.5, area.right, y + 1.5);
    canvas.drawRect(
      line,
      Paint()
        ..shader = LinearGradient(
          colors: [
            color.withValues(alpha: 0),
            color,
            color.withValues(alpha: 0),
          ],
        ).createShader(line),
    );
  }
}
