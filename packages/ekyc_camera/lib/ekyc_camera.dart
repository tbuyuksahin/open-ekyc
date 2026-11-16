/// Camera plumbing shared by the open-ekyc capture packages.
///
/// [MlKitCamera] streams frames to ML Kit and follows the app lifecycle,
/// [MlKitCameraView] shows it with an overlay, and [ScrimPainter] darkens
/// everything outside a capture guide.
library;

import 'package:ekyc_camera/src/camera_view.dart';
import 'package:ekyc_camera/src/ml_kit_camera.dart';

export 'src/camera_view.dart';
export 'src/guide_painting.dart';
export 'src/input_image.dart';
export 'src/ml_kit_camera.dart';
export 'src/shutter_button.dart';
