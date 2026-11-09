import 'package:ekyc_nfc_reader/ekyc_nfc_reader.dart';

/// Failures the user can understand and act on.
///
/// Every low-level exception is mapped to one of these, so the UI never
/// shows raw error text (which could contain technical noise) to users.
enum KycError {
  /// The device has no NFC hardware.
  nfcNotSupported,

  /// NFC is turned off in system settings.
  nfcDisabled,

  /// The chip rejected the MRZ key: a document number or date is wrong.
  wrongMrz,

  /// The document moved away from the antenna during reading.
  tagLost,

  /// No document was found before the scan timed out.
  timeout,

  /// The user closed the system NFC sheet (iOS).
  cancelled,

  /// Passive Authentication failed: the chip data was altered or forged.
  documentNotAuthentic,

  /// The chip data could not be understood.
  unsupportedDocument,

  /// The verification service rejected or could not process the request.
  submissionFailed,

  /// Anything else.
  unknown,
}

/// Maps chip reading failures from `ekyc_nfc_reader` to flow errors.
KycError kycErrorFromChip(ChipReadError error) => switch (error) {
  ChipReadError.nfcNotSupported => KycError.nfcNotSupported,
  ChipReadError.nfcDisabled => KycError.nfcDisabled,
  ChipReadError.wrongMrz => KycError.wrongMrz,
  ChipReadError.tagLost => KycError.tagLost,
  ChipReadError.timeout => KycError.timeout,
  ChipReadError.cancelled => KycError.cancelled,
  ChipReadError.documentNotAuthentic => KycError.documentNotAuthentic,
  ChipReadError.unsupportedDocument => KycError.unsupportedDocument,
  ChipReadError.unknown => KycError.unknown,
};
