import 'dart:convert';
import 'dart:typed_data';

import 'package:ekyc_demo/kyc/domain/liveness.dart';
import 'package:icao_mrtd/icao_mrtd.dart';

/// A verification session issued by the server.
///
/// The token is short-lived and bound to one verification, so a leaked
/// session id alone cannot be used to write data for someone else.
class VerificationSession {
  const VerificationSession({required this.id, required this.token});

  final String id;
  final String token;

  @override
  String toString() => 'VerificationSession($id)';
}

/// What the app sends for verification.
///
/// Raw chip files are sent instead of parsed fields, so the server can run
/// Passive Authentication itself and never has to trust the client.
class KycSubmission {
  const KycSubmission({
    required this.session,
    required this.chipFiles,
    required this.selfie,
    required this.liveness,
    required this.clientPassiveAuth,
  });

  final VerificationSession session;
  final Map<LdsFile, Uint8List> chipFiles;
  final Uint8List selfie;
  final LivenessOutcome liveness;

  /// The on-device result, sent for diagnostics only.
  final PassiveAuthStatus clientPassiveAuth;

  /// The request body (the token travels in the Authorization header).
  Map<String, Object> toJson() => {
    'sessionId': session.id,
    'chip': {
      for (final MapEntry(:key, :value) in chipFiles.entries)
        key.name: base64.encode(value),
    },
    'selfie': base64.encode(selfie),
    'liveness': liveness.name,
    'clientPassiveAuth': clientPassiveAuth.name,
  };

  @override
  String toString() => 'KycSubmission(${session.id}, <redacted>)';
}

/// The server's decision.
enum VerificationDecision { approved, rejected, manualReview }

/// Talks to the verification backend.
abstract interface class KycRepository {
  Future<VerificationSession> startSession();

  Future<VerificationDecision> submit(KycSubmission submission);
}

/// Raised when the backend cannot be reached or refuses the request.
class KycRepositoryException implements Exception {
  const KycRepositoryException(this.message);

  final String message;

  @override
  String toString() => 'KycRepositoryException: $message';
}
