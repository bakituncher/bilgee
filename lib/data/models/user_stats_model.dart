  // lib/data/models/user_stats_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class UserStats {
  final int streak;
  final int testCount;
  final double totalNetSum;
  final int engagementScore;
  final DateTime? lastStreakUpdate;

  const UserStats({
    this.streak = 0,
    this.testCount = 0,
    this.totalNetSum = 0.0,
    this.engagementScore = 0,
    this.lastStreakUpdate,
  });

  factory UserStats.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return UserStats(
      streak: (data['streak'] as num?)?.toInt() ?? 0,
      testCount: (data['testCount'] as num?)?.toInt() ?? 0,
      totalNetSum: (data['totalNetSum'] as num?)?.toDouble() ?? 0.0,
      engagementScore: (data['engagementScore'] as num?)?.toInt() ?? 0,
      lastStreakUpdate: (data['lastStreakUpdate'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
        'streak': streak,
        'testCount': testCount,
        'totalNetSum': totalNetSum,
        'engagementScore': engagementScore,
        if (lastStreakUpdate != null)
          'lastStreakUpdate': Timestamp.fromDate(lastStreakUpdate!),
      };
}

