# ekyc_face_capture

The selfie step of an e-KYC flow in Flutter.

* `FaceCapture` uses the front camera with on-device ML Kit face
  detection. It takes the photo automatically once `FaceQualityGate` has
  seen several good frames in a row. The temporary photo file is deleted
  right after it is read.
* `FaceQualityGate` decides when a frame is good:
  * exactly one face,
  * large enough and centered,
  * looking straight at the camera,
  * eyes open.

  Each failing condition gives a hint, and `progress` reports the
  countdown to capture.
* `FaceOverlay` is an oval mask whose color follows the state (idle,
  adjusting, ready). While ready, a progress arc runs along the oval. It
  breathes gently while waiting for a face.
* `LivenessCheck` is an interface for a certified presentation attack
  detection provider. `NoLivenessCheck` reports `notPerformed`, honestly.

```dart
FaceCapture(
  onCaptured: (result) => match(result.image),
  unavailableBuilder: (_) => const Text('Camera not available'),
  hintText: (hint) => switch (hint) {
    FaceHint.noFace => 'Put your face in the oval',
    FaceHint.multipleFaces => 'Only one person, please',
    FaceHint.moveCloser => 'Move closer',
    FaceHint.center => 'Center your face',
    FaceHint.lookStraight => 'Look straight at the camera',
    FaceHint.openEyes => 'Keep your eyes open',
    FaceHint.holdStill => 'Hold still…',
  },
  gate: FaceQualityGate(requiredStableFrames: 5, minFaceWidthRatio: 0.35),
  style: const FaceOverlayStyle(
    idleColor: Colors.white,
    adjustColor: Colors.amber,
    readyColor: Colors.green,
    widthFactor: 0.72,
    aspectRatio: 1.3,
    showProgress: true,
    pulse: true,
  ),
)
```

## Movement challenges and capture modes

Ask for randomized head movements and expressions before the photo, and
choose whether the photo is taken automatically or with a shutter button:

```dart
FaceCapture(
  onCaptured: (result) => submit(result.image, result.challenges),
  unavailableBuilder: (_) => const Text('Camera not available'),
  challenges: const [
    FaceChallenge.turnLeft,
    FaceChallenge.turnRight,
    FaceChallenge.lookUp,
    FaceChallenge.lookDown,
    FaceChallenge.smile,
    FaceChallenge.blink,
  ],
  challengeCount: 3,                 // random 3 of the list
  randomOrder: true,                 // new order on every attempt
  challengeTimeout: const Duration(seconds: 8),
  maxAttempts: 3,
  onChallengesFailed: () => showRetry(),
  challengeText: (c) => texts[c]!,
  captureMode: FaceCaptureMode.manual, // or auto
)
```

The flow has three steps:

1. Frame the face.
2. Do each movement. An arrow or icon shows what to do, and dots show the
   progress.
3. Take a frontal, neutral photo for face matching.

A movement only counts if the user was *not* already in that pose when it
was asked, and holds it for a couple of frames. Thresholds and the yaw and
pitch signs are in `FaceChallengeThresholds`.

`FaceCaptureResult.challengesPassed` tells your backend which movements
were done. Report it as `LivenessOutcome.challengesPassed`, never as
`live`: active challenges stop printed photos and still screens, but a live
video of the user can pass them.

The quality gate is **not** liveness detection. A printed photo can pass
it. Use a certified liveness provider before you accept a selfie as proof
that a live person is present.
