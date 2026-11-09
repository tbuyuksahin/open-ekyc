import 'package:icao_mrtd/icao_mrtd.dart';

/// Whether the device can read NFC documents right now.
enum NfcStatus {
  /// NFC is on.
  available,

  /// NFC hardware exists but is turned off.
  disabled,

  /// The device has no NFC reader.
  notSupported,
}

/// A platform NFC reader session.
///
/// Separating the platform session from the protocol keeps the reading
/// logic testable with a virtual chip; see
/// `package:ekyc_nfc_reader/testing.dart`.
abstract interface class NfcSession {
  /// Whether NFC can be used now.
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
  /// Creates an exception for [reason].
  const NfcSessionException(this.reason);

  /// Why the session failed.
  final NfcFailure reason;

  @override
  String toString() => 'NfcSessionException(${reason.name})';
}

/// Platform-level NFC failures.
enum NfcFailure {
  /// The card left the field.
  tagLost,

  /// No card was found in time.
  timeout,

  /// The user closed the system sheet (iOS).
  cancelled,

  /// NFC is off or unavailable.
  unavailable,

  /// Anything else.
  other,
}
