// lib/data/repositories/weekly_planner_service.dart
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:taktik/data/models/exam_model.dart';
import 'package:taktik/data/models/performance_summary.dart';
import 'package:taktik/data/models/plan_document.dart';
import 'package:taktik/data/models/test_model.dart';
import 'package:taktik/data/models/user_model.dart';
import 'package:taktik/data/models/topic_performance_model.dart';
import 'package:taktik/data/repositories/exam_schedule.dart';
import 'package:taktik/data/repositories/plan_revision_service.dart';

/// Haftalık çalışma planı oluşturma servisi
/// v3.9: UNLEASHED TOPIC DATA (Serbest Bırakılmış Konu Verisi)
/// FIX: "Ders Filtresi" kaldırıldı. Test listesinde o dersin adı geçmese bile,
/// PerformanceSummary içinde verisi (topicPerf) olan her konu değerlendirmeye alınır.
/// Bu sayede Fizik, Tarih, Matematik gibi derslerdeki eski ama çözülmüş başarısız konular artık plana dahil edilir.
class WeeklyPlannerService {
  final FirebaseFirestore _firestore;
  final PlanRevisionService _revisionService;

  WeeklyPlannerService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _revisionService = PlanRevisionService();

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

      final completedTopicIds = await _loadCompletedTopics(user.id, days: 365);

      // Revizyon analizi
      RevisionAnalysis? revisionAnalysis;
      String effectivePacing = pacing;

      if (revisionRequest != null && revisionRequest.trim().isNotEmpty) {
        revisionAnalysis = _revisionService.analyzeRevisionRequest(revisionRequest);
        effectivePacing = _revisionService.calculateNewPacing(pacing, revisionAnalysis);
      }

      final totalAvailableSlots = _calculateTotalWeeklySlots(user, effectivePacing);

      // 1. TEST ANALİZİ (Sadece Puanlama İçin Kullanılır, Filtreleme İçin Değil)
      final subjectPerformances = _calculateSubjectPerformanceFromTests(tests);
      print('📊 Ders Başarı Oranları (Ref): $subjectPerformances');

      // 2. KONU HAVUZU OLUŞTURMA (Ders Kısıtlaması Olmadan)
      List<_ScoredTopic> topicPool = await _getUrgentTopicPool(
        examType,
        user.selectedExamSection,
        completedTopicIds,
        performance,
        totalAvailableSlots,
        subjectPerformances,
      );

      // Revizyon varsa havuzu güncelle
      if (revisionAnalysis != null && revisionAnalysis.hasChanges) {
        final List<StudyTopic> currentTopics = topicPool
            .map((st) => StudyTopic(subject: st.subject, topic: st.topic))
            .toList();

        final List<StudyTopic> revisedTopics = _revisionService.adjustTopicList(
          originalTopics: currentTopics,
          analysis: revisionAnalysis,
          performance: performance,
          targetSlotCount: totalAvailableSlots,
        );

        final List<_ScoredTopic> newPool = [];
        for (final t in revisedTopics) {
          final existing = topicPool.firstWhere(
                (st) => st.subject == t.subject && st.topic == t.topic,
            orElse: () => _ScoredTopic(
                subject: t.subject,
                topic: t.topic,
                priority: 999.0,
                curriculumOrder: 0
            ),
          );
          newPool.add(existing);
        }
        topicPool = newPool;
      }

      // 3. KATI KURALLI DAĞITIM
      final weeklyPlan = _buildStrictlyBalancedWeeklySchedule(
        user: user,
        topicPool: topicPool,
        pacing: effectivePacing,
        performance: performance,
        subjectPerformances: subjectPerformances,
      );

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
        'version': '3.9', // Unleashed Fix
      };
    } catch (e) {
      if (e is PlannerException) rethrow;
      throw PlannerException('Plan oluşturulurken bir hata oluştu: ${e.toString()}');
    }
  }

  // --- Yardımcı Metodlar ---

  /// Firestore'da kullanılan sanitize metodu ile uyumlu key oluşturur
  /// Boşluk, nokta ve parantezleri alt çizgiye dönüştürür
  String _sanitizeKey(String key) {
    return key.replaceAll(RegExp(r'[.\s()]'), '_');
  }

  Future<List<_ScoredTopic>> _getUrgentTopicPool(
      ExamType examType,
      String? selectedSection,
      Set<String> completedTopicIds,
      PerformanceSummary performance,
      int totalAvailableSlots,
      Map<String, double> subjectPerformances,
      ) async {
    final exam = await ExamData.getExamByType(examType);
    final sections = _getRelevantSections(exam, examType, selectedSection);

    final List<_ScoredTopic> allTopics = [];

    for (final section in sections) {
      section.subjects.forEach((subjectName, subjectDetails) {

        // KRİTİK DEĞİŞİKLİK (v3.9):
        // Artık subjectPerformances içinde bu ders yoksa bile (yani listede test yoksa),
        // döngüyü kırmıyoruz (return demiyoruz). Devam edip PerformanceSummary'e bakıyoruz.

        // Eğer dersin genel başarısı bilinmiyorsa varsayılan 0.5 alalım.
        // Amaç konuyu engellemek değil, sadece puanlamaya baz oluşturmak.
        final subjectSuccessRate = subjectPerformances[subjectName] ?? 0.5;

        // FİX v3.10: Firestore'da ders ve konu isimleri sanitize edilmiş durumda
        final sanitizedSubject = _sanitizeKey(subjectName);

        for (int i = 0; i < subjectDetails.topics.length; i++) {
          final topic = subjectDetails.topics[i];
          final isCompleted = completedTopicIds.contains(topic.name) ||
              completedTopicIds.contains(topic.name.trim());

          // FİX v3.10: Konu ismini de sanitize et
          final sanitizedTopic = _sanitizeKey(topic.name);

          // PerformanceSummary'den (Firestore'dan gelen gerçek veri) kontrol et
          // ÖNCEKİ HATA: Orijinal isimleri kullanıyorduk, sanitize edilmiş key'leri kullanmalıyız!
          final TopicPerformanceModel? topicPerf = performance.topicPerformances[sanitizedSubject]?[sanitizedTopic];

          // SADECE VE SADECE KONU VERİSİ VARSA LİSTEYE GİRER
          // Konu hakkında hiç soru çözülmemişse (null veya 0), atla.
          if (topicPerf == null || (topicPerf.correctCount + topicPerf.wrongCount) == 0) {
            continue;
          }

          final score = _calculateTopicUrgencyScore(
            topicName: topic.name,
            subjectName: subjectName,
            curriculumOrder: i,
            performance: performance,
            subjectSuccessRate: subjectSuccessRate,
            isCompleted: isCompleted,
            topicPerf: topicPerf,
          );

          // Tamamlanmış ve puanı düşükse alma
          if (isCompleted && score < 60) continue;

          allTopics.add(_ScoredTopic(
            subject: subjectName,
            topic: topic.name,
            priority: score,
            curriculumOrder: i,
          ));
        }
      });
    }

    allTopics.sort((a, b) => b.priority.compareTo(a.priority));

    final neededCount = ((totalAvailableSlots / 2) * 1.5).ceil().clamp(15, 60);
    return allTopics.take(neededCount).toList();
  }

  /// KATI KURALLI DENGELİ PROGRAM OLUŞTURUCU
  Map<String, dynamic> _buildStrictlyBalancedWeeklySchedule({
    required UserModel user,
    required List<_ScoredTopic> topicPool,
    required String pacing,
    required PerformanceSummary performance,
    required Map<String, double> subjectPerformances,
  }) {
    if (topicPool.isEmpty) {
      return {'plan': [], 'summary': 'Analiz edilecek konu test verisi bulunamadı. Lütfen önce test çözün.'};
    }

    final trDays = ['Pazartesi', 'Salı', 'Çarşamba', 'Perşembe', 'Cuma', 'Cumartesi', 'Pazar'];
    final todayIndex = DateTime.now().weekday - 1;
    final List<String> orderedDays = List.generate(7, (i) => trDays[(todayIndex + i) % 7]);

    final examType = ExamType.values.byName(user.selectedExam!);
    final trialExams = _getTrialExamsForWeek(examType, user.selectedExamSection);
    final fillRatio = _getFillRatio(pacing);

    final List<Map<String, dynamic>> plan = [];
    final trialDayIndices = _findBestTrialDays(orderedDays, user.weeklyAvailability, trialExams);

    final List<_ScoredTopic> availableTopics = List.from(topicPool);
    final Set<String> usedTopicSignatures = {};

    for (int dayIdx = 0; dayIdx < orderedDays.length; dayIdx++) {
      final day = orderedDays[dayIdx];
      final availability = user.weeklyAvailability[day] ?? [];

      if (availability.isEmpty) {
        plan.add({'day': day, 'schedule': [], 'focus': 'Dinlenme Günü'});
        continue;
      }

      final targetSlotCount = (availability.length * fillRatio).ceil();
      final actualSlotCount = targetSlotCount > availability.length ? availability.length : targetSlotCount;
      final dayActivities = <Map<String, String>>[];

      final Map<String, int> dailySubjectCounts = {};
      String? lastSubject;

      final trialExamForToday = trialDayIndices[dayIdx];
      int startSlotIdx = 0;

      if (trialExamForToday != null) {
        final trialSlotCount = trialExamForToday['slotsNeeded'] as int;
        final slotsToUse = min(actualSlotCount, trialSlotCount);

        for (int i = 0; i < slotsToUse; i++) {
          final slot = availability[i];
          dayActivities.add({
            'time': slot,
            'activity': '${trialExamForToday['name']} - Deneme Sınavı ${i == 0 ? '(Çözüm)' : '(Devam)'}',
            'id': '$slot-trial-$i',
          });
        }
        startSlotIdx = slotsToUse;
      }

      for (int slotIdx = startSlotIdx; slotIdx < actualSlotCount; slotIdx++) {
        final slot = availability[slotIdx];
        _ScoredTopic? selectedTopic;
        int bestCandidateIndex = -1;

        // 1. ÖNCELİK: Gün içinde HİÇ kullanılmamış ders
        for (int i = 0; i < availableTopics.length; i++) {
          final t = availableTopics[i];
          final count = dailySubjectCounts[t.subject] ?? 0;

          if (count == 0 && lastSubject != t.subject) {
            bestCandidateIndex = i;
            break;
          }
        }

        // 2. ÖNCELİK: Gün içinde HİÇ kullanılmamış ama arka arkaya gelen
        if (bestCandidateIndex == -1) {
          for (int i = 0; i < availableTopics.length; i++) {
            final t = availableTopics[i];
            final count = dailySubjectCounts[t.subject] ?? 0;

            if (count == 0) {
              bestCandidateIndex = i;
              break;
            }
          }
        }

        // 3. ÖNCELİK: Limit < 2
        if (bestCandidateIndex == -1) {
          for (int i = 0; i < availableTopics.length; i++) {
            final t = availableTopics[i];
            final count = dailySubjectCounts[t.subject] ?? 0;

            if (count < 4 && lastSubject != t.subject) {
              bestCandidateIndex = i;
              break;
            }
          }
        }

        // 4. SON ÇARE
        if (bestCandidateIndex == -1 && availableTopics.isNotEmpty) {
          bestCandidateIndex = 0;
        }

        if (bestCandidateIndex != -1) {
          selectedTopic = availableTopics[bestCandidateIndex];
          availableTopics.removeAt(bestCandidateIndex);

          dailySubjectCounts[selectedTopic.subject] = (dailySubjectCounts[selectedTopic.subject] ?? 0) + 2;
          lastSubject = selectedTopic.subject;
          usedTopicSignatures.add('${selectedTopic.subject}-${selectedTopic.topic}');

          final subjectSuccess = subjectPerformances[selectedTopic.subject] ?? 0.0;
          final isStrong = subjectSuccess > 0.7;

          dayActivities.add({
            'time': slot,
            'activity': isStrong
                ? '${selectedTopic.subject} - ${selectedTopic.topic} (Genel Tekrar)'
                : '${selectedTopic.subject} - ${selectedTopic.topic} (Konu Anlatımı)',
            'id': '$slot-${selectedTopic.topic}-0',
          });

          if (slotIdx + 1 < actualSlotCount) {
            slotIdx++;
            final nextSlot = availability[slotIdx];
            dayActivities.add({
              'time': nextSlot,
              'activity': '${selectedTopic.subject} - ${selectedTopic.topic} (Soru Çözümü)',
              'id': '$nextSlot-${selectedTopic.topic}-1',
            });
          }
        }
      }

      String dayFocus = trialExamForToday != null
          ? '${trialExamForToday['name']} Denemesi'
          : _getDayFocus(dayActivities);

      plan.add({'day': day, 'schedule': dayActivities, 'focus': dayFocus});
    }

    return {
      'plan': plan,
      'summary': 'Program dengelendi: ${usedTopicSignatures.length} farklı konu, çeşitlendirilmiş günlere yayıldı.',
    };
  }

  // --- İstatistik Metodları ---

  Map<String, double> _calculateSubjectPerformanceFromTests(List<TestModel> tests) {
    if (tests.isEmpty) return {};

    final limitDate = DateTime.now().subtract(const Duration(days: 365));

    // FİLTRE: Tarih + Sadece Branch Test (Konu Testi)
    // Sadece genel başarıyı hesaplamak için kullanılır, konu elemek için DEĞİL.
    final List<TestModel> testsToAnalyze = tests.where((test) {
      return test.date.isAfter(limitDate) && test.isBranchTest;
    }).toList();

    if (testsToAnalyze.isEmpty) return {};

    final Map<String, Map<String, int>> aggregates = {};

    for (final test in testsToAnalyze) {
      test.scores.forEach((subject, stats) {
        if (!aggregates.containsKey(subject)) aggregates[subject] = {'dogru': 0, 'toplam': 0};

        final dogru = stats['dogru'] ?? 0;
        final toplam = (stats['dogru'] ?? 0) + (stats['yanlis'] ?? 0) + (stats['bos'] ?? 0);

        aggregates[subject]!['dogru'] = aggregates[subject]!['dogru']! + dogru;
        aggregates[subject]!['toplam'] = aggregates[subject]!['toplam']! + toplam;
      });
    }

    final Map<String, double> performances = {};
    aggregates.forEach((subject, stats) {
      final toplam = stats['toplam']!;
      if (toplam < 5) return;
      performances[subject] = stats['dogru']! / toplam;
    });

    return performances;
  }

  double _calculateTopicUrgencyScore({
    required String topicName,
    required String subjectName,
    required int curriculumOrder,
    required PerformanceSummary performance,
    required double subjectSuccessRate,
    required bool isCompleted,
    required TopicPerformanceModel? topicPerf,
  }) {
    double score = 0.0;

    // Konu testlerindeki genel ders başarısızlığı puanı (Etkisi biraz azaltıldı, konu başarısı öne çıksın)
    score += (1.0 - subjectSuccessRate) * 150;

    // Spesifik konu verisi (Artık topicPerf'in null olmadığı garanti)
    final attempts = topicPerf!.correctCount + topicPerf.wrongCount;

    if (attempts > 0) {
      final accuracy = topicPerf.correctCount / attempts;
      if (accuracy < 0.3) score += 200; // Çok başarısız konu - ZİRVE ÖNCELİK
      else if (accuracy < 0.5) score += 120;
      else if (accuracy < 0.7) score += 60;
      else score -= 50;
    } else {
      score += 20;
    }

    score += (50 - curriculumOrder).clamp(0, 15);
    if (isCompleted) score -= 150;

    return score;
  }

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
            if (task['id'] != null) {
              final rawId = task['id'].toString();
              completedIds.add(rawId);
              final extracted = _extractTopicFromId(rawId);
              if (extracted != rawId && extracted.isNotEmpty) completedIds.add(extracted);
            }
            if (task['topic'] != null) completedIds.add(task['topic'].toString());
          } else if (task is String) {
            completedIds.add(task);
            final extracted = _extractTopicFromId(task);
            if (extracted != task && extracted.isNotEmpty) completedIds.add(extracted);
          }
        }
      }
    }
    return completedIds;
  }

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

  int _calculateTotalWeeklySlots(UserModel user, String pacing) {
    int totalSlots = 0;
    final fillRatio = _getFillRatio(pacing);
    user.weeklyAvailability.forEach((day, slots) {
      totalSlots += (slots.length * fillRatio).ceil();
    });
    return totalSlots;
  }

  List<ExamSection> _getRelevantSections(Exam exam, ExamType examType, String? selectedSection) {
    if (examType == ExamType.ags) {
      final sections = exam.sections.where((s) => s.name == 'AGS').toList();
      if (selectedSection != null && selectedSection.isNotEmpty) {
        sections.addAll(exam.sections.where((s) => s.name.toLowerCase() == selectedSection.toLowerCase()));
      }
      return sections;
    } else if (examType == ExamType.yks) {
      final sections = exam.sections.where((s) => s.name == 'TYT').toList();
      if (selectedSection != null && selectedSection.isNotEmpty && selectedSection != 'TYT') {
        sections.addAll(exam.sections.where((s) => s.name.toLowerCase() == selectedSection.toLowerCase()));
      }
      return sections;
    } else {
      return (selectedSection != null && selectedSection.isNotEmpty)
          ? exam.sections.where((s) => s.name.toLowerCase() == selectedSection.toLowerCase()).toList()
          : exam.sections;
    }
  }

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
    if (topSubject.value / activities.length > 0.6) return topSubject.key;
    return 'Karışık Çalışma';
  }

  double _getFillRatio(String pacing) {
    switch (pacing.toLowerCase()) {
      case 'intense': case 'yoğun': return 1.0;
      case 'moderate': case 'dengeli': return 0.8;
      default: return 0.6;
    }
  }

  List<Map<String, dynamic>> _getTrialExamsForWeek(ExamType examType, String? selectedSection) {
    switch (examType) {
      case ExamType.yks:
        if (selectedSection == null || selectedSection.isEmpty || selectedSection == 'TYT') {
          return [{'name': 'TYT', 'slotsNeeded': 2, 'duration': '120 dakika'}];
        } else {
          final secondExam = selectedSection.toLowerCase().contains('ayt')
              ? {'name': 'AYT', 'slotsNeeded': 2, 'duration': '180 dakika'}
              : selectedSection.toLowerCase().contains('ydt')
              ? {'name': 'YDT', 'slotsNeeded': 2, 'duration': '180 dakika'}
              : {'name': 'AYT', 'slotsNeeded': 2, 'duration': '180 dakika'};
          return [{'name': 'TYT', 'slotsNeeded': 2, 'duration': '120 dakika'}, secondExam];
        }
      case ExamType.lgs:
      case ExamType.ags:
        return [{'name': examType.name.toUpperCase(), 'slotsNeeded': 2, 'duration': '120 dakika'}];
      case ExamType.kpssLisans:
      case ExamType.kpssOnlisans:
      case ExamType.kpssOrtaogretim:
        if (selectedSection != null && selectedSection.toLowerCase().contains('öabt')) {
          return [{'name': 'ÖABT', 'slotsNeeded': 2, 'duration': '150 dakika'}];
        }
        return [{'name': 'KPSS', 'slotsNeeded': 2, 'duration': '135 dakika'}];
      default: return [];
    }
  }

  Map<int, Map<String, dynamic>?> _findBestTrialDays(
      List<String> orderedDays,
      Map<String, List<String>> weeklyAvailability,
      List<Map<String, dynamic>> trialExams,
      ) {
    final Map<int, Map<String, dynamic>?> result = {};
    for (int i = 0; i < orderedDays.length; i++) result[i] = null;
    if (trialExams.isEmpty) return result;

    if (trialExams.length == 2) {
      final tytExam = trialExams.firstWhere((e) => e['name'] == 'TYT', orElse: () => trialExams[0]);
      final otherExam = trialExams.firstWhere((e) => e['name'] != 'TYT', orElse: () => trialExams[1]);
      final saturdayIndex = orderedDays.indexOf('Cumartesi');
      if (saturdayIndex != -1) {
        final saturdaySlots = weeklyAvailability['Cumartesi'] ?? [];
        if (saturdaySlots.length >= (tytExam['slotsNeeded'] as int)) result[saturdayIndex] = tytExam;
      }
      final sundayIndex = orderedDays.indexOf('Pazar');
      if (sundayIndex != -1) {
        final sundaySlots = weeklyAvailability['Pazar'] ?? [];
        if (sundaySlots.length >= (otherExam['slotsNeeded'] as int)) result[sundayIndex] = otherExam;
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
        if (attempts > 5 && perf.correctCount / attempts < 0.5) weakTopics.add('$subject - $topic');
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