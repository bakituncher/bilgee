// lib/data/models/plan_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

// Bir günlük plandaki tek bir görevi (saat, aktivite, tür) temsil eder.
class ScheduleItem {
  final String time;
  final String activity;
  final String type;

  ScheduleItem({required this.time, required this.activity, required this.type});

  factory ScheduleItem.fromMap(Map<String, dynamic> map) {
    return ScheduleItem(
      time: map['time'] ?? 'Belirsiz',
      activity: map['activity'] ?? 'Görev Belirtilmemiş',
      type: map['type'] ?? 'study',
    );
  }

  @override
  String toString() {
    return activity;
  }
}

// Bir günün tamamını (örn: Pazartesi) ve o günün tüm görevlerini içerir.
class DailyPlan {
  final String day;
  final List<ScheduleItem> schedule;
  final String? rawScheduleString;

  DailyPlan({required this.day, required this.schedule, this.rawScheduleString});

  factory DailyPlan.fromJson(Map<String, dynamic> json) {
    List<ScheduleItem> scheduleItems = [];
    String? rawString;

    if (json['schedule'] is List) {
      var list = (json['schedule'] as List);
      // GÜNCELLENMİŞ, SAĞLAMLAŞTIRILMIŞ PARSER
      for (var item in list) {
        if (item is Map<String, dynamic>) {
          scheduleItems.add(ScheduleItem.fromMap(item));
        }
        // AI'ın bazen harita yerine sadece bir metin gönderme ihtimaline karşı
        else if (item is String) {
          scheduleItems.add(ScheduleItem(time: "Görev", activity: item, type: "study"));
        }
      }
    } else if (json['schedule'] is String) {
      rawString = json['schedule'] as String;
    }

    if (json.containsKey('tasks') && json['tasks'] is List) {
      var taskList = (json['tasks'] as List).cast<String>();
      scheduleItems.addAll(taskList.map((task) => ScheduleItem(time: "Görev", activity: task, type: "study")));
    }


    return DailyPlan(
      day: json['day'] ?? 'Bilinmeyen Gün',
      schedule: scheduleItems,
      rawScheduleString: rawString,
    );
  }
}

// Tüm haftalık planı kapsayan ana model.
class WeeklyPlan {
  final String planTitle;
  final String strategyFocus;
  final List<DailyPlan> plan;
  final DateTime creationDate;

  WeeklyPlan({required this.planTitle, required this.strategyFocus, required this.plan, required this.creationDate});

  factory WeeklyPlan.fromJson(Map<String, dynamic> json) {
    var list = (json['plan'] as List?) ?? [];
    List<DailyPlan> dailyPlans = list.map((i) => DailyPlan.fromJson(i)).toList();

    DateTime date;
    if (json['creationDate'] is Timestamp) {
      date = (json['creationDate'] as Timestamp).toDate();
    } else if (json['creationDate'] is String) {
      date = DateTime.parse(json['creationDate']);
    } else {
      date = DateTime.now(); // Fallback
    }

    return WeeklyPlan(
      planTitle: json['planTitle'] ?? "Haftalık Stratejik Plan",
      strategyFocus: json['strategyFocus'] ?? "Strateji belirlenemedi.",
      plan: dailyPlans,
      creationDate: date,
    );
  }
}