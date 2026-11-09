import 'package:meta/meta.dart';

/// Base class for every error raised by this package.
///
/// Messages never contain personal data or key material, so they are safe
/// to log and to show in crash reports.
@immutable
sealed class MrtdException implements Exception {
  const MrtdException(this.message);

  /// A description of the failure without personal data.
  final String message;

  /// A short name for the kind of failure.
  String get kind;

  @override
  String toString() => '$kind: $message';
}

/// The chip answered a command with an error status word.
final class ApduException extends MrtdException {
  /// Creates an exception for status word [sw].
  ApduException(this.sw, String command)
    : super('$command failed with SW ${sw.toRadixString(16).padLeft(4, '0')}');

  /// The two-byte status word, for example `0x6982`.
  final int sw;

  @override
  String get kind => 'ApduException';
}

/// Basic Access Control failed. This almost always means that the
/// document number or one of the dates used as the key is wrong.
final class AccessDeniedException extends MrtdException {
  /// Creates the exception.
  const AccessDeniedException(super.message);

  @override
  String get kind => 'AccessDeniedException';
}

/// A secure messaging response could not be authenticated or decrypted.
/// The session must be discarded.
final class SecureMessagingException extends MrtdException {
  /// Creates the exception.
  const SecureMessagingException(super.message);

  @override
  String get kind => 'SecureMessagingException';
}

/// Bytes read from the chip do not have the structure ICAO 9303 requires.
final class LdsFormatException extends MrtdException {
  /// Creates the exception.
  const LdsFormatException(super.message);

  @override
  String get kind => 'LdsFormatException';
}
