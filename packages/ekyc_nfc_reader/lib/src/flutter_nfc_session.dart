import 'package:ekyc_nfc_reader/src/nfc_session.dart';
import 'package:flutter/services.dart';
import 'package:flutter_nfc_kit/flutter_nfc_kit.dart';
import 'package:icao_mrtd/icao_mrtd.dart';

/// [NfcSession] backed by `flutter_nfc_kit` (Android IsoDep, iOS
/// NFCTagReaderSession).
class FlutterNfcSession implements NfcSession {
  /// Creates a session with the given timeouts.
  const FlutterNfcSession({
    this.pollTimeout = const Duration(seconds: 30),
    this.commandTimeout = const Duration(seconds: 5),
  });

  /// How long to wait for a card.
  final Duration pollTimeout;

  /// How long to wait for each chip response.
  final Duration commandTimeout;

  @override
  Future<NfcStatus> status() async {
    try {
      return switch (await FlutterNfcKit.nfcAvailability) {
        NFCAvailability.available => NfcStatus.available,
        NFCAvailability.disabled => NfcStatus.disabled,
        NFCAvailability.not_supported => NfcStatus.notSupported,
      };
    } on PlatformException {
      return NfcStatus.notSupported;
    }
  }

  @override
  Future<ApduTransceiver> connect({required String prompt}) async {
    final NFCTag tag;
    try {
      tag = await FlutterNfcKit.poll(
        timeout: pollTimeout,
        iosAlertMessage: prompt,
        readIso15693: false,
        androidCheckNDEF: false,
        androidPlatformSound: false,
      );
    } on PlatformException catch (e) {
      throw NfcSessionException(_map(e));
    }
    if (tag.type != NFCTagType.iso7816) {
      throw const NfcSessionException(NfcFailure.other);
    }
    return _Transceiver(commandTimeout);
  }

  @override
  Future<void> setMessage(String message) async {
    try {
      await FlutterNfcKit.setIosAlertMessage(message);
    } on Object {
      // Android has no system sheet; iOS may have closed it already.
    }
  }

  @override
  Future<void> close({String? message, String? errorMessage}) async {
    try {
      await FlutterNfcKit.finish(
        iosAlertMessage: message,
        iosErrorMessage: errorMessage,
      );
    } on Object {
      // Nothing to close.
    }
  }

  static NfcFailure _map(PlatformException e) => switch (e.code) {
    '408' => NfcFailure.timeout,
    '409' => NfcFailure.cancelled,
    '404' => NfcFailure.unavailable,
    '500' || '503' => NfcFailure.tagLost,
    _ => NfcFailure.other,
  };
}

class _Transceiver implements ApduTransceiver {
  const _Transceiver(this.timeout);

  final Duration timeout;

  @override
  Future<Uint8List> transceive(Uint8List command) async {
    try {
      return await FlutterNfcKit.transceive<Uint8List>(
        command,
        timeout: timeout,
      );
    } on PlatformException catch (e) {
      throw NfcSessionException(FlutterNfcSession._map(e));
    }
  }
}
