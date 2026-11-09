import 'dart:typed_data';

import 'package:ekyc_demo/core/app_log.dart';
import 'package:ekyc_demo/kyc/domain/document_data.dart';
import 'package:ekyc_demo/kyc/domain/kyc_error.dart';
import 'package:ekyc_demo/kyc/domain/nfc_session.dart';
import 'package:icao_mrtd/icao_mrtd.dart';
import 'package:icao_mrz/icao_mrz.dart';

/// Steps of a chip read, for progress UI.
enum ChipReadStep { waitingForCard, authenticating, reading, verifying }

/// Progress callback: current step and overall fraction (0-1).
typedef ChipReadProgress = void Function(ChipReadStep step, double fraction);

/// Raised by [ChipReader] with a user-facing [KycError].
class ChipReadException implements Exception {
  const ChipReadException(this.error);

  final KycError error;

  @override
  String toString() => 'ChipReadException(${error.name})';
}

/// Localized texts for the iOS NFC sheet.
class ChipReadMessages {
  const ChipReadMessages({
    required this.prompt,
    required this.reading,
    required this.done,
    required this.failed,
  });

  final String prompt;
  final String reading;
  final String done;
  final String failed;
}

/// Reads and verifies an eMRTD chip.
class ChipReader {
  ChipReader({required this.session, required this.trustStore});

  final NfcSession session;
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

  Future<DocumentData> read(
    MrzKey key, {
    required ChipReadMessages messages,
    ChipReadProgress? onProgress,
  }) async {
    final status = await session.status();
    switch (status) {
      case NfcStatus.notSupported:
        throw const ChipReadException(KycError.nfcNotSupported);
      case NfcStatus.disabled:
        throw const ChipReadException(KycError.nfcDisabled);
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
      AppLog.event('chip_read', {
        'passive_auth': data.passiveAuth.status.name,
        'dg11': data.dg11 != null,
      });
      return data;
    } on Object catch (e) {
      final error = _map(e);
      AppLog.event('chip_read_failed', {'error': error.name});
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
      throw const ChipReadException(KycError.documentNotAuthentic);
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

  static KycError _map(Object e) => switch (e) {
    ChipReadException(:final error) => error,
    AccessDeniedException() => KycError.wrongMrz,
    NfcSessionException(reason: NfcFailure.tagLost) => KycError.tagLost,
    NfcSessionException(reason: NfcFailure.timeout) => KycError.timeout,
    NfcSessionException(reason: NfcFailure.cancelled) => KycError.cancelled,
    NfcSessionException(reason: NfcFailure.unavailable) => KycError.nfcDisabled,
    // A broken secure messaging session almost always means the card
    // moved; retrying is the right advice.
    SecureMessagingException() => KycError.tagLost,
    LdsFormatException() => KycError.unsupportedDocument,
    _ => KycError.unknown,
  };
}
