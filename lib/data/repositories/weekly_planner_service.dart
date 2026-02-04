// lib/data/repositories/weekly_planner_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:taktik/data/models/exam_model.dart';
import 'package:taktik/data/models/performance_summary.dart';
import 'package:taktik/data/models/plan_document.dart';
import 'package:taktik/data/models/test_model.dart';
import 'package:taktik/data/models/user_model.dart';
import 'package:taktik/data/repositories/exam_schedule.dart';
import 'package:taktik/data/repositories/plan_revision_service.dart';

/// Haftalık çalışma planı oluşturma servisi
/// AI kullanmadan deterministik algoritma ile akıllı plan üretir
class WeeklyPlannerService {
  final FirebaseFirestore _firestore;
  final PlanRevisionService _revisionService;

  WeeklyPlannerService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _revisionService = PlanRevisionService();

  /// Ana fonksiyon: Kullanıcı için haftalık plan oluşturur
  Future<Map<String, dynamic>> generateWeeklyPlan({
    required UserModel user,
    required List<TestModel> tests,
    required PerformanceSummary performance,
    PlanDocument? existingPlan,
    required String pacing,
    String? revisionRequest,
  }) async {
    // Validasyonlar
    if (user.selectedExam == null) {
      throw PlannerException('Analiz için önce bir sınav seçmelisiniz.');
    }

    if (user.weeklyAvailability.values.every((list) => list.isEmpty)) {
      throw PlannerException(
        'Strateji oluşturmadan önce en az bir tane müsait zaman dilimi seçmelisiniz.',
      );
    }

    try {
      final examType = ExamType.values.byName(user.selectedExam!);
      final daysUntilExam = ExamSchedule.daysUntilExam(examType);

      // Tamamlanan görevleri yükle
      final completedTopicIds = await _loadCompletedTopics(user.id, days: 365);

      print('Tamamlanan Konu Sayısı: ${completedTopicIds.length}');

      // Revizyon analizi yap
      RevisionAnalysis? revisionAnalysis;
      String effectivePacing = pacing;

      if (revisionRequest != null && revisionRequest.trim().isNotEmpty) {
        revisionAnalysis = _revisionService.analyzeRevisionRequest(revisionRequest);

        // Tempo değişikliği varsa uygula
        effectivePacing = _revisionService.calculateNewPacing(pacing, revisionAnalysis);

        print('🔄 Revizyon Analizi:');
        print(revisionAnalysis.toString());
      }

      // Kullanıcının haftalık müsait slot sayısını hesapla
      final totalAvailableSlots = _calculateTotalWeeklySlots(user, effectivePacing);

      // YENİ: Deneme sınavlarından ders ağırlıklarını/önceliklerini hesapla
      final subjectPriorities = _calculateSubjectPrioritiesFromTests(tests);
      print('📊 Deneme Analizi Sonucu Öncelikler: $subjectPriorities');

      // Sıradaki çalışılacak konuları belirle (Önceliklere göre)
      var nextTopics = await _getNextTopicsToStudy(
        examType,
        user.selectedExamSection,
        completedTopicIds,
        performance,
        totalAvailableSlots,
        subjectPriorities, // Öncelik haritasını gönderiyoruz
      );

      // Revizyon analizi varsa konu listesini ayarla
      if (revisionAnalysis != null && revisionAnalysis.hasChanges) {
        nextTopics = _revisionService.adjustTopicList(
          originalTopics: nextTopics,
          analysis: revisionAnalysis,
          performance: performance,
          targetSlotCount: totalAvailableSlots,
        );

        print('✅ Konu listesi revizyona göre ayarlandı: ${nextTopics.length} konu');
      }

      // Haftalık programı oluştur
      final weeklyPlan = _buildWeeklySchedule(
        user: user,
        topics: nextTopics,
        pacing: effectivePacing,
        performance: performance,
        completedTopicIds: completedTopicIds,
        subjectPriorities: subjectPriorities, // Aktivite tipi belirlemek için gönderiyoruz
      );

      // Stratejiyi oluştur
      final strategy = _buildStrategyText(
        user: user,
        examType: examType,
        daysUntilExam: daysUntilExam,
        tests: tests,
        performance: performance,
        pacing: effectivePacing,
        revisionRequest: revisionRequest,
        revisionAnalysis: revisionAnalysis,
      );

      return {
        'weeklyPlan': weeklyPlan,
        'strategy': strategy,
        'createdAt': DateTime.now().toIso8601String(),
        'version': '2.3', // Deneme analizi ve akıllı aktivite atama eklendi
      };
    } catch (e) {
      if (e is PlannerException) rethrow;
      throw PlannerException('Plan oluşturulurken bir hata oluştu: ${e.toString()}');
    }
  }

  /// Deneme sonuçlarına göre ders önceliklerini hesaplar
  /// Düşük başarı = Negatif Puan (Yüksek Öncelik/Listenin Başı)
  /// Yüksek başarı = Nötr Puan (Normal/Genel Tekrar Modu)
  Map<String, double> _calculateSubjectPrioritiesFromTests(List<TestModel> tests) {
    if (tests.isEmpty) return {};

    // Ders bazında toplam doğru ve yanlışları topla
    final Map<String, Map<String, int>> aggregates = {};

    // Sadece son 5 denemeyi dikkate alarak güncel durumu yansıt
    final recentTests = tests.length > 5 ? tests.sublist(tests.length - 5) : tests;

    for (final test in recentTests) {
      test.scores.forEach((subject, stats) {
        if (!aggregates.containsKey(subject)) {
          aggregates[subject] = {'dogru': 0, 'toplam': 0};
        }

        final dogru = stats['dogru'] ?? 0;
        final yanlis = stats['yanlis'] ?? 0;
        final bos = stats['bos'] ?? 0;
        final toplam = dogru + yanlis + bos;

        aggregates[subject]!['dogru'] = aggregates[subject]!['dogru']! + dogru;
        aggregates[subject]!['toplam'] = aggregates[subject]!['toplam']! + toplam;
      });
    }

    // Başarı oranına göre öncelik puanı
    final Map<String, double> priorities = {};

    aggregates.forEach((subject, stats) {
      final toplam = stats['toplam']!;
      if (toplam < 10) return; // Çok az veri varsa yoksay

      final dogru = stats['dogru']!;
      final basariOrani = dogru / toplam;

      if (basariOrani < 0.30) {
        // %30 altı: Kritik Durum -> Çok yüksek öncelik (-200 puan)
        // Bu ders listenin en başına geçer.
        priorities[subject] = -200.0;
      } else if (basariOrani < 0.50) {
        // %30-%50 arası: Zayıf -> Yüksek öncelik (-150 puan)
        priorities[subject] = -150.0;
      } else if (basariOrani < 0.70) {
        // %50-%70 arası: Orta -> Hafif öncelik (-50 puan)
        priorities[subject] = -50.0;
      } else {
        // %70 üzeri: İyi -> Normal akış (0 puan)
        // Bu derste "Genel Tekrar" modu aktif olur.
        priorities[subject] = 0.0;
      }
    });

    return priorities;
  }

  /// Tamamlanan görev/konu ID'lerini yükler
  Future<Set<String>> _loadCompletedTopics(String userId, {int days = 365}) async {
    final startDate = DateTime.now().subtract(Duration(days: days));
    final snapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('user_activity')
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .get();

    final Set<String> completedIds = {};
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final tasks = data['completedDailyTasks'] as List<dynamic>?;
      if (tasks != null) {
        for (final task in tasks) {
          if (task is Map) {
            // 1. Doğrudan konu adı veya ID
            if (task['id'] != null) {
              final rawId = task['id'].toString();
              completedIds.add(rawId);

              // ID karmaşık bir yapıdaysa (örn: 09:00-11:00-Konu-0) içinden konu adını çek
              final extracted = _extractTopicFromId(rawId);
              if (extracted != rawId && extracted.isNotEmpty) {
                completedIds.add(extracted);
              }
            }
            // 2. Varsa açıkça belirtilmiş 'topic' alanı
            if (task['topic'] != null) {
              completedIds.add(task['topic'].toString());
            }
          } else if (task is String) {
            // String olarak kayıtlıysa hem kendisini hem de parse edilmiş halini ekle
            completedIds.add(task);
            final extracted = _extractTopicFromId(task);
            if (extracted != task && extracted.isNotEmpty) {
              completedIds.add(extracted);
            }
          }
        }
      }
    }
    return completedIds;
  }

  /// ID stringinden konu adını ayıklar
  String _extractTopicFromId(String id) {
    if (RegExp(r'^[a-zA-ZğüşıöçĞÜŞİÖÇ\s]+$').hasMatch(id)) return id;

    final parts = id.split('-');
    if (parts.length < 2) return id;

    final topicParts = parts.where((part) {
      if (RegExp(r'^\d{1,2}:\d{2}$').hasMatch(part)) return false;
      if (RegExp(r'^\d+$').hasMatch(part)) return false;
      return true;
    }).toList();

    if (topicParts.isEmpty) return id;
    return topicParts.join('-');
  }

  /// Kullanıcının haftalık toplam müsait slot sayısını hesaplar
  int _calculateTotalWeeklySlots(UserModel user, String pacing) {
    int totalSlots = 0;
    final fillRatio = _getFillRatio(pacing);

    user.weeklyAvailability.forEach((day, slots) {
      totalSlots += (slots.length * fillRatio).ceil();
    });

    return totalSlots;
  }

  /// Çalışılacak konuları öncelik sırasına göre belirler
  Future<List<StudyTopic>> _getNextTopicsToStudy(
      ExamType examType,
      String? selectedSection,
      Set<String> completedTopicIds,
      PerformanceSummary performance,
      int totalAvailableSlots,
      Map<String, double> subjectPriorities, // YENİ PARAMETRE
      ) async {
    final exam = await ExamData.getExamByType(examType);
    final sections = _getRelevantSections(exam, examType, selectedSection);

    final List<_ScoredTopic> scoredTopics = [];

    for (final section in sections) {
      section.subjects.forEach((subjectName, subjectDetails) {
        // Bu ders için denemelerden gelen genel bir öncelik ayarı var mı?
        final subjectPriorityAdjustment = subjectPriorities[subjectName] ?? 0.0;

        for (int i = 0; i < subjectDetails.topics.length; i++) {
          final topic = subjectDetails.topics[i];

          if (completedTopicIds.contains(topic.name) ||
              completedTopicIds.contains(topic.name.trim())) {
            continue;
          }

          // Öncelik puanı hesapla
          final priority = _calculateTopicPriority(
            topicName: topic.name,
            subjectName: subjectName,
            curriculumOrder: i,
            performance: performance,
            subjectPriorityAdjustment: subjectPriorityAdjustment, // YENİ
          );

          scoredTopics.add(_ScoredTopic(
            subject: subjectName,
            topic: topic.name,
            priority: priority,
            curriculumOrder: i,
          ));
        }
      });
    }

    // Önceliğe göre sırala (Düşük/Negatif puan en üstte)
    scoredTopics.sort((a, b) => a.priority.compareTo(b.priority));

    final neededTopicCount = ((totalAvailableSlots / 2) * 1.2).ceil();
    final finalTopicCount = neededTopicCount.clamp(10, scoredTopics.length);

    return scoredTopics
        .take(finalTopicCount)
        .map((st) => StudyTopic(subject: st.subject, topic: st.topic))
        .toList();
  }

  /// İlgili bölümleri döndürür
  List<ExamSection> _getRelevantSections(
      Exam exam,
      ExamType examType,
      String? selectedSection,
      ) {
    if (examType == ExamType.ags) {
      final sections = exam.sections.where((s) => s.name == 'AGS').toList();
      if (selectedSection != null && selectedSection.isNotEmpty) {
        sections.addAll(
          exam.sections.where((s) => s.name.toLowerCase() == selectedSection.toLowerCase()),
        );
      }
      return sections;
    } else if (examType == ExamType.yks) {
      final sections = exam.sections.where((s) => s.name == 'TYT').toList();
      if (selectedSection != null && selectedSection.isNotEmpty && selectedSection != 'TYT') {
        sections.addAll(
          exam.sections.where((s) => s.name.toLowerCase() == selectedSection.toLowerCase()),
        );
      }
      return sections;
    } else {
      return (selectedSection != null && selectedSection.isNotEmpty)
          ? exam.sections.where((s) => s.name.toLowerCase() == selectedSection.toLowerCase()).toList()
          : exam.sections;
    }
  }

  /// Konu için öncelik puanı hesaplar (düşük = daha öncelikli)
  double _calculateTopicPriority({
    required String topicName,
    required String subjectName,
    required int curriculumOrder,
    required PerformanceSummary performance,
    required double subjectPriorityAdjustment, // YENİ PARAMETRE
  }) {
    // Baz puan: Müfredat sırası
    double priority = curriculumOrder.toDouble();

    // Deneme sonuçlarına göre ders bazlı önceliği uygula
    // Eğer ders kötüyse priority değeri azalır ve konu en üste çıkar.
    priority += subjectPriorityAdjustment;

    final topicPerf = performance.topicPerformances[subjectName]?[topicName];

    if (topicPerf != null) {
      final attempts = topicPerf.correctCount + topicPerf.wrongCount;
      if (attempts > 5) {
        final accuracy = topicPerf.correctCount / attempts;
        // Zayıf konulara ekstra öncelik ver
        if (accuracy < 0.5) {
          priority -= 100; // Konu da zayıfsa daha da öne al
        } else if (accuracy < 0.7) {
          priority -= 50;
        }
      } else if (topicPerf.questionCount < 5) {
        priority -= 20; // Hiç çalışılmamış
      }
    } else {
      priority -= 10; // Veri yok
    }

    return priority;
  }

  /// Haftalık program oluşturur
  Map<String, dynamic> _buildWeeklySchedule({
    required UserModel user,
    required List<StudyTopic> topics,
    required String pacing,
    required PerformanceSummary performance,
    required Set<String> completedTopicIds,
    required Map<String, double> subjectPriorities, // YENİ PARAMETRE
  }) {
    if (topics.isEmpty) {
      return {
        'plan': [],
        'summary': 'Çalışılacak konu bulunamadı. Tüm konuları tamamlamış olabilirsiniz!',
      };
    }

    final trDays = ['Pazartesi', 'Salı', 'Çarşamba', 'Perşembe', 'Cuma', 'Cumartesi', 'Pazar'];
    final todayIndex = DateTime.now().weekday - 1;

    final List<String> orderedDays = [];
    for (int i = 0; i < 7; i++) {
      orderedDays.add(trDays[(todayIndex + i) % 7]);
    }

    final examType = ExamType.values.byName(user.selectedExam!);
    final trialExams = _getTrialExamsForWeek(examType, user.selectedExamSection);
    final fillRatio = _getFillRatio(pacing);

    final List<Map<String, dynamic>> plan = [];
    int globalTopicIndex = 0;
    int slotCountForCurrentTopic = 0;
    final Set<String> usedTopics = {};

    final trialDayIndices = _findBestTrialDays(orderedDays, user.weeklyAvailability, trialExams);

    for (int dayIdx = 0; dayIdx < orderedDays.length; dayIdx++) {
      final day = orderedDays[dayIdx];
      final availability = user.weeklyAvailability[day] ?? [];
      if (availability.isEmpty) {
        plan.add({
          'day': day,
          'schedule': [],
          'focus': 'Dinlenme Günü'
        });
        continue;
      }

      final targetSlotCount = (availability.length * fillRatio).ceil();
      final actualSlotCount = targetSlotCount > availability.length ? availability.length : targetSlotCount;
      final dayActivities = <Map<String, String>>[];
      final trialExamForToday = trialDayIndices[dayIdx];

      if (trialExamForToday != null) {
        // Deneme Sınavı Günü
        final trialSlotCount = trialExamForToday['slotsNeeded'] as int;
        final availableSlotsForTrial = actualSlotCount.clamp(0, trialSlotCount);

        for (int i = 0; i < availableSlotsForTrial && i < availability.length; i++) {
          final slot = availability[i];
          dayActivities.add({
            'time': slot,
            'activity': '${trialExamForToday['name']} - Deneme Sınavı ${i == 0 ? '(Çözüm)' : i == trialSlotCount - 1 ? '(Analiz)' : '(Devam)'}',
            'id': '$slot-trial-exam-$i',
          });
        }

        // Kalan slotlara normal çalışma
        for (int slotIdx = availableSlotsForTrial; slotIdx < actualSlotCount; slotIdx++) {
          if (globalTopicIndex >= topics.length) break;

          final topic = topics[globalTopicIndex];
          final slot = availability[slotIdx];

          // Bu ders "Güçlü" bir ders mi? (Puanı 0 veya daha iyi mi?)
          final isStrongSubject = (subjectPriorities[topic.subject] ?? 0) >= 0;

          final activityType = _getProgressiveActivityType(
            slotCountForCurrentTopic,
            topic,
            performance,
            isStrongSubject,
          );

          dayActivities.add({
            'time': slot,
            'activity': activityType,
            'id': '$slot-${topic.topic}-$slotCountForCurrentTopic',
          });

          slotCountForCurrentTopic++;
          const slotsPerTopic = 2;

          if (slotCountForCurrentTopic >= slotsPerTopic) {
            usedTopics.add('${topic.subject}-${topic.topic}');
            globalTopicIndex++;
            slotCountForCurrentTopic = 0;
          }
        }
      } else {
        // Normal çalışma günü
        for (int slotIdx = 0; slotIdx < actualSlotCount; slotIdx++) {
          if (globalTopicIndex >= topics.length) break;

          final topic = topics[globalTopicIndex];
          final slot = availability[slotIdx];

          // Bu ders "Güçlü" bir ders mi?
          final isStrongSubject = (subjectPriorities[topic.subject] ?? 0) >= 0;

          final activityType = _getProgressiveActivityType(
            slotCountForCurrentTopic,
            topic,
            performance,
            isStrongSubject,
          );

          dayActivities.add({
            'time': slot,
            'activity': activityType,
            'id': '$slot-${topic.topic}-$slotCountForCurrentTopic',
          });

          slotCountForCurrentTopic++;
          const slotsPerTopic = 2;

          if (slotCountForCurrentTopic >= slotsPerTopic) {
            usedTopics.add('${topic.subject}-${topic.topic}');
            globalTopicIndex++;
            slotCountForCurrentTopic = 0;
          }
        }
      }

      String dayFocus = trialExamForToday != null
          ? '${trialExamForToday['name']} Denemesi'
          : _getDayFocus(dayActivities);

      plan.add({
        'day': day,
        'schedule': dayActivities,
        'focus': dayFocus,
      });
    }

    return {
      'plan': plan,
      'summary': 'Haftalık çalışma programınız hazır! ${usedTopics.length} farklı konu üzerinde çalışacaksınız.',
    };
  }

  /// Konu ilerlemesine göre aktivite türü belirler
  /// isStrongSubject: Eğer true ise, konu anlatımı yerine genel tekrar verilir.
  String _getProgressiveActivityType(
      int slotCount,
      StudyTopic topic,
      PerformanceSummary performance,
      bool isStrongSubject, // YENİ PARAMETRE
      ) {
    // EĞER KULLANICI BU DERSTE İYİYSE (%70+ Başarı)
    if (isStrongSubject) {
      if (slotCount % 2 == 0) {
        // İlk slot: Konu Anlatımı yerine GENEL TEKRAR
        return '${topic.subject} - ${topic.topic} (Genel Tekrar)';
      } else {
        // İkinci slot: Soru Çözümü
        return '${topic.subject} - ${topic.topic} (Soru Çözümü)';
      }
    }

    // EĞER KULLANICI BU DERSTE ZAYIF VEYA ORTA SEVİYEDEYSE
    // (Konu Anlatımı ile başlar, Soru Çözümü ile biter)
    if (slotCount % 2 == 0) {
      return '${topic.subject} - ${topic.topic} (Konu Anlatımı)';
    } else {
      return '${topic.subject} - ${topic.topic} (Soru Çözümü)';
    }
  }

  /// Günün fokusunu belirler (en çok geçen ders adı)
  String _getDayFocus(List<Map<String, String>> activities) {
    if (activities.isEmpty) return 'Karışık Çalışma';

    final Map<String, int> subjectCounts = {};

    for (final activity in activities) {
      final activityText = activity['activity'] ?? '';
      final subjectMatch = RegExp(r'^([^-]+)').firstMatch(activityText);
      if (subjectMatch != null) {
        final subject = subjectMatch.group(1)?.trim() ?? '';
        subjectCounts[subject] = (subjectCounts[subject] ?? 0) + 1;
      }
    }

    if (subjectCounts.isEmpty) return 'Karışık Çalışma';

    final topSubject = subjectCounts.entries.reduce((a, b) => a.value > b.value ? a : b);

    if (topSubject.value / activities.length > 0.6) {
      return topSubject.key;
    }

    return 'Karışık Çalışma';
  }

  /// Pacing moduna göre doluluk oranını döndürür
  double _getFillRatio(String pacing) {
    switch (pacing.toLowerCase()) {
      case 'intense':
      case 'yoğun':
        return 1.0; // %100 doluluk
      case 'moderate':
      case 'dengeli':
        return 0.8; // %80 doluluk
      default:
        return 0.6; // %60 doluluk (rahat)
    }
  }

  /// Sınav türüne göre haftalık deneme sınavlarını döndürür
  List<Map<String, dynamic>> _getTrialExamsForWeek(ExamType examType, String? selectedSection) {
    switch (examType) {
      case ExamType.yks:
        if (selectedSection == null || selectedSection.isEmpty || selectedSection == 'TYT') {
          return [
            {'name': 'TYT', 'slotsNeeded': 2, 'duration': '120 dakika'}
          ];
        } else {
          final secondExam = selectedSection.toLowerCase().contains('ayt')
              ? {'name': 'AYT', 'slotsNeeded': 2, 'duration': '180 dakika'}
              : selectedSection.toLowerCase().contains('ydt')
              ? {'name': 'YDT', 'slotsNeeded': 2, 'duration': '180 dakika'}
              : {'name': 'AYT', 'slotsNeeded': 2, 'duration': '180 dakika'};

          return [
            {'name': 'TYT', 'slotsNeeded': 2, 'duration': '120 dakika'},
            secondExam,
          ];
        }
      case ExamType.lgs:
      case ExamType.ags:
        return [
          {'name': examType.name.toUpperCase(), 'slotsNeeded': 2, 'duration': '120 dakika'}
        ];
      case ExamType.kpssLisans:
      case ExamType.kpssOnlisans:
      case ExamType.kpssOrtaogretim:
        if (selectedSection != null && selectedSection.toLowerCase().contains('öabt')) {
          return [
            {'name': 'ÖABT', 'slotsNeeded': 2, 'duration': '150 dakika'}
          ];
        }
        return [
          {'name': 'KPSS', 'slotsNeeded': 2, 'duration': '135 dakika'}
        ];
      default:
        return [];
    }
  }

  /// Deneme sınavları için en uygun günleri bulur
  Map<int, Map<String, dynamic>?> _findBestTrialDays(
      List<String> orderedDays,
      Map<String, List<String>> weeklyAvailability,
      List<Map<String, dynamic>> trialExams,
      ) {
    final Map<int, Map<String, dynamic>?> result = {};

    for (int i = 0; i < orderedDays.length; i++) {
      result[i] = null;
    }

    if (trialExams.isEmpty) return result;

    if (trialExams.length == 2) {
      final tytExam = trialExams.firstWhere((e) => e['name'] == 'TYT', orElse: () => trialExams[0]);
      final otherExam = trialExams.firstWhere((e) => e['name'] != 'TYT', orElse: () => trialExams[1]);

      final saturdayIndex = orderedDays.indexOf('Cumartesi');
      if (saturdayIndex != -1) {
        final saturdaySlots = weeklyAvailability['Cumartesi'] ?? [];
        if (saturdaySlots.length >= (tytExam['slotsNeeded'] as int)) {
          result[saturdayIndex] = tytExam;
        }
      }

      final sundayIndex = orderedDays.indexOf('Pazar');
      if (sundayIndex != -1) {
        final sundaySlots = weeklyAvailability['Pazar'] ?? [];
        if (sundaySlots.length >= (otherExam['slotsNeeded'] as int)) {
          result[sundayIndex] = otherExam;
        }
      }

      if (saturdayIndex != -1 && result[saturdayIndex] == null) {
        final altIndex = _findAlternativeDay(orderedDays, weeklyAvailability, tytExam, [sundayIndex]);
        if (altIndex != -1) result[altIndex] = tytExam;
      }

      if (sundayIndex != -1 && result[sundayIndex] == null) {
        final usedIndices = result.entries.where((e) => e.value != null).map((e) => e.key).toList();
        final altIndex = _findAlternativeDay(orderedDays, weeklyAvailability, otherExam, usedIndices);
        if (altIndex != -1) result[altIndex] = otherExam;
      }
    } else {
      final exam = trialExams[0];
      final sundayIndex = orderedDays.indexOf('Pazar');
      if (sundayIndex != -1) {
        final sundaySlots = weeklyAvailability['Pazar'] ?? [];
        if (sundaySlots.length >= (exam['slotsNeeded'] as int)) {
          result[sundayIndex] = exam;
          return result;
        }
      }
      final altIndex = _findAlternativeDay(orderedDays, weeklyAvailability, exam, []);
      if (altIndex != -1) result[altIndex] = exam;
    }

    return result;
  }

  /// Deneme için alternatif gün bulur
  int _findAlternativeDay(
      List<String> orderedDays,
      Map<String, List<String>> weeklyAvailability,
      Map<String, dynamic> exam,
      List<int> excludedIndices,
      ) {
    final slotsNeeded = exam['slotsNeeded'] as int;
    final preferredDays = ['Cumartesi', 'Cuma', 'Perşembe', 'Çarşamba', 'Salı', 'Pazartesi'];

    for (final day in preferredDays) {
      final dayIndex = orderedDays.indexOf(day);
      if (dayIndex == -1 || excludedIndices.contains(dayIndex)) continue;
      final slots = weeklyAvailability[day] ?? [];
      if (slots.length >= slotsNeeded) return dayIndex;
    }

    int maxSlots = 0;
    int bestIndex = -1;
    for (int i = 0; i < orderedDays.length; i++) {
      if (excludedIndices.contains(i)) continue;
      final day = orderedDays[i];
      final slots = weeklyAvailability[day] ?? [];
      if (slots.length > maxSlots && slots.length >= slotsNeeded) {
        maxSlots = slots.length;
        bestIndex = i;
      }
    }
    return bestIndex;
  }

  /// Strateji metnini oluşturur
  String _buildStrategyText({
    required UserModel user,
    required ExamType examType,
    required int daysUntilExam,
    required List<TestModel> tests,
    required PerformanceSummary performance,
    required String pacing,
    String? revisionRequest,
    RevisionAnalysis? revisionAnalysis,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('# ${examType.displayName} Hazırlık Stratejisi\n');

    if (revisionRequest != null && revisionRequest.trim().isNotEmpty) {
      buffer.writeln('## 📝 Revizyon Talebi');
      buffer.writeln('> $revisionRequest\n');
      if (revisionAnalysis != null && revisionAnalysis.hasChanges) {
        buffer.writeln('### Uygulanan Değişiklikler:');
        if (revisionAnalysis.pacingChange != PacingChange.none) {
          final change = revisionAnalysis.pacingChange == PacingChange.increase ? 'Program temposu artırıldı' : 'Program temposu azaltıldı';
          buffer.writeln('- ✅ $change');
        }
        revisionAnalysis.subjectAdjustments.forEach((subject, adjustment) {
          final change = adjustment == SubjectAdjustment.increase ? '$subject dersine daha fazla ağırlık verildi' : '$subject dersi azaltıldı';
          buffer.writeln('- ✅ $change');
        });
        buffer.writeln();
      }
    }

    buffer.writeln('## Genel Durum');
    buffer.writeln('- Sınava Kalan Gün: $daysUntilExam');

    if (tests.isNotEmpty) {
      final avgNet = _calculateAverageNet(tests);
      buffer.writeln('- Ortalama Net: ${avgNet.toStringAsFixed(1)}');
      buffer.writeln('- Çözülen Deneme Sayısı: ${tests.length}');
    }

    buffer.writeln('- Çalışma Temposu: ${_getPacingDisplayName(pacing)}');
    if (examType == ExamType.yks && user.selectedExamSection != null && user.selectedExamSection != 'TYT' && user.selectedExamSection!.isNotEmpty) {
      buffer.writeln('- Deneme Sistemi: Her hafta 1 TYT + 1 ${user.selectedExamSection} denemesi');
    }
    buffer.writeln();

    buffer.writeln('## Ders Bazlı Durum');
    final subjectAverages = _calculateSubjectAverages(tests);
    if (subjectAverages.isNotEmpty) {
      final sortedSubjects = subjectAverages.entries.toList()..sort((a, b) => a.value.compareTo(b.value));
      for (final entry in sortedSubjects) {
        buffer.writeln('${_getStatusIcon(entry.value)} **${entry.key}**: ${entry.value.toStringAsFixed(1)} net');
      }
    } else {
      buffer.writeln('Henüz deneme verisi bulunmuyor.');
    }

    buffer.writeln('\n## Öncelikler');
    final weakTopics = _findWeakTopics(performance);
    if (weakTopics.isNotEmpty) {
      buffer.writeln('### Güçlendirilmesi Gereken Konular');
      for (final topic in weakTopics.take(5)) buffer.writeln('- $topic');
    }

    buffer.writeln('\n## Hedefler');
    buffer.writeln(_getGoalsByTimeRemaining(daysUntilExam));

    return buffer.toString();
  }

  double _calculateAverageNet(List<TestModel> tests) {
    if (tests.isEmpty) return 0.0;
    final totalNet = tests.fold<double>(0.0, (sum, test) => sum + test.totalNet);
    return totalNet / tests.length;
  }

  Map<String, double> _calculateSubjectAverages(List<TestModel> tests) {
    if (tests.isEmpty) return {};
    final Map<String, List<double>> subjectNets = {};
    for (final test in tests) {
      test.scores.forEach((subject, scores) {
        final net = (scores['dogru'] ?? 0.0) - ((scores['yanlis'] ?? 0.0) * test.penaltyCoefficient);
        subjectNets.putIfAbsent(subject, () => []).add(net);
      });
    }
    return subjectNets.map((subject, nets) {
      final avg = nets.isEmpty ? 0.0 : nets.reduce((a, b) => a + b) / nets.length;
      return MapEntry(subject, avg);
    });
  }

  List<String> _findWeakTopics(PerformanceSummary performance) {
    final weakTopics = <String>[];
    performance.topicPerformances.forEach((subject, topics) {
      topics.forEach((topic, perf) {
        final attempts = perf.correctCount + perf.wrongCount;
        if (attempts > 5 && perf.correctCount / attempts < 0.5) {
          weakTopics.add('$subject - $topic');
        }
      });
    });
    return weakTopics;
  }

  String _getStatusIcon(double netScore) {
    if (netScore < 5) return '🔴';
    if (netScore < 10) return '🟡';
    return '🟢';
  }

  String _getPacingDisplayName(String pacing) {
    switch (pacing.toLowerCase()) {
      case 'intense': case 'yoğun': return 'Yoğun';
      case 'moderate': case 'dengeli': return 'Dengeli';
      default: return 'Rahat';
    }
  }

  String _getGoalsByTimeRemaining(int daysUntilExam) {
    if (daysUntilExam > 90) {
      return '- Müfredatı tamamlamaya odaklanın\n- Her konudan soru çözümü yapın\n- Haftada en az 1 deneme çözün';
    } else if (daysUntilExam > 30) {
      return '- Zayıf konuları pekiştirin\n- Deneme sayısını artırın (haftada 2-3)\n- Hız ve doğruluk dengesi kurun';
    } else {
      return '- Deneme çözümüne ağırlık verin\n- Sadece en zayıf konulara tekrar yapın\n- Sınav stratejisi ve zaman yönetimine odaklanın';
    }
  }
}

// ============================================================================
// YARDIMCI SINIFLAR
// ============================================================================

class StudyTopic {
  final String subject;
  final String topic;
  StudyTopic({required this.subject, required this.topic});
  Map<String, String> toMap() => {'subject': subject, 'topic': topic};
}

class _ScoredTopic {
  final String subject;
  final String topic;
  final double priority;
  final int curriculumOrder;
  _ScoredTopic({required this.subject, required this.topic, required this.priority, required this.curriculumOrder});
}

class PlannerException implements Exception {
  final String message;
  PlannerException(this.message);
  @override
  String toString() => message;
}