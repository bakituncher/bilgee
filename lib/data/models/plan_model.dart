// lib/data/models/plan_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

// Bir günlük plandaki tek bir görevi (saat, aktivite, tür) temsil eder.
class ScheduleItem {
  final String id;
  final String time;
  final String activity;
  final String type;

  ScheduleItem({required this.id, required this.time, required this.activity, required this.type});

  factory ScheduleItem.fromMap(Map<String, dynamic> map) {
    final time = map['time'] ?? 'Belirsiz';
    final activity = map['activity'] ?? 'Görev Belirtilmemiş';
    final type = map['type'] ?? 'study';

    // DÜZELTME: hashCode kalıcı değildir. ID üretirken metinden deterministik bir parça üret.
    final cleanAct = activity.toString().replaceAll(RegExp(r'\s+'), '').toLowerCase();
    final safeAct = cleanAct.length > 30 ? cleanAct.substring(0, 30) : cleanAct;
    final generatedId = '${time}_${safeAct}_$type';

    final id = (map['id'] ?? map['uid']) ?? generatedId;
    return ScheduleItem(
      id: id,
      time: time,
      activity: activity,
      type: type,
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
      for (var i = 0; i < list.length; i++) {
        final item = list[i];
        final fallbackId = '${json['day'] ?? 'gun'}_$i';
        if (item is Map<String, dynamic>) {
          final itemWithId = {...item, 'id': item['id'] ?? fallbackId};
          scheduleItems.add(ScheduleItem.fromMap(itemWithId));
        }
        // AI'ın bazen harita yerine sadece bir metin gönderme ihtimaline karşı
        else if (item is String) {
          scheduleItems.add(ScheduleItem(id: fallbackId, time: "Görev", activity: item, type: "study"));
        }
      }
    } else if (json['schedule'] is String) {
      rawString = json['schedule'] as String;
    }

    if (scheduleItems.isEmpty && json.containsKey('tasks') && json['tasks'] is List) {
      var taskList = (json['tasks'] as List).cast<String>();
      for (var i = 0; i < taskList.length; i++) {
        final fallbackId = '${json['day'] ?? 'gun'}_$i';
        scheduleItems.add(ScheduleItem(id: fallbackId, time: "Görev", activity: taskList[i], type: "study"));
      }
    }

    // Sağlam parser: schedule boş veya stringse placeholderlarla doldur
    if (scheduleItems.isEmpty) {
      rawString = rawString ?? (json['schedule']?.toString());
      scheduleItems = [
        ScheduleItem(id: '${json['day'] ?? 'gun'}_0', time: '09:00', activity: 'Mola', type: 'break'),
        ScheduleItem(id: '${json['day'] ?? 'gun'}_1', time: '21:00', activity: 'Genel Tekrar', type: 'review'),
      ];
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
  final String? motivationalQuote; // AI tarafından üretilen motive edici söz

  // Planın süresinin dolup dolmadığını kontrol eder (7 günden eski mi?)
  bool get isExpired {
    return DateTime.now().difference(creationDate).inDays >= 7;
  }

  WeeklyPlan({required this.planTitle, required this.strategyFocus, required this.plan, required this.creationDate, this.motivationalQuote});

  factory WeeklyPlan.fromJson(Map<String, dynamic> json) {
    // Salt: plan oluşturulma anı bazlı parmak izi
    DateTime date;
    if (json['creationDate'] is Timestamp) {
      date = (json['creationDate'] as Timestamp).toDate();
    } else if (json['creationDate'] is String) {
      date = DateTime.tryParse(json['creationDate']) ?? DateTime.now();
    } else {
      date = DateTime.now();
    }

    // DÜZELTME: Salt'ı timezone'dan etkilenmeyen ham string üzerinden al.
    // Not: Timestamp geliyorsa string olmadığından, önceki davranış (epoch) korunur.
    final dateStr = json['creationDate']?.toString() ?? '';
    final planSalt = (json['creationDate'] is String) ? dateStr.hashCode.toString() : date.millisecondsSinceEpoch.toString();

    var list = (json['plan'] as List?) ?? [];
    List<DailyPlan> dailyPlans = [];
    for (var i = 0; i < list.length; i++) {
      final dayJson = list[i];
      if (dayJson is Map<String, dynamic>) {
        final withIndexId = {
          ...dayJson,
          'day': dayJson['day'],
          'schedule': (dayJson['schedule'] is List)
              ? List.generate((dayJson['schedule'] as List).length, (j) {
                  final item = (dayJson['schedule'] as List)[j];
                  if (item is Map<String, dynamic>) {
                    final baseId = item['id'] ?? '${dayJson['day'] ?? 'gun'}_${j}';
                    return {...item, 'id': '${planSalt}_$baseId'};
                  } else if (item is String) {
                    final baseId = '${dayJson['day'] ?? 'gun'}_${j}';
                    return {'id': '${planSalt}_$baseId', 'activity': item, 'time': 'Görev', 'type': 'study'};
                  }
                  return item;
                })
              : dayJson['schedule'],
        };
        dailyPlans.add(DailyPlan.fromJson(withIndexId));
      }
    }


    return WeeklyPlan(
      planTitle: json['planTitle'] ?? "Haftalık Stratejik Plan",
      strategyFocus: json['strategyFocus'] ?? "Strateji belirlenemedi.",
      plan: dailyPlans,
      creationDate: date,
      motivationalQuote: json['motivationalQuote'] as String?,
    );
  }
}