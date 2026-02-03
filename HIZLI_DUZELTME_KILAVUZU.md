# 🎯 HAFTALIK PLANLAMA - HIZLI DÜZELTME KILAVUZU

## 🚨 EN ACİL 3 DÜZELTME (30 Dakika)

### 1️⃣ Firestore Gün Limiti (5 dakika)
**Dosya:** `lib/data/repositories/ai_service.dart:214`

```dart
// ÖNCE:
Future<Set<String>> _loadRecentCompletedTaskIdsOnly(String userId, {int days = 365}) async {

// SONRA:
Future<Set<String>> _loadRecentCompletedTaskIdsOnly(String userId, {int days = 14}) async {
  // ... mevcut kod ...
  .orderBy('completedAt', descending: true)  // EKLE
  .limit(500)  // EKLE
```

**Kazanç:** ⚡ 4-6 saniye

---

### 2️⃣ Backend Token Limiti (3 dakika)
**Dosya:** `functions/src/ai.js:169`

```javascript
// ÖNCE:
if (requestType === 'weekly_plan') {
  effectiveMaxTokens = 50000;
}

// SONRA:
if (requestType === 'weekly_plan') {
  effectiveMaxTokens = 12000;
}
```

**Kazanç:** ⚡ 8-10 saniye

---

### 3️⃣ Frontend Timeout (5 dakika)
**Dosya:** `lib/data/repositories/ai_service.dart:344`

```dart
// generateGrandStrategy fonksiyonunda, return yapmadan önce:

return await _callGemini(prompt, expectJson: true, requestType: 'weekly_plan')
    .timeout(
      const Duration(seconds: 50),
      onTimeout: () => jsonEncode({
        'error': 'Plan oluşturma çok uzun sürdü. Lütfen "Rahat" tempoyu deneyin.'
      }),
    );
```

**Kazanç:** ⚡ Kullanıcı deneyimi %90 iyileşme

---

## 📊 BEKLENEN SONUÇ

| Metrik | Şimdi | Sonra | İyileşme |
|--------|-------|-------|----------|
| Ortalama Süre | 27s | 14s | **-48%** |
| Worst Case | 45s | 20s | **-56%** |
| Başarı Oranı | 85% | 95% | **+12%** |

**Toplam Geliştirme Süresi:** ~30 dakika  
**Deployment:** Backend + App güncellemesi gerekli

---

## 🔄 DEPLOY ADIMLARI

1. Backend değişikliği deploy et:
```bash
cd functions
npm run deploy
```

2. App'i yeni versiyonla yayınla:
```bash
flutter build apk --release
flutter build ios --release
```

3. Monitoring aktive et (opsiyonel):
- Firebase Console > Performance Monitoring
- Custom traces ekle: "weekly_plan_generation"

---

## ✅ TEST SENARYOSU

1. Haftalık plan oluştur
2. Süreyi ölç (beklenen: 12-16s)
3. Tekrar oluştur (cache beklenen: 10-12s)
4. Premium kullanıcı ile test et
5. Free kullanıcı ile test et

**Başarı Kriteri:** %90'dan fazla istek 15 saniyenin altında

---

## 🆘 ACİL DESTEK

Sorun çıkarsa geri al:

**Backend:**
```javascript
effectiveMaxTokens = 50000; // Eski haline
```

**Frontend:**
```dart
{int days = 365}  // Eski haline
// .timeout(...) satırını kaldır
```

---

**Not:** Bu hızlı düzeltmeler %50 iyileştirme sağlar. Tam %75 için detaylı rapora bakın.

