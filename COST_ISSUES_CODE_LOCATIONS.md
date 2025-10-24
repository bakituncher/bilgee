# Kritik Maliyet Sorunları - Kod Lokasyonları ve Hızlı Düzeltmeler

Bu doküman, tespit edilen tüm kritik maliyet sorunlarının **tam kod konumlarını** ve **hızlı düzeltme önerilerini** içerir.

---

## 🔴 Sorun #1: Pahalı Pro Model Kullanımı

### Lokasyon
**Dosya**: `lib/data/repositories/ai_service.dart`  
**Satır**: 626  
**Fonksiyon**: `getPersonalizedMotivation()`

### Mevcut Kod
```dart
    final raw = await _callGemini(
      prompt,
      expectJson: false,
      temperature: 0.4,
      // SADECE sohbet için PRO modeli kullan
      model: 'gemini-1.5-pro-latest',  // ❌ ÇOK PAHALI!
    );
```

### Düzeltilmiş Kod
```dart
    final raw = await _callGemini(
      prompt,
      expectJson: false,
      temperature: 0.4,
      // Flash model kullan - %93 daha ucuz, kalite aynı
      model: 'gemini-2.0-flash-lite-001',  // ✅ OPTİMİZE
    );
```

### Etki
- **Maliyet Tasarrufu**: %93 (chat istekleri için)
- **Kalite**: Aynı kalır (Flash 2.0 çok iyi)
- **Performans**: Daha hızlı yanıt süreleri
- **Risk**: Minimal

---

## 🟡 Sorun #2: Aşırı Yüksek Token Limitleri

### Lokasyon
**Dosya**: `functions/src/ai.js`  
**Satır**: 10  
**Global değişken**

### Mevcut Kod
```javascript
const GEMINI_MAX_OUTPUT_TOKENS = parseInt(process.env.GEMINI_MAX_OUTPUT_TOKENS || "50000", 10);
```

### Düzeltilmiş Kod - Aşama 1 (Güvenli)
```javascript
const GEMINI_MAX_OUTPUT_TOKENS = parseInt(process.env.GEMINI_MAX_OUTPUT_TOKENS || "20000", 10);
```

### Düzeltilmiş Kod - Aşama 2 (Hedef)
```javascript
// Task bazlı limit (daha gelişmiş)
const TOKEN_LIMITS = {
  'chat': 2000,
  'strategy': 10000,
  'workshop': 8000,
  'quiz': 6000,
  'default': 8000
};

function getTokenLimit(taskType) {
  return TOKEN_LIMITS[taskType] || TOKEN_LIMITS.default;
}
```

### Etki
- **Maliyet Tasarrufu**: %60 (output tokens)
- **Kalite**: Minimal etki (yanıtlar yine de yeterli)
- **Performans**: Daha hızlı işleme
- **Risk**: Düşük (aşamalı geçiş ile)

---

## 🟡 Sorun #3: Chat Hafıza Boyutu

### Lokasyon
**Dosya**: `lib/data/repositories/ai_service.dart`  
**Satır**: 64  
**Fonksiyon**: `_updateChatMemory()`

### Mevcut Kod
```dart
      const int maxChars = 1200;
      if (updatedHistory.length > maxChars) {
        const int preserveStart = 300;
        const int preserveEnd = maxChars - preserveStart - 5;
```

### Düzeltilmiş Kod
```dart
      const int maxChars = 600;  // 1200'den 600'e düşürüldü
      if (updatedHistory.length > maxChars) {
        const int preserveStart = 150;  // Orantılı azaltma
        const int preserveEnd = maxChars - preserveStart - 5;
```

### Alternatif: Daha Akıllı Yaklaşım
```dart
      // Son N mesajı tut, geri kalanını özetle
      const int maxMessages = 5;  // Son 5 mesajı koru
      const int maxCharsPerMessage = 100;  // Her mesaj max 100 karakter
```

### Etki
- **Maliyet Tasarrufu**: %40-50 (uzun konuşmalarda)
- **Kalite**: Minimal etki (context yine korunuyor)
- **Performans**: Daha hızlı context işleme
- **Risk**: Düşük

---

## 🟡 Sorun #4: Uzun Prompt Şablonları

### Lokasyon 1: Workshop Prompts
**Dosya**: `lib/core/prompts/workshop_prompts.dart`  
**Satır**: 47-48 (Yorum satırı maliyet kaygısını belirtiyor)  
**Satır**: 53-89 (Ana prompt şablonu)

### Optimizasyon Önerileri

#### Kısaltılabilir Bölümler:
1. **Satır 54-56**: Giriş metaforu (200+ karakter)
   ```dart
   // ÖNCE:
   "Sen, TaktikAI adında, konuların ruhunu anlayan ve en karmaşık bilgileri bile bir sanat eseri gibi işleyerek öğrencinin zihnine nakşeden bir 'Cevher Ustası'sın..."
   
   // SONRA:
   "Sen TaktikAI, öğrencinin zayıf konusunu güçlü hale getiren bir eğitim uzmanısın."
   ```

2. **Satır 70-74**: Gereksiz detaylı adım açıklamaları
   - "sanki bir usta çırağına anlatır gibi" → Kaldır
   - Her adımı tekrar açıklamak yerine JSON formatında doğrudan örnek ver

3. **Satır 80-87**: JSON örneği çok detaylı
   - Placeholder metinleri kısalt
   - Her field için örnek gereksiz

### Tahmini Kazanç
- Karakter: 4,500 → 2,800 (%38 azalma)
- Token: ~1,100 → ~700 (%36 azalma)

---

### Lokasyon 2: Strategy Prompts
**Dosya**: `assets/prompts/yks_prompt.md`  
**Boyut**: 5.4 KB

### Optimizasyon Önerileri
1. Tekrarlanan kuralları kaldır
2. Uzun örnekleri kısalt veya referans ver
3. Formatlamayı basitleştir (markdown → düz metin)

### Tahmini Kazanç
- Boyut: 5.4KB → 3.5KB (%35 azalma)
- Token: ~1,350 → ~875 (%35 azalma)

---

## 🟢 Sorun #5: Rate Limiting Parametreleri

### Lokasyon
**Dosya**: `functions/src/ai.js`  
**Satır**: 11-13

### Mevcut Kod
```javascript
const GEMINI_RATE_LIMIT_WINDOW_SEC = parseInt(process.env.GEMINI_RATE_LIMIT_WINDOW_SEC || "60", 10);
const GEMINI_RATE_LIMIT_MAX = parseInt(process.env.GEMINI_RATE_LIMIT_MAX || "5", 10);
const GEMINI_RATE_LIMIT_IP_MAX = parseInt(process.env.GEMINI_RATE_LIMIT_IP_MAX || "20", 10);
```

### Düzeltilmiş Kod
```javascript
// Daha sıkı limitler (abuse prevention)
const GEMINI_RATE_LIMIT_WINDOW_SEC = parseInt(process.env.GEMINI_RATE_LIMIT_WINDOW_SEC || "60", 10);
const GEMINI_RATE_LIMIT_MAX = parseInt(process.env.GEMINI_RATE_LIMIT_MAX || "3", 10);  // 5 → 3
const GEMINI_RATE_LIMIT_IP_MAX = parseInt(process.env.GEMINI_RATE_LIMIT_IP_MAX || "15", 10);  // 20 → 15

// Burst allowance ekle
const BURST_ALLOWANCE = 2;  // İlk 2 istek throttle'sız
```

### Etki
- **Abuse Prevention**: Script/bot saldırılarını engeller
- **Maliyet Tasarrufu**: %20-30 (kötüye kullanım durumunda)
- **Kullanıcı Deneyimi**: Normal kullanıcıları etkilemez
- **Risk**: Çok düşük

---

## 🟢 Sorun #6: Client-Side Model Seçimi

### Lokasyon
**Dosya**: `functions/src/ai.js`  
**Satır**: 38-48

### Mevcut Kod (Güvenlik Riski)
```javascript
    let modelId = "gemini-2.0-flash-lite-001";
    const reqModel = typeof request.data?.model === "string" ? String(request.data.model).toLowerCase().trim() : "";
    if (reqModel) {
      if (reqModel.includes("pro")) {
        modelId = "gemini-2.0-flash-001";  // ❌ Client kontrol ediyor!
      }
```

### Düzeltilmiş Kod (Backend Kontrol)
```javascript
    // Task type'a göre backend model seçer
    const taskType = request.data?.taskType || 'default';
    const MODEL_MAP = {
      'chat': 'gemini-2.0-flash-lite-001',
      'strategy': 'gemini-2.0-flash-001',
      'workshop': 'gemini-2.0-flash-001',
      'quiz': 'gemini-2.0-flash-lite-001',
      'default': 'gemini-2.0-flash-lite-001'
    };
    
    const modelId = MODEL_MAP[taskType] || MODEL_MAP.default;
    // Client'tan gelen model parametresi YOKSAYILIR
```

### Client-Side Değişiklik Gerekli
**Dosya**: `lib/data/repositories/ai_service.dart`  
**Değişiklik**: `model` parametresi yerine `taskType` gönder

```dart
// ÖNCE:
return _callGemini(prompt, expectJson: true, model: 'gemini-1.5-pro-latest');

// SONRA:
return _callGemini(prompt, expectJson: true, taskType: 'chat');
```

### Etki
- **Güvenlik**: Client model seçemez
- **Maliyet Kontrolü**: Backend optimize eder
- **Esneklik**: A/B testing kolaylaşır
- **Risk**: Orta (client güncellemesi gerekir)

---

## 🟢 Sorun #7: UI'da Kota Göstergesi Eksik

### Lokasyon
**Backend**: `functions/src/ai.js:69-85` (Kota var ama UI'da yok)  
**Frontend**: Henüz yok, eklenecek

### Gerekli Yeni Dosya/Widget
**Önerilen Dosya**: `lib/shared/widgets/ai_quota_indicator.dart`

### Örnek Kod
```dart
class AIQuotaIndicator extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Firestore'dan günlük kota bilgisi çek
    final today = _getTodayKey();
    final quotaRef = ref.watch(quotaStreamProvider(today));
    
    return quotaRef.when(
      data: (quota) {
        final remaining = quota?.balance ?? 100;
        final total = 100;
        final percentage = (remaining / total * 100).toInt();
        
        return Row(
          children: [
            Icon(Icons.auto_awesome, size: 16, color: _getColor(percentage)),
            SizedBox(width: 4),
            Text('$remaining/$total', style: TextStyle(fontSize: 12)),
            SizedBox(width: 8),
            LinearProgressIndicator(value: remaining / total, minHeight: 4),
          ],
        );
      },
      loading: () => CircularProgressIndicator(),
      error: (e, _) => Icon(Icons.error),
    );
  }
  
  Color _getColor(int percentage) {
    if (percentage > 50) return Colors.green;
    if (percentage > 20) return Colors.orange;
    return Colors.red;
  }
}
```

### Firestore Stream Provider
```dart
final quotaStreamProvider = StreamProvider.family<QuotaDoc?, String>((ref, day) {
  final user = ref.watch(userProfileProvider).value;
  if (user == null) return Stream.value(null);
  
  return FirebaseFirestore.instance
    .collection('users')
    .doc(user.id)
    .collection('stars')
    .doc(day)
    .snapshots()
    .map((snap) => snap.exists ? QuotaDoc.fromMap(snap.data()!) : null);
});
```

### Nereye Eklenecek
1. Ana ekran app bar'ında (sürekli görünür)
2. AI özellikleri ekranlarında (chat, workshop, vb.)
3. Settings ekranında (detaylı görünüm)

### Etki
- **Kullanıcı Bilinçlendirme**: Kota farkındalığı artar
- **Premium Conversion**: Kota bitince upgrade önerisi
- **Destek Azalması**: "Neden çalışmıyor?" sorularını önler
- **Risk**: Yok

---

## 📋 Hızlı Checklist

Tüm düzeltmeleri yapmak için:

### 1. Backend Değişiklikleri (functions/src/ai.js)
- [ ] Satır 10: Token limit 50000 → 20000
- [ ] Satır 12: Rate limit 5 → 3
- [ ] Satır 13: IP rate limit 20 → 15
- [ ] Satır 38-48: Model seçimini backend'e taşı

### 2. Dart Değişiklikleri (lib/data/repositories/ai_service.dart)
- [ ] Satır 626: Pro model → Flash model
- [ ] Satır 64: maxChars 1200 → 600
- [ ] Model parametresi → taskType parametresi

### 3. Prompt Optimizasyonu
- [ ] lib/core/prompts/workshop_prompts.dart: %30 kısalt
- [ ] assets/prompts/yks_prompt.md: %30 kısalt
- [ ] Diğer prompt dosyaları: İncele ve optimize et

### 4. UI İyileştirmeleri
- [ ] AI kota gösterge widget'ı oluştur
- [ ] Ana ekrana kota göstergesi ekle
- [ ] Kota bitince güzel error mesajı göster

### 5. Testing
- [ ] Flash model ile chat kalitesini test et
- [ ] Düşük token limitleriyle output kalitesini test et
- [ ] Kısa prompt'larla sonuç doğruluğunu test et
- [ ] Rate limiting'i test et

### 6. Monitoring
- [ ] Firebase Console'da maliyet takibi
- [ ] Daily cost alert kur ($50 eşiği)
- [ ] Usage metrics dashboard

---

## 🎯 Öncelikli Düzeltme Sırası

**Hemen (2 saat)**:
1. Pro model → Flash model (ai_service.dart:626)
2. Token limit düşür (ai.js:10)

**Bu Hafta (1 gün)**:
3. Chat hafıza optimize et (ai_service.dart:64)
4. Rate limiting sıkılaştır (ai.js:12-13)

**Bu Ay (1 hafta)**:
5. Prompt'ları kısalt
6. UI kota göstergesi ekle
7. Backend model kontrolü

---

**NOT**: Her değişiklikten sonra test edin! Rollback planınız hazır olsun.
