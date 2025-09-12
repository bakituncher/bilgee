// lib/data/models/user_stats_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class UserStats {
  final int streak;
  final int testCount;
  final double totalNetSum;
  final int engagementScore;
  final DateTime? lastStreakUpdate;
  // YENI ALANLAR
  final int focusMinutes; // toplu odaklanma dakikası
  final int bp; // Bilgelik Puanı (genel)
  final int pomodoroSessions; // tamamlanan pomodoro seans sayısı
  final int pomodoroBp; // YENI: Sadece Pomodoro seanslarından gelen BP
  final int totalFocusSeconds; // YENI: Toplam odak saniyesi (daha hassas metrik)
  final DateTime? updatedAt; // EKLENDI: son güncelleme
  final Map<String, int> focusRollup30; // YENI: Son ~30 güne ait gün=dk haritası

  const UserStats({
    this.streak = 0,
    this.testCount = 0,
    this.totalNetSum = 0.0,
    this.engagementScore = 0,
    this.lastStreakUpdate,
    this.focusMinutes = 0,
    this.bp = 0,
    this.pomodoroSessions = 0,
    this.pomodoroBp = 0,
    this.totalFocusSeconds = 0,
    this.updatedAt,
    this.focusRollup30 = const {},
  });

  factory UserStats.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    Map<String, int> roll = {};
    final raw = data['focusRollup30'];
    if (raw is Map) {
      roll = raw.map((k, v) => MapEntry(k.toString(), (v is num) ? v.toInt() : 0));
    }
    return UserStats(
      streak: (data['streak'] as num?)?.toInt() ?? 0,
      testCount: (data['testCount'] as num?)?.toInt() ?? 0,
      totalNetSum: (data['totalNetSum'] as num?)?.toDouble() ?? 0.0,
      engagementScore: (data['engagementScore'] as num?)?.toInt() ?? 0,
      lastStreakUpdate: (data['lastStreakUpdate'] as Timestamp?)?.toDate(),
      focusMinutes: (data['focusMinutes'] as num?)?.toInt() ?? 0,
      bp: (data['bp'] as num?)?.toInt() ?? 0,
      pomodoroSessions: (data['pomodoroSessions'] as num?)?.toInt() ?? 0,
      pomodoroBp: (data['pomodoroBp'] as num?)?.toInt() ?? 0,
      totalFocusSeconds: (data['totalFocusSeconds'] as num?)?.toInt() ?? 0,
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      focusRollup30: roll,
    );
  }

  Map<String, dynamic> toMap() => {
        'streak': streak,
        'testCount': testCount,
        'totalNetSum': totalNetSum,
        'engagementScore': engagementScore,
        if (lastStreakUpdate != null)
          'lastStreakUpdate': Timestamp.fromDate(lastStreakUpdate!),
        'focusMinutes': focusMinutes,
        'bp': bp,
        'pomodoroSessions': pomodoroSessions,
        'pomodoroBp': pomodoroBp,
        'totalFocusSeconds': totalFocusSeconds,
        if (updatedAt != null) 'updatedAt': Timestamp.fromDate(updatedAt!),
        'focusRollup30': focusRollup30,
      };
}
