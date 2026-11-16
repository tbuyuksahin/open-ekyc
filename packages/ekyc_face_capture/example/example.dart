import 'package:ekyc_face_capture/ekyc_face_capture.dart';
import 'package:material_ui/material_ui.dart';

void main() => runApp(const MaterialApp(home: SelfiePage()));

class SelfiePage extends StatelessWidget {
  const SelfiePage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    body: FaceCapture(
      challenges: const [FaceChallenge.turnLeft, FaceChallenge.smile],
      onCaptured: (result) => Navigator.of(context).pop(result.image),
      unavailableBuilder: (_) => const Center(child: Text('No camera')),
      hintText: (hint) => hint.name,
      challengeText: (challenge) => challenge.name,
    ),
  );
}
