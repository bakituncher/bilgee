# Haftalık Planlama Sistemi - Teknik Rapor

**Tarih**: 4 Şubat 2026  
**Versiyon**: 2.0 (AI-Free)  
**Dosya**: `weekly_planner_service.dart`

---

## 📊 Genel Bakış

Haftalık planlama sistemi, kullanıcının performans verilerini, sınav bilgilerini ve müsaitlik durumunu analiz ederek **kişiselleştirilmiş haftalık çalışma programı** oluşturur. Sistem tamamen **deterministik** çalışır ve AI kullanmaz.

---

## 🔍 Kullanılan Veriler

### 1. Kullanıcı Profil Verileri

#### `UserModel` - Ana Kullanıcı Bilgileri
```dart
// Kaynak: user_model.dart
class UserModel {
  final String id;                          // Kullanıcı ID (Firebase UID)
  final String? selectedExam;               // Seçili sınav (yks, lgs, kpss, ags)
  final String? selectedExamSection;        // Sınav bölümü (TYT, AYT-Sayısal, vb.)
  final Map<String, List<String>> weeklyAvailability;  // Haftalık müsaitlik
}
```

**Kullanım Amacı**:
- `selectedExam`: Müfredat filtreleme (hangi dersleri planlayacağız?)
- `selectedExamSection`: Alt bölüm filtreleme (TYT, AYT, YDT seçimi)
- `weeklyAvailability`: Çalışma zamanları (hangi günlerde, hangi saatlerde?)

**Örnek Veri**:
```json
{
  "id": "user123",
  "selectedExam": "yks",
  "selectedExamSection": "AYT - Sayısal",
  "weeklyAvailability": {
    "Pazartesi": ["09:00-11:00", "14:00-16:00", "19:00-21:00"],
    "Salı": ["09:00-11:00", "14:00-16:00"],
    "Çarşamba": [],
    "Perşembe": ["14:00-16:00", "19:00-21:00"],
    "Cuma": ["09:00-11:00"],
    "Cumartesi": ["09:00-13:00", "14:00-18:00"],
    "Pazar": ["10:00-12:00"]
  }
}
```

**Veri Miktarı**: ~1-2 KB (kullanıcı başına)

---

### 2. Performans Verileri

#### `PerformanceSummary` - Konu Bazlı Performans Özeti
```dart
// Kaynak: performance_summary.dart
class PerformanceSummary {
  final Map<String, Map<String, TopicPerformanceModel>> topicPerformances;
  // Yapı: {
  //   "Matematik": {
  //     "Fonksiyonlar": TopicPerformanceModel(doğru: 15, yanlış: 5),
  //     "Türev": TopicPerformanceModel(doğru: 8, yanlış: 12)
  //   }
  // }
}

class TopicPerformanceModel {
  final int correctCount;      // Doğru sayısı
  final int wrongCount;        // Yanlış sayısı
  final int questionCount;     // Toplam soru sayısı
}
```

**Kullanım Amacı**:
- **Önceliklendirme**: Zayıf konular önce planlanır
- **Aktivite Türü**: Yeni/zayıf/güçlü konulara göre özel program

**Hesaplama Mantığı**:
```dart
final accuracy = correctCount / (correctCount + wrongCount);

if (accuracy < 0.5) {
  priority -= 100;  // ÇOK ZAYIF → En öncelikli
} else if (accuracy < 0.7) {
  priority -= 50;   // ORTA ZAYIF → Yüksek öncelik
}
```

**Örnek Veri**:
```json
{
  "Matematik": {
    "Fonksiyonlar": {"correctCount": 15, "wrongCount": 5, "questionCount": 20},
    "Türev": {"correctCount": 3, "wrongCount": 17, "questionCount": 20},
    "İntegral": {"correctCount": 0, "wrongCount": 0, "questionCount": 0}
  },
  "Fizik": {
    "Hareket": {"correctCount": 8, "wrongCount": 12, "questionCount": 20}
  }
}
```

**Veri Miktarı**: ~5-50 KB (kullanıcının çözdüğü konu sayısına göre)

---

### 3. Test Geçmişi

#### `List<TestModel>` - Deneme Sonuçları
```dart
// Kaynak: test_model.dart
class TestModel {
  final Map<String, Map<String, dynamic>> scores;  // Ders bazlı puanlar
  final double totalNet;                            // Toplam net
  final double penaltyCoefficient;                  // Yanlış çarpanı (0.25)
  // scores yapısı:
  // {
  //   "Matematik": {"dogru": 25, "yanlis": 5, "bos": 10},
  //   "Fizik": {"dogru": 10, "yanlis": 3, "bos": 1}
  // }
}
```

**Kullanım Amacı**:
- **Strateji Metni**: Ortalama net hesaplama
- **Ders Analizi**: Hangi dersler zayıf?
- **Hedef Belirleme**: Gelişim yönü

**Hesaplamalar**:
```dart
// Ortalama Net
final avgNet = tests.fold<double>(0.0, (sum, test) => sum + test.totalNet) / tests.length;

// Ders Bazlı Ortalama
for (final test in tests) {
  test.scores.forEach((subject, scores) {
    final net = (scores['dogru'] ?? 0.0) - ((scores['yanlis'] ?? 0.0) * 0.25);
    subjectNets[subject].add(net);
  });
}
```

**Örnek Veri**:
```json
[
  {
    "totalNet": 65.5,
    "penaltyCoefficient": 0.25,
    "scores": {
      "Matematik": {"dogru": 25, "yanlis": 10, "bos": 5},
      "Fizik": {"dogru": 8, "yanlis": 4, "bos": 2},
      "Kimya": {"dogru": 10, "yanlis": 2, "bos": 1}
    }
  },
  {
    "totalNet": 72.0,
    "scores": { ... }
  }
]
```

**Veri Miktarı**: ~1-10 KB (test sayısına göre)

---

### 4. Tamamlanan Görevler

#### Firebase Firestore - `user_activity` Koleksiyonu
```dart
// Firestore Yolu: users/{userId}/user_activity/{docId}
// Her doküman bir günü temsil eder
{
  "date": Timestamp,
  "completedDailyTasks": [
    {"id": "Fonksiyonlar", "type": "topic"},
    {"id": "Türev", "type": "topic"}
  ]
}
```

**Çekilen Veri**:
```dart
final snapshot = await _firestore
    .collection('users')
    .doc(userId)
    .collection('user_activity')
    .where('date', isGreaterThanOrEqualTo: startDate)  // Son 365 gün
    .get();
```

**Kullanım Amacı**:
- **Filtreleme**: Tamamlanan konuları plana ekleme
- **Tekrar Önleme**: Bitmiş konular tekrar çıkmasın

**Veri Miktarı**: ~10-100 KB (yıllık veri, 365 gün × ~100-300 byte)

---

### 5. Müfredat Verisi (ExamData)

#### `Exam` - Sınav Müfredatı
```dart
// Kaynak: assets/data/yks.json, lgs.json, kpss.json, ags.json
class Exam {
  final ExamType type;
  final String name;
  final List<ExamSection> sections;
}

class ExamSection {
  final String name;                              // "TYT", "AYT - Sayısal"
  final Map<String, SubjectDetails> subjects;     // Dersler
}

class SubjectDetails {
  final int questionCount;
  final List<SubjectTopic> topics;  // Konu listesi (müfredat sırası korunur)
}
```

**Kullanım Amacı**:
- **Konu Listesi**: Hangi konular var?
- **Müfredat Sırası**: Konuların doğal sırasını koruma
- **Filtreleme**: Kullanıcının bölümüne göre ilgili dersleri seçme

**Örnek Yapı** (YKS):
```json
{
  "type": "yks",
  "sections": [
    {
      "name": "TYT",
      "subjects": {
        "Temel Matematik": {
          "questionCount": 40,
          "topics": [
            "Temel Kavramlar",
            "Sayı Basamakları",
            "Bölme ve Bölünebilme",
            "EBOB-EKOK",
            ...
          ]
        }
      }
    },
    {
      "name": "AYT - Sayısal",
      "subjects": {
        "Matematik": {
          "questionCount": 40,
          "topics": ["Fonksiyonlar", "Türev", ...]
        }
      }
    }
  ]
}
```

**Veri Miktarı**: ~50-200 KB (sınav türüne göre, cache'lenir)

---

### 6. Sınav Tarihi

#### `ExamSchedule` - Sınav Takvimi
```dart
// Kaynak: exam_schedule.dart
static final Map<ExamType, (int, int, int)> _defaults = {
  ExamType.yks: (0, 6, 15),      // 15 Haziran
  ExamType.lgs: (0, 6, 1),       // 1 Haziran
  ExamType.ags: (0, 7, 12),      // 12 Temmuz
};

final daysUntilExam = ExamSchedule.daysUntilExam(examType);
```

**Kullanım Amacı**:
- **Strateji Metni**: "Sınava X gün kaldı"
- **Hedef Belirleme**: Süreye göre farklı hedefler
  - 90+ gün → Müfredat tamamlama
  - 30-90 gün → Zayıf konulara odaklanma
  - 0-30 gün → Deneme çözümü

**Veri Miktarı**: ~100 bytes (hesaplama sonucu)

---

## 🔄 Plan Oluşturma Akışı

### Adım 1: Veri Toplama

```dart
// 1. Kullanıcı bilgileri (zaten var)
final user = currentUser;  // ~1 KB

// 2. Performans özeti (zaten var)
final performance = performanceSummary;  // ~5-50 KB

// 3. Test geçmişi (zaten var)
final tests = userTests;  // ~1-10 KB

// 4. Tamamlanan konular (Firestore çağrısı)
final completedTopicIds = await _loadCompletedTopics(user.id, days: 365);
// Firestore Query: ~10-100 KB

// 5. Müfredat (Cache'den)
final exam = await ExamData.getExamByType(examType);
// Cache hit: ~0 KB (bellekte)
// Cache miss: ~50-200 KB (ilk yükleme)

// 6. Sınav tarihi (Hesaplama)
final daysUntilExam = ExamSchedule.daysUntilExam(examType);
// ~0 KB (hesaplama)
```

**Toplam Veri Çekimi**: ~67-362 KB (tipik: ~100 KB)

---

### Adım 2: Slot Sayısı Hesaplama

```dart
int _calculateTotalWeeklySlots(UserModel user, String pacing) {
  int totalSlots = 0;
  final fillRatio = _getFillRatio(pacing);  // 0.6, 0.8, 1.0
  
  user.weeklyAvailability.forEach((day, slots) {
    totalSlots += (slots.length * fillRatio).ceil();
  });
  
  return totalSlots;
}
```

**Örnek**:
```
Kullanıcı müsaitliği:
- Pazartesi: 3 slot
- Salı: 2 slot
- Perşembe: 2 slot
- Cumartesi: 4 slot
- Pazar: 1 slot
Toplam: 12 slot

Pacing: Yoğun (1.0)
Hesaplanan slot: 12 * 1.0 = 12 slot

Pacing: Dengeli (0.8)
Hesaplanan slot: 12 * 0.8 = 10 slot

Pacing: Rahat (0.6)
Hesaplanan slot: 12 * 0.6 = 7 slot
```

---

### Adım 3: Konu Seçimi ve Önceliklendirme

#### 3.1. İlgili Bölümleri Filtrele
```dart
// YKS Örneği
if (examType == ExamType.yks) {
  sections = [TYT]  // Her zaman TYT
  
  if (selectedSection == "AYT - Sayısal") {
    sections.add("AYT - Sayısal")
  }
}
```

#### 3.2. Tüm Konuları Topla ve Puanla
```dart
for (final section in sections) {
  section.subjects.forEach((subjectName, subjectDetails) {
    for (int i = 0; i < subjectDetails.topics.length; i++) {
      final topic = subjectDetails.topics[i];
      
      // Tamamlanmış konuları atla
      if (completedTopicIds.contains(topic.name)) continue;
      
      // Öncelik puanı hesapla
      double priority = i.toDouble();  // Müfredat sırası (0, 1, 2, ...)
      
      final topicPerf = performance.topicPerformances[subjectName]?[topic.name];
      
      if (topicPerf != null && attempts > 5) {
        final accuracy = topicPerf.correctCount / attempts;
        
        if (accuracy < 0.5) {
          priority -= 100;  // ÇOK ZAYIF
        } else if (accuracy < 0.7) {
          priority -= 50;   // ORTA ZAYIF
        }
      } else if (topicPerf == null || attempts < 5) {
        priority -= 10;  // YENİ KONU
      }
      
      scoredTopics.add({
        subject: subjectName,
        topic: topic.name,
        priority: priority
      });
    }
  });
}
```

**Öncelik Puanlama Örnekleri**:

| Konu | Müfredat Sırası | Performans | Öncelik Puanı | Sonuç |
|------|----------------|-----------|---------------|-------|
| Fonksiyonlar | 15 | %30 doğruluk | 15 - 100 = -85 | **1. sıra** |
| Türev | 25 | %60 doğruluk | 25 - 50 = -25 | **2. sıra** |
| İntegral | 26 | Veri yok | 26 - 10 = 16 | **3. sıra** |
| Limit | 24 | %80 doğruluk | 24 - 0 = 24 | **4. sıra** |

#### 3.3. Dinamik Konu Sayısı Seçimi
```dart
// Her konu için 2 slot gerekir (Konu Anlatımı + Soru Çözümü)
final neededTopicCount = ((totalAvailableSlots / 2) * 1.2).ceil();

// En az 10, en fazla tüm konular
final finalTopicCount = neededTopicCount.clamp(10, scoredTopics.length);

return scoredTopics.take(finalTopicCount);
```

**Örnek**:
```
Toplam Slot: 20
Gerekli Konu: (20 / 2) * 1.2 = 12 konu
Buffer (%20): Bazı günler daha az slot kullanılabilir

Seçilen Konular: 12 konu (en öncelikli)
```

---

### Adım 4: Haftalık Program Oluşturma

#### 4.1. Günleri Sırala (Bugünden Başla)
```dart
final trDays = ['Pazartesi', 'Salı', 'Çarşamba', 'Perşembe', 'Cuma', 'Cumartesi', 'Pazar'];
final todayIndex = DateTime.now().weekday - 1;  // 0=Pzt, 6=Paz

final orderedDays = [];
for (int i = 0; i < 7; i++) {
  orderedDays.add(trDays[(todayIndex + i) % 7]);
}

// Örnek: Bugün Çarşamba ise
// orderedDays = ["Çarşamba", "Perşembe", "Cuma", "Cumartesi", "Pazar", "Pazartesi", "Salı"]
```

#### 4.2. Her Gün İçin Slot Doldur
```dart
int globalTopicIndex = 0;
int slotCountForCurrentTopic = 0;
final usedTopics = <String>{};

for (final day in orderedDays) {
  final availability = user.weeklyAvailability[day];
  final targetSlotCount = (availability.length * fillRatio).ceil();
  
  for (int slotIdx = 0; slotIdx < targetSlotCount; slotIdx++) {
    if (globalTopicIndex >= topics.length) {
      break;  // Konular bitti
    }
    
    final topic = topics[globalTopicIndex];
    final slot = availability[slotIdx];
    
    // Aktivite türü belirle
    final activityType = slotCountForCurrentTopic == 0
        ? "${topic.subject} - ${topic.topic} (Konu Anlatımı)"
        : "${topic.subject} - ${topic.topic} (Soru Çözümü)";
    
    daySchedule.add({
      'time': slot,
      'activity': activityType,
      'id': '$slot-${topic.topic}-$slotCountForCurrentTopic',
    });
    
    slotCountForCurrentTopic++;
    
    // Her konu için 2 slot
    if (slotCountForCurrentTopic >= 2) {
      usedTopics.add('${topic.subject}-${topic.topic}');
      globalTopicIndex++;
      slotCountForCurrentTopic = 0;
    }
  }
}
```

**Örnek Plan**:
```json
{
  "plan": [
    {
      "day": "Çarşamba",
      "schedule": [
        {
          "time": "09:00-11:00",
          "activity": "Matematik - Fonksiyonlar (Konu Anlatımı)",
          "id": "09:00-11:00-Fonksiyonlar-0"
        },
        {
          "time": "14:00-16:00",
          "activity": "Matematik - Fonksiyonlar (Soru Çözümü)",
          "id": "14:00-16:00-Fonksiyonlar-1"
        }
      ],
      "focus": "Matematik"
    },
    {
      "day": "Perşembe",
      "schedule": [
        {
          "time": "09:00-11:00",
          "activity": "Fizik - Hareket (Konu Anlatımı)",
          "id": "09:00-11:00-Hareket-0"
        }
      ],
      "focus": "Fizik"
    }
  ],
  "summary": "Haftalık çalışma programınız hazır! 2 farklı konu üzerinde çalışacaksınız."
}
```

---

### Adım 5: Strateji Metni Oluşturma

```markdown
# YKS Hazırlık Stratejisi

## Genel Durum
- Sınava Kalan Gün: 132
- Ortalama Net: 65.5
- Çözülen Deneme Sayısı: 8
- Çalışma Temposu: Yoğun

## Ders Bazlı Durum
🔴 **Fizik**: 3.5 net
🟡 **Kimya**: 8.2 net
🟢 **Matematik**: 12.5 net
🟢 **Biyoloji**: 10.8 net

## Öncelikler
### Güçlendirilmesi Gereken Konular
- Fizik - Hareket
- Fizik - Kuvvet ve Hareket
- Kimya - Asitler ve Bazlar
- Matematik - Türev
- Matematik - İntegral

## Hedefler
- Müfredatı tamamlamaya odaklanın
- Her konudan soru çözümü yapın
- Haftada en az 1 deneme çözün
```

---

## 📈 Performans ve Optimizasyonlar

### Veri Çekimi

| Veri Kaynağı | Boyut | Süre | Önbellekleme |
|--------------|-------|------|--------------|
| Kullanıcı Profili | ~1 KB | 0ms | Bellekte |
| Performans Özeti | ~5-50 KB | 0ms | Bellekte |
| Test Geçmişi | ~1-10 KB | 0ms | Bellekte |
| Tamamlanan Görevler | ~10-100 KB | 100-300ms | ❌ Yok |
| Müfredat | ~50-200 KB | 0ms (cache) | ✅ Bellekte |
| Sınav Tarihi | ~100 bytes | 0ms | Hesaplama |
| **TOPLAM** | **~67-362 KB** | **~100-300ms** | - |

### Hesaplama Karmaşıklığı

```
n = Toplam konu sayısı (tipik: 100-300)
m = Seçilen konu sayısı (tipik: 10-30)
s = Haftalık slot sayısı (tipik: 5-20)

1. Konu Filtreleme: O(n)
2. Öncelik Puanlama: O(n)
3. Sıralama: O(n log n)
4. Konu Seçimi: O(m)
5. Program Oluşturma: O(s)
6. Strateji Metni: O(test sayısı) = O(10-50)

Toplam: O(n log n) + O(s)
Tipik: ~100-300 işlem + ~5-20 işlem = ~300 işlem
Süre: < 50ms
```

### Cache Stratejisi

```dart
// Müfredat cache'i (ExamData)
static final Map<ExamType, Exam> _cache = {};

// İlk yükleme
final exam = await _loadExam(type, 'assets/data/yks.json');
_cache[type] = exam;  // Bellekte sakla

// Sonraki kullanımlar
if (_cache.containsKey(type)) {
  return _cache[type]!;  // Anında döndür
}
```

---

## 🎯 Karar Ağacı

```
BAŞLA
├─ Kullanıcı validasyonu?
│  ├─ Sınav seçilmemiş → HATA
│  ├─ Müsait zaman yok → HATA
│  └─ ✅ Geçerli
│
├─ Veri toplama
│  ├─ Performans verisi var mı?
│  │  ├─ Yok → Tüm konular "yeni"
│  │  └─ Var → Öncelik puanlama
│  │
│  ├─ Test geçmişi var mı?
│  │  ├─ Yok → Genel strateji
│  │  └─ Var → Detaylı analiz
│  │
│  └─ Tamamlanan konular?
│     ├─ Yok → Tüm konular adaydır
│     └─ Var → Filtreleme
│
├─ Konu seçimi
│  ├─ Slot sayısı hesapla
│  │  └─ (Haftalık slot) × (Pacing oranı)
│  │
│  ├─ Gereken konu sayısı
│  │  └─ (Slot / 2) × 1.2
│  │
│  ├─ Öncelik sırala
│  │  ├─ Zayıf konular (< %50) → priority - 100
│  │  ├─ Orta konular (< %70) → priority - 50
│  │  ├─ Yeni konular → priority - 10
│  │  └─ Diğerleri → müfredat sırası
│  │
│  └─ En öncelikli N konu seç
│
├─ Program oluştur
│  ├─ Günleri sırala (bugünden başla)
│  │
│  ├─ Her gün için:
│  │  ├─ Müsait slotları al
│  │  ├─ Pacing'e göre doldur (%60/%80/%100)
│  │  │
│  │  └─ Her slot için:
│  │     ├─ Konu var mı?
│  │     │  ├─ Yok → Bu günü bitir
│  │     │  └─ Var → Devam
│  │     │
│  │     ├─ Aktivite türü belirle
│  │     │  ├─ İlk slot → Konu Anlatımı
│  │     │  └─ İkinci slot → Soru Çözümü
│  │     │
│  │     └─ 2 slot tamamlandı mı?
│  │        ├─ Evet → Sonraki konuya geç
│  │        └─ Hayır → Aynı konu devam
│  │
│  └─ Günün fokusunu belirle
│     └─ En çok geçen ders adı (> %60)
│
├─ Strateji metni oluştur
│  ├─ Sınava kalan gün
│  ├─ Ortalama net (varsa)
│  ├─ Ders bazlı durum
│  ├─ Zayıf konular listesi
│  └─ Süreye göre hedefler
│
└─ JSON döndür
   ├─ weeklyPlan
   ├─ strategy
   ├─ createdAt
   └─ version
```

---

## 🔒 Güvenlik ve Gizlilik

### Veri Erişimi
- ✅ Sadece kullanıcının kendi verileri
- ✅ Firebase Security Rules ile korunur
- ✅ Hiçbir veri üçüncü parti servise gönderilmez
- ✅ AI kullanılmadığı için token/API maliyeti yok

### Veri Depolama
- Haftalık plan **Firestore**'da saklanır: `users/{userId}/plans/weekly_plan`
- Müfredat **bellekte** cache'lenir (uygulama kapanınca silinir)
- Performans verileri zaten **Firestore**'da

---

## 📊 Örnek Senaryo - Baştan Sona

### Kullanıcı: Ahmet

**Profil**:
```json
{
  "id": "ahmet123",
  "selectedExam": "yks",
  "selectedExamSection": "AYT - Sayısal",
  "weeklyAvailability": {
    "Pazartesi": ["09:00-11:00", "14:00-16:00"],
    "Salı": ["09:00-11:00"],
    "Çarşamba": [],
    "Perşembe": ["14:00-16:00", "19:00-21:00"],
    "Cuma": ["09:00-11:00"],
    "Cumartesi": ["09:00-13:00", "14:00-18:00"],
    "Pazar": []
  }
}
```

**Performans**:
```json
{
  "Matematik": {
    "Fonksiyonlar": {"correctCount": 5, "wrongCount": 15},
    "Türev": {"correctCount": 12, "wrongCount": 8}
  },
  "Fizik": {
    "Hareket": {"correctCount": 3, "wrongCount": 17}
  }
}
```

**Testler**: 5 deneme (Ortalama: 58.5 net)

**Pacing**: Yoğun

---

### İşlem Adımları

#### 1. Slot Hesaplama
```
Pazartesi: 2 slot × 1.0 = 2
Salı: 1 slot × 1.0 = 1
Perşembe: 2 slot × 1.0 = 2
Cuma: 1 slot × 1.0 = 1
Cumartesi: 4 slot × 1.0 = 4
Toplam: 10 slot
```

#### 2. Konu Sayısı
```
Gerekli: (10 / 2) × 1.2 = 6 konu
```

#### 3. Konu Önceliklendirme
```
TYT + AYT-Sayısal müfredatından:

1. Fizik - Hareket: priority = 0 - 100 = -100 (zayıf)
2. Matematik - Fonksiyonlar: priority = 0 - 100 = -100 (zayıf)
3. Matematik - Türev: priority = 1 - 50 = -49 (orta)
4. Fizik - Kuvvet: priority = 1 - 10 = -9 (yeni)
5. Kimya - Atom: priority = 0 - 10 = -10 (yeni)
6. Biyoloji - Hücre: priority = 0 - 10 = -10 (yeni)

Seçilen 6 konu: Sırayla yukarıdakiler
```

#### 4. Program Oluşturma

**Bugün: Çarşamba**

```json
{
  "plan": [
    {
      "day": "Çarşamba",
      "schedule": [],
      "focus": "Dinlenme Günü"
    },
    {
      "day": "Perşembe",
      "schedule": [
        {
          "time": "14:00-16:00",
          "activity": "Fizik - Hareket (Konu Anlatımı)"
        },
        {
          "time": "19:00-21:00",
          "activity": "Fizik - Hareket (Soru Çözümü)"
        }
      ],
      "focus": "Fizik"
    },
    {
      "day": "Cuma",
      "schedule": [
        {
          "time": "09:00-11:00",
          "activity": "Matematik - Fonksiyonlar (Konu Anlatımı)"
        }
      ],
      "focus": "Matematik"
    },
    {
      "day": "Cumartesi",
      "schedule": [
        {
          "time": "09:00-11:00",
          "activity": "Matematik - Fonksiyonlar (Soru Çözümü)"
        },
        {
          "time": "11:00-13:00",
          "activity": "Matematik - Türev (Konu Anlatımı)"
        },
        {
          "time": "14:00-16:00",
          "activity": "Matematik - Türev (Soru Çözümü)"
        },
        {
          "time": "16:00-18:00",
          "activity": "Fizik - Kuvvet (Konu Anlatımı)"
        }
      ],
      "focus": "Matematik"
    },
    {
      "day": "Pazar",
      "schedule": [],
      "focus": "Dinlenme Günü"
    },
    {
      "day": "Pazartesi",
      "schedule": [
        {
          "time": "09:00-11:00",
          "activity": "Fizik - Kuvvet (Soru Çözümü)"
        },
        {
          "time": "14:00-16:00",
          "activity": "Kimya - Atom (Konu Anlatımı)"
        }
      ],
      "focus": "Karışık Çalışma"
    },
    {
      "day": "Salı",
      "schedule": [
        {
          "time": "09:00-11:00",
          "activity": "Kimya - Atom (Soru Çözümü)"
        }
      ],
      "focus": "Kimya"
    }
  ],
  "summary": "Haftalık çalışma programınız hazır! 5 farklı konu üzerinde çalışacaksınız."
}
```

#### 5. Strateji Metni

```markdown
# YKS Hazırlık Stratejisi

## Genel Durum
- Sınava Kalan Gün: 132
- Ortalama Net: 58.5
- Çözülen Deneme Sayısı: 5
- Çalışma Temposu: Yoğun

## Ders Bazlı Durum
🔴 **Fizik**: 3.5 net
🟡 **Matematik**: 8.0 net

## Öncelikler
### Güçlendirilmesi Gereken Konular
- Fizik - Hareket
- Matematik - Fonksiyonlar

## Hedefler
- Müfredatı tamamlamaya odaklanın
- Her konudan soru çözümü yapın
- Haftada en az 1 deneme çözün
```

---

## 📋 Özet

### Kullanılan Veriler
1. **Kullanıcı Profili**: Sınav seçimi, bölüm, müsaitlik (~1 KB)
2. **Performans Verileri**: Konu bazlı doğru/yanlış (~5-50 KB)
3. **Test Geçmişi**: Deneme sonuçları (~1-10 KB)
4. **Tamamlanan Görevler**: Firestore sorgusu (~10-100 KB)
5. **Müfredat**: JSON dosyası (~50-200 KB, cache)
6. **Sınav Tarihi**: Hesaplama (~100 bytes)

### Toplam Veri
- **İlk Yükleme**: ~67-362 KB
- **Sonraki Kullanımlar**: ~17-162 KB (müfredat cache'den)

### Süre
- **Veri Çekimi**: ~100-300ms (Firestore)
- **Hesaplama**: ~50ms
- **Toplam**: ~150-350ms ⚡

### Maliyet
- **AI Token**: 0 (AI kullanılmıyor)
- **Firestore Okuma**: 1-365 doküman (tamamlanan görevler)
- **Network**: ~100 KB (ilk yükleme)

### Çıktı
- **Haftalık Plan**: 7 günlük program, gün bazlı aktiviteler
- **Strateji Metni**: Markdown formatında detaylı analiz
- **Boyut**: ~5-10 KB JSON

---

## 🎯 Sonuç

Haftalık planlama sistemi:
- ✅ **Hızlı**: < 500ms
- ✅ **Verimli**: Minimum veri çekimi
- ✅ **Akıllı**: Performansa göre önceliklendirme
- ✅ **Kişisel**: Her kullanıcıya özel
- ✅ **Ücretsiz**: AI token maliyeti yok
- ✅ **Güvenli**: Sadece kullanıcının kendi verisi

---

**Hazırlayan**: GitHub Copilot  
**Tarih**: 4 Şubat 2026  
**Dosya**: `WEEKLY_PLANNER_TECHNICAL_REPORT.md`

