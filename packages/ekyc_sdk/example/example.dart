import 'package:ekyc_sdk/ekyc_sdk.dart';
import 'package:material_ui/material_ui.dart';

void main() => runApp(const MaterialApp(home: VerifyPage()));

class VerifyPage extends StatelessWidget {
  const VerifyPage({super.key});

  Future<void> _verify(BuildContext context) async {
    final result = await Ekyc.start(
      context,
      config: EkycConfig(
        steps: const [EkycStep.document, ...EkycStep.standard],
        theme: EkycTheme.brand(primary: Colors.indigo),
        face: const EkycFaceOptions(
          challenges: FaceChallenge.values,
          challengeCount: 2,
        ),
      ),
    );
    if (result == null) return;
    // Send result.document!.rawFiles and result.selfie to your server,
    // which repeats Passive Authentication, then erase them.
    result.wipe();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: FilledButton(
        onPressed: () => _verify(context),
        child: const Text('Verify my identity'),
      ),
    ),
  );
}
