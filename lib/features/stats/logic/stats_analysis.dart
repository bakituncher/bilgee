// lib/features/stats/logic/stats_analysis.dart
import 'dart:math';
import 'package:collection/collection.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:taktik/data/models/exam_model.dart';
import 'package:taktik/data/models/test_model.dart';
import 'package:taktik/data/models/user_model.dart';
import 'package:taktik/core/theme/app_theme.dart';
import 'package:taktik/data/models/performance_summary.dart';
import 'package:taktik/data/models/topic_performance_model.dart';
import 'package:taktik/data/repositories/firestore_service.dart';

class TacticalAdvice {
  final String text;
  final IconData icon;
  final Color color;
  TacticalAdvice(this.text, {required this.icon, required this.color});
}

class SubjectAnalysis {
  final String subjectName;
  final double averageNet;
  final double bestNet;
  final double worstNet;
  final double trend;
  final int questionCount;
  final double penaltyCoefficient;
  final List<TestModel> subjectTests;
  final List<FlSpot> netSpots;

  SubjectAnalysis({
    required this.subjectName,
    required this.averageNet,
    required this.bestNet,
    required this.worstNet,
    required this.trend,
    required this.questionCount,
    required this.penaltyCoefficient,
    required this.subjectTests,
    required this.netSpots,
  });
}

class StatsAnalysis {
  final List<TestModel> tests;
  final Exam examData;
  final FirestoreService firestoreService;
  final UserModel? user;

  late List<TestModel> sortedTests;
  late List<FlSpot> netSpots;
  late double warriorScore;
  late double accuracy;
  late double consistency;
  late double trend;
  late Map<String, double> subjectAverages;
  late List<MapEntry<String, double>> sortedSubjects;
  late List<TacticalAdvice> tacticalAdvice;
  late double averageNet;
  late String weakestSubjectByNet;
  late String strongestSubjectByNet;
  late PerformanceSummary performanceSummary;

  StatsAnalysis(this.tests, this.examData, this.firestoreService, {this.user}) {

    // Calculate performanceSummary from tests
    performanceSummary = _calculatePerformanceFromTests();

    if (tests.isEmpty && performanceSummary.topicPerformances.isEmpty) {
      _initializeEmpty();
      return;
    }

    if(tests.isNotEmpty) {
      sortedTests = List.from(tests)..sort((a, b) => a.date.compareTo(b.date));
      final allNets = sortedTests.map((t) => t.totalNet).toList();
      averageNet = allNets.average;
      final totalQuestionsAttempted = sortedTests.map((t) => t.totalCorrect + t.totalWrong).sum;
      final totalCorrectAnswers = sortedTests.map((t) => t.totalCorrect).sum;
      if (averageNet.abs() > 0.001) {
        final double stdDev = sqrt(allNets.map((n) => pow(n - averageNet, 2)).sum / allNets.length);
        consistency = max(0, (1 - (stdDev / averageNet.abs())) * 100);
      } else {
        consistency = 0.0;
      }
      accuracy = totalQuestionsAttempted > 0 ? (totalCorrectAnswers / totalQuestionsAttempted) * 100 : 0.0;
      trend = _calculateTrend(allNets);
      netSpots = List.generate(sortedTests.length, (i) => FlSpot(i.toDouble(), sortedTests[i].totalNet));
      final totalQuestionsInFirstTest = sortedTests.first.totalQuestions;
      final netComponent = (totalQuestionsInFirstTest > 0)
          ? (averageNet / (totalQuestionsInFirstTest * 1.0)) * 50
          : 0.0;
      final accuracyComponent = (accuracy / 100) * 25;
      final consistencyComponent = (consistency / 100) * 15;
      final trendComponent = (atan(trend) / (pi / 2)) * 10;
      warriorScore = (netComponent + accuracyComponent + consistencyComponent + trendComponent).clamp(0, 100);
      final subjectNets = <String, List<double>>{};
      for (var test in sortedTests) {
        test.scores.forEach((subject, scores) {
          final net = (scores['dogru'] ?? 0) - ((scores['yanlis'] ?? 0) * test.penaltyCoefficient);
          subjectNets.putIfAbsent(subject, () => []).add(net);
        });
      }

      if (subjectNets.isNotEmpty) {
        subjectAverages = subjectNets.map((subject, nets) => MapEntry(subject, nets.average));
        sortedSubjects = subjectAverages.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
        weakestSubjectByNet = sortedSubjects.last.key;
        strongestSubjectByNet = sortedSubjects.first.key;
      } else {
        _initializeEmptySubjects();
      }
      tacticalAdvice = _generateTacticalAdvice();
    } else {
      _initializeEmptyFromTopics();
    }
  }

  // YENI: Özet veriden minimal StatsAnalysis oluşturur
  factory StatsAnalysis.fromSummary(
      Map<String, dynamic> data,
      Exam examData,
      FirestoreService firestoreService, {
        UserModel? user,
      }) {
    final analysis = StatsAnalysis(
      const <TestModel>[],
      examData,
      firestoreService,
      user: user,
    );
    // Varsayılan boşları oluşturduktan sonra özet alanları üzerine yaz
    analysis.averageNet = (data['averageNet'] as num?)?.toDouble() ?? 0.0;
    analysis.trend = (data['trend'] as num?)?.toDouble() ?? 0.0;
    analysis.warriorScore = (data['warriorScore'] as num?)?.toDouble() ?? 0.0;
    analysis.weakestSubjectByNet = (data['weakestSubjectByNet'] as String?) ?? 'Belirlenemedi';
    analysis.strongestSubjectByNet = (data['strongestSubjectByNet'] as String?) ?? 'Belirlenemedi';
    // Diğer alanları minimal tut
    analysis.accuracy = 0.0;
    analysis.consistency = 0.0;
    analysis.subjectAverages = {};
    analysis.sortedSubjects = [];
    analysis.sortedTests = const <TestModel>[];
    analysis.netSpots = const <FlSpot>[];
    analysis.tacticalAdvice = const <TacticalAdvice>[];
    return analysis;
  }

  PerformanceSummary _calculatePerformanceFromTests() {
    if (tests.isEmpty) return const PerformanceSummary();

    final Map<String, Map<String, dynamic>> topicPerformances = {};
    final Set<String> masteredTopics = {};

    // Iterate through all tests and accumulate topic performance data
    for (final test in tests) {
      // Her test için kendi bölümünü bul
      final testSection = examData.sections.firstWhereOrNull(
              (s) => s.name == test.sectionName
      );

      if (testSection == null) {
        debugPrint('StatsAnalysis Hata: ${test.sectionName} bölümü examData içinde bulunamadı.');
        continue; // Bu testi atla, diğerlerine devam et
      }

      test.scores.forEach((subjectName, scores) {
        // Bu dersin testin kendi bölümünde olup olmadığını kontrol et
        final SubjectDetails? subjectDetails = testSection.subjects[subjectName];

        if (subjectDetails == null) {
          // Bu ders bu bölümde yok, muhtemelen yanlış kaydedilmiş, atla
          return;
        }

        final sanitizedSubject = firestoreService.sanitizeKey(subjectName);

        final correct = scores['dogru'] ?? 0;
        final wrong = scores['yanlis'] ?? 0;

        // For now, distribute performance across all topics in the subject
        // This is a simplified approach since test data doesn't track per-topic performance
        for (final topic in subjectDetails.topics) {
          final sanitizedTopic = firestoreService.sanitizeKey(topic.name);

          topicPerformances.putIfAbsent(sanitizedSubject, () => {});

          if (!topicPerformances[sanitizedSubject]!.containsKey(sanitizedTopic)) {
            topicPerformances[sanitizedSubject]![sanitizedTopic] = {
              'correctCount': 0,
              'wrongCount': 0,
              'questionCount': 0,
            };
          }

          // Distribute subject performance across topics proportionally
          final topicCount = subjectDetails.topics.length;
          final topicCorrect = (correct / topicCount).round();
          final topicWrong = (wrong / topicCount).round();
          final topicQuestions = topicCorrect + topicWrong;

          topicPerformances[sanitizedSubject]![sanitizedTopic]['correctCount'] += topicCorrect;
          topicPerformances[sanitizedSubject]![sanitizedTopic]['wrongCount'] += topicWrong;
          topicPerformances[sanitizedSubject]![sanitizedTopic]['questionCount'] += topicQuestions;
        }
      });
    }

    // Convert to TopicPerformanceModel objects
    final Map<String, Map<String, TopicPerformanceModel>> convertedPerformances = {};
    topicPerformances.forEach((subject, topics) {
      convertedPerformances[subject] = {};
      topics.forEach((topic, data) {
        convertedPerformances[subject]![topic] = TopicPerformanceModel(
          correctCount: data['correctCount'],
          wrongCount: data['wrongCount'],
          questionCount: data['questionCount'],
        );
      });
    });

    return PerformanceSummary(
      topicPerformances: convertedPerformances,
      masteredTopics: masteredTopics.toList(),
    );
  }

  double _calculateTrend(List<double> data) {
    if (data.length < 2) return 0.0;
    final n = data.length;
    final sumX = (n * (n - 1)) / 2;
    final sumY = data.sum;
    final sumXY = List.generate(n, (i) => i * data[i]).sum;
    final sumX2 = List.generate(n, (i) => i * i).sum;
    final numerator = (n * sumXY) - (sumX * sumY);
    final denominator = (n * sumX2) - (sumX * sumX);
    return denominator == 0 ? 0.0 : numerator / denominator;
  }

  SubjectAnalysis getAnalysisForSubject(String subjectName) {
    final subjectTests = sortedTests.where((t) => t.scores.containsKey(subjectName)).toList();
    if (subjectTests.isEmpty) {
      return SubjectAnalysis(subjectName: subjectName, averageNet: 0, bestNet: 0, worstNet: 0, trend: 0, questionCount: 0, penaltyCoefficient: 0.25, subjectTests: [], netSpots: []);
    }

    final subjectNets = subjectTests.map((t) {
      final scores = t.scores[subjectName]!;
      return (scores['dogru'] ?? 0) - ((scores['yanlis'] ?? 0) * t.penaltyCoefficient);
    }).toList();

    final netSpots = List.generate(subjectNets.length, (i) => FlSpot(i.toDouble(), subjectNets[i]));

    return SubjectAnalysis(
      subjectName: subjectName,
      averageNet: subjectNets.average,
      bestNet: subjectNets.reduce(max),
      worstNet: subjectNets.reduce(min),
      trend: _calculateTrend(subjectNets),
      questionCount: getQuestionCountForSubject(subjectName),
      penaltyCoefficient: subjectTests.first.penaltyCoefficient,
      subjectTests: subjectTests,
      netSpots: netSpots,
    );
  }

  List<TacticalAdvice> _generateTacticalAdvice() {
    final adviceList = <TacticalAdvice>[];
    if (sortedSubjects.isEmpty || sortedTests.isEmpty) return adviceList;

    // 1. GENEL DURUM ANALİZİ
    _addPerformanceStatusAdvice(adviceList);

    // 2. TUTARLILIK ANALİZİ
    _addConsistencyAdvice(adviceList);

    // 3. TREND ANALİZİ (Son 5 test)
    _addTrendAdvice(adviceList);

    // 4. DOĞRULUK ANALİZİ
    _addAccuracyAdvice(adviceList);

    // 5. ZAYIF DERS STRATEJİSİ
    _addWeakSubjectStrategy(adviceList);

    // 6. GÜÇLÜ DERS OPTİMİZASYONU
    _addStrongSubjectOptimization(adviceList);

    // 7. DENGELI GELİŞİM ÖNERİSİ
    _addBalancedDevelopmentAdvice(adviceList);

    return adviceList;
  }

  void _addPerformanceStatusAdvice(List<TacticalAdvice> adviceList) {
    if (warriorScore >= 85) {
      adviceList.add(TacticalAdvice(
        "🏆 MÜKEMMEL PERFORMANS: Savaşçı skorun ${warriorScore.toStringAsFixed(0)}/100. Üst düzey bir sınav performansı sergiliyorsun. Bu tempoyu koru ve zirvede kal!",
        icon: Icons.workspace_premium,
        color: Colors.amber,
      ));
    } else if (warriorScore >= 70) {
      adviceList.add(TacticalAdvice(
        "💪 ÇOK İYİ SEVİYE: Savaşçı skorun ${warriorScore.toStringAsFixed(0)}/100. Sağlam bir performans gösteriyorsun. Tutarlılık ve doğruluğu artırarak zirveye çıkabilirsin.",
        icon: Icons.trending_up,
        color: const Color(0xFF34D399),
      ));
    } else if (warriorScore >= 50) {
      adviceList.add(TacticalAdvice(
        "📈 GELİŞİM AŞAMASINDA: Savaşçı skorun ${warriorScore.toStringAsFixed(0)}/100. İyi bir temele sahipsin. Zayıf derslerine odaklanarak hızla gelişebilirsin.",
        icon: Icons.show_chart,
        color: Colors.orange,
      ));
    } else {
      adviceList.add(TacticalAdvice(
        "🎯 YENİ BAŞLANGIÇ: Savaşçı skorun ${warriorScore.toStringAsFixed(0)}/100. Her sınav bir öğrenme fırsatı. Düzenli çalışma ve doğru strateji ile hızla gelişeceksin.",
        icon: Icons.rocket_launch,
        color: Colors.blue,
      ));
    }
  }

  void _addConsistencyAdvice(List<TacticalAdvice> adviceList) {
    if (consistency >= 80) {
      adviceList.add(TacticalAdvice(
        "🎯 ÜSTÜN TUTARLILIK: Netlerin çok istikrarlı (%${consistency.toStringAsFixed(0)}). Bu, sınav gününde de performansını koruyacağın anlamına geliyor. Mükemmel!",
        icon: Icons.verified,
        color: Colors.green,
      ));
    } else if (consistency >= 60) {
      adviceList.add(TacticalAdvice(
        "⚖️ ORTA SEVİYE TUTARLILIK: Netlerin kabul edilebilir düzeyde istikrarlı (%${consistency.toStringAsFixed(0)}). Benzer koşullarda düzenli deneme çözerek tutarlılığı artırabilirsin.",
        icon: Icons.balance,
        color: Colors.blue,
      ));
    } else if (consistency >= 40) {
      adviceList.add(TacticalAdvice(
        "📊 DEĞİŞKEN PERFORMANS: Netlerin çok dalgalı (%${consistency.toStringAsFixed(0)}). Sabit bir çalışma rutini oluştur, benzer zorluktaki denemeleri düzenli çöz.",
        icon: Icons.waves,
        color: Colors.orange,
      ));
    } else {
      adviceList.add(TacticalAdvice(
        "⚠️ İSTİKRAR GEREKİYOR: Netlerin çok değişken (%${consistency.toStringAsFixed(0)}). Temel konuları sağlamlaştır, her gün aynı saatte ve sakin ortamda çalış.",
        icon: Icons.warning_amber,
        color: Colors.red,
      ));
    }
  }

  void _addTrendAdvice(List<TacticalAdvice> adviceList) {
    if (sortedTests.length < 3) return;

    // Son 5 testin trendini hesapla
    final recentTests = sortedTests.length > 5 ? sortedTests.sublist(sortedTests.length - 5) : sortedTests;
    final recentNets = recentTests.map((t) => t.totalNet).toList();
    final recentTrend = _calculateTrend(recentNets);

    if (recentTrend > 0.5) {
      adviceList.add(TacticalAdvice(
        "🚀 HIZLI YÜKSELİŞ: Son ${recentTests.length} denemede güçlü bir artış var (+${recentTrend.toStringAsFixed(2)} net/deneme). Çalışma yöntemin işe yarıyor, bu tempoyu sürdür!",
        icon: Icons.trending_up,
        color: Colors.green,
      ));
    } else if (recentTrend > 0.1) {
      adviceList.add(TacticalAdvice(
        "📈 İSTİKRARLI İLERLEME: Son ${recentTests.length} denemede düzenli artış var (+${recentTrend.toStringAsFixed(2)} net/deneme). Sabırlı ve planlı çalışma meyvesini veriyor.",
        icon: Icons.show_chart,
        color: Colors.teal,
      ));
    } else if (recentTrend > -0.1) {
      adviceList.add(TacticalAdvice(
        "➡️ PLATO DÖNEMİ: Son ${recentTests.length} denemede net değişim yok. Yeni çalışma teknikleri dene, farklı kaynaklardan sorular çöz.",
        icon: Icons.horizontal_rule,
        color: Colors.grey,
      ));
    } else if (recentTrend > -0.5) {
      adviceList.add(TacticalAdvice(
        "⚠️ HAFİF DÜŞÜŞ: Son ${recentTests.length} denemede küçük bir düşüş var (${recentTrend.toStringAsFixed(2)} net/deneme). Çalışma programını gözden geçir, dinlenmeye önem ver.",
        icon: Icons.trending_down,
        color: Colors.orange,
      ));
    } else {
      adviceList.add(TacticalAdvice(
        "🔴 DİKKAT GEREKİYOR: Son ${recentTests.length} denemede belirgin düşüş var (${recentTrend.toStringAsFixed(2)} net/deneme). Temel konuları tekrar et, hocalarından yardım al.",
        icon: Icons.warning,
        color: Colors.red,
      ));
    }
  }

  void _addAccuracyAdvice(List<TacticalAdvice> adviceList) {
    if (accuracy >= 85) {
      adviceList.add(TacticalAdvice(
        "🎯 YÜKSEK İSABET: Doğruluk oranın %${accuracy.toStringAsFixed(0)}. Bildiğin sorularda neredeyse hata yapmıyorsun. Şimdi bilgi dağarcığını genişletmeye odaklan.",
        icon: Icons.gps_fixed,
        color: Colors.green,
      ));
    } else if (accuracy >= 70) {
      adviceList.add(TacticalAdvice(
        "✅ İYİ İSABET: Doğruluk oranın %${accuracy.toStringAsFixed(0)}. Bildiğin konularda genelde doğru yapıyorsun. Dikkatsiz hatalarını azaltmaya çalış.",
        icon: Icons.check_circle,
        color: Colors.teal,
      ));
    } else if (accuracy >= 55) {
      adviceList.add(TacticalAdvice(
        "⚡ GELİŞTİRİLEBİLİR: Doğruluk oranın %${accuracy.toStringAsFixed(0)}. Bilmediğin sorulara rastgele cevap verme. 'Emin değilsen boş bırak' kuralını uygula.",
        icon: Icons.bolt,
        color: Colors.orange,
      ));
    } else {
      adviceList.add(TacticalAdvice(
        "🎲 STRATEJİ DEĞİŞİKLİĞİ: Doğruluk oranın %${accuracy.toStringAsFixed(0)}. Çok fazla şüpheli işaretleme yapıyorsun. Önce temel konuları sağlamlaştır, sonra deneme çöz.",
        icon: Icons.psychology,
        color: Colors.red,
      ));
    }
  }

  void _addWeakSubjectStrategy(List<TacticalAdvice> adviceList) {
    if (sortedSubjects.isEmpty) return;

    final weakest = sortedSubjects.last;
    final weakestNet = weakest.value;
    final weakestSubject = weakest.key;
    final average = subjectAverages.values.average;

    if (weakestNet < average * 0.7) {
      adviceList.add(TacticalAdvice(
        "🎯 ÖNCELİKLİ HEDEF: '$weakestSubject' dersinde ortalama ${weakestNet.toStringAsFixed(1)} net yapıyorsun. Bu, genel ortalamandan %${((1 - weakestNet/average) * 100).toStringAsFixed(0)} düşük. Günde 45 dakika sadece bu derse odaklan.",
        icon: Icons.my_location,
        color: Colors.red,
      ));
    } else if (weakestNet < average * 0.85) {
      adviceList.add(TacticalAdvice(
        "📚 GELİŞTİRME ALANI: '$weakestSubject' dersinde ${weakestNet.toStringAsFixed(1)} net yapıyorsun. Her gün 2-3 konu çalış ve 20 soru çöz. Bir ayda belirgin fark yaratabilirsin.",
        icon: Icons.auto_stories,
        color: Colors.orange,
      ));
    } else {
      adviceList.add(TacticalAdvice(
        "⚖️ DENGELEME: '$weakestSubject' dersin en düşük ama ortalamaya yakın (${weakestNet.toStringAsFixed(1)} net). Tüm derslerinde dengeli bir seviyedesin, aferin!",
        icon: Icons.balance,
        color: Colors.blue,
      ));
    }
  }

  void _addStrongSubjectOptimization(List<TacticalAdvice> adviceList) {
    if (sortedSubjects.isEmpty) return;

    final strongest = sortedSubjects.first;
    final strongestNet = strongest.value;
    final strongestSubject = strongest.key;
    final maxPossible = getQuestionCountForSubject(strongestSubject).toDouble();

    if (strongestNet >= maxPossible * 0.9) {
      adviceList.add(TacticalAdvice(
        "⭐ USTA SEVİYESİ: '$strongestSubject' dersinde ${strongestNet.toStringAsFixed(1)} net ile zirvedesin! Bu dersi haftada 2-3 deneme ile tazelemeye devam et, diğer derslere daha fazla zaman ayır.",
        icon: Icons.star,
        color: Colors.amber,
      ));
    } else if (strongestNet >= maxPossible * 0.75) {
      adviceList.add(TacticalAdvice(
        "💎 GÜÇLÜ YÖN: '$strongestSubject' dersinde ${strongestNet.toStringAsFixed(1)} net ile çok iyisin. Tam nete ulaşmak için zor sorulara odaklan ve hız çalış.",
        icon: Icons.diamond,
        color: Colors.purple,
      ));
    } else {
      adviceList.add(TacticalAdvice(
        "✨ EN İYİ DERSİN: '$strongestSubject' dersinde ${strongestNet.toStringAsFixed(1)} net ile en iyisin. Bu dersi sabitleştirmek için düzenli soru çöz.",
        icon: Icons.auto_awesome,
        color: Colors.blue,
      ));
    }
  }

  void _addBalancedDevelopmentAdvice(List<TacticalAdvice> adviceList) {
    if (sortedSubjects.length < 3) return;

    final highest = sortedSubjects.first.value;
    final lowest = sortedSubjects.last.value;
    final gap = highest - lowest;

    if (gap > 10) {
      adviceList.add(TacticalAdvice(
        "⚖️ DENGE STRATEJİSİ: Derslerin arası çok farkli (${gap.toStringAsFixed(1)} net fark). Her gün en az 15 dakika en zayıf dersine çalış. Dengeli gelişim, sınav başarısının anahtarıdır.",
        icon: Icons.balance_outlined,
        color: Colors.deepOrange,
      ));
    } else if (gap > 5) {
      adviceList.add(TacticalAdvice(
        "✅ KABUL EDİLEBİLİR DENGE: Dersler arası fark ${gap.toStringAsFixed(1)} net. Dengeli bir performans gösteriyorsun. Tüm dersleri düzenli çalışmaya devam et.",
        icon: Icons.check_circle_outline,
        color: Colors.green,
      ));
    } else {
      adviceList.add(TacticalAdvice(
        "🌟 MÜKEMMEL DENGE: Tüm derslerin birbirine çok yakın! (${gap.toStringAsFixed(1)} net fark). Dengeli çalışma yöntemin harika. Bu şekilde devam et.",
        icon: Icons.emoji_events,
        color: Colors.amber,
      ));
    }
  }

  List<Map<String, dynamic>> _getRankedTopics() {
    final List<Map<String, dynamic>> allTopics = [];
    final relevantSections = examData.sections;

    performanceSummary.topicPerformances.forEach((sanitizedSubjectKey, topics) {
      String originalSubjectName = "";
      SubjectDetails? subjectDetails;

      for (var section in relevantSections) {
        for (var entry in section.subjects.entries) {
          if (firestoreService.sanitizeKey(entry.key) == sanitizedSubjectKey) {
            originalSubjectName = entry.key;
            subjectDetails = entry.value;
            break;
          }
        }
        if (originalSubjectName.isNotEmpty) break;
      }
      if (originalSubjectName.isEmpty) return;

      final penalty = relevantSections
          .firstWhere((s) => s.subjects.containsKey(originalSubjectName))
          .penaltyCoefficient;

      topics.forEach((sanitizedTopicKey, performance) {
        final originalTopicName = subjectDetails?.topics
            .firstWhere((t) => firestoreService.sanitizeKey(t.name) == sanitizedTopicKey, orElse: () => SubjectTopic(name: ''))
            .name ?? '';
        if (originalTopicName.isEmpty) return;

        if (performance.questionCount > 3) {
          final mastery = (performance.correctCount - (performance.wrongCount * penalty)) / performance.questionCount;
          final weightedScore = mastery - (performance.questionCount / 1000);
          allTopics.add({
            'subject': originalSubjectName,
            'topic': originalTopicName,
            'mastery': mastery.clamp(0.0, 1.0),
            'weightedScore': weightedScore,
          });
        }
      });
    });

    allTopics.sort((a, b) => a['weightedScore'].compareTo(b['weightedScore']));
    return allTopics;
  }

  List<Map<String, dynamic>> getWorkshopSuggestions({int count = 3}) {
    final rankedTopics = _getRankedTopics();

    final unmasteredTopics = rankedTopics.where((topic) {
      final sanitizedSubject = firestoreService.sanitizeKey(topic['subject']);
      final sanitizedTopic = firestoreService.sanitizeKey(topic['topic']);
      final uniqueIdentifier = '$sanitizedSubject-$sanitizedTopic';
      return !(performanceSummary.masteredTopics.contains(uniqueIdentifier));
    }).toList();

    if (unmasteredTopics.isNotEmpty) {
      return unmasteredTopics.take(count).toList();
    }

    final suggestions = <Map<String, dynamic>>[];
    final random = Random();

    final primarySubjects = examData.sections.expand((s) => s.subjects.entries).toList();
    if (primarySubjects.isEmpty) return [];

    while (suggestions.length < count && primarySubjects.isNotEmpty) {
      final randomSubjectEntry = primarySubjects[random.nextInt(primarySubjects.length)];
      final subjectName = randomSubjectEntry.key;
      final subjectDetails = randomSubjectEntry.value;

      if (subjectDetails.topics.isNotEmpty) {
        final randomTopic = subjectDetails.topics[random.nextInt(subjectDetails.topics.length)];
        final alreadyExists = suggestions.any((s) => s['topic'] == randomTopic.name);
        if (!alreadyExists) {
          suggestions.add({
            'subject': subjectName,
            'topic': randomTopic.name,
            'mastery': -0.1,
            'isSuggestion': true,
          });
        }
      }
    }
    return suggestions;
  }

  Map<String, String>? getWeakestTopicWithDetails() {
    final ranked = _getRankedTopics();
    if (ranked.isNotEmpty) {
      final weakest = ranked.first;
      return {
        'subject': weakest['subject'].toString(),
        'topic': weakest['topic'].toString(),
      };
    }
    return null;
  }

  void _initializeEmptySubjects() {
    subjectAverages = {};
    sortedSubjects = [];
    weakestSubjectByNet = "Belirlenemedi";
    strongestSubjectByNet = "Belirlenemedi";
  }

  void _initializeEmpty() {
    sortedTests = [];
    netSpots = [];
    warriorScore = 0.0;
    accuracy = 0.0;
    consistency = 0.0;
    trend = 0.0;
    averageNet = 0.0;
    tacticalAdvice = [];
    _initializeEmptySubjects();
  }

  void _initializeEmptyFromTopics() {
    sortedTests = [];
    netSpots = [];
    warriorScore = 0.0;
    accuracy = 0.0;
    consistency = 0.0;
    trend = 0.0;
    averageNet = 0.0;
    tacticalAdvice = [];
    _initializeEmptySubjects();
  }

  int getQuestionCountForSubject(String subjectName) {
    if (tests.isEmpty) return 40;
    final sectionName = tests.first.sectionName;
    final section = examData.sections.firstWhere((s) => s.name == sectionName, orElse: () => examData.sections.first);
    return section.subjects[subjectName]?.questionCount ?? 40;
  }
}