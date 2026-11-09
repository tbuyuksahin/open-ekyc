import 'dart:ui';

import 'package:ekyc_face_capture/ekyc_face_capture.dart';
import 'package:ekyc_mrz_scanner/ekyc_mrz_scanner.dart';
import 'package:ekyc_nfc_reader/ekyc_nfc_reader.dart';
import 'package:flutter/foundation.dart';

/// Every text the SDK screens show.
///
/// English ([en]) and Turkish ([tr]) are built in; [of] picks one for a
/// locale. Override single texts with [copyWith], or pass all of them for
/// another language.
@immutable
class EkycStrings {
  /// Creates strings; every text defaults to English.
  const EkycStrings({
    this.cancel = 'Cancel',
    this.retry = 'Try again',
    this.checkDetails = 'Check document details',
    this.cameraUnavailable =
        'The camera is not available. Check the camera permission '
        'in Settings, or enter the details manually.',
    this.mrzTitle = 'Document details',
    this.mrzScanHint =
        'Place the two or three lines of letters and < signs at the'
        ' bottom of the photo page inside the frame.',
    this.mrzStatusSearching =
        'Line up the letters and < signs with the band at the '
        'bottom of the frame',
    this.mrzStatusConfirming = 'Reading… hold still',
    this.mrzStatusDetected = 'Got it',
    this.mrzScanCamera = 'Scan with camera',
    this.mrzEnterManually = 'Enter manually',
    this.mrzManualHint =
        'These three fields unlock the chip. Copy them exactly as '
        'printed.',
    this.mrzDocNumber = 'Document number',
    this.mrzDob = 'Date of birth',
    this.mrzDoe = 'Date of expiry',
    this.mrzDateHint = 'DD.MM.YYYY',
    this.mrzContinue = 'Continue',
    this.mrzInvalidNumber = 'Use 1-15 letters and digits, without spaces.',
    this.mrzInvalidDate = 'Enter a real date as DD.MM.YYYY.',
    this.mrzBirthInFuture = 'The date of birth cannot be in the future.',
    this.mrzExpiryBeforeBirth =
        'The expiry date must be after the date of birth.',
    this.nfcTitle = 'Read the chip',
    this.nfcInstructionPassport =
        'Passport: open it to the back cover and place the phone on'
        ' it.',
    this.nfcInstructionCard =
        'ID card: hold the card flat against the back of the phone,'
        ' next to the cameras.',
    this.nfcHold = 'Keep still until reading finishes.',
    this.nfcStepWaiting = 'Hold your document to the phone',
    this.nfcStepAuthenticating = 'Unlocking the chip',
    this.nfcStepReading = 'Reading the chip',
    this.nfcStepVerifying = "Checking the issuer's signature",
    this.nfcIllustration =
        'Hold the document flat over the antenna on the back of the'
        ' phone',
    this.nfcIosPrompt = 'Hold your document against the top of your iPhone.',
    this.nfcIosReading = 'Reading… keep still.',
    this.nfcIosDone = 'Chip read.',
    this.nfcIosFailed = 'Reading failed.',
    this.errorNfcNotSupported =
        'This device cannot read NFC chips. Please use a phone with'
        ' NFC.',
    this.errorNfcDisabled =
        'NFC is turned off. Turn it on in Settings and try again.',
    this.errorWrongMrz =
        'The chip did not accept the document details. Check the '
        'document number and the two dates.',
    this.errorTagLost =
        'The connection to the chip was lost. Hold the document '
        'still and try again.',
    this.errorTimeout =
        'No document was found. Move it slowly around the back of '
        'the phone.',
    this.errorCancelled = 'Reading was cancelled.',
    this.errorNotAuthentic =
        'The chip data failed the authenticity check. This document'
        ' cannot be used.',
    this.errorUnsupported =
        "This document's chip could not be read. It may be damaged "
        'or unsupported.',
    this.errorUnknown = 'Something went wrong. Please try again.',
    this.faceTitle = 'Take a selfie',
    this.faceInstruction =
        'Hold the phone at eye level in good light. The photo is '
        'taken automatically.',
    this.faceNoFace = 'Position your face in the oval',
    this.faceMultipleFaces = 'Only one person should be in view',
    this.faceMoveCloser = 'Move closer',
    this.faceCenter = 'Center your face in the oval',
    this.faceLookStraight = 'Look straight at the camera',
    this.faceOpenEyes = 'Keep your eyes open',
    this.faceHoldStill = 'Hold still…',
    this.faceChallengeTurnLeft = 'Slowly turn your head to the left',
    this.faceChallengeTurnRight = 'Slowly turn your head to the right',
    this.faceChallengeLookUp = 'Tilt your head up',
    this.faceChallengeLookDown = 'Tilt your head down',
    this.faceChallengeSmile = 'Smile',
    this.faceChallengeBlink = 'Blink',
    this.faceChallengeTimeout = "That took too long. Let's try again.",
    this.faceShutter = 'Take photo',
    this.faceModeAuto = 'Automatic',
    this.faceModeManual = 'Manual',
  });

  /// English.
  static const EkycStrings en = EkycStrings();

  /// Turkish.
  static const EkycStrings tr = EkycStrings(
    cancel: 'İptal',
    retry: 'Tekrar dene',
    checkDetails: 'Belge bilgilerini kontrol et',
    cameraUnavailable:
        "Kamera kullanılamıyor. Ayarlar'dan kamera iznini kontrol "
        'edin veya bilgileri elle girin.',
    mrzTitle: 'Belge bilgileri',
    mrzScanHint:
        'Fotoğraflı sayfanın altındaki harf ve < işaretlerinden '
        'oluşan iki veya üç satırı çerçeveye yerleştirin.',
    mrzStatusSearching:
        'Harf ve < işaretlerini çerçevenin altındaki şeride '
        'hizalayın',
    mrzStatusConfirming: 'Okunuyor… sabit tutun',
    mrzStatusDetected: 'Okundu',
    mrzScanCamera: 'Kamerayla tara',
    mrzEnterManually: 'Elle gir',
    mrzManualHint:
        'Bu üç bilgi çipin kilidini açar. Belgede yazdığı gibi '
        'girin.',
    mrzDocNumber: 'Belge numarası',
    mrzDob: 'Doğum tarihi',
    mrzDoe: 'Son geçerlilik tarihi',
    mrzDateHint: 'GG.AA.YYYY',
    mrzContinue: 'Devam',
    mrzInvalidNumber: 'Boşluksuz, 1-15 harf ve rakam girin.',
    mrzInvalidDate: 'GG.AA.YYYY biçiminde geçerli bir tarih girin.',
    mrzBirthInFuture: 'Doğum tarihi gelecekte olamaz.',
    mrzExpiryBeforeBirth:
        'Son geçerlilik tarihi doğum tarihinden sonra olmalı.',
    nfcTitle: 'Çipi okutun',
    nfcInstructionPassport:
        'Pasaport: arka kapağı açın ve telefonu üzerine koyun.',
    nfcInstructionCard:
        'Kimlik kartı: kartı telefonun arkasına, kameraların yanına'
        ' düz tutun.',
    nfcHold: 'Okuma bitene kadar hareket ettirmeyin.',
    nfcStepWaiting: 'Belgenizi telefona yaklaştırın',
    nfcStepAuthenticating: 'Çipin kilidi açılıyor',
    nfcStepReading: 'Çip okunuyor',
    nfcStepVerifying: 'Veren devletin imzası kontrol ediliyor',
    nfcIllustration: 'Belgeyi telefonun arkasındaki antenin üzerine düz tutun',
    nfcIosPrompt: "Belgenizi iPhone'unuzun üst kısmına tutun.",
    nfcIosReading: 'Okunuyor… hareket ettirmeyin.',
    nfcIosDone: 'Çip okundu.',
    nfcIosFailed: 'Okuma başarısız.',
    errorNfcNotSupported:
        "Bu cihaz NFC çipi okuyamıyor. Lütfen NFC'li bir telefon "
        'kullanın.',
    errorNfcDisabled: "NFC kapalı. Ayarlar'dan açıp tekrar deneyin.",
    errorWrongMrz:
        'Çip belge bilgilerini kabul etmedi. Belge numarasını ve '
        'iki tarihi kontrol edin.',
    errorTagLost: 'Çiple bağlantı koptu. Belgeyi sabit tutup tekrar deneyin.',
    errorTimeout: 'Belge bulunamadı. Telefonun arkasında yavaşça gezdirin.',
    errorCancelled: 'Okuma iptal edildi.',
    errorNotAuthentic:
        'Çip verisi orijinallik kontrolünden geçemedi. Bu belge '
        'kullanılamaz.',
    errorUnsupported:
        'Bu belgenin çipi okunamadı. Hasarlı veya desteklenmiyor '
        'olabilir.',
    errorUnknown: 'Bir sorun oluştu. Lütfen tekrar deneyin.',
    faceTitle: 'Selfie çekin',
    faceInstruction:
        'Telefonu göz hizasında, iyi ışıkta tutun. Fotoğraf '
        'otomatik çekilir.',
    faceNoFace: 'Yüzünüzü ovalin içine yerleştirin',
    faceMultipleFaces: 'Görüntüde yalnızca bir kişi olmalı',
    faceMoveCloser: 'Biraz yaklaşın',
    faceCenter: 'Yüzünüzü ovalin ortasına alın',
    faceLookStraight: 'Kameraya düz bakın',
    faceOpenEyes: 'Gözlerinizi açık tutun',
    faceHoldStill: 'Sabit durun…',
    faceChallengeTurnLeft: 'Başınızı yavaşça sola çevirin',
    faceChallengeTurnRight: 'Başınızı yavaşça sağa çevirin',
    faceChallengeLookUp: 'Başınızı yukarı kaldırın',
    faceChallengeLookDown: 'Başınızı aşağı indirin',
    faceChallengeSmile: 'Gülümseyin',
    faceChallengeBlink: 'Gözlerinizi kırpın',
    faceChallengeTimeout: 'Biraz uzun sürdü. Tekrar deneyelim.',
    faceShutter: 'Fotoğraf çek',
    faceModeAuto: 'Otomatik',
    faceModeManual: 'Manuel',
  );

  /// The built-in strings for [locale]; English when it is not Turkish.
  static EkycStrings of(Locale locale) => locale.languageCode == 'tr' ? tr : en;

  // Shared.

  /// Shared text: `cancel`.
  final String cancel;

  /// Shared text: `retry`.
  final String retry;

  /// Shared text: `checkDetails`.
  final String checkDetails;

  /// Shared text: `cameraUnavailable`.
  final String cameraUnavailable;

  // MRZ step.

  /// MRZ step text: `mrzTitle`.
  final String mrzTitle;

  /// MRZ step text: `mrzScanHint`.
  final String mrzScanHint;

  /// MRZ step text: `mrzStatusSearching`.
  final String mrzStatusSearching;

  /// MRZ step text: `mrzStatusConfirming`.
  final String mrzStatusConfirming;

  /// MRZ step text: `mrzStatusDetected`.
  final String mrzStatusDetected;

  /// MRZ step text: `mrzScanCamera`.
  final String mrzScanCamera;

  /// MRZ step text: `mrzEnterManually`.
  final String mrzEnterManually;

  /// MRZ step text: `mrzManualHint`.
  final String mrzManualHint;

  /// MRZ step text: `mrzDocNumber`.
  final String mrzDocNumber;

  /// MRZ step text: `mrzDob`.
  final String mrzDob;

  /// MRZ step text: `mrzDoe`.
  final String mrzDoe;

  /// MRZ step text: `mrzDateHint`.
  final String mrzDateHint;

  /// MRZ step text: `mrzContinue`.
  final String mrzContinue;

  /// MRZ step text: `mrzInvalidNumber`.
  final String mrzInvalidNumber;

  /// MRZ step text: `mrzInvalidDate`.
  final String mrzInvalidDate;

  /// MRZ step text: `mrzBirthInFuture`.
  final String mrzBirthInFuture;

  /// MRZ step text: `mrzExpiryBeforeBirth`.
  final String mrzExpiryBeforeBirth;

  // NFC step.

  /// NFC step text: `nfcTitle`.
  final String nfcTitle;

  /// NFC step text: `nfcInstructionPassport`.
  final String nfcInstructionPassport;

  /// NFC step text: `nfcInstructionCard`.
  final String nfcInstructionCard;

  /// NFC step text: `nfcHold`.
  final String nfcHold;

  /// NFC step text: `nfcStepWaiting`.
  final String nfcStepWaiting;

  /// NFC step text: `nfcStepAuthenticating`.
  final String nfcStepAuthenticating;

  /// NFC step text: `nfcStepReading`.
  final String nfcStepReading;

  /// NFC step text: `nfcStepVerifying`.
  final String nfcStepVerifying;

  /// NFC step text: `nfcIllustration`.
  final String nfcIllustration;

  /// NFC step text: `nfcIosPrompt`.
  final String nfcIosPrompt;

  /// NFC step text: `nfcIosReading`.
  final String nfcIosReading;

  /// NFC step text: `nfcIosDone`.
  final String nfcIosDone;

  /// NFC step text: `nfcIosFailed`.
  final String nfcIosFailed;

  // Chip read errors.

  /// Chip read errors text: `errorNfcNotSupported`.
  final String errorNfcNotSupported;

  /// Chip read errors text: `errorNfcDisabled`.
  final String errorNfcDisabled;

  /// Chip read errors text: `errorWrongMrz`.
  final String errorWrongMrz;

  /// Chip read errors text: `errorTagLost`.
  final String errorTagLost;

  /// Chip read errors text: `errorTimeout`.
  final String errorTimeout;

  /// Chip read errors text: `errorCancelled`.
  final String errorCancelled;

  /// Chip read errors text: `errorNotAuthentic`.
  final String errorNotAuthentic;

  /// Chip read errors text: `errorUnsupported`.
  final String errorUnsupported;

  /// Chip read errors text: `errorUnknown`.
  final String errorUnknown;

  // Selfie step.

  /// Selfie step text: `faceTitle`.
  final String faceTitle;

  /// Selfie step text: `faceInstruction`.
  final String faceInstruction;

  /// Selfie step text: `faceNoFace`.
  final String faceNoFace;

  /// Selfie step text: `faceMultipleFaces`.
  final String faceMultipleFaces;

  /// Selfie step text: `faceMoveCloser`.
  final String faceMoveCloser;

  /// Selfie step text: `faceCenter`.
  final String faceCenter;

  /// Selfie step text: `faceLookStraight`.
  final String faceLookStraight;

  /// Selfie step text: `faceOpenEyes`.
  final String faceOpenEyes;

  /// Selfie step text: `faceHoldStill`.
  final String faceHoldStill;

  /// Selfie step text: `faceChallengeTurnLeft`.
  final String faceChallengeTurnLeft;

  /// Selfie step text: `faceChallengeTurnRight`.
  final String faceChallengeTurnRight;

  /// Selfie step text: `faceChallengeLookUp`.
  final String faceChallengeLookUp;

  /// Selfie step text: `faceChallengeLookDown`.
  final String faceChallengeLookDown;

  /// Selfie step text: `faceChallengeSmile`.
  final String faceChallengeSmile;

  /// Selfie step text: `faceChallengeBlink`.
  final String faceChallengeBlink;

  /// Selfie step text: `faceChallengeTimeout`.
  final String faceChallengeTimeout;

  /// Selfie step text: `faceShutter`.
  final String faceShutter;

  /// Selfie step text: `faceModeAuto`.
  final String faceModeAuto;

  /// Selfie step text: `faceModeManual`.
  final String faceModeManual;

  /// The message for a chip read [error].
  String error(ChipReadError error) => switch (error) {
    ChipReadError.nfcNotSupported => errorNfcNotSupported,
    ChipReadError.nfcDisabled => errorNfcDisabled,
    ChipReadError.wrongMrz => errorWrongMrz,
    ChipReadError.tagLost => errorTagLost,
    ChipReadError.timeout => errorTimeout,
    ChipReadError.cancelled => errorCancelled,
    ChipReadError.documentNotAuthentic => errorNotAuthentic,
    ChipReadError.unsupportedDocument => errorUnsupported,
    ChipReadError.unknown => errorUnknown,
  };

  /// The label for an MRZ scan [status].
  String mrzStatus(MrzScanStatus status) => switch (status) {
    MrzScanStatus.searching => mrzStatusSearching,
    MrzScanStatus.confirming => mrzStatusConfirming,
    MrzScanStatus.detected => mrzStatusDetected,
  };

  /// The label for a chip read [step].
  String nfcStep(ChipReadStep step) => switch (step) {
    ChipReadStep.waitingForCard => nfcStepWaiting,
    ChipReadStep.authenticating => nfcStepAuthenticating,
    ChipReadStep.reading => nfcStepReading,
    ChipReadStep.verifying => nfcStepVerifying,
  };

  /// The guidance for a selfie framing [hint].
  String faceHint(FaceHint hint) => switch (hint) {
    FaceHint.noFace => faceNoFace,
    FaceHint.multipleFaces => faceMultipleFaces,
    FaceHint.moveCloser => faceMoveCloser,
    FaceHint.center => faceCenter,
    FaceHint.lookStraight => faceLookStraight,
    FaceHint.openEyes => faceOpenEyes,
    FaceHint.holdStill => faceHoldStill,
  };

  /// The instruction for a movement [challenge].
  String faceChallenge(FaceChallenge challenge) => switch (challenge) {
    FaceChallenge.turnLeft => faceChallengeTurnLeft,
    FaceChallenge.turnRight => faceChallengeTurnRight,
    FaceChallenge.lookUp => faceChallengeLookUp,
    FaceChallenge.lookDown => faceChallengeLookDown,
    FaceChallenge.smile => faceChallengeSmile,
    FaceChallenge.blink => faceChallengeBlink,
  };

  /// Labels for the manual MRZ form.
  MrzFormLabels get formLabels => MrzFormLabels(
    instructions: mrzManualHint,
    documentNumber: mrzDocNumber,
    dateOfBirth: mrzDob,
    dateOfExpiry: mrzDoe,
    dateHint: mrzDateHint,
    invalidNumber: mrzInvalidNumber,
    invalidDate: mrzInvalidDate,
    birthInFuture: mrzBirthInFuture,
    expiryBeforeBirth: mrzExpiryBeforeBirth,
    submit: mrzContinue,
    scanWithCamera: mrzScanCamera,
  );

  /// Texts for the iOS NFC sheet.
  ChipReadMessages get chipMessages => ChipReadMessages(
    prompt: nfcIosPrompt,
    reading: nfcIosReading,
    done: nfcIosDone,
    failed: nfcIosFailed,
  );

  /// A copy with the given texts replaced.
  EkycStrings copyWith({
    String? cancel,
    String? retry,
    String? checkDetails,
    String? cameraUnavailable,
    String? mrzTitle,
    String? mrzScanHint,
    String? mrzStatusSearching,
    String? mrzStatusConfirming,
    String? mrzStatusDetected,
    String? mrzScanCamera,
    String? mrzEnterManually,
    String? mrzManualHint,
    String? mrzDocNumber,
    String? mrzDob,
    String? mrzDoe,
    String? mrzDateHint,
    String? mrzContinue,
    String? mrzInvalidNumber,
    String? mrzInvalidDate,
    String? mrzBirthInFuture,
    String? mrzExpiryBeforeBirth,
    String? nfcTitle,
    String? nfcInstructionPassport,
    String? nfcInstructionCard,
    String? nfcHold,
    String? nfcStepWaiting,
    String? nfcStepAuthenticating,
    String? nfcStepReading,
    String? nfcStepVerifying,
    String? nfcIllustration,
    String? nfcIosPrompt,
    String? nfcIosReading,
    String? nfcIosDone,
    String? nfcIosFailed,
    String? errorNfcNotSupported,
    String? errorNfcDisabled,
    String? errorWrongMrz,
    String? errorTagLost,
    String? errorTimeout,
    String? errorCancelled,
    String? errorNotAuthentic,
    String? errorUnsupported,
    String? errorUnknown,
    String? faceTitle,
    String? faceInstruction,
    String? faceNoFace,
    String? faceMultipleFaces,
    String? faceMoveCloser,
    String? faceCenter,
    String? faceLookStraight,
    String? faceOpenEyes,
    String? faceHoldStill,
    String? faceChallengeTurnLeft,
    String? faceChallengeTurnRight,
    String? faceChallengeLookUp,
    String? faceChallengeLookDown,
    String? faceChallengeSmile,
    String? faceChallengeBlink,
    String? faceChallengeTimeout,
    String? faceShutter,
    String? faceModeAuto,
    String? faceModeManual,
  }) => EkycStrings(
    cancel: cancel ?? this.cancel,
    retry: retry ?? this.retry,
    checkDetails: checkDetails ?? this.checkDetails,
    cameraUnavailable: cameraUnavailable ?? this.cameraUnavailable,
    mrzTitle: mrzTitle ?? this.mrzTitle,
    mrzScanHint: mrzScanHint ?? this.mrzScanHint,
    mrzStatusSearching: mrzStatusSearching ?? this.mrzStatusSearching,
    mrzStatusConfirming: mrzStatusConfirming ?? this.mrzStatusConfirming,
    mrzStatusDetected: mrzStatusDetected ?? this.mrzStatusDetected,
    mrzScanCamera: mrzScanCamera ?? this.mrzScanCamera,
    mrzEnterManually: mrzEnterManually ?? this.mrzEnterManually,
    mrzManualHint: mrzManualHint ?? this.mrzManualHint,
    mrzDocNumber: mrzDocNumber ?? this.mrzDocNumber,
    mrzDob: mrzDob ?? this.mrzDob,
    mrzDoe: mrzDoe ?? this.mrzDoe,
    mrzDateHint: mrzDateHint ?? this.mrzDateHint,
    mrzContinue: mrzContinue ?? this.mrzContinue,
    mrzInvalidNumber: mrzInvalidNumber ?? this.mrzInvalidNumber,
    mrzInvalidDate: mrzInvalidDate ?? this.mrzInvalidDate,
    mrzBirthInFuture: mrzBirthInFuture ?? this.mrzBirthInFuture,
    mrzExpiryBeforeBirth: mrzExpiryBeforeBirth ?? this.mrzExpiryBeforeBirth,
    nfcTitle: nfcTitle ?? this.nfcTitle,
    nfcInstructionPassport:
        nfcInstructionPassport ?? this.nfcInstructionPassport,
    nfcInstructionCard: nfcInstructionCard ?? this.nfcInstructionCard,
    nfcHold: nfcHold ?? this.nfcHold,
    nfcStepWaiting: nfcStepWaiting ?? this.nfcStepWaiting,
    nfcStepAuthenticating: nfcStepAuthenticating ?? this.nfcStepAuthenticating,
    nfcStepReading: nfcStepReading ?? this.nfcStepReading,
    nfcStepVerifying: nfcStepVerifying ?? this.nfcStepVerifying,
    nfcIllustration: nfcIllustration ?? this.nfcIllustration,
    nfcIosPrompt: nfcIosPrompt ?? this.nfcIosPrompt,
    nfcIosReading: nfcIosReading ?? this.nfcIosReading,
    nfcIosDone: nfcIosDone ?? this.nfcIosDone,
    nfcIosFailed: nfcIosFailed ?? this.nfcIosFailed,
    errorNfcNotSupported: errorNfcNotSupported ?? this.errorNfcNotSupported,
    errorNfcDisabled: errorNfcDisabled ?? this.errorNfcDisabled,
    errorWrongMrz: errorWrongMrz ?? this.errorWrongMrz,
    errorTagLost: errorTagLost ?? this.errorTagLost,
    errorTimeout: errorTimeout ?? this.errorTimeout,
    errorCancelled: errorCancelled ?? this.errorCancelled,
    errorNotAuthentic: errorNotAuthentic ?? this.errorNotAuthentic,
    errorUnsupported: errorUnsupported ?? this.errorUnsupported,
    errorUnknown: errorUnknown ?? this.errorUnknown,
    faceTitle: faceTitle ?? this.faceTitle,
    faceInstruction: faceInstruction ?? this.faceInstruction,
    faceNoFace: faceNoFace ?? this.faceNoFace,
    faceMultipleFaces: faceMultipleFaces ?? this.faceMultipleFaces,
    faceMoveCloser: faceMoveCloser ?? this.faceMoveCloser,
    faceCenter: faceCenter ?? this.faceCenter,
    faceLookStraight: faceLookStraight ?? this.faceLookStraight,
    faceOpenEyes: faceOpenEyes ?? this.faceOpenEyes,
    faceHoldStill: faceHoldStill ?? this.faceHoldStill,
    faceChallengeTurnLeft: faceChallengeTurnLeft ?? this.faceChallengeTurnLeft,
    faceChallengeTurnRight:
        faceChallengeTurnRight ?? this.faceChallengeTurnRight,
    faceChallengeLookUp: faceChallengeLookUp ?? this.faceChallengeLookUp,
    faceChallengeLookDown: faceChallengeLookDown ?? this.faceChallengeLookDown,
    faceChallengeSmile: faceChallengeSmile ?? this.faceChallengeSmile,
    faceChallengeBlink: faceChallengeBlink ?? this.faceChallengeBlink,
    faceChallengeTimeout: faceChallengeTimeout ?? this.faceChallengeTimeout,
    faceShutter: faceShutter ?? this.faceShutter,
    faceModeAuto: faceModeAuto ?? this.faceModeAuto,
    faceModeManual: faceModeManual ?? this.faceModeManual,
  );
}
