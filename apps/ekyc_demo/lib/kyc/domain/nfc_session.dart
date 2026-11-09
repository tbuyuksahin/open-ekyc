import 'package:icao_mrtd/icao_mrtd.dart';

/// Whether the device can read NFC documents right now.
enum NfcStatus { available, disabled, notSupported }

/// A platform NFC reader session.
///
/// Separating the platform session from the protocol keeps the reading
/// logic testable with a virtual chip.
abstract interface class NfcSession {
  Future<NfcStatus> status();

  /// Waits for an ISO 14443 card and returns a transceiver for it.
  ///
  /// [prompt] is shown on the iOS system sheet.
  Future<ApduTransceiver> connect({required String prompt});

  /// Updates the iOS system sheet text (no-op on Android).
  Future<void> setMessage(String message);

  /// Ends the session; [errorMessage] marks it as failed on iOS.
  Future<void> close({String? message, String? errorMessage});
}

/// Thrown by [NfcSession] implementations, with a mapped reason.
class NfcSessionException implements Exception {
  const NfcSessionException(this.reason);

  final NfcFailure reason;

  @override
  String toString() => 'NfcSessionException(${reason.name})';
}

/// Platform-level NFC failures.
enum NfcFailure { tagLost, timeout, cancelled, unavailable, other }
