import 'dart:typed_data';
import 'dart:ui';

import 'package:ekyc_document_capture/ekyc_document_capture.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart';

Uint8List gray(int width, int height, int Function(int x, int y) value) {
  final bytes = Uint8List(width * height);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      bytes[y * width + x] = value(x, y);
    }
  }
  return bytes;
}

void main() {
  group('FrameAnalyzer.measure', () {
    test('a flat frame has no edges and no glare', () {
      final q = FrameAnalyzer.measure(
        bytes: gray(64, 48, (_, _) => 120),
        width: 64,
        height: 48,
        rowStride: 64,
      )!;
      expect(q.brightness, 120);
      expect(q.glare, 0);
      expect(q.sharpness, 0);
      expect(q.toString(), contains('brightness: 120.0'));
    });

    test('fine detail scores much sharper than a soft gradient', () {
      final sharp = FrameAnalyzer.measure(
        bytes: gray(64, 48, (x, y) => (x ~/ 2 + y ~/ 2).isEven ? 30 : 220),
        width: 64,
        height: 48,
        rowStride: 64,
      )!;
      final soft = FrameAnalyzer.measure(
        bytes: gray(64, 48, (x, _) => 60 + x * 2),
        width: 64,
        height: 48,
        rowStride: 64,
      )!;
      expect(sharp.sharpness, greaterThan(100));
      expect(soft.sharpness, lessThan(1));
    });

    test('blown-out pixels count as glare', () {
      final q = FrameAnalyzer.measure(
        bytes: gray(64, 48, (x, _) => x < 32 ? 255 : 100),
        width: 64,
        height: 48,
        rowStride: 64,
      )!;
      expect(q.glare, closeTo(0.5, 0.1));
    });

    test('only the central region is measured', () {
      final q = FrameAnalyzer.measure(
        bytes: gray(100, 100, (x, y) {
          final inside = x >= 20 && x < 80 && y >= 20 && y < 80;
          return inside ? 100 : 255;
        }),
        width: 100,
        height: 100,
        rowStride: 100,
      )!;
      expect(q.glare, 0);
      expect(q.brightness, 100);
    });

    test('large frames are sampled, not scanned', () {
      final q = FrameAnalyzer.measure(
        bytes: gray(1280, 720, (_, _) => 90),
        width: 1280,
        height: 720,
        rowStride: 1280,
        samples: 8,
      )!;
      expect(q.brightness, 90);
    });

    test('rejects frames that are too small or truncated', () {
      expect(
        FrameAnalyzer.measure(
          bytes: Uint8List(16),
          width: 4,
          height: 4,
          rowStride: 4,
        ),
        isNull,
      );
      expect(
        FrameAnalyzer.measure(
          bytes: Uint8List(100),
          width: 64,
          height: 48,
          rowStride: 64,
        ),
        isNull,
      );
    });
  });

  group('FrameAnalyzer.analyze', () {
    InputImage image(
      Uint8List bytes,
      InputImageFormat format, {
      int bytesPerRow = 64,
    }) => InputImage.fromBytes(
      bytes: bytes,
      metadata: InputImageMetadata(
        size: const Size(64, 48),
        rotation: InputImageRotation.rotation0deg,
        format: format,
        bytesPerRow: bytesPerRow,
      ),
    );

    test('reads the Y plane of NV21', () {
      final bytes = Uint8List(64 * 48 * 3 ~/ 2)..fillRange(0, 64 * 48, 140);
      expect(
        FrameAnalyzer.analyze(image(bytes, InputImageFormat.nv21))!.brightness,
        140,
      );
    });

    test('reads the green channel of BGRA', () {
      final bytes = Uint8List(64 * 48 * 4);
      for (var i = 1; i < bytes.length; i += 4) {
        bytes[i] = 200;
      }
      final q = FrameAnalyzer.analyze(
        image(bytes, InputImageFormat.bgra8888, bytesPerRow: 256),
      )!;
      expect(q.brightness, 200);
    });

    test('skips other formats and file images', () {
      expect(
        FrameAnalyzer.analyze(
          image(Uint8List(64 * 48 * 2), InputImageFormat.yuv_420_888),
        ),
        isNull,
      );
      expect(
        FrameAnalyzer.analyze(InputImage.fromFilePath('/tmp/none.jpg')),
        isNull,
      );
    });
  });
}
