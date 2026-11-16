import 'package:ekyc_mrz_scanner/ekyc_mrz_scanner.dart';
import 'package:material_ui/material_ui.dart';

void main() => runApp(const MaterialApp(home: ScanPage()));

class ScanPage extends StatelessWidget {
  const ScanPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    body: MrzScanner(
      onDetected: (mrz) => Navigator.of(context).pop(mrz.key),
      unavailableBuilder: (_) => const Center(child: Text('No camera')),
      hintText: (status) => switch (status) {
        MrzScanStatus.searching => 'Line up the bottom lines of the card',
        MrzScanStatus.confirming => 'Reading… hold still',
        MrzScanStatus.detected => 'Got it',
      },
      style: const MrzOverlayStyle(successColor: Colors.teal),
    ),
  );
}
