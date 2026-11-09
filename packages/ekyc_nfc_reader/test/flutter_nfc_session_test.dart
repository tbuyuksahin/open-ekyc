import 'dart:convert';

import 'package:ekyc_nfc_reader/ekyc_nfc_reader.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('flutter_nfc_kit/method');
  final calls = <MethodCall>[];
  late Object? Function(MethodCall call) handler;

  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return handler(call);
        });
  });

  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null),
  );

  String tag(String type) => jsonEncode({
    'type': type,
    'id': '01020304',
    'standard': 'ISO 14443-4 (Type B)',
  });

  test('reports NFC availability and treats channel errors as none', () async {
    const session = FlutterNfcSession();
    for (final (value, expected) in [
      ('available', NfcStatus.available),
      ('disabled', NfcStatus.disabled),
      ('not_supported', NfcStatus.notSupported),
    ]) {
      handler = (_) => value;
      expect(await session.status(), expected);
    }
    handler = (_) => throw PlatformException(code: '500');
    expect(await session.status(), NfcStatus.notSupported);
  });

  test('polls for ISO-DEP cards only and exchanges APDUs', () async {
    final response = Uint8List.fromList([0x90, 0x00]);
    handler = (call) => switch (call.method) {
      'poll' => tag('iso7816'),
      'transceive' => response,
      _ => null,
    };
    const session = FlutterNfcSession(
      pollTimeout: Duration(seconds: 7),
      commandTimeout: Duration(seconds: 2),
    );
    final transceiver = await session.connect(prompt: 'Hold it');
    final poll = calls.single.arguments as Map<Object?, Object?>;
    expect(poll['timeout'], 7000);
    expect(poll['iosAlertMessage'], 'Hold it');
    // NFC-A and NFC-B, no NDEF check, no platform sound; no ISO 15693.
    expect(poll['technologies'], 0x1 | 0x2 | 0x80 | 0x100);

    final apdu = Uint8List.fromList([0x00, 0xA4, 0x04, 0x0C]);
    expect(await transceiver.transceive(apdu), response);
    final transceive = calls.last.arguments as Map<Object?, Object?>;
    expect(transceive['data'], apdu);
    expect(transceive['timeout'], 2000);
  });

  test('rejects tags that cannot carry an eMRTD application', () async {
    handler = (_) => tag('mifare_ultralight');
    await expectLater(
      const FlutterNfcSession().connect(prompt: ''),
      throwsA(
        isA<NfcSessionException>().having(
          (e) => e.reason,
          'reason',
          NfcFailure.other,
        ),
      ),
    );
  });

  test('maps plugin error codes to failures', () async {
    for (final (code, reason) in [
      ('408', NfcFailure.timeout),
      ('409', NfcFailure.cancelled),
      ('404', NfcFailure.unavailable),
      ('500', NfcFailure.tagLost),
      ('503', NfcFailure.tagLost),
      ('406', NfcFailure.other),
    ]) {
      handler = (_) => throw PlatformException(code: code);
      await expectLater(
        const FlutterNfcSession().connect(prompt: ''),
        throwsA(
          isA<NfcSessionException>()
              .having((e) => e.reason, 'reason', reason)
              .having((e) => e.toString(), 'text', contains(reason.name)),
        ),
        reason: code,
      );
    }
    handler = (call) => call.method == 'poll'
        ? tag('iso7816')
        : throw PlatformException(code: '500');
    final transceiver = await const FlutterNfcSession().connect(prompt: '');
    await expectLater(
      transceiver.transceive(Uint8List(4)),
      throwsA(isA<NfcSessionException>()),
    );
  });

  test('updates and closes the iOS sheet, ignoring errors', () async {
    handler = (_) => null;
    const session = FlutterNfcSession();
    await session.setMessage('Reading');
    await session.close(message: 'Done');
    expect(calls.map((c) => c.method), ['setIosAlertMessage', 'finish']);
    expect(
      (calls.last.arguments as Map<Object?, Object?>)['iosAlertMessage'],
      'Done',
    );

    handler = (_) => throw PlatformException(code: '500');
    await session.setMessage('x');
    await session.close(errorMessage: 'Failed');
  });
}
