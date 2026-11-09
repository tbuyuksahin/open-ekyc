# open-ekyc

[English](README.md) | **Türkçe**

Flutter ile mobil kimlik doğrulamanın (e-KYC) örnek uygulaması:
- MRZ'yi tarar,
- pasaport veya kimlik kartı çipini NFC ile okur,
- çip verisinin belgeyi veren devlet tarafından imzalandığını doğrular,
- selfie çeker.

Her şey herkese açık ICAO Doc 9303 standardından, mümkün olan her yerde saf
Dart ile yazıldı ve donanım olmadan sanal bir çiple test edildi.

| Paket | Ne yapar |
| --- | --- |
| [`icao_mrz`](packages/icao_mrz) | TD1/TD2/TD3 MRZ okuma ve doğrulama, gürültülü OCR çıktısından MRZ'yi kurtarma, BAC anahtarı üretme. Saf Dart, bağımlılıksız. |
| [`icao_mrtd`](packages/icao_mrtd) | BAC, 3DES güvenli mesajlaşma, LDS dosyaları (COM, DG1, DG2, DG11, SOD) ve **Passive Authentication** (RSA, RSA-PSS, açık parametreli eğriler dahil ECDSA). Taşıma katmanından bağımsız, saf Dart. |
| [`ekyc_sdk`](packages/ekyc_sdk) | **Hazır SDK.** `Ekyc.start(context)` tüm akışı çalıştırır; `Ekyc.scanMrz`, `Ekyc.readChip` ve `Ekyc.captureSelfie` tek adımı çalıştırır. Türkçe ve İngilizce metinler hazır gelir, tüm overlay'ler tek temadan ayarlanır. |
| [`ekyc_mrz_scanner`](packages/ekyc_mrz_scanner) | **MRZ adımı.** Kamerayla tarama (cihazda ML Kit, art arda iki aynı okuma şartı), ICAO ölçülerinde çizilen belge şablonlu overlay ve elle giriş formu. |
| [`ekyc_nfc_reader`](packages/ekyc_nfc_reader) | **NFC adımı.** `ChipReader` (BAC → DG1/DG2/DG11/SOD → Passive Authentication, kullanıcının anlayacağı hatalar, ilerleme), `flutter_nfc_kit` oturumu ve "belgeyi buraya tutun" animasyonlu overlay. |
| [`ekyc_face_capture`](packages/ekyc_face_capture) | **Selfie adımı.** Otomatik çeken kalite kontrolü, geri sayımlı oval overlay ve canlılık (liveness) arayüzü. |
| [`ekyc_camera`](packages/ekyc_camera) | Ortak kamera kodu. Uygulama yaşam döngüsüne uyan ML Kit kare akışı, ekranı dolduran önizleme, karartma katmanı ve testler için sahte kamera platformu. |
| [`ekyc_demo`](apps/ekyc_demo) | Örnek uygulama. SDK ekranlarının çevresine rıza, kontrol ve gönderim adımlarını ekler. Sanal örnek belgeyle çalışan bir demo modu da var. |

## Neden var?

Çoğu e-KYC kodu çipi okur, sonra sunucuya **ayrıştırılmış JSON** gönderir.
Bu, NFC'yi değerli kılan tek şeyi çöpe atar: belgeyi veren devletin
imzasını. Değiştirilmiş bir istemci istediği kimliği iddia edebilir.

Bu proje zinciri korur:

```text
çip ──BAC/SM──▶ ham DG1, DG2, DG11, SOD ──▶ cihazda Passive Authentication (bilgi amaçlı)
                                        └──▶ sunucu aynı ham dosyaları yeniden doğrular (asıl karar)
```

## Kendi uygulamanızda kullanın

```dart
final result = await Ekyc.start(context);          // MRZ → NFC → selfie
final key = await Ekyc.scanMrz(context);           // ya da tek adım
final document = await Ekyc.readChip(context, mrzKey: key!);
final selfie = await Ekyc.captureSelfie(context);
```

`EkycFlow` widget'ını kendi sayfanıza gömebilir, tek bir adım ekranını
kullanabilir ya da `MrzScanner` gibi yalın bir widget'ı kendi düzeninize
koyabilirsiniz. Tüm seviyeler ve seçenekler
[`ekyc_sdk` README](packages/ekyc_sdk/README.md) dosyasında.

## Deneyin

```sh
flutter pub get
cd apps/ekyc_demo
flutter run            # demo modu için "Örnek belgeyle dene"ye dokunun
```

Demo modu kamera, NFC veya kişisel veri gerektirmez. ICAO'nun hayali örnek
belgesini (Utopia) sanal bir çip üzerinde kullanır. Belge, geçici olarak
üretilen bir CSCA ile imzalanır.

## Overlay'leri özelleştirme

Her adımın kendi overlay'i ve stil sınıfı var. Ekranları kodu
çatallamadan kendi markanıza uydurabilirsiniz:

```dart
MrzScanner(style: MrzOverlayStyle(successColor: brand.success, cornerRadius: 16), ...)
NfcScanOverlay(status: status, style: NfcOverlayStyle(antennaAlignment: Alignment(0, -0.5)))
FaceCapture(style: FaceOverlayStyle(readyColor: brand.primary, widthFactor: 0.7), ...)
```

Overlay'ler her adımın durumuna göre değişir:

| Adım | Durumlar |
| --- | --- |
| MRZ | arıyor → doğruluyor → okundu |
| NFC | bekliyor → okuyor → başarılı veya hata |
| Selfie | boşta → düzeltiliyor → hazır |

Sistemde azaltılmış hareket açıksa animasyonlar durur. Tüm seçenekler her
paketin README'sinde.

## Kalite kontrolleri

* `very_good_analysis` ile `dart analyze --fatal-infos` çalışır. Tip
  kontrolleri katı modda (strict casts/inference/raw types). `avoid_print`
  uyarı değil, hata olarak işaretlenir.
* 183 test:
  * Her BAC ve güvenli mesajlaşma adımı için ICAO 9303-11 Ek D vektörleri.
  * Sanal çiple tam okuma: yanlış anahtar, kopan bağlantı, sahte MAC.
  * Gerçek imzalarla Passive Authentication: değiştirilmiş veri, yanlış
    CSCA, süresi dolmuş sertifika.
  * `flutter_nfc_kit` kanalı.
  * Sahte platformlar üzerinden kamera ve ML Kit.
  * Her overlay durumu.
  * Hareketli doğrulama ve iki çekim modu.
  * SDK giriş noktaları, Türkçe ve İngilizce.
  * Akış durum makinesi.
  * Demo akışının uçtan uca ekran testi.
* CI'da her paketin test kapsamı %90'ın altına düşemez. Şu an %96 ile %99,8
  arasında.
* CI release AAB ve iOS uygulaması derler, ikisine de
  [`preflight`](https://pub.dev/packages/preflight) uygular.

## Güvenlik ve gizlilik

Tehdit modeli için [SECURITY.md](SECURITY.md). Özetle:

* Kişisel veri yalnızca bellekte tutulur ve asla log'lanmaz. Bunu lint ve
  sadece olay kaydeden bir logger garanti eder. Veri gönderimde, iptalde
  veya uygulama kapanınca silinir.
* Android'de `FLAG_SECURE` açık ve yedekleme kapalı. iOS'ta uygulama
  değiştiricide içerik gizlenir. Demonun release sürümünde ağ izni yok.
* Açıkça belirtilen eksikler:
  * canlılık tespiti yok (yalnızca arayüzü var),
  * PACE yok,
  * sertifika iptal (CRL) kontrolü yok,
  * sunucu sahte.

## Lisans

MIT. ICAO örnek verileri hayalidir. Hiçbir işverene veya üçüncü taraf KYC
ürününe ait kod, görsel ya da API kullanılmamıştır.
