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
| [`ekyc_demo`](apps/ekyc_demo) | Flutter uygulaması. Akış: rıza → MRZ (kamera veya elle) → NFC → selfie → kontrol → gönderim. Tüm akışı sanal bir örnek belgeyle çalıştıran demo modu da var. |

## Neden var?

Çoğu e-KYC kodu çipi okur, sonra sunucuya **ayrıştırılmış JSON** gönderir.
Bu, NFC'yi değerli kılan tek şeyi çöpe atar: belgeyi veren devletin
imzasını. Değiştirilmiş bir istemci istediği kimliği iddia edebilir.

Bu proje zinciri korur:

```text
çip ──BAC/SM──▶ ham DG1, DG2, DG11, SOD ──▶ cihazda Passive Authentication (bilgi amaçlı)
                                        └──▶ sunucu aynı ham dosyaları yeniden doğrular (asıl karar)
```

## Deneyin

```sh
flutter pub get
cd apps/ekyc_demo
flutter run            # demo modu için "Örnek belgeyle dene"ye dokunun
```

Demo modu kamera, NFC veya kişisel veri gerektirmez. ICAO'nun hayali örnek
belgesini (Utopia) sanal bir çip üzerinde kullanır. Belge, geçici olarak
üretilen bir CSCA ile imzalanır.

## Kalite kontrolleri

* `very_good_analysis` ile `dart analyze --fatal-infos` çalışır. Tip
  kontrolleri katı modda (strict casts/inference/raw types). `avoid_print`
  uyarı değil, hata olarak işaretlenir.
* 100 test:
  * Her BAC ve güvenli mesajlaşma adımı için ICAO 9303-11 Ek D vektörleri.
  * Sanal çiple tam okuma: yanlış anahtar, kopan bağlantı, sahte MAC.
  * Gerçek imzalarla Passive Authentication: değiştirilmiş veri, yanlış
    CSCA, süresi dolmuş sertifika.
  * Akış durum makinesi.
  * Demo akışının uçtan uca ekran testi.
* CI'da test kapsamı %90'ın altına düşemez. Şu an %96 ve %95.
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
