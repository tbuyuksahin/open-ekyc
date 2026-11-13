import 'package:flutter/foundation.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart';

/// Brightness, glare and sharpness of the middle of a camera frame.
@immutable
class FrameQuality {
  /// Creates a measurement.
  const FrameQuality({
    required this.brightness,
    required this.glare,
    required this.sharpness,
  });

  /// Mean luminance, 0 (black) to 255 (white).
  final double brightness;

  /// Share of blown-out pixels, 0 to 1. Reflections on a laminated card
  /// show up here.
  final double glare;

  /// Mean absolute Laplacian of the luminance. Higher is sharper; the
  /// scale depends on the camera, so tune [FrameQualityThresholds] on the
  /// devices you support.
  final double sharpness;

  @override
  String toString() =>
      'FrameQuality(brightness: ${brightness.toStringAsFixed(1)}, '
      'glare: ${glare.toStringAsFixed(3)}, '
      'sharpness: ${sharpness.toStringAsFixed(1)})';
}

/// Limits a [FrameQuality] must meet before a photo is taken.
@immutable
class FrameQualityThresholds {
  /// Creates thresholds.
  const FrameQualityThresholds({
    this.minBrightness = 60,
    this.maxGlare = 0.04,
    this.minSharpness = 6,
  });

  /// Darker frames are rejected.
  final double minBrightness;

  /// Frames with a larger share of blown-out pixels are rejected.
  final double maxGlare;

  /// Softer frames are rejected.
  final double minSharpness;
}

/// Measures [FrameQuality] from raw camera frames, on the device.
abstract final class FrameAnalyzer {
  /// Luminance at or above this counts as blown out.
  static const int glareLevel = 250;

  /// Measures an ML Kit frame, or returns `null` for a format other than
  /// NV21 and BGRA8888.
  static FrameQuality? analyze(InputImage image) {
    final bytes = image.bytes;
    final metadata = image.metadata;
    if (bytes == null || metadata == null) return null;
    final width = metadata.size.width.toInt();
    final height = metadata.size.height.toInt();
    return switch (metadata.format) {
      // The Y plane comes first and has one byte per pixel.
      InputImageFormat.nv21 => measure(
        bytes: bytes,
        width: width,
        height: height,
        rowStride: width,
      ),
      // Green is a good stand-in for luminance.
      InputImageFormat.bgra8888 => measure(
        bytes: bytes,
        width: width,
        height: height,
        rowStride: metadata.bytesPerRow,
        pixelStride: 4,
        channelOffset: 1,
      ),
      _ => null,
    };
  }

  /// Measures the central [region] (a fraction of each side) of a pixel
  /// buffer, sampling at most [samples] points per axis.
  ///
  /// Returns `null` when the buffer is too small for its stated size.
  static FrameQuality? measure({
    required Uint8List bytes,
    required int width,
    required int height,
    required int rowStride,
    int pixelStride = 1,
    int channelOffset = 0,
    double region = 0.6,
    int samples = 96,
  }) {
    const reach = 2;
    if (width <= reach * 2 || height <= reach * 2) return null;
    final needed =
        (height - 1) * rowStride + (width - 1) * pixelStride + channelOffset;
    if (needed >= bytes.length) return null;
    final marginX = (width * (1 - region) / 2).round().clamp(
      reach,
      width ~/ 2 - 1,
    );
    final marginY = (height * (1 - region) / 2).round().clamp(
      reach,
      height ~/ 2 - 1,
    );
    final spanX = width - marginX * 2;
    final spanY = height - marginY * 2;
    final stepX = (spanX / samples).ceil().clamp(1, spanX);
    final stepY = (spanY / samples).ceil().clamp(1, spanY);

    int at(int x, int y) =>
        bytes[y * rowStride + x * pixelStride + channelOffset];

    var count = 0;
    var sum = 0;
    var blown = 0;
    var edges = 0;
    for (var y = marginY; y < height - marginY; y += stepY) {
      for (var x = marginX; x < width - marginX; x += stepX) {
        final c = at(x, y);
        sum += c;
        if (c >= glareLevel) blown++;
        final laplacian =
            4 * c -
            at(x - reach, y) -
            at(x + reach, y) -
            at(x, y - reach) -
            at(x, y + reach);
        edges += laplacian.abs();
        count++;
      }
    }
    return FrameQuality(
      brightness: sum / count,
      glare: blown / count,
      sharpness: edges / count,
    );
  }
}
