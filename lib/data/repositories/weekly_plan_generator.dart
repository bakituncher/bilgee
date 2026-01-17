// lib/data/repositories/weekly_plan_generator.dart
import 'package:taktik/data/models/user_model.dart';
import 'package:taktik/data/models/test_model.dart';
import 'package:taktik/data/models/performance_summary.dart';
import 'package:taktik/data/models/exam_model.dart';
import 'package:taktik/data/models/topic_performance_model.dart';

/// İstemci tarafı haftalık plan oluşturucu
/// AI kullanmadan, kullanıcının performans verilerine göre otomatik plan oluşturur
class WeeklyPlanGenerator {

  // Performans kategorileri
  static const double criticalThreshold = 0.40;  // %40'ın altı kritik
  static const double weakThreshold = 0.60;      // %40-60 arası zayıf
  static const double moderateThreshold = 0.75;  // %60-75 arası orta
  // %75'in üstü güçlü

  static const int minQuestionsForAnalysis = 5;  // Analiz için minimum soru sayısı

  /// Haftalık plan oluştur
  static Future<Map<String, dynamic>> generateWeeklyPlan({
    required UserModel user,
    required List<TestModel> tests,
    required PerformanceSummary performance,
    required String pacing,
  }) async {
    if (user.selectedExam == null) {
      throw Exception('Analiz için önce bir sınav seçmelisiniz.');
    }
    if (user.weeklyAvailability.values.every((list) => list.isEmpty)) {
      throw Exception('Plan oluşturmadan önce en az bir tane müsait zaman dilimi seçmelisiniz.');
    }

    final examType = ExamType.values.byName(user.selectedExam!);
    final daysUntilExam = _getDaysUntilExam(examType);

    // Detaylı performans analizi
    final analysis = _analyzePerformance(tests, performance);

    // Tempo ayarı
    final intensityMultiplier = _getIntensityMultiplier(pacing);

    // Müsaitlik analizi
    final availableSlots = user.weeklyAvailability;
    final totalWeeklyHours = _calculateTotalHours(availableSlots);

    // Günlük planlar oluştur
    final dailyPlans = _createSmartDailyPlans(
      availableSlots: availableSlots,
      analysis: analysis,
      examType: examType,
      intensityMultiplier: intensityMultiplier,
      daysUntilExam: daysUntilExam,
      totalWeeklyHours: totalWeeklyHours,
    );

    // Strateji odağı ve motivasyon
    final strategyFocus = _determineStrategyFocus(analysis, daysUntilExam, totalWeeklyHours);
    final motivationalQuote = _generateSmartMotivation(analysis, daysUntilExam);

    return {
      'weeklyPlan': {
        'planTitle': 'Haftalık Çalışma Planı',
        'strategyFocus': strategyFocus,
        'plan': dailyPlans,
        'creationDate': DateTime.now().toIso8601String(),
        'motivationalQuote': motivationalQuote,
      },
      'pacing': pacing,
    };
  }

  /// Detaylı performans analizi
  static PerformanceAnalysis _analyzePerformance(
    List<TestModel> tests,
    PerformanceSummary performance,
  ) {
    final criticalTopics = <TopicInfo>[];
    final weakTopics = <TopicInfo>[];
    final moderateTopics = <TopicInfo>[];
    final strongTopics = <TopicInfo>[];

    // Konu bazlı analiz
    for (final subject in performance.topicPerformances.keys) {
      final topics = performance.topicPerformances[subject] ?? {};

      for (final entry in topics.entries) {
        final topicName = entry.key;
        final perf = entry.value;

        if (perf.questionCount < minQuestionsForAnalysis) continue;

        final successRate = perf.correctCount / perf.questionCount;
        final topicInfo = TopicInfo(
          subject: subject,
          topic: topicName,
          successRate: successRate,
          questionCount: perf.questionCount,
          correctCount: perf.correctCount,
          wrongCount: perf.wrongCount,
        );

        if (successRate < criticalThreshold) {
          criticalTopics.add(topicInfo);
        } else if (successRate < weakThreshold) {
          weakTopics.add(topicInfo);
        } else if (successRate < moderateThreshold) {
          moderateTopics.add(topicInfo);
        } else {
          strongTopics.add(topicInfo);
        }
      }
    }

    // Öncelik sıralaması: başarı oranı düşük + soru sayısı fazla olanlar önce
    criticalTopics.sort((a, b) {
      final scoreA = a.successRate - (a.questionCount * 0.01);
      final scoreB = b.successRate - (b.questionCount * 0.01);
      return scoreA.compareTo(scoreB);
    });

    weakTopics.sort((a, b) => a.successRate.compareTo(b.successRate));

    // Test performansı
    final avgNet = tests.isEmpty ? 0.0 :
        tests.fold<double>(0.0, (sum, test) => sum + test.totalNet) / tests.length;

    final recentTests = tests.length > 5 ? tests.sublist(0, 5) : tests;
    final recentAvg = recentTests.isEmpty ? 0.0 :
        recentTests.fold<double>(0.0, (sum, test) => sum + test.totalNet) / recentTests.length;

    final trend = tests.length >= 3 ? _calculateTrend(tests.take(3).toList()) : 0.0;

    return PerformanceAnalysis(
      criticalTopics: criticalTopics,
      weakTopics: weakTopics,
      moderateTopics: moderateTopics,
      strongTopics: strongTopics,
      averageNet: avgNet,
      recentAverageNet: recentAvg,
      trend: trend,
      totalTests: tests.length,
    );
  }

  /// Trend hesapla (pozitif = yükseliş, negatif = düşüş)
  static double _calculateTrend(List<TestModel> recentTests) {
    if (recentTests.length < 2) return 0.0;

    final first = recentTests.last.totalNet;
    final last = recentTests.first.totalNet;

    return last - first;
  }

  /// Toplam haftalık çalışma saati
  static int _calculateTotalHours(Map<String, List<String>> availability) {
    int total = 0;
    for (final slots in availability.values) {
      total += slots.length * 2; // Her slot 2 saat
    }
    return total;
  }

  /// Akıllı günlük plan oluştur
  static List<Map<String, dynamic>> _createSmartDailyPlans({
    required Map<String, List<String>> availableSlots,
    required PerformanceAnalysis analysis,
    required ExamType examType,
    required double intensityMultiplier,
    required int daysUntilExam,
    required int totalWeeklyHours,
  }) {
    final days = ['Pazartesi', 'Salı', 'Çarşamba', 'Perşembe', 'Cuma', 'Cumartesi', 'Pazar'];
    final dailyPlans = <Map<String, dynamic>>[];

    // Konu dağılımı planla
    final topicDistribution = _planTopicDistribution(
      analysis: analysis,
      totalHours: totalWeeklyHours,
      daysUntilExam: daysUntilExam,
    );

    int topicIndex = 0;
    int dayCount = 0;

    for (final day in days) {
      final slots = availableSlots[day] ?? [];
      final isWeekend = day == 'Cumartesi' || day == 'Pazar';

      if (slots.isEmpty) {
        // Boş gün - hafif öneriler
        dailyPlans.add({
          'day': day,
          'schedule': [
            {
              'id': '${day}_rest',
              'time': 'Esnek',
              'activity': isWeekend ? 'Hafta sonu dinlenme' : 'İsteğe bağlı kısa tekrar',
              'type': 'rest',
            }
          ],
        });
      } else {
        // Aktif çalışma günü
        final schedule = _createDaySchedule(
          day: day,
          slots: slots,
          dayIndex: dayCount,
          topicDistribution: topicDistribution,
          topicIndexRef: topicIndex,
          analysis: analysis,
          isWeekend: isWeekend,
          daysUntilExam: daysUntilExam,
          intensityMultiplier: intensityMultiplier,
        );

        dailyPlans.add({
          'day': day,
          'schedule': schedule,
        });

        dayCount++;
        topicIndex = (topicIndex + slots.length * 2) % (topicDistribution.length + 1);
      }
    }

    return dailyPlans;
  }

  /// Konu dağılım planı oluştur
  static List<StudyBlock> _planTopicDistribution({
    required PerformanceAnalysis analysis,
    required int totalHours,
    required int daysUntilExam,
  }) {
    final blocks = <StudyBlock>[];

    // Kritik konular - %50 oranında
    final criticalCount = (totalHours * 0.5).floor();
    for (var i = 0; i < criticalCount && i < analysis.criticalTopics.length * 2; i++) {
      final topic = analysis.criticalTopics[i % analysis.criticalTopics.length];
      blocks.add(StudyBlock(
        subject: topic.subject,
        topic: topic.topic,
        type: i % 2 == 0 ? 'Konu Anlatımı' : 'Soru Çözümü',
        priority: 'critical',
      ));
    }

    // Zayıf konular - %30 oranında
    final weakCount = (totalHours * 0.3).floor();
    for (var i = 0; i < weakCount && i < analysis.weakTopics.length * 2; i++) {
      final topic = analysis.weakTopics[i % analysis.weakTopics.length];
      blocks.add(StudyBlock(
        subject: topic.subject,
        topic: topic.topic,
        type: 'Soru Çözümü',
        priority: 'weak',
      ));
    }

    // Test çözümü ve pekiştirme - %20 oranında
    final testCount = (totalHours * 0.2).floor();
    for (var i = 0; i < testCount; i++) {
      if (daysUntilExam < 60) {
        blocks.add(StudyBlock(
          subject: 'Genel',
          topic: 'Deneme Sınavı',
          type: 'Test Çözümü',
          priority: 'test',
        ));
      } else if (analysis.moderateTopics.isNotEmpty) {
        final topic = analysis.moderateTopics[i % analysis.moderateTopics.length];
        blocks.add(StudyBlock(
          subject: topic.subject,
          topic: topic.topic,
          type: 'Pekiştirme',
          priority: 'moderate',
        ));
      }
    }

    return blocks;
  }

  /// Günlük program oluştur
  static List<Map<String, dynamic>> _createDaySchedule({
    required String day,
    required List<String> slots,
    required int dayIndex,
    required List<StudyBlock> topicDistribution,
    required int topicIndexRef,
    required PerformanceAnalysis analysis,
    required bool isWeekend,
    required int daysUntilExam,
    required double intensityMultiplier,
  }) {
    final schedule = <Map<String, dynamic>>[];
    int topicIndex = topicIndexRef;

    for (int slotIdx = 0; slotIdx < slots.length; slotIdx++) {
      final slot = slots[slotIdx];
      final times = slot.split('-');
      if (times.length != 2) continue;

      final startTime = times[0].trim();
      int currentMinute = 0;

      // 2 saatlik slot = 4 x 25 dakika çalışma bloğu + molalar
      final blockCount = intensityMultiplier >= 1.2 ? 4 : 3;

      for (int blockIdx = 0; blockIdx < blockCount; blockIdx++) {
        if (topicIndex < topicDistribution.length) {
          final block = topicDistribution[topicIndex];

          schedule.add({
            'id': '${day}_${slotIdx}_$blockIdx',
            'time': _addMinutes(startTime, currentMinute),
            'activity': '${block.subject} • ${block.topic}',
            'type': block.priority,
          });

          currentMinute += 25;
          topicIndex++;

          // Mola (son bloktan sonra değil)
          if (blockIdx < blockCount - 1) {
            currentMinute += 5;
          }
        }
      }

      // Slot sonu değerlendirme
      if (slotIdx == slots.length - 1 && schedule.isNotEmpty) {
        schedule.add({
          'id': '${day}_${slotIdx}_review',
          'time': _addMinutes(startTime, currentMinute),
          'activity': 'Günlük Değerlendirme',
          'type': 'review',
        });
      }
    }

    return schedule;
  }

  /// Tempo çarpanı belirle
  static double _getIntensityMultiplier(String pacing) {
    switch (pacing.toLowerCase()) {
      case 'relaxed':
        return 0.8;
      case 'intense':
        return 1.2;
      default: // moderate
        return 1.0;
    }
  }

  /// Saat stringine dakika ekle
  static String _addMinutes(String time, int minutes) {
    try {
      final parts = time.split(':');
      if (parts.length != 2) return time;

      final hours = int.parse(parts[0]);
      final mins = int.parse(parts[1]);

      final totalMinutes = hours * 60 + mins + minutes;
      final newHours = (totalMinutes ~/ 60) % 24;
      final newMins = totalMinutes % 60;

      return '${newHours.toString().padLeft(2, '0')}:${newMins.toString().padLeft(2, '0')}';
    } catch (e) {
      return time;
    }
  }

  /// Akıllı motivasyon mesajı
  static String _generateSmartMotivation(PerformanceAnalysis analysis, int daysUntilExam) {
    if (daysUntilExam < 30) {
      if (analysis.trend > 5) {
        return 'Sınava yaklaşırken performansın yükseliyor! Bu tempoyu koruyarak hedefe ulaşacaksın. 🎯';
      } else if (analysis.trend < -5) {
        return 'Son sprint zamanı! Odaklan ve bu hafta kritik konularını güçlendir. 💪';
      }
      return 'Sınava az kaldı! Planına sadık kalarak son hazırlıklarını tamamla. 🚀';
    }

    if (analysis.criticalTopics.isEmpty && analysis.weakTopics.isEmpty) {
      return 'Tebrikler! Tüm konularda güçlü performans gösteriyorsun. Test çözümüne devam et. 🌟';
    }

    if (analysis.criticalTopics.length > 5) {
      return 'Kritik konulara odaklanma zamanı. Sabırlı ve düzenli çalışarak her gün ilerliyorsun. 📚';
    }

    if (analysis.trend > 0) {
      return 'Performansın sürekli yükseliyor! Bu planla zayıf konularını güçlendireceğiz. 📈';
    }

    return 'Her gün biraz daha güçleniyorsun. Planına güven ve devam et! 💪';
  }

  /// Strateji odağı belirle
  static String _determineStrategyFocus(
    PerformanceAnalysis analysis,
    int daysUntilExam,
    int totalWeeklyHours,
  ) {
    final criticalCount = analysis.criticalTopics.length;
    final weeklyHoursText = '$totalWeeklyHours saat';

    if (daysUntilExam < 30) {
      return 'Sınava $daysUntilExam gün kaldı! Bu hafta $weeklyHoursText çalışma planlandı. '
             'Deneme sınavları ve hızlı tekrarlara ağırlık veriyoruz.';
    }

    if (criticalCount > 3) {
      return 'Bu hafta $weeklyHoursText içinde $criticalCount kritik konuya yoğunlaşacaksın. '
             'Her konu için önce anlatım sonra soru çözümü yapacağız.';
    }

    if (analysis.weakTopics.length > 5) {
      return 'Haftalık $weeklyHoursText planında zayıf konularını güçlendirmeye odaklanıyoruz. '
             'Soru çözümü ve pekiştirme ağırlıklı çalışma yapacaksın.';
    }

    if (analysis.averageNet > 60) {
      return 'Güçlü performansını sürdürmek için $weeklyHoursText içinde test çözümü ve '
             'hız geliştirme çalışmaları yapacaksın.';
    }

    return 'Bu hafta $weeklyHoursText dengeli bir plan ile hem eksiklerini kapatacak '
           'hem de güçlü yönlerini pekiştireceksin.';
  }

  /// Sınava kalan gün sayısı
  static int _getDaysUntilExam(ExamType examType) {
    final now = DateTime.now();
    DateTime? examDate;

    switch (examType) {
      case ExamType.yks:
        final year = now.month >= 6 ? now.year + 1 : now.year;
        examDate = DateTime(year, 6, 7);
        break;
      case ExamType.lgs:
        final year = now.month >= 6 ? now.year + 1 : now.year;
        examDate = DateTime(year, 6, 7);
        break;
      case ExamType.kpssLisans:
      case ExamType.kpssOnlisans:
      case ExamType.kpssOrtaogretim:
        final year = now.month >= 7 ? now.year + 1 : now.year;
        examDate = DateTime(year, 7, 15);
        break;
      case ExamType.ags:
        final year = now.month >= 7 ? now.year + 1 : now.year;
        examDate = DateTime(year, 7, 20);
        break;
    }

    return examDate?.difference(now).inDays.clamp(1, 365) ?? 180;
  }
}

/// Performans analiz sonucu
class PerformanceAnalysis {
  final List<TopicInfo> criticalTopics;
  final List<TopicInfo> weakTopics;
  final List<TopicInfo> moderateTopics;
  final List<TopicInfo> strongTopics;
  final double averageNet;
  final double recentAverageNet;
  final double trend;
  final int totalTests;

  PerformanceAnalysis({
    required this.criticalTopics,
    required this.weakTopics,
    required this.moderateTopics,
    required this.strongTopics,
    required this.averageNet,
    required this.recentAverageNet,
    required this.trend,
    required this.totalTests,
  });
}

/// Konu bilgisi
class TopicInfo {
  final String subject;
  final String topic;
  final double successRate;
  final int questionCount;
  final int correctCount;
  final int wrongCount;

  TopicInfo({
    required this.subject,
    required this.topic,
    required this.successRate,
    required this.questionCount,
    required this.correctCount,
    required this.wrongCount,
  });
}

/// Çalışma bloğu
class StudyBlock {
  final String subject;
  final String topic;
  final String type;
  final String priority;

  StudyBlock({
    required this.subject,
    required this.topic,
    required this.type,
    required this.priority,
  });
}

