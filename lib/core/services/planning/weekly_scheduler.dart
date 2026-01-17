import 'dart:math';
import 'package:taktik/core/services/planning/topic_scorer.dart';
import 'package:taktik/data/models/plan_model.dart';
import 'package:taktik/data/models/user_model.dart';

class WeeklyScheduler {

  WeeklyPlan generateSchedule({
    required List<WeightedTopic> prioritizedTopics,
    required UserModel user,
    required DateTime startDate,
  }) {
    final List<DailyPlan> dailyPlans = [];
    final availability = user.weeklyAvailability;

    // Day mapping (Turkish to English keys usually, or consistent keys)
    // Assuming keys are 'Monday', 'Tuesday' etc. or 'Pazartesi'...
    // Let's assume the keys in availability match what we want to iterate.
    // Standard order: Pazartesi -> Pazar
    final weekDays = ['Pazartesi', 'Salı', 'Çarşamba', 'Perşembe', 'Cuma', 'Cumartesi', 'Pazar'];

    // Topics Queues
    final fixQueue = prioritizedTopics.where((t) => t.status == 'red').toList();
    final improveQueue = prioritizedTopics.where((t) => t.status == 'yellow').toList();
    final learnQueue = prioritizedTopics.where((t) => t.status == 'new').toList();
    final reviewQueue = prioritizedTopics.where((t) => t.status == 'green').toList();

    // Strategy Focus String Construction
    String strategyFocus = _generateStrategyFocus(fixQueue, learnQueue);

    for (var i = 0; i < weekDays.length; i++) {
      final dayName = weekDays[i];
      final slots = availability[dayName] ?? []; // List of time strings e.g. "09:00"

      // Sort slots by time
      slots.sort();

      final List<ScheduleItem> dailyItems = [];

      // Logic for Specific Days
      if (dayName == 'Cumartesi') {
        // Mock Exam Day
        _scheduleMockDay(dailyItems, slots, dayName);
      } else if (dayName == 'Pazar') {
        // Review Day
        _scheduleReviewDay(dailyItems, slots, dayName);
      } else {
        // Study Day
        _scheduleStudyDay(
          dailyItems,
          slots,
          dayName,
          fixQueue,
          improveQueue,
          learnQueue,
          reviewQueue
        );
      }

      dailyPlans.add(DailyPlan(
        day: dayName,
        schedule: dailyItems,
      ));
    }

    return WeeklyPlan(
      planTitle: "Kişiselleştirilmiş Strateji",
      strategyFocus: strategyFocus,
      plan: dailyPlans,
      creationDate: DateTime.now(),
      motivationalQuote: _getRandomQuote(),
    );
  }

  void _scheduleMockDay(List<ScheduleItem> items, List<String> slots, String day) {
    if (slots.isEmpty) return;

    // Find a block for the exam (usually morning)
    if (slots.isNotEmpty) {
      items.add(ScheduleItem(
        id: '${day}_mock',
        time: slots.first,
        activity: "TYT/Genel Deneme Sınavı",
        type: "exam"
      ));
    }

    // Analysis after exam
    if (slots.length > 1) {
       items.add(ScheduleItem(
        id: '${day}_analysis',
        time: slots.last,
        activity: "Deneme Analizi ve Eksik Tespiti",
        type: "review"
      ));
    }
  }

  void _scheduleReviewDay(List<ScheduleItem> items, List<String> slots, String day) {
    for (var slot in slots) {
      items.add(ScheduleItem(
        id: '${day}_${slot}',
        time: slot,
        activity: "Haftalık Genel Tekrar ve Planlama",
        type: "review"
      ));
    }
  }

  void _scheduleStudyDay(
    List<ScheduleItem> items,
    List<String> slots,
    String day,
    List<WeightedTopic> fixQ,
    List<WeightedTopic> improveQ,
    List<WeightedTopic> learnQ,
    List<WeightedTopic> reviewQ
  ) {
    String? lastSubject;

    for (var slot in slots) {
      WeightedTopic? selectedTopic;
      String type = 'study';
      String prefix = "Çalışma";

      // Selection Logic (Ratio: 40% Fix, 40% Learn, 20% Review/Improve)
      // We cycle through queues or pick based on priority

      // Simple Heuristic:
      // Priority 1: Fix Red (if not same subject as last)
      // Priority 2: Learn New
      // Priority 3: Improve Yellow

      // Try to find a 'Fix' topic not matching last subject
      selectedTopic = _pickTopic(fixQ, lastSubject);
      if (selectedTopic != null) {
        prefix = "Eksik Kapatma";
        type = "fix";
      } else {
        // Try Learn
        selectedTopic = _pickTopic(learnQ, lastSubject);
        if (selectedTopic != null) {
          prefix = "Konu Çalışması";
          type = "new";
        } else {
          // Try Improve
          selectedTopic = _pickTopic(improveQ, lastSubject);
          if (selectedTopic != null) {
            prefix = "Pekiştirme Testi";
            type = "improve";
          } else {
            // Fallback to Review or just pick anything
            if (fixQ.isNotEmpty) selectedTopic = fixQ.first;
            else if (learnQ.isNotEmpty) selectedTopic = learnQ.first;

            prefix = "Genel Tekrar";
            type = "review";
          }
        }
      }

      if (selectedTopic != null) {
        items.add(ScheduleItem(
          id: '${day}_${slot}',
          time: slot,
          activity: "$prefix: ${selectedTopic.topic} (${selectedTopic.subject})",
          type: type
        ));
        lastSubject = selectedTopic.subject;

        // Rotate: Move to end of queue to avoid repetition
        // (In a real app, we might remove it if completed, but here we schedule blocks)
        _rotateQueue(fixQ, selectedTopic);
        _rotateQueue(learnQ, selectedTopic);
        _rotateQueue(improveQ, selectedTopic);
      } else {
        items.add(ScheduleItem(
          id: '${day}_${slot}',
          time: slot,
          activity: "Serbest Çalışma / Kitap Okuma",
          type: "free"
        ));
      }
    }
  }

  WeightedTopic? _pickTopic(List<WeightedTopic> queue, String? avoidSubject) {
    if (queue.isEmpty) return null;
    try {
      return queue.firstWhere((t) => t.subject != avoidSubject);
    } catch (e) {
      return queue.first; // Return first if all match avoidSubject
    }
  }

  void _rotateQueue(List<WeightedTopic> queue, WeightedTopic item) {
    if (queue.contains(item)) {
      queue.remove(item);
      queue.add(item);
    }
  }

  String _generateStrategyFocus(List<WeightedTopic> fix, List<WeightedTopic> learn) {
    if (fix.isNotEmpty) {
      final topFix = fix.take(2).map((e) => e.topic).join(", ");
      return "Bu hafta özellikle $topFix konularındaki eksikleri kapatmaya odaklanıyoruz.";
    } else if (learn.isNotEmpty) {
      final topLearn = learn.take(2).map((e) => e.topic).join(", ");
      return "Temel konular sağlam. $topLearn ile müfredatta ilerleme zamanı.";
    }
    return "Dengeli bir ilerleme ve tekrar haftası.";
  }

  String _getRandomQuote() {
    final quotes = [
      "Başarı, her gün tekrarlanan küçük çabaların toplamıdır.",
      "Gelecek, bugünden hazırlananlara aittir.",
      "Zorluklar, başarının değerini artıran süslerdir.",
      "Asla vazgeçme. Şimdi çalıştıkların, yarınki zaferindir.",
      "Hedefine giden yolda durmadığın sürece ne kadar yavaş gittiğinin bir önemi yoktur."
    ];
    return quotes[Random().nextInt(quotes.length)];
  }
}
