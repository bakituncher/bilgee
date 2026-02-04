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

      // Sıradaki çalışılacak konuları belirle
      var nextTopics = await _getNextTopicsToStudy(
        examType,
        user.selectedExamSection,
        completedTopicIds,
        performance,
        totalAvailableSlots,
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
        'version': '2.1', // Revision service integrated
      };
    } catch (e) {
      if (e is PlannerException) rethrow;
      throw PlannerException('Plan oluşturulurken bir hata oluştu: ${e.toString()}');
    }
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
          if (task is Map && task['id'] != null) {
            completedIds.add(task['id'].toString());
          }
        }
      }
    }
    return completedIds;
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
  ) async {
    final exam = await ExamData.getExamByType(examType);
    final sections = _getRelevantSections(exam, examType, selectedSection);

    // Her dersten konuları topla ve öncelik puanla
    final List<_ScoredTopic> scoredTopics = [];

    for (final section in sections) {
      section.subjects.forEach((subjectName, subjectDetails) {
        for (int i = 0; i < subjectDetails.topics.length; i++) {
          final topic = subjectDetails.topics[i];

          // Tamamlanmış konuları atla
          if (completedTopicIds.contains(topic.name)) continue;

          // Öncelik puanı hesapla
          final priority = _calculateTopicPriority(
            topicName: topic.name,
            subjectName: subjectName,
            curriculumOrder: i,
            performance: performance,
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

    // Önceliğe göre sırala
    scoredTopics.sort((a, b) => a.priority.compareTo(b.priority));

    // Her konu için 2 slot gerekir, dolayısıyla gerekli konu sayısı:
    // (totalSlots / 2) + %20 buffer (bazı günler daha az slot olabilir)
    final neededTopicCount = ((totalAvailableSlots / 2) * 1.2).ceil();

    // En az 10, en fazla tüm konular kadar seç
    final finalTopicCount = neededTopicCount.clamp(10, scoredTopics.length);

    return scoredTopics
        .take(finalTopicCount)
        .map((st) => StudyTopic(subject: st.subject, topic: st.topic))
        .toList();
  }

  /// İlgili bölümleri döndürür (YKS, AGS, KPSS vb. mantığı)
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
  }) {
    double priority = curriculumOrder.toDouble(); // Müfredat sırası

    final topicPerf = performance.topicPerformances[subjectName]?[topicName];

    if (topicPerf != null) {
      final attempts = topicPerf.correctCount + topicPerf.wrongCount;
      if (attempts > 5) {
        final accuracy = topicPerf.correctCount / attempts;
        // Zayıf konulara öncelik ver
        if (accuracy < 0.5) {
          priority -= 100; // Çok zayıf (en öncelikli)
        } else if (accuracy < 0.7) {
          priority -= 50; // Orta zayıf
        }
      } else if (topicPerf.questionCount < 5) {
        // Hiç çalışılmamış konular
        priority -= 20;
      }
    } else {
      // Hiç verisi olmayan konular
      priority -= 10;
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
  }) {
    if (topics.isEmpty) {
      return {
        'plan': [],
        'summary': 'Çalışılacak konu bulunamadı. Tüm konuları tamamlamış olabilirsiniz!',
      };
    }

    final trDays = ['Pazartesi', 'Salı', 'Çarşamba', 'Perşembe', 'Cuma', 'Cumartesi', 'Pazar'];
    final todayIndex = DateTime.now().weekday - 1;

    // Günleri bugünden başlayarak sırala
    final List<String> orderedDays = [];
    for (int i = 0; i < 7; i++) {
      orderedDays.add(trDays[(todayIndex + i) % 7]);
    }

    // Kullanıcının sınavına göre deneme türünü belirle
    final examType = ExamType.values.byName(user.selectedExam!);

    // YKS için hem TYT hem de AYT/YDT denemeleri, diğer sınavlar için tek deneme
    final trialExams = _getTrialExamsForWeek(examType, user.selectedExamSection);

    // Pacing'e göre doluluk oranını belirle
    final fillRatio = _getFillRatio(pacing);

    final List<Map<String, dynamic>> plan = [];
    int globalTopicIndex = 0;
    int slotCountForCurrentTopic = 0; // Mevcut konu için kaç slot kullanıldı
    final Set<String> usedTopics = {}; // Kullanılan konuları takip et

    // Deneme sınavları için en uygun günleri bul
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

      // Bu gün için aktiviteleri oluştur
      final dayActivities = <Map<String, String>>[];

      // Bu gün deneme günlerinden biri mi kontrol et
      final trialExamForToday = trialDayIndices[dayIdx];

      if (trialExamForToday != null) {
        // Deneme sınavı ekle
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

        // Kalan slotlara normal çalışma ekle
        for (int slotIdx = availableSlotsForTrial; slotIdx < actualSlotCount; slotIdx++) {
          if (globalTopicIndex >= topics.length) break;

          final topic = topics[globalTopicIndex];
          final slot = availability[slotIdx];

          final activityType = _getProgressiveActivityType(
            slotCountForCurrentTopic,
            topic,
            performance,
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

          final activityType = _getProgressiveActivityType(
            slotCountForCurrentTopic,
            topic,
            performance,
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

      // Günün fokusunu belirle
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
  /// slotCount: Bu konu için kaçıncı slot (0=ilk, 1=ikinci)
  String _getProgressiveActivityType(
    int slotCount,
    StudyTopic topic,
    PerformanceSummary performance,
  ) {
    // Her konu için sadece 2 aktivite: Konu Anlatımı ve Soru Çözümü
    if (slotCount % 2 == 0) {
      // İlk slot: Konu Anlatımı
      return '${topic.subject} - ${topic.topic} (Konu Anlatımı)';
    } else {
      // İkinci slot: Soru Çözümü
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

    // En çok geçen dersi bul
    final topSubject = subjectCounts.entries.reduce((a, b) => a.value > b.value ? a : b);

    // Eğer %60'tan fazla aynı dersse, onu yaz
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
  /// YKS için hem TYT hem de AYT/YDT, diğer sınavlar için tek deneme
  List<Map<String, dynamic>> _getTrialExamsForWeek(ExamType examType, String? selectedSection) {
    switch (examType) {
      case ExamType.yks:
        // YKS için özel mantık: Hem TYT hem de AYT/YDT
        if (selectedSection == null || selectedSection.isEmpty || selectedSection == 'TYT') {
          // Sadece TYT hazırlananlar için her hafta TYT
          return [
            {
              'name': 'TYT',
              'slotsNeeded': 2,
              'duration': '120 dakika'
            }
          ];
        } else {
          // AYT veya YDT hazırlananlar için her hafta hem TYT hem de AYT/YDT
          final secondExam = selectedSection.toLowerCase().contains('ayt')
              ? {
                  'name': 'AYT',
                  'slotsNeeded': 2,
                  'duration': '180 dakika'
                }
              : selectedSection.toLowerCase().contains('ydt')
                  ? {
                      'name': 'YDT',
                      'slotsNeeded': 2,
                      'duration': '180 dakika'
                    }
                  : {
                      'name': 'AYT',
                      'slotsNeeded': 2,
                      'duration': '180 dakika'
                    };

          return [
            {
              'name': 'TYT',
              'slotsNeeded': 2,
              'duration': '120 dakika'
            },
            secondExam,
          ];
        }

      case ExamType.lgs:
        return [
          {
            'name': 'LGS',
            'slotsNeeded': 2,
            'duration': '120 dakika'
          }
        ];

      case ExamType.kpssLisans:
      case ExamType.kpssOnlisans:
      case ExamType.kpssOrtaogretim:
        if (selectedSection != null && selectedSection.toLowerCase().contains('öabt')) {
          return [
            {
              'name': 'ÖABT',
              'slotsNeeded': 2,
              'duration': '150 dakika'
            }
          ];
        }
        return [
          {
            'name': 'KPSS',
            'slotsNeeded': 2,
            'duration': '135 dakika'
          }
        ];

      case ExamType.ags:
        return [
          {
            'name': 'AGS',
            'slotsNeeded': 2,
            'duration': '120 dakika'
          }
        ];

      default:
        return [];
    }
  }

  /// Deneme sınavları için en uygun günleri bulur
  /// YKS için: Cumartesi TYT, Pazar AYT/YDT (sabit düzen)
  /// Diğer sınavlar için: Pazar veya en uygun gün
  /// Return: Map<dayIndex, trialExamInfo> - Her gün için deneme bilgisi (yoksa null)
  Map<int, Map<String, dynamic>?> _findBestTrialDays(
    List<String> orderedDays,
    Map<String, List<String>> weeklyAvailability,
    List<Map<String, dynamic>> trialExams,
  ) {
    final Map<int, Map<String, dynamic>?> result = {};

    // Tüm günleri başlangıçta null yap
    for (int i = 0; i < orderedDays.length; i++) {
      result[i] = null;
    }

    if (trialExams.isEmpty) return result;

    // YKS için özel düzen: Cumartesi TYT, Pazar AYT/YDT
    if (trialExams.length == 2) {
      // İki deneme var, muhtemelen YKS (TYT + AYT/YDT)
      final tytExam = trialExams.firstWhere(
        (e) => e['name'] == 'TYT',
        orElse: () => trialExams[0],
      );
      final otherExam = trialExams.firstWhere(
        (e) => e['name'] != 'TYT',
        orElse: () => trialExams[1],
      );

      // Cumartesi'yi bul ve TYT ata
      final saturdayIndex = orderedDays.indexOf('Cumartesi');
      if (saturdayIndex != -1) {
        final saturdaySlots = weeklyAvailability['Cumartesi'] ?? [];
        final tytSlotsNeeded = tytExam['slotsNeeded'] as int;
        if (saturdaySlots.length >= tytSlotsNeeded) {
          result[saturdayIndex] = tytExam;
        }
      }

      // Pazar'ı bul ve AYT/YDT ata
      final sundayIndex = orderedDays.indexOf('Pazar');
      if (sundayIndex != -1) {
        final sundaySlots = weeklyAvailability['Pazar'] ?? [];
        final otherSlotsNeeded = otherExam['slotsNeeded'] as int;
        if (sundaySlots.length >= otherSlotsNeeded) {
          result[sundayIndex] = otherExam;
        }
      }

      // Eğer Cumartesi veya Pazar uygun değilse, alternatif günler bul
      if (saturdayIndex != -1 && result[saturdayIndex] == null) {
        // TYT için alternatif gün bul
        final altIndex = _findAlternativeDay(orderedDays, weeklyAvailability, tytExam, [sundayIndex]);
        if (altIndex != -1) {
          result[altIndex] = tytExam;
        }
      }

      if (sundayIndex != -1 && result[sundayIndex] == null) {
        // AYT/YDT için alternatif gün bul
        final usedIndices = result.entries.where((e) => e.value != null).map((e) => e.key).toList();
        final altIndex = _findAlternativeDay(orderedDays, weeklyAvailability, otherExam, usedIndices);
        if (altIndex != -1) {
          result[altIndex] = otherExam;
        }
      }
    } else {
      // Tek deneme var (LGS, KPSS, AGS vb.)
      // Pazar'ı tercih et, yoksa en uygun günü bul
      final exam = trialExams[0];
      final slotsNeeded = exam['slotsNeeded'] as int;

      final sundayIndex = orderedDays.indexOf('Pazar');
      if (sundayIndex != -1) {
        final sundaySlots = weeklyAvailability['Pazar'] ?? [];
        if (sundaySlots.length >= slotsNeeded) {
          result[sundayIndex] = exam;
          return result;
        }
      }

      // Pazar uygun değilse alternatif bul
      final altIndex = _findAlternativeDay(orderedDays, weeklyAvailability, exam, []);
      if (altIndex != -1) {
        result[altIndex] = exam;
      }
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

    // Önce tercih edilen günlerden dene
    for (final day in preferredDays) {
      final dayIndex = orderedDays.indexOf(day);
      if (dayIndex == -1 || excludedIndices.contains(dayIndex)) continue;

      final slots = weeklyAvailability[day] ?? [];
      if (slots.length >= slotsNeeded) {
        return dayIndex;
      }
    }

    // Bulunamadıysa en fazla slotu olan günü bul
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


  /// Strateji metnini oluşturur (Markdown formatında)
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

    // Başlık
    buffer.writeln('# ${examType.displayName} Hazırlık Stratejisi\n');

    // Revizyon talebi varsa ekle
    if (revisionRequest != null && revisionRequest.trim().isNotEmpty) {
      buffer.writeln('## 📝 Revizyon Talebi');
      buffer.writeln('> $revisionRequest\n');

      if (revisionAnalysis != null && revisionAnalysis.hasChanges) {
        buffer.writeln('### Uygulanan Değişiklikler:');

        if (revisionAnalysis.pacingChange != PacingChange.none) {
          final change = revisionAnalysis.pacingChange == PacingChange.increase
              ? 'Program temposu artırıldı'
              : 'Program temposu azaltıldı';
          buffer.writeln('- ✅ $change');
        }

        if (revisionAnalysis.subjectAdjustments.isNotEmpty) {
          revisionAnalysis.subjectAdjustments.forEach((subject, adjustment) {
            final change = adjustment == SubjectAdjustment.increase
                ? '$subject dersine daha fazla ağırlık verildi'
                : '$subject dersi azaltıldı';
            buffer.writeln('- ✅ $change');
          });
        }

        buffer.writeln();
      }
    }

    // Genel Durum
    buffer.writeln('## Genel Durum');
    buffer.writeln('- Sınava Kalan Gün: $daysUntilExam');

    if (tests.isNotEmpty) {
      final avgNet = _calculateAverageNet(tests);
      buffer.writeln('- Ortalama Net: ${avgNet.toStringAsFixed(1)}');
      buffer.writeln('- Çözülen Deneme Sayısı: ${tests.length}');
    }

    buffer.writeln('- Çalışma Temposu: ${_getPacingDisplayName(pacing)}');

    // YKS için deneme sistemi açıklaması
    if (examType == ExamType.yks && user.selectedExamSection != null &&
        user.selectedExamSection != 'TYT' && user.selectedExamSection!.isNotEmpty) {
      buffer.writeln('- Deneme Sistemi: Her hafta 1 TYT + 1 ${user.selectedExamSection} denemesi');
    }

    buffer.writeln();

    // Ders Bazlı Durum
    buffer.writeln('## Ders Bazlı Durum');
    final subjectAverages = _calculateSubjectAverages(tests);

    if (subjectAverages.isNotEmpty) {
      final sortedSubjects = subjectAverages.entries.toList()
        ..sort((a, b) => a.value.compareTo(b.value));

      for (final entry in sortedSubjects) {
        final subject = entry.key;
        final avg = entry.value;
        final status = _getStatusIcon(avg);
        buffer.writeln('$status **$subject**: ${avg.toStringAsFixed(1)} net');
      }
    } else {
      buffer.writeln('Henüz deneme verisi bulunmuyor.');
    }

    // Öncelikler
    buffer.writeln('\n## Öncelikler');
    final weakTopics = _findWeakTopics(performance);

    if (weakTopics.isNotEmpty) {
      buffer.writeln('### Güçlendirilmesi Gereken Konular');
      for (final topic in weakTopics.take(5)) {
        buffer.writeln('- $topic');
      }
    }

    // Hedefler
    buffer.writeln('\n## Hedefler');
    buffer.writeln(_getGoalsByTimeRemaining(daysUntilExam));

    return buffer.toString();
  }

  /// Ortalama net hesaplar
  double _calculateAverageNet(List<TestModel> tests) {
    if (tests.isEmpty) return 0.0;
    final totalNet = tests.fold<double>(0.0, (sum, test) => sum + test.totalNet);
    return totalNet / tests.length;
  }

  /// Ders bazlı ortalama netleri hesaplar
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

  /// Zayıf konuları bulur
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

  /// Net skoruna göre durum ikonu
  String _getStatusIcon(double netScore) {
    if (netScore < 5) return '🔴';
    if (netScore < 10) return '🟡';
    return '🟢';
  }

  /// Pacing modu görüntü adı
  String _getPacingDisplayName(String pacing) {
    switch (pacing.toLowerCase()) {
      case 'intense':
      case 'yoğun':
        return 'Yoğun';
      case 'moderate':
      case 'dengeli':
        return 'Dengeli';
      default:
        return 'Rahat';
    }
  }

  /// Sınava kalan süreye göre hedefler
  String _getGoalsByTimeRemaining(int daysUntilExam) {
    if (daysUntilExam > 90) {
      return '''- Müfredatı tamamlamaya odaklanın
- Her konudan soru çözümü yapın
- Haftada en az 1 deneme çözün''';
    } else if (daysUntilExam > 30) {
      return '''- Zayıf konuları pekiştirin
- Deneme sayısını artırın (haftada 2-3)
- Hız ve doğruluk dengesi kurun''';
    } else {
      return '''- Deneme çözümüne ağırlık verin
- Sadece en zayıf konulara tekrar yapın
- Sınav stratejisi ve zaman yönetimine odaklanın''';
    }
  }
}

// ============================================================================
// YARDIMCI SINIFLAR
// ============================================================================

/// Çalışma konusu modeli
class StudyTopic {
  final String subject;
  final String topic;

  StudyTopic({required this.subject, required this.topic});

  Map<String, String> toMap() => {'subject': subject, 'topic': topic};
}

/// Puanlanmış konu (iç kullanım için)
class _ScoredTopic {
  final String subject;
  final String topic;
  final double priority;
  final int curriculumOrder;

  _ScoredTopic({
    required this.subject,
    required this.topic,
    required this.priority,
    required this.curriculumOrder,
  });
}

/// Planlama hataları için özel exception
class PlannerException implements Exception {
  final String message;
  PlannerException(this.message);

  @override
  String toString() => message;
}

