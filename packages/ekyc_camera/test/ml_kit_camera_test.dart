import 'dart:io';
import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:ekyc_camera/ekyc_camera.dart';
import 'package:ekyc_camera/testing.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeCameraPlatform platform;
  setUp(() => CameraPlatform.instance = platform = FakeCameraPlatform());

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  group('inputImageRotation', () {
    InputImageRotation? android(
      int sensor,
      CameraLensDirection lens,
      DeviceOrientation device,
    ) => inputImageRotation(
      isIOS: false,
      sensorOrientation: sensor,
      lensDirection: lens,
      deviceOrientation: device,
    );

    test('compensates the device orientation on Android', () {
      const back = CameraLensDirection.back;
      const front = CameraLensDirection.front;
      expect(
        android(90, back, DeviceOrientation.portraitUp),
        InputImageRotation.rotation90deg,
      );
      expect(
        android(90, back, DeviceOrientation.landscapeLeft),
        InputImageRotation.rotation0deg,
      );
      expect(
        android(270, front, DeviceOrientation.portraitUp),
        InputImageRotation.rotation270deg,
      );
      expect(
        android(270, front, DeviceOrientation.landscapeRight),
        InputImageRotation.rotation180deg,
      );
    });

    test('uses the sensor orientation alone on iOS', () {
      expect(
        inputImageRotation(
          isIOS: true,
          sensorOrientation: 90,
          lensDirection: CameraLensDirection.back,
          deviceOrientation: DeviceOrientation.landscapeLeft,
        ),
        InputImageRotation.rotation90deg,
      );
    });
  });

  group('MlKitCamera', () {
    test(
      'opens the preferred lens and delivers frames one at a time',
      () async {
        final images = <InputImage>[];
        final camera = MlKitCamera(
          lensDirection: CameraLensDirection.front,
          onFrame: (image) async {
            images.add(image);
            await settle();
          },
        );
        var notified = 0;
        camera.addListener(() => notified++);
        await camera.start();
        expect(camera.status, MlKitCameraStatus.ready);
        expect(notified, 1);
        expect(platform.created, ['front']);
        expect(camera.controller?.value.isInitialized, isTrue);

        platform
          ..emitFrame()
          // Dropped: the first frame is still being processed.
          ..emitFrame();
        await settle();
        await settle();
        expect(images, hasLength(1));
        expect(images.single.metadata?.size, const Size(480, 640));

        // Unsupported formats never reach ML Kit.
        platform.emitFrame(rawFormat: 17);
        await settle();
        expect(images, hasLength(1));

        camera.stopProcessing();
        platform.emitFrame();
        await settle();
        expect(images, hasLength(1));
        camera.dispose();
        await settle();
        expect(platform.open, isEmpty);
      },
    );

    test('skips frames inside the frame interval', () async {
      var frames = 0;
      final camera = MlKitCamera(
        lensDirection: CameraLensDirection.back,
        frameInterval: const Duration(hours: 1),
        onFrame: (_) async => frames++,
      );
      await camera.start();
      platform.emitFrame();
      await settle();
      platform.emitFrame();
      await settle();
      expect(frames, 1);
      camera.dispose();
    });

    test('a failing frame handler does not stop the stream', () async {
      var frames = 0;
      final camera = MlKitCamera(
        lensDirection: CameraLensDirection.back,
        onFrame: (_) async {
          frames++;
          throw StateError('ML Kit failed');
        },
      );
      await camera.start();
      platform.emitFrame();
      await settle();
      platform.emitFrame();
      await settle();
      expect(frames, 2);
      camera.dispose();
    });

    test('takes a picture and deletes the file', () async {
      final camera = MlKitCamera(
        lensDirection: CameraLensDirection.front,
        onFrame: (_) async {},
      );
      await camera.start();
      final bytes = await camera.takePicture();
      expect(bytes, platform.pictureBytes);
      expect(File(platform.pictures.single).existsSync(), isFalse);
      expect(platform.isStreaming, isFalse);
      camera.dispose();
    });

    test('resumes the stream when a picture fails', () async {
      final camera = MlKitCamera(
        lensDirection: CameraLensDirection.front,
        onFrame: (_) async {},
      );
      expect(await camera.takePicture(), isNull, reason: 'not started');
      await camera.start();
      platform.pictureError = CameraException('busy', null);
      expect(await camera.takePicture(), isNull);
      expect(platform.isStreaming, isTrue);
      camera.dispose();
    });

    test('releases the camera in the background and reopens it', () async {
      final camera = MlKitCamera(
        lensDirection: CameraLensDirection.back,
        onFrame: (_) async {},
      );
      await camera.start();
      camera
        ..didChangeAppLifecycleState(AppLifecycleState.inactive)
        // A second background event changes nothing.
        ..didChangeAppLifecycleState(AppLifecycleState.paused);
      await settle();
      expect(camera.status, MlKitCameraStatus.starting);
      expect(camera.controller, isNull);
      expect(platform.open, isEmpty);

      camera.didChangeAppLifecycleState(AppLifecycleState.resumed);
      for (var i = 0; i < 5; i++) {
        await settle();
      }
      expect(camera.status, MlKitCameraStatus.ready);
      expect(platform.created, ['back', 'back']);
      camera.dispose();
    });

    test(
      'a camera that opens after going to the background is closed',
      () async {
        final camera = MlKitCamera(
          lensDirection: CameraLensDirection.back,
          onFrame: (_) async {},
        );
        final opening = camera.start();
        camera.didChangeAppLifecycleState(AppLifecycleState.paused);
        await opening;
        expect(camera.status, MlKitCameraStatus.starting);
        expect(platform.open, isEmpty);
        camera.dispose();
      },
    );

    test('reports an unavailable camera', () async {
      for (final p in [
        FakeCameraPlatform(cameras: const []),
        FakeCameraPlatform(denyPermission: true),
      ]) {
        CameraPlatform.instance = p;
        final camera = MlKitCamera(
          lensDirection: CameraLensDirection.back,
          onFrame: (_) async {},
        );
        await camera.start();
        expect(camera.status, MlKitCameraStatus.unavailable);
        // It stays unavailable when the app comes back.
        camera
          ..didChangeAppLifecycleState(AppLifecycleState.paused)
          ..didChangeAppLifecycleState(AppLifecycleState.resumed);
        await settle();
        expect(camera.status, MlKitCameraStatus.unavailable);
        camera.dispose();
      }
    });
  });

  group('MlKitCameraView', () {
    testWidgets('shows loading, the preview with its overlay, or the '
        'fallback', (tester) async {
      final camera = MlKitCamera(
        lensDirection: CameraLensDirection.back,
        onFrame: (_) async {},
      );
      Widget view() => MaterialApp(
        home: MlKitCameraView(
          camera: camera,
          overlay: const Text('overlay'),
          unavailableBuilder: (_) => const Text('no camera'),
        ),
      );
      await tester.pumpWidget(view());
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.runAsync(camera.start);
      await tester.pump();
      expect(find.text('overlay'), findsOneWidget);
      expect(find.byType(CoverPreview), findsOneWidget);
      camera.dispose();

      CameraPlatform.instance = FakeCameraPlatform(cameras: const []);
      final missing = MlKitCamera(
        lensDirection: CameraLensDirection.back,
        onFrame: (_) async {},
      );
      await tester.pumpWidget(
        MaterialApp(
          home: MlKitCameraView(
            camera: missing,
            unavailableBuilder: (_) => const Text('no camera'),
            loadingBuilder: (_) => const Text('loading'),
          ),
        ),
      );
      expect(find.text('loading'), findsOneWidget);
      await tester.runAsync(missing.start);
      await tester.pump();
      expect(find.text('no camera'), findsOneWidget);
      missing.dispose();
    });

    testWidgets('CoverPreview crops a landscape sensor to portrait', (
      tester,
    ) async {
      await tester.pumpWidget(
        const Center(
          child: SizedBox(
            width: 300,
            height: 300,
            child: CoverPreview(
              previewSize: Size(640, 480),
              child: ColoredBox(color: Color(0xFF000000)),
            ),
          ),
        ),
      );
      final box = tester.getSize(find.byType(ColoredBox));
      expect(box.width / box.height, closeTo(480 / 640, 0.001));
    });
  });

  test('ScrimPainter repaints only when its inputs change', () {
    final cutout = Path()..addRect(const Rect.fromLTWH(10, 10, 20, 20));
    final painter = ScrimPainter(
      cutout: cutout,
      color: const Color(0x80000000),
    );
    expect(
      painter.shouldRepaint(
        ScrimPainter(cutout: cutout, color: const Color(0x80000000)),
      ),
      isFalse,
    );
    expect(
      painter.shouldRepaint(
        ScrimPainter(cutout: cutout, color: const Color(0xFF000000)),
      ),
      isTrue,
    );
    final recorder = PictureRecorder();
    painter.paint(Canvas(recorder), const Size(100, 100));
    recorder.endRecording().dispose();
  });
}
