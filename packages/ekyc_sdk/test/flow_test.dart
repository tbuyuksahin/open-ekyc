import 'package:ekyc_camera/testing.dart';
import 'package:ekyc_nfc_reader/testing.dart';
import 'package:ekyc_sdk/ekyc_sdk.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'helpers.dart';

/// Pumps until [finder] matches; the NFC illustration animates forever,
/// so pumpAndSettle cannot be used.
Future<void> pumpUntil(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 300; i++) {
    if (finder.evaluate().isNotEmpty) return;
    await tester.pump(const Duration(milliseconds: 50));
  }
  fail('Timed out waiting for $finder');
}

void main() {
  late TestDocument doc;
  setUpAll(() => doc = TestDocument());

  const en = EkycStrings.en;
  const tr = EkycStrings.tr;

  EkycConfig config({
    List<EkycStep> steps = const [EkycStep.mrz, EkycStep.nfc],
    NfcFailure? connectFailure,
  }) => EkycConfig(
    steps: steps,
    startWithCamera: false,
    trustStore: doc.trustStore,
    nfcSession: VirtualNfcSession(
      key: specimenKey,
      files: doc.files,
      connectFailure: connectFailure,
    ),
  );

  /// A host app with one button that calls [run] and stores the outcome.
  Future<List<Object?>> pumpHost(
    WidgetTester tester,
    Future<Object?> Function(BuildContext context) run, {
    Locale locale = const Locale('en'),
  }) async {
    final outcomes = <Object?>[];
    await tester.pumpWidget(
      MaterialApp(
        locale: locale,
        supportedLocales: const [Locale('en'), Locale('tr')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () async => outcomes.add(await run(context)),
                child: const Text('verify'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('verify'));
    // Camera and NFC screens animate forever, so settle by time instead.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    return outcomes;
  }

  Future<void> fillForm(WidgetTester tester, EkycStrings s) async {
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'L898902C3');
    await tester.enterText(fields.at(1), '12.08.1974');
    await tester.enterText(fields.at(2), '15.04.2012');
    await tester.tap(find.text(s.mrzContinue));
  }

  testWidgets('Ekyc.start runs MRZ and NFC and returns the document', (
    tester,
  ) async {
    final outcomes = await pumpHost(
      tester,
      (context) => Ekyc.start(context, config: config()),
    );
    expect(find.text(en.mrzTitle), findsOneWidget);
    await fillForm(tester, en);
    await pumpUntil(tester, find.text('verify'));
    await tester.pumpAndSettle();
    final result = outcomes.single! as EkycResult;
    expect(result.document!.mrz.documentNumber, 'L898902C3');
    expect(result.document!.passiveAuth.status, PassiveAuthStatus.verified);
    expect(result.selfie, isNull);
  });

  testWidgets('uses Turkish texts for a Turkish app', (tester) async {
    await pumpHost(
      tester,
      (context) => Ekyc.scanMrz(context, config: config()),
      locale: const Locale('tr'),
    );
    expect(find.text(tr.mrzTitle), findsOneWidget);
    expect(find.text(tr.mrzContinue), findsOneWidget);
  });

  testWidgets('Ekyc.scanMrz returns only the key', (tester) async {
    final outcomes = await pumpHost(
      tester,
      (context) => Ekyc.scanMrz(context, config: config()),
    );
    await fillForm(tester, en);
    await tester.pumpAndSettle();
    expect((outcomes.single! as MrzKey).documentNumber, 'L898902C3');
  });

  testWidgets('Ekyc.readChip reads with a key the host already has', (
    tester,
  ) async {
    final outcomes = <Object?>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async => outcomes.add(
              await Ekyc.readChip(
                context,
                mrzKey: specimenKey,
                config: config(),
              ),
            ),
            child: const Text('verify'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('verify'));
    await pumpUntil(tester, find.text('verify'));
    await tester.pumpAndSettle();
    expect((outcomes.single! as DocumentData).surname, 'ERIKSSON');
  });

  testWidgets('a failed read offers retry and editing; cancel returns null', (
    tester,
  ) async {
    final outcomes = await pumpHost(
      tester,
      (context) => Ekyc.start(
        context,
        config: config(connectFailure: NfcFailure.timeout),
      ),
    );
    await fillForm(tester, en);
    await pumpUntil(tester, find.text(en.errorTimeout));
    expect(find.text(en.retry), findsOneWidget);

    await tester.tap(find.text(en.checkDetails));
    await tester.pumpAndSettle();
    // Back on the form with the values kept.
    expect(find.text('L898902C3'), findsOneWidget);

    await tester.tap(find.byTooltip(en.cancel));
    await tester.pumpAndSettle();
    expect(outcomes, [null]);
  });

  testWidgets('a forged document cannot be retried', (tester) async {
    final forged = TestDocument(tamperDg1: true);
    await pumpHost(
      tester,
      (context) => Ekyc.start(
        context,
        config: EkycConfig(
          steps: const [EkycStep.mrz, EkycStep.nfc],
          startWithCamera: false,
          trustStore: forged.trustStore,
          nfcSession: VirtualNfcSession(
            key: specimenKey,
            files: forged.files,
          ),
        ),
      ),
    );
    await fillForm(tester, en);
    await pumpUntil(tester, find.text(en.errorNotAuthentic));
    expect(find.text(en.retry), findsNothing);
    expect(find.text(en.checkDetails), findsOneWidget);
  });

  group('with a camera', () {
    const faces = MethodChannel('google_mlkit_face_detector');
    const text = MethodChannel('google_mlkit_text_recognizer');
    late FakeCameraPlatform camera;

    setUp(() {
      CameraPlatform.instance = camera = FakeCameraPlatform();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        ..setMockMethodCallHandler(
          faces,
          (call) async => call.method == 'vision#startFaceDetector'
              ? [
                  {
                    'rect': {
                      'left': 120,
                      'top': 180,
                      'right': 360,
                      'bottom': 460,
                    },
                    'headEulerAngleX': 0.0,
                    'headEulerAngleY': 0.0,
                    'headEulerAngleZ': 0.0,
                    'smilingProbability': 0.1,
                    'leftEyeOpenProbability': 0.9,
                    'rightEyeOpenProbability': 0.9,
                    'landmarks': <String, Object?>{},
                  },
                ]
              : null,
        )
        ..setMockMethodCallHandler(
          text,
          (call) async => call.method == 'vision#startTextRecognizer'
              ? {'text': specimenMrz.join('\n'), 'blocks': <Object>[]}
              : null,
        );
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        ..setMockMethodCallHandler(faces, null)
        ..setMockMethodCallHandler(text, null);
    });

    // Photo capture reads and deletes a real file.
    Future<void> frames(
      WidgetTester tester,
      int count, {
      Uint8List? bytes,
    }) async {
      for (var f = 0; f < count; f++) {
        camera.emitFrame(bytes: bytes);
        for (var i = 0; i < 20; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 10)),
          );
          await tester.pump(const Duration(milliseconds: 100));
        }
      }
    }

    testWidgets('Ekyc.captureSelfie takes the photo, with a mode switch', (
      tester,
    ) async {
      final outcomes = await pumpHost(
        tester,
        (context) => Ekyc.captureSelfie(
          context,
          config: const EkycConfig(
            face: EkycFaceOptions(allowModeSwitch: true),
          ),
        ),
      );
      expect(find.text(en.faceTitle), findsOneWidget);
      // Switching to manual shows the shutter; back to automatic.
      await tester.tap(find.text(en.faceModeManual));
      await tester.pump();
      await frames(tester, 1);
      expect(find.bySemanticsLabel(en.faceShutter), findsOneWidget);
      await tester.tap(find.text(en.faceModeAuto));
      await tester.pump();

      await frames(tester, 7);
      await tester.pumpAndSettle();
      final result = outcomes.single! as EkycResult;
      expect(result.selfie, camera.pictureBytes);
      expect(result.liveness, LivenessOutcome.notPerformed);
    });

    testWidgets('Ekyc.captureDocument photographs a passport page', (
      tester,
    ) async {
      // A lit, detailed frame; the default black one is too dark.
      final detailed = Uint8List(480 * 640 * 4);
      for (var y = 0; y < 640; y++) {
        for (var x = 0; x < 480; x++) {
          final value = (x ~/ 2 + y ~/ 2).isEven ? 90 : 190;
          detailed.fillRange((y * 480 + x) * 4, (y * 480 + x) * 4 + 4, value);
        }
      }
      final outcomes = await pumpHost(
        tester,
        (context) => Ekyc.captureDocument(
          context,
          config: const EkycConfig(
            document: EkycDocumentOptions(
              kind: DocumentKind.passport,
              allowModeSwitch: true,
            ),
          ),
        ),
      );
      expect(find.text(en.documentTitle), findsOneWidget);
      expect(find.text(en.documentSideFront), findsOneWidget);
      await frames(tester, 1);
      expect(find.text(en.documentTooDark), findsOneWidget);

      await tester.tap(find.text(en.faceModeManual));
      await tester.pump();
      await frames(tester, 1, bytes: detailed);
      expect(find.bySemanticsLabel(en.documentShutter), findsOneWidget);
      await tester.tap(find.text(en.faceModeAuto));
      await tester.pump();

      await frames(tester, 4, bytes: detailed);
      await tester.pumpAndSettle();
      final result = outcomes.single! as DocumentCaptureResult;
      expect(result.front, camera.pictureBytes);
      expect(result.mrz!.documentNumber, 'L898902C3');
    });

    testWidgets('the MRZ camera scans and can switch to the form', (
      tester,
    ) async {
      final outcomes = await pumpHost(
        tester,
        Ekyc.scanMrz,
      );
      expect(find.text(en.mrzScanHint), findsOneWidget);
      await tester.tap(find.text(en.mrzEnterManually));
      await tester.pumpAndSettle();
      expect(find.text(en.mrzContinue), findsOneWidget);
      await tester.tap(find.text(en.mrzScanCamera));
      await tester.pump();

      await frames(tester, 3);
      await tester.pumpAndSettle();
      expect((outcomes.single! as MrzKey).documentNumber, 'L898902C3');
    });

    testWidgets('explains a missing camera', (tester) async {
      CameraPlatform.instance = FakeCameraPlatform(denyPermission: true);
      await pumpHost(tester, Ekyc.captureSelfie);
      expect(find.text(en.cameraUnavailable), findsOneWidget);
    });
  });

  testWidgets('EkycFlow embeds without navigation', (tester) async {
    final results = <EkycResult>[];
    await tester.pumpWidget(
      MaterialApp(
        home: EkycFlow(
          config: config(steps: const [EkycStep.mrz]),
          onCompleted: results.add,
        ),
      ),
    );
    // No close button without onCancelled.
    expect(find.byTooltip(en.cancel), findsNothing);
    await fillForm(tester, en);
    await tester.pumpAndSettle();
    expect(results.single.mrzKey!.documentNumber, 'L898902C3');
    expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
  });
}
