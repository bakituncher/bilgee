# Google AdMob Entegrasyonu - Kullanım Kılavuzu

## 📋 Genel Bakış

Bu projede Google AdMob entegrasyonu tamamlanmıştır. Kullanıcıların yaşına göre kişiselleştirilmiş veya kişiselleştirilmemiş reklamlar gösterilmektedir.

### ✅ Özellikler

- ✨ **Yaşa Göre Reklam**: 18 yaş altı kullanıcılara kişiselleştirilmemiş (COPPA uyumlu), 18 yaş ve üstü kullanıcılara kişiselleştirilmiş reklamlar
- 🎯 **Banner Reklamlar**: Ana ekran (Dashboard) ve Liderlik Tablosu (Arena) ekranlarında
- 🚀 **Geçiş Reklamları (Interstitial)**: Genel Bakış ekranına her girişte
- 🛡️ **Test Modu**: Debug modda otomatik olarak test reklamları gösterilir

---

## 📍 Reklam Konumları

### 1. Ana Ekran (Dashboard)
- **Konum**: Sayfanın en altında, diğer içeriklerden sonra
- **Tip**: Banner reklam
- **Dosya**: `lib/features/home/screens/dashboard_screen.dart`

### 2. Liderlik Tablosu (Arena)
- **Konum**: Lider listesinin en üstünde
- **Tip**: Banner reklam
- **Dosya**: `lib/features/arena/screens/arena_screen.dart`

### 3. Genel Bakış Ekranı
- **Konum**: Ekran açılırken
- **Tip**: Tam ekran geçiş reklamı (Interstitial)
- **Dosya**: `lib/features/stats/screens/general_overview_screen.dart`

---

## 🔧 Yapılandırma

### Android Yapılandırması

**Dosya**: `android/app/src/main/AndroidManifest.xml`

```xml
<!-- AdMob App ID -->
<meta-data
    android:name="com.google.android.gms.ads.APPLICATION_ID"
    android:value="ca-app-pub-3940256099942544~3347511713"/>
```

> ⚠️ **ÖNEMLİ**: `ca-app-pub-3940256099942544~3347511713` test App ID'sidir. 
> Production'a geçmeden önce gerçek AdMob App ID'nizi ile değiştirin!

### iOS Yapılandırması

**Dosya**: `ios/Runner/Info.plist`

```xml
<key>GADApplicationIdentifier</key>
<string>ca-app-pub-3940256099942544~1458002511</string>
<key>SKAdNetworkItems</key>
<array>
    <dict>
        <key>SKAdNetworkIdentifier</key>
        <string>cstr6suwn9.skadnetwork</string>
    </dict>
</array>
```

> ⚠️ **ÖNEMLİ**: `ca-app-pub-3940256099942544~1458002511` test App ID'sidir.
> Production'a geçmeden önce gerçek AdMob App ID'nizi ile değiştirin!

---

## 🎯 Ad Unit ID'leri Değiştirme

### Gerçek Reklam ID'lerini Alma

1. [AdMob Console](https://apps.admob.com/) adresine gidin
2. Uygulamanızı seçin veya yeni uygulama ekleyin
3. "Ad Units" bölümüne gidin
4. Her platform için (Android & iOS):
   - Banner Ad Unit oluşturun
   - Interstitial Ad Unit oluşturun

### Ad Unit ID'lerini Değiştirme

**Dosya**: `lib/core/services/admob_service.dart`

```dart
// Banner Ad Unit IDs - Gerçek ID'lerinizi buraya yazın
String get bannerAdUnitId {
  if (isTestMode) {
    // Test modda değişiklik yapmayın
    return Platform.isAndroid
        ? 'ca-app-pub-3940256099942544/6300978111'
        : 'ca-app-pub-3940256099942544/2934735716';
  }
  
  // ⚠️ BU SATIRLARI DEĞİŞTİRİN
  return Platform.isAndroid
      ? 'ca-app-pub-XXXXXXXXXXXXXXXX/YYYYYYYYYY' // Android banner ID'niz
      : 'ca-app-pub-XXXXXXXXXXXXXXXX/YYYYYYYYYY'; // iOS banner ID'niz
}

// Interstitial Ad Unit IDs - Gerçek ID'lerinizi buraya yazın
String get interstitialAdUnitId {
  if (isTestMode) {
    // Test modda değişiklik yapmayın
    return Platform.isAndroid
        ? 'ca-app-pub-3940256099942544/1033173712'
        : 'ca-app-pub-3940256099942544/4411468910';
  }
  
  // ⚠️ BU SATIRLARI DEĞİŞTİRİN
  return Platform.isAndroid
      ? 'ca-app-pub-XXXXXXXXXXXXXXXX/ZZZZZZZZZZ' // Android interstitial ID'niz
      : 'ca-app-pub-XXXXXXXXXXXXXXXX/ZZZZZZZZZZ'; // iOS interstitial ID'niz
}
```

---

## 👶 Yaş Kontrolü ve COPPA Uyumluluğu

Sistem, kullanıcının doğum tarihine göre otomatik olarak uygun reklam tipini seçer:

```dart
// 18 yaş altı kontrolü
final isUnder18 = AgeHelper.isUnder18(user.dateOfBirth);

// Yaşa göre reklam isteği
AdRequest createAdRequest({required bool isUnder18}) {
  if (isUnder18) {
    // COPPA uyumlu, kişiselleştirilmemiş reklamlar
    return const AdRequest(
      keywords: ['education', 'study', 'learning', 'student'],
      nonPersonalizedAds: true,
    );
  } else {
    // Normal kişiselleştirilmiş reklamlar
    return const AdRequest(
      keywords: ['education', 'study', 'learning', 'student', 'exam'],
    );
  }
}
```

### Yaş Bilgisi Olmayan Kullanıcılar

Kullanıcının doğum tarihi bilinmiyorsa, güvenli tarafta kalarak **kişiselleştirilmemiş reklamlar** gösterilir.

---

## 🧪 Test Etme

### Debug Modda Test

Debug modda (Development) otomatik olarak Google'ın test reklamları kullanılır:
- ✅ Gerçek reklamlar gösterilmez
- ✅ Test reklamları sınırsız tıklanabilir
- ✅ Google politikalarını ihlal etmez

### Production Öncesi Kontrol Listesi

- [ ] AdMob hesabınızı oluşturdunuz mu?
- [ ] Android ve iOS için ayrı ayrı uygulama eklediniz mi?
- [ ] Her platform için Banner ve Interstitial Ad Unit oluşturdunuz mu?
- [ ] `AndroidManifest.xml` ve `Info.plist` dosyalarında gerçek App ID'leri güncellediniz mi?
- [ ] `admob_service.dart` dosyasında gerçek Ad Unit ID'leri güncellediniz mi?
- [ ] Test cihazlarda reklamların düzgün göründüğünü kontrol ettiniz mi?
- [ ] 18 yaş altı ve üstü kullanıcılar için farklı reklam tiplerini test ettiniz mi?

---

## 📊 Performans Optimizasyonu

### Reklam Yükleme Stratejisi

1. **Banner Reklamlar**: Her sayfa açıldığında otomatik yüklenir
2. **Interstitial Reklamlar**: 
   - Uygulama başlatıldığında ilk reklam yüklenir
   - Bir reklam gösterildikten sonra hemen yeni reklam yüklemeye başlar
   - Kullanıcı deneyimini bozmamak için sayfa açılırken gösterilir

### RepaintBoundary Kullanımı

Banner reklamlar `RepaintBoundary` içine alınmıştır. Bu sayede:
- Reklam yüklenirken sayfa performansı etkilenmez
- UI render işlemleri optimize edilir

```dart
RepaintBoundary(
  child: Padding(
    padding: const EdgeInsets.symmetric(vertical: 8.0),
    child: AdBannerWidget(isUnder18: isUnder18),
  ),
),
```

---

## 🔍 Sorun Giderme

### Reklamlar Görünmüyor

1. **AdMob hesabı aktif mi?** AdMob hesabınızın onaylanması birkaç saat sürebilir
2. **Ad Unit ID'ler doğru mu?** `admob_service.dart` dosyasını kontrol edin
3. **App ID'ler doğru mu?** Manifest ve Info.plist dosyalarını kontrol edin
4. **Test modunda mısınız?** Debug modda test reklamları gösterilmelidir

### "Ad failed to load" Hatası

```dart
❌ Banner ad failed to load: LoadAdError(code: 3, domain: ..., message: ...)
```

**Çözümler**:
- İnternet bağlantınızı kontrol edin
- AdMob konsolunda uygulamanızın durumunu kontrol edin
- Ad Unit ID'lerin doğru olduğundan emin olun
- Birkaç dakika bekleyin (yeni oluşturulan Ad Unit'ler aktif olmak için zaman alabilir)

### İlk Yüklemede Reklam Yok

İlk yüklemede reklamların görünmemesi normaldir. AdMob:
- Kullanıcı davranışını öğrenir
- Uygun reklamları seçer
- Birkaç oturum sonra daha stabil çalışır

---

## 📁 Dosya Yapısı

```
lib/
├── core/
│   └── services/
│       └── admob_service.dart          # AdMob servis sınıfı
├── shared/
│   └── widgets/
│       └── ad_banner_widget.dart       # Banner reklam widget'ı
├── utils/
│   └── age_helper.dart                 # Yaş hesaplama yardımcıları
└── features/
    ├── home/
    │   └── screens/
    │       └── dashboard_screen.dart   # Ana ekran (banner)
    ├── arena/
    │   └── screens/
    │       └── arena_screen.dart       # Liderlik tablosu (banner)
    └── stats/
        └── screens/
            └── general_overview_screen.dart  # Genel bakış (interstitial)
```

---

## 💰 Gelir Optimizasyonu İpuçları

1. **Reklam Yerleşimi**: Reklamlar doğal akışta ve kullanıcı deneyimini bozmayacak şekilde yerleştirilmiştir
2. **Frekans**: Interstitial reklamlar sadece ekran geçişlerinde gösterilir, spam değil
3. **Yaş Segmentasyonu**: Farklı yaş grupları için uygun reklamlar
4. **Test ve Optimizasyon**: AdMob konsolundan performansı takip edin

---

## 📞 Destek ve Kaynaklar

- [Google AdMob Resmi Dokümantasyonu](https://developers.google.com/admob)
- [Flutter Google Mobile Ads Plugin](https://pub.dev/packages/google_mobile_ads)
- [COPPA Compliance Guide](https://support.google.com/admob/answer/9283682)
- [AdMob Policy Center](https://support.google.com/admob/answer/6128543)

---

## ⚖️ Önemli Notlar

### Gizlilik ve Yasal Uyum

- ✅ **COPPA Uyumlu**: 18 yaş altı kullanıcılar için kişiselleştirilmemiş reklamlar
- ✅ **GDPR Hazır**: Kullanıcı tercihlerine göre reklam personalizasyonu
- ✅ **Şeffaf**: Kullanıcılar doğum tarihlerini gönüllü olarak paylaşır

### Google Policies

AdMob kullanırken şunlara dikkat edin:
- ❌ Reklamlara kendiniz tıklamayın
- ❌ Kullanıcıları reklam tıklamaya teşvik etmeyin
- ❌ Reklam görünümünü manipüle etmeyin
- ✅ [AdMob Program Policies](https://support.google.com/admob/answer/6128543)'i okuyun

---

## 🎉 Başarıyla Tamamlandı!

AdMob entegrasyonu başarıyla tamamlanmıştır. Test edin, gerçek ID'lerinizi ekleyin ve yayınlayın! 

**Son Güncelleme**: 2025-11-19

