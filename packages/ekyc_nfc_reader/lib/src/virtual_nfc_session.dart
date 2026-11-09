import 'dart:typed_data';

import 'package:ekyc_nfc_reader/src/nfc_session.dart';
import 'package:icao_mrtd/icao_mrtd.dart';
import 'package:icao_mrtd/testing.dart';
import 'package:icao_mrz/icao_mrz.dart';

/// An [NfcSession] over a [VirtualMrtd], for tests and demo modes.
///
/// It records the messages it was asked to show and how it was closed, and
/// can add latency so progress UI is visible.
class VirtualNfcSession implements NfcSession {
  /// Creates a session that "finds" a chip opened by [key] with [files].
  VirtualNfcSession({
    required this.key,
    required this.files,
    this.nfcStatus = NfcStatus.available,
    this.connectFailure,
    this.loseTagAfter,
    this.connectDelay = Duration.zero,
    this.commandDelay = Duration.zero,
  });

  /// The MRZ key the virtual chip accepts.
  final MrzKey key;

  /// The LDS files on the virtual chip.
  final Map<LdsFile, Uint8List> files;

  /// What [status] reports.
  final NfcStatus nfcStatus;

  /// When set, [connect] fails with this reason.
  final NfcFailure? connectFailure;

  /// See [VirtualMrtd.loseTagAfter].
  final int? loseTagAfter;

  /// Time before [connect] "finds" the card.
  final Duration connectDelay;

  /// Time added to each chip command.
  final Duration commandDelay;

  /// Messages passed to [connect] and [setMessage], in order.
  final messages = <String>[];

  /// Whether [close] was called.
  bool closed = false;

  /// The error message [close] was called with, if any.
  String? closedWithError;

  @override
  Future<NfcStatus> status() async => nfcStatus;

  @override
  Future<ApduTransceiver> connect({required String prompt}) async {
    messages.add(prompt);
    if (connectDelay > Duration.zero) await Future<void>.delayed(connectDelay);
    final failure = connectFailure;
    if (failure != null) throw NfcSessionException(failure);
    final chip = VirtualMrtd(
      key: key,
      files: files,
      loseTagAfter: loseTagAfter,
    );
    return commandDelay > Duration.zero ? _SlowChip(chip, commandDelay) : chip;
  }

  @override
  Future<void> setMessage(String message) async => messages.add(message);

  @override
  Future<void> close({String? message, String? errorMessage}) async {
    closed = true;
    closedWithError = errorMessage;
  }
}

class _SlowChip implements ApduTransceiver {
  _SlowChip(this.chip, this.delay);

  final ApduTransceiver chip;
  final Duration delay;

  @override
  Future<Uint8List> transceive(Uint8List command) async {
    await Future<void>.delayed(delay);
    return chip.transceive(command);
  }
}
