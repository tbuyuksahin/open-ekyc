/// Drop-in identity verification for Flutter.
///
/// Use it at the level you need:
///
/// * [Ekyc.start] runs the whole flow (MRZ, NFC, selfie) and returns an
///   [EkycResult]; [Ekyc.scanMrz], [Ekyc.readChip] and
///   [Ekyc.captureSelfie] run a single step.
/// * [EkycFlow] embeds the flow in your own page.
/// * [EkycMrzScreen], [EkycNfcScreen] and [EkycFaceScreen] are the step
///   screens on their own, and the re-exported step packages give you the
///   bare widgets (`MrzScanner`, `ChipReader`, `FaceCapture`…).
library;

import 'package:ekyc_sdk/src/config.dart';
import 'package:ekyc_sdk/src/face_screen.dart';
import 'package:ekyc_sdk/src/flow.dart';
import 'package:ekyc_sdk/src/mrz_screen.dart';
import 'package:ekyc_sdk/src/nfc_screen.dart';

export 'package:ekyc_face_capture/ekyc_face_capture.dart';
export 'package:ekyc_mrz_scanner/ekyc_mrz_scanner.dart';
export 'package:ekyc_nfc_reader/ekyc_nfc_reader.dart';

export 'src/config.dart';
export 'src/controller.dart';
export 'src/face_screen.dart';
export 'src/flow.dart';
export 'src/mrz_screen.dart';
export 'src/nfc_screen.dart';
export 'src/scaffold.dart';
export 'src/strings.dart';
