import 'package:camera/camera.dart';
import 'package:ekyc_camera/ekyc_camera.dart';
import 'package:material_ui/material_ui.dart';

void main() => runApp(const MaterialApp(home: PreviewPage()));

class PreviewPage extends StatefulWidget {
  const PreviewPage({super.key});

  @override
  State<PreviewPage> createState() => _PreviewPageState();
}

class _PreviewPageState extends State<PreviewPage> {
  var _frames = 0;
  late final _camera = MlKitCamera(
    lensDirection: CameraLensDirection.back,
    frameInterval: const Duration(milliseconds: 250),
    // Hand each InputImage to any ML Kit detector here.
    onFrame: (image) async => setState(() => _frames++),
  );

  @override
  void initState() {
    super.initState();
    _camera.start().ignore();
  }

  @override
  void dispose() {
    _camera.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: MlKitCameraView(
      camera: _camera,
      unavailableBuilder: (_) => const Center(child: Text('No camera')),
      overlay: Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Frames: $_frames',
            style: const TextStyle(color: Colors.white),
          ),
        ),
      ),
    ),
  );
}
