import 'package:ekyc_demo/core/app_log.dart';
import 'package:flutter/services.dart';
import 'package:icao_mrtd/icao_mrtd.dart';

/// Loads trusted CSCA certificates bundled under `assets/csca/` (PEM).
///
/// The repository ships none: obtain them from the ICAO PKD or the
/// issuing states' published master lists and review each one. Without
/// them, real documents verify as "untrusted" rather than "verified".
Future<CscaStore> loadCscaStore(AssetBundle bundle) async {
  final manifest = await AssetManifest.loadFromAssetBundle(bundle);
  final certificates = <X509Certificate>[];
  for (final path in manifest.listAssets()) {
    if (!path.startsWith('assets/csca/') || !path.endsWith('.pem')) continue;
    try {
      final pem = await bundle.loadString(path);
      certificates.addAll(X509Certificate.fromPem(pem));
    } on LdsFormatException {
      AppLog.event('csca_skipped', {'reason': 'malformed'});
    }
  }
  AppLog.event('csca_loaded', {'count': certificates.length});
  return CscaStore(certificates);
}
