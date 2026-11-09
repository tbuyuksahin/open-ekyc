import 'package:ekyc_demo/app.dart';
import 'package:ekyc_demo/kyc/data/csca_assets.dart';
import 'package:ekyc_demo/kyc/data/demo_document.dart';
import 'package:ekyc_demo/kyc/data/fake_kyc_repository.dart';
import 'package:ekyc_demo/kyc/flow/kyc_services.dart';
import 'package:ekyc_sdk/ekyc_sdk.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final repository = FakeKycRepository();

  Future<KycServices> load({required bool demo}) async {
    if (demo) {
      final document = await DemoDocument.create(rootBundle);
      return KycServices(
        chipReader: ChipReader(
          session: document.asNfcSession(),
          trustStore: document.trustStore,
        ),
        repository: repository,
        demoKey: document.mrz.key,
        sampleSelfie: document.portrait,
      );
    }
    return KycServices(
      chipReader: ChipReader(
        session: const FlutterNfcSession(),
        trustStore: await loadCscaStore(rootBundle),
      ),
      repository: repository,
    );
  }

  runApp(EkycApp(loadServices: load));
}
