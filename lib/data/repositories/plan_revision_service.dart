// lib/data/repositories/plan_revision_service.dart
import 'package:taktik/data/models/performance_summary.dart';
import 'package:taktik/data/repositories/weekly_planner_service.dart';

/// Revizyon talepleri için özel servis
/// Kullanıcının geri bildirimlerini analiz eder ve planı buna göre ayarlar
class PlanRevisionService {
  /// Revizyon talebini analiz eder ve yeni plan parametreleri döndürür
  RevisionAnalysis analyzeRevisionRequest(String request) {
    final analysis = RevisionAnalysis();
    final lowerRequest = request.toLowerCase();

    // 1. TEMPO ANALİZİ
    _analyzePacingRequest(lowerRequest, analysis);

    // 2. DERS TERCİHLERİ ANALİZİ
    _analyzeSubjectPreferences(lowerRequest, analysis);

    // 3. ÇALIŞMA TÜRÜ TERCİHLERİ
    _analyzeStudyTypePreferences(lowerRequest, analysis);

    return analysis;
  }

  /// Tempo değişikliklerini analiz eder
  void _analyzePacingRequest(String request, RevisionAnalysis analysis) {
    // Yoğunluk artırma ifadeleri
    final intensityIncreasePatterns = [
      'daha yoğun',
      'daha fazla',
      'daha çok çalış',
      'yoğun program',
      'daha sıkı',
      'daha ağır',
      'programı doldur',
      'boş zaman kalmasın',
    ];

    // Yoğunluk azaltma ifadeleri
    final intensityDecreasePatterns = [
      'daha hafif',
      'daha az',
      'rahat',
      'dinlenme zamanı',
      'yoruldum',
      'biraz ara',
      'daha gevşek',
      'soluklanma',
    ];

    for (final pattern in intensityIncreasePatterns) {
      if (request.contains(pattern)) {
        analysis.pacingChange = PacingChange.increase;
        break;
      }
    }

    if (analysis.pacingChange == PacingChange.none) {
      for (final pattern in intensityDecreasePatterns) {
        if (request.contains(pattern)) {
          analysis.pacingChange = PacingChange.decrease;
          break;
        }
      }
    }
  }

  /// Ders tercihlerini analiz eder
  void _analyzeSubjectPreferences(String request, RevisionAnalysis analysis) {
    // Ders isimleri ve eş anlamlıları
    final subjectPatterns = {
      'Matematik': ['matematik', 'mat ', ' mat', 'matematic'],
      'Geometri': ['geometri', 'geo'],
      'Türkçe': ['türkçe', 'turkce', 'turkish'],
      'Edebiyat': ['edebiyat', 'edb'],
      'Fizik': ['fizik', 'fiz'],
      'Kimya': ['kimya', 'kim'],
      'Biyoloji': ['biyoloji', 'bio', 'canlılar'],
      'Fen Bilimleri': ['fen', 'fen bilim'],
      'Tarih': ['tarih'],
      'Coğrafya': ['coğrafya', 'cografya', 'geography'],
      'Sosyal Bilgiler': ['sosyal'],
      'Felsefe': ['felsefe'],
      'Din Kültürü': ['din kültür', 'din kultur', 'dkab'],
      'İngilizce': ['ingilizce', 'english', 'ing'],
    };

    // Yoğunluk verme ifadeleri
    final focusPatterns = [
      'yoğunlaş',
      'odaklan',
      'ağırlık ver',
      'daha fazla',
      'daha çok',
      'öncelik ver',
      'çalış',
    ];

    // Azaltma ifadeleri
    final reducePatterns = [
      'azalt',
      'daha az',
      'kaldır',
      'çıkar',
      'istemiyorum',
    ];

    // Her ders için kontrol et
    subjectPatterns.forEach((subject, patterns) {
      bool subjectMentioned = false;

      for (final pattern in patterns) {
        if (request.contains(pattern)) {
          subjectMentioned = true;
          break;
        }
      }

      if (subjectMentioned) {
        // Bu ders için artırma mı azaltma mı yapılacak?
        bool shouldIncrease = false;
        bool shouldDecrease = false;

        for (final focusPattern in focusPatterns) {
          if (request.contains(focusPattern)) {
            shouldIncrease = true;
            break;
          }
        }

        if (!shouldIncrease) {
          for (final reducePattern in reducePatterns) {
            if (request.contains(reducePattern)) {
              shouldDecrease = true;
              break;
            }
          }
        }

        if (shouldIncrease) {
          analysis.subjectAdjustments[subject] = SubjectAdjustment.increase;
        } else if (shouldDecrease) {
          analysis.subjectAdjustments[subject] = SubjectAdjustment.decrease;
        } else {
          // Sadece bahsedildi ama yön belirtilmedi, muhtemelen artırma isteniyor
          analysis.subjectAdjustments[subject] = SubjectAdjustment.increase;
        }
      }
    });

    // Özel durumlar: Sözel/Sayısal/EA
    if (request.contains('sözel') || request.contains('sozel')) {
      final sozelSubjects = ['Türkçe', 'Edebiyat', 'Tarih', 'Coğrafya'];
      for (final subject in sozelSubjects) {
        if (!analysis.subjectAdjustments.containsKey(subject)) {
          analysis.subjectAdjustments[subject] = SubjectAdjustment.increase;
        }
      }
    }

    if (request.contains('sayısal') || request.contains('sayisal')) {
      final sayisalSubjects = ['Matematik', 'Fizik', 'Kimya', 'Biyoloji'];
      for (final subject in sayisalSubjects) {
        if (!analysis.subjectAdjustments.containsKey(subject)) {
          analysis.subjectAdjustments[subject] = SubjectAdjustment.increase;
        }
      }
    }
  }

  /// Çalışma türü tercihlerini analiz eder
  void _analyzeStudyTypePreferences(String request, RevisionAnalysis analysis) {
    if (request.contains('deneme') || request.contains('test çöz')) {
      analysis.preferMoreTests = true;
    }

    if (request.contains('konu anlat') || request.contains('teori')) {
      analysis.preferMoreTheory = true;
    }

    if (request.contains('soru çöz') || request.contains('pratik')) {
      analysis.preferMorePractice = true;
    }
  }

  /// Revizyon analizine göre yeni pacing değerini hesaplar
  String calculateNewPacing(String currentPacing, RevisionAnalysis analysis) {
    if (analysis.pacingChange == PacingChange.none) {
      return currentPacing;
    }

    final pacingLevels = ['relaxed', 'moderate', 'intense'];
    final currentIndex = pacingLevels.indexOf(currentPacing.toLowerCase());

    if (currentIndex == -1) return currentPacing;

    if (analysis.pacingChange == PacingChange.increase) {
      final newIndex = (currentIndex + 1).clamp(0, pacingLevels.length - 1);
      return pacingLevels[newIndex];
    } else {
      final newIndex = (currentIndex - 1).clamp(0, pacingLevels.length - 1);
      return pacingLevels[newIndex];
    }
  }

  /// Revizyon analizine göre konu listesini ayarlar
  List<StudyTopic> adjustTopicList({
    required List<StudyTopic> originalTopics,
    required RevisionAnalysis analysis,
    required PerformanceSummary performance,
    required int targetSlotCount,
  }) {
    if (analysis.subjectAdjustments.isEmpty) {
      return originalTopics;
    }

    // 1. Konuları kategorize et
    final Map<String, List<StudyTopic>> topicsBySubject = {};
    for (final topic in originalTopics) {
      topicsBySubject.putIfAbsent(topic.subject, () => []).add(topic);
    }

    // 2. Her ders için hedef slot sayısını hesapla
    final Map<String, int> targetSlotsBySubject = {};
    int totalAdjustedSlots = 0;

    // Önce artırılacak/azaltılacak derslerin slot sayısını belirle
    topicsBySubject.forEach((subject, topics) {
      final adjustment = analysis.subjectAdjustments[subject];
      final currentSlots = topics.length * 2; // Her konu 2 slot

      int newSlots = currentSlots;
      if (adjustment == SubjectAdjustment.increase) {
        // %50 artır
        newSlots = (currentSlots * 1.5).round();
      } else if (adjustment == SubjectAdjustment.decrease) {
        // %50 azalt
        newSlots = (currentSlots * 0.5).round();
      }

      targetSlotsBySubject[subject] = newSlots;
      totalAdjustedSlots += newSlots;
    });

    // 3. Hedef slot sayısına göre normalize et
    if (totalAdjustedSlots > targetSlotCount) {
      final ratio = targetSlotCount / totalAdjustedSlots;
      targetSlotsBySubject.forEach((subject, slots) {
        targetSlotsBySubject[subject] = (slots * ratio).round();
      });
    }

    // 4. Yeni konu listesini oluştur
    final List<StudyTopic> adjustedTopics = [];

    targetSlotsBySubject.forEach((subject, targetSlots) {
      final availableTopics = topicsBySubject[subject] ?? [];
      final neededTopicCount = (targetSlots / 2).ceil();

      // Bu dersten gerekli kadar konu ekle
      final topicsToAdd = availableTopics.take(neededTopicCount).toList();
      adjustedTopics.addAll(topicsToAdd);
    });

    // 5. Ayarlanmayan derslerden kalan slot sayısı kadar konu ekle
    final unusedSlots = targetSlotCount - (adjustedTopics.length * 2);
    if (unusedSlots > 0) {
      final unusedTopics = originalTopics
          .where((t) => !adjustedTopics.any((at) =>
              at.subject == t.subject && at.topic == t.topic))
          .toList();

      final additionalTopicCount = (unusedSlots / 2).ceil();
      adjustedTopics.addAll(unusedTopics.take(additionalTopicCount));
    }

    return adjustedTopics;
  }
}

/// Revizyon analiz sonucu
class RevisionAnalysis {
  PacingChange pacingChange = PacingChange.none;
  Map<String, SubjectAdjustment> subjectAdjustments = {};
  bool preferMoreTests = false;
  bool preferMoreTheory = false;
  bool preferMorePractice = false;

  bool get hasChanges =>
      pacingChange != PacingChange.none ||
      subjectAdjustments.isNotEmpty ||
      preferMoreTests ||
      preferMoreTheory ||
      preferMorePractice;

  @override
  String toString() {
    final buffer = StringBuffer();
    buffer.writeln('Revizyon Analizi:');

    if (pacingChange != PacingChange.none) {
      buffer.writeln('- Tempo: ${pacingChange == PacingChange.increase ? "Artır" : "Azalt"}');
    }

    if (subjectAdjustments.isNotEmpty) {
      buffer.writeln('- Ders Ayarlamaları:');
      subjectAdjustments.forEach((subject, adjustment) {
        buffer.writeln('  * $subject: ${adjustment == SubjectAdjustment.increase ? "Artır" : "Azalt"}');
      });
    }

    if (preferMoreTests) buffer.writeln('- Daha fazla deneme');
    if (preferMoreTheory) buffer.writeln('- Daha fazla konu anlatımı');
    if (preferMorePractice) buffer.writeln('- Daha fazla soru çözümü');

    return buffer.toString();
  }
}

/// Tempo değişikliği yönü
enum PacingChange {
  none,
  increase,
  decrease,
}

/// Ders ayarlama yönü
enum SubjectAdjustment {
  increase,
  decrease,
}

