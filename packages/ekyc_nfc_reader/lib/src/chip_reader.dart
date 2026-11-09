import 'dart:typed_data';

import 'package:ekyc_nfc_reader/src/document_data.dart';
import 'package:ekyc_nfc_reader/src/nfc_session.dart';
import 'package:icao_mrtd/icao_mrtd.dart';
import 'package:icao_mrz/icao_mrz.dart';

/// Steps of a chip read, for progress UI.
enum ChipReadStep {
  /// Waiting for the user to hold the document to the phone.
  waitingForCard,

  /// Basic Access Control with the MRZ key.
  authenticating,

  /// Reading the data groups.
  reading,

  /// Passive Authentication.
  verifying,
}

/// Progress callback: current step and overall fraction (0-1).
typedef ChipReadProgress = void Function(ChipReadStep step, double fraction);

/// Why a chip read failed, in terms the user can act on.
///
/// Low-level exceptions never leak to the UI; every one maps to one of
/// these.
enum ChipReadError {
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

  /// Anything else.
  unknown;

  /// Whether trying again can help, as opposed to a dead end.
  bool get isRetryable => switch (this) {
    nfcNotSupported || documentNotAuthentic => false,
    _ => true,
  };
}

/// Raised by [ChipReader] with a user-facing [error].
class ChipReadException implements Exception {
  /// Creates an exception for [error].
  const ChipReadException(this.error);

  /// What went wrong.
  final ChipReadError error;

  @override
  String toString() => 'ChipReadException(${error.name})';
}

/// Localized texts for the iOS NFC sheet.
class ChipReadMessages {
  /// Creates messages, defaulting to English.
  const ChipReadMessages({
    this.prompt = 'Hold your document to the top of the phone.',
    this.reading = 'Reading the chip. Keep still.',
    this.done = 'Done.',
    this.failed = 'Could not read the document.',
  });

  /// Shown while waiting for the document.
  final String prompt;

  /// Shown while reading.
  final String reading;

  /// Shown on success.
  final String done;

  /// Shown on failure.
  final String failed;
}

/// Reads and verifies an eMRTD chip.
class ChipReader {
  /// Creates a reader that uses [session] and trusts [trustStore].
  ChipReader({required this.session, required this.trustStore});

  /// The platform NFC session.
  final NfcSession session;

  /// Trusted CSCA certificates for Passive Authentication.
  final CscaStore trustStore;

  // Progress before the first file (connect and BAC).
  static const _setupShare = 0.05;

  // Files and their share of the progress bar; with [_setupShare] the
  // shares add up to 1. DG2 (the portrait) dominates.
  static const _files = <(LdsFile, double)>[
    (LdsFile.com, 0.02),
    (LdsFile.dg1, 0.03),
    (LdsFile.dg11, 0.05),
    (LdsFile.dg2, 0.70),
    (LdsFile.sod, 0.15),
  ];

  /// Reads the document that opens with [key].
  ///
  /// Throws [ChipReadException] on any failure.
  Future<DocumentData> read(
    MrzKey key, {
    ChipReadMessages messages = const ChipReadMessages(),
    ChipReadProgress? onProgress,
  }) async {
    final status = await session.status();
    switch (status) {
      case NfcStatus.notSupported:
        throw const ChipReadException(ChipReadError.nfcNotSupported);
      case NfcStatus.disabled:
        throw const ChipReadException(ChipReadError.nfcDisabled);
      case NfcStatus.available:
        break;
    }

    MrtdReader? reader;
    try {
      onProgress?.call(ChipReadStep.waitingForCard, 0);
      final transceiver = await session.connect(prompt: messages.prompt);
      onProgress?.call(ChipReadStep.authenticating, 0.02);
      reader = MrtdReader(transceiver);
      await reader.openSession(key);
      await session.setMessage(messages.reading);

      final files = <LdsFile, Uint8List>{};
      var done = _setupShare;
      for (final (file, weight) in _files) {
        final start = done;
        try {
          files[file] = await reader.readFile(
            file,
            onProgress: (read, total) => onProgress?.call(
              ChipReadStep.reading,
              (start + weight * read / total).clamp(0, 1),
            ),
          );
        } on ApduException catch (e) {
          // DG11 is optional; everything else is mandatory.
          if (file != LdsFile.dg11 || e.sw != StatusWord.fileNotFound) {
            rethrow;
          }
        }
        done += weight;
      }
      onProgress?.call(ChipReadStep.verifying, 1);
      final data = _parse(files);
      await session.close(message: messages.done);
      return data;
    } on Object catch (e) {
      final error = _map(e);
      await session.close(errorMessage: messages.failed);
      throw ChipReadException(error);
    } finally {
      reader?.close();
    }
  }

  DocumentData _parse(Map<LdsFile, Uint8List> files) {
    final sod = EfSod.parse(files[LdsFile.sod]!);
    final passive = verifyPassiveAuthentication(
      sod: sod,
      dataGroups: {
        for (final MapEntry(:key, :value) in files.entries)
          if (key.dataGroup != null) key.dataGroup!: value,
      },
      trustStore: trustStore,
    );
    if (passive.status == PassiveAuthStatus.failed) {
      throw const ChipReadException(ChipReadError.documentNotAuthentic);
    }
    final dg11 = files[LdsFile.dg11];
    return DocumentData(
      mrz: parseDg1(files[LdsFile.dg1]!),
      face: parseDg2(files[LdsFile.dg2]!),
      dg11: dg11 == null ? null : Dg11.parse(dg11),
      passiveAuth: passive,
      rawFiles: files,
    );
  }

  static ChipReadError _map(Object e) => switch (e) {
    ChipReadException(:final error) => error,
    AccessDeniedException() => ChipReadError.wrongMrz,
    NfcSessionException(reason: NfcFailure.tagLost) => ChipReadError.tagLost,
    NfcSessionException(reason: NfcFailure.timeout) => ChipReadError.timeout,
    NfcSessionException(reason: NfcFailure.cancelled) =>
      ChipReadError.cancelled,
    NfcSessionException(reason: NfcFailure.unavailable) =>
      ChipReadError.nfcDisabled,
    // A broken secure messaging session almost always means the card
    // moved; retrying is the right advice.
    SecureMessagingException() => ChipReadError.tagLost,
    LdsFormatException() => ChipReadError.unsupportedDocument,
    _ => ChipReadError.unknown,
  };
}
