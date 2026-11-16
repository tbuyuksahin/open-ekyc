import 'package:ekyc_nfc_reader/ekyc_nfc_reader.dart';
import 'package:icao_mrz/icao_mrz.dart';
import 'package:material_ui/material_ui.dart';

void main() => runApp(const MaterialApp(home: ChipPage()));

class ChipPage extends StatefulWidget {
  const ChipPage({super.key});

  @override
  State<ChipPage> createState() => _ChipPageState();
}

class _ChipPageState extends State<ChipPage> {
  final _reader = ChipReader(
    session: const FlutterNfcSession(),
    // Load your CSCA master list here; without it a genuine chip is
    // reported as untrusted.
    trustStore: CscaStore.empty(),
  );
  ChipReadStep? _step;
  double _progress = 0;
  String? _message;

  Future<void> _read() async {
    final key = MrzKey(
      documentNumber: 'L898902C3',
      dateOfBirth: const MrzDate('740812'),
      dateOfExpiry: const MrzDate('120415'),
    );
    try {
      final document = await _reader.read(
        key,
        onProgress: (step, fraction) => setState(() {
          _step = step;
          _progress = fraction;
        }),
      );
      setState(() => _message = document.passiveAuth.status.name);
      document.wipe();
    } on ChipReadException catch (e) {
      setState(() => _message = e.error.name);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        NfcScanOverlay(
          status: NfcScanStatus.of(_step, failed: _message != null),
          progress: _progress,
        ),
        if (_message case final message?) Text(message),
        FilledButton(onPressed: _read, child: const Text('Read chip')),
      ],
    ),
  );
}
