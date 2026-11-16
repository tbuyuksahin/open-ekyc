import 'package:ekyc_document_capture/ekyc_document_capture.dart';
import 'package:material_ui/material_ui.dart';

void main() => runApp(const MaterialApp(home: CapturePage()));

class CapturePage extends StatelessWidget {
  const CapturePage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    body: DocumentCapture(
      onCaptured: (result) {
        final check = result.crossCheck();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Printed details found: ${check?.score}')),
        );
        result.wipe();
      },
      unavailableBuilder: (_) => const Center(child: Text('No camera')),
      sideLabel: (side) => side.name,
      hintText: (hint, side) => switch (hint) {
        DocumentHint.noDocument => 'Place the ${side.name} inside the frame',
        DocumentHint.wrongSide => 'Turn the document over',
        DocumentHint.tooDark => 'Find more light',
        DocumentHint.glare => 'Tilt the document to remove the reflection',
        DocumentHint.blurry => 'Hold the phone steady',
        DocumentHint.holdStill => 'Hold still…',
      },
    ),
  );
}
