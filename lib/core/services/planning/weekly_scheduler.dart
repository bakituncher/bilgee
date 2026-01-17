import 'dart:math';
import 'package:taktik/core/services/planning/topic_scorer.dart';
import 'package:taktik/data/models/plan_model.dart';
import 'package:taktik/data/models/user_model.dart';
import 'package:intl/intl.dart';

class WeeklyScheduler {

  // Maps DateTime.weekday (1=Mon, 7=Sun) to availability keys
  static const Map<int, String> _weekdayMap = {
    1: 'Pazartesi',
    2: 'Salı',
    3: 'Çarşamba',
    4: 'Perşembe',
    5: 'Cuma',
    6: 'Cumartesi',
    7: 'Pazar',
  };

  WeeklyPlan generateSchedule({
    required List<WeightedTopic> prioritizedTopics,
    required UserModel user,
    required DateTime startDate,
  }) {
    final List<DailyPlan> dailyPlans = [];
    final availability = user.weeklyAvailability;

    // Create queues from prioritized topics
    // We sort prioritized topics again to ensure 'Red' (Fix) comes first, then 'New' (Learn), then 'Yellow' (Improve)
    // Also respect the 'score' which already includes weights.
    prioritizedTopics.sort((a, b) => b.score.compareTo(a.score));

    final fixQueue = prioritizedTopics.where((t) => t.status == 'red').toList();
    final learnQueue = prioritizedTopics.where((t) => t.status == 'new').toList();
    final improveQueue = prioritizedTopics.where((t) => t.status == 'yellow').toList();
    final reviewQueue = prioritizedTopics.where((t) => t.status == 'green').toList();

    // Strategy Focus
    String strategyFocus = _generateStrategyFocus(fixQueue, learnQueue);

    // Generate 7 days starting from startDate
    for (var i = 0; i < 7; i++) {
      final date = startDate.add(Duration(days: i));
      final weekdayIndex = date.weekday; // 1..7
      final dayKey = _weekdayMap[weekdayIndex]!; // e.g., 'Cumartesi'

      // Get availability for this specific day of the week
      final slots = List<String>.from(availability[dayKey] ?? []);
      slots.sort(); // Ensure 09:00 comes before 10:00

      final List<ScheduleItem> dailyItems = [];

      // Special Days Logic
      if (dayKey == 'Cumartesi') {
        _scheduleMockDay(dailyItems, slots, dayKey, date);
      } else if (dayKey == 'Pazar') {
        _scheduleReviewDay(dailyItems, slots, dayKey, date);
      } else {
        _scheduleStudyDay(
          items: dailyItems,
          slots: slots,
          dayKey: dayKey,
          date: date,
          fixQ: fixQueue,
          improveQ: improveQueue,
          learnQ: learnQueue,
          reviewQ: reviewQueue,
        );
      }

      // Format day name for display (e.g., "Cumartesi (12 Ekim)")
      // Or just keep the day name if the UI handles date mapping.
      // Based on the user request "don't give past days", this generation logic works for "Next 7 Days".
      // The DailyPlan model takes a 'day' string.

      dailyPlans.add(DailyPlan(
        day: dayKey,
        schedule: dailyItems,
      ));
    }

    return WeeklyPlan(
      planTitle: "Kişiselleştirilmiş Strateji",
      strategyFocus: strategyFocus,
      plan: dailyPlans,
      creationDate: startDate,
      motivationalQuote: _getRandomQuote(),
    );
  }

  void _scheduleMockDay(List<ScheduleItem> items, List<String> slots, String dayKey, DateTime date) {
    if (slots.isEmpty) return;

    // If we have at least one slot, schedule exam
    items.add(ScheduleItem(
      id: '${dayKey}_mock_${date.millisecondsSinceEpoch}',
      time: slots.first,
      activity: "TYT/Genel Deneme Sınavı",
      type: "exam"
    ));

    // If we have more slots, analysis
    if (slots.length > 1) {
       items.add(ScheduleItem(
        id: '${dayKey}_analysis_${date.millisecondsSinceEpoch}',
        time: slots.last,
        activity: "Deneme Analizi ve Eksik Tespiti",
        type: "review"
      ));
    }
  }

  void _scheduleReviewDay(List<ScheduleItem> items, List<String> slots, String dayKey, DateTime date) {
    for (var i = 0; i < slots.length; i++) {
      items.add(ScheduleItem(
        id: '${dayKey}_${slots[i]}_${date.millisecondsSinceEpoch}',
        time: slots[i],
        activity: "Haftalık Genel Tekrar ve Planlama",
        type: "review"
      ));
    }
  }

  void _scheduleStudyDay({
    required List<ScheduleItem> items,
    required List<String> slots,
    required String dayKey,
    required DateTime date,
    required List<WeightedTopic> fixQ,
    required List<WeightedTopic> improveQ,
    required List<WeightedTopic> learnQ,
    required List<WeightedTopic> reviewQ
  }) {
    String? lastSubject;

    // We want to avoid scheduling the same subject consecutively (Interleaving)
    // We also want to prioritize: Fix > Learn > Improve > Review

    for (var slot in slots) {
      WeightedTopic? selectedTopic;
      String type = 'study';
      String prefix = "Çalışma";

      // 1. Try Fix (Red) - Highest Priority
      // Try to find a Fix topic different from last subject
      selectedTopic = _pickTopic(fixQ, lastSubject);
      if (selectedTopic != null) {
        prefix = "Eksik Kapatma";
        type = "fix";
      } else {
        // 2. Try Learn (New) - Medium Priority
        selectedTopic = _pickTopic(learnQ, lastSubject);
        if (selectedTopic != null) {
          prefix = "Konu Çalışması";
          type = "new";
        } else {
          // 3. Try Improve (Yellow)
          selectedTopic = _pickTopic(improveQ, lastSubject);
          if (selectedTopic != null) {
            prefix = "Pekiştirme Testi";
            type = "improve";
          } else {
             // 4. Review (Green) or Fallback
             // If we ran out of new/fix topics, review old ones or cycle back
             if (fixQ.isNotEmpty) selectedTopic = fixQ.first; // Cycle Fix
             else if (learnQ.isNotEmpty) selectedTopic = learnQ.first; // Cycle Learn
             else if (reviewQ.isNotEmpty) selectedTopic = reviewQ.first; // Review Green

             prefix = "Genel Tekrar";
             type = "review";
          }
        }
      }

      if (selectedTopic != null) {
        items.add(ScheduleItem(
          id: '${dayKey}_${slot}_${date.millisecondsSinceEpoch}',
          time: slot,
          activity: "$prefix: ${selectedTopic.topic} (${selectedTopic.subject})",
          type: type
        ));
        lastSubject = selectedTopic.subject;

        // "Rotate" logic: Move the used topic to the end of its queue
        // This ensures we don't repeat the same topic all day if queue is small,
        // but we still cover everything.
        _rotateQueue(fixQ, selectedTopic);
        _rotateQueue(learnQ, selectedTopic);
        _rotateQueue(improveQ, selectedTopic);
        _rotateQueue(reviewQ, selectedTopic);

      } else {
        // Absolute fallback if no topics exist at all
        items.add(ScheduleItem(
          id: '${dayKey}_${slot}_${date.millisecondsSinceEpoch}',
          time: slot,
          activity: "Serbest Çalışma / Kitap Okuma",
          type: "free"
        ));
      }
    }
  }

  /// Picks a topic from the queue.
  /// Tries to find one where subject != avoidSubject (Interleaving).
  /// If all match avoidSubject (or queue has only 1), returns the first one.
  WeightedTopic? _pickTopic(List<WeightedTopic> queue, String? avoidSubject) {
    if (queue.isEmpty) return null;

    // Try to find a topic with a different subject
    try {
      return queue.firstWhere((t) => t.subject != avoidSubject);
    } catch (e) {
      // If all topics are the same subject, just return the first one
      return queue.first;
    }
  }

  void _rotateQueue(List<WeightedTopic> queue, WeightedTopic item) {
    // If the item is in the queue, move it to the end
    // This simple rotation ensures variety across the week
    final index = queue.indexOf(item);
    if (index != -1) {
      queue.removeAt(index);
      queue.add(item);
    }
  }

  String _generateStrategyFocus(List<WeightedTopic> fix, List<WeightedTopic> learn) {
    if (fix.isNotEmpty) {
      final topFix = fix.take(3).map((e) => e.topic).join(", ");
      return "Bu hafta önceliğimiz temelleri sağlamlaştırmak: $topFix konularındaki eksikleri kapatmaya odaklanıyoruz.";
    } else if (learn.isNotEmpty) {
      final topLearn = learn.take(3).map((e) => e.topic).join(", ");
      return "Temel konuların gayet iyi görünüyor. Şimdi $topLearn ile müfredatta hızla ilerleme zamanı.";
    }
    return "Harika bir seviyedesin! Bu hafta bol bol deneme çözerek hızını ve kondisyonunu artırıyoruz.";
  }

  String _getRandomQuote() {
    final quotes = [
      "Zirveye tırmanış her zaman en dik yokuşta başlar. Pes etme!",
      "Bugün attığın her adım, yarınki zaferinin temel taşıdır.",
      "Başarı tesadüf değildir; planlı çalışmanın ve azmin sonucudur.",
      "Yorulduğunda dinlenmeyi öğren, bırakmayı değil.",
      "Rakiplerin uyurken sen çalışıyorsan, zafer çok yakındır."
    ];
    return quotes[Random().nextInt(quotes.length)];
  }
}
