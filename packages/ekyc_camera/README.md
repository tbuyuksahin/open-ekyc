# ekyc_camera

Camera code shared by `ekyc_mrz_scanner` and `ekyc_face_capture`.

* `MlKitCamera` opens the preferred lens and streams frames to ML Kit.
  * It processes one frame at a time, at the interval you choose.
  * It releases the camera while the app is in the background and reopens
    it on return.
  * `takePicture()` deletes the plugin's temporary file once the photo is
    read.
* `MlKitCameraView` shows the camera cover-fit with an overlay on top. It
  shows a loading view while the camera opens and a fallback when there is
  no camera or permission.
* `ScrimPainter` darkens everything outside a capture guide.
* `inputImageRotation` and `toInputImage` convert camera frames for ML Kit
  on Android (NV21) and iOS (BGRA).
* `package:ekyc_camera/testing.dart` provides `FakeCameraPlatform`, so
  camera code can be widget-tested without a device. It can emit frames,
  write photos and deny permission.
