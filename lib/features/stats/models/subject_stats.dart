// lib/features/stats/models/subject_stats.dart

/// Ders istatistikleri modeli
class SubjectStats {
  final String subject;
  int totalCorrect;
  int totalWrong;
  int totalBlank;

  SubjectStats({
    required this.subject,
    required this.totalCorrect,
    required this.totalWrong,
    required this.totalBlank,
  });

  double get net => totalCorrect - (totalWrong * 0.25);
  int get total => totalCorrect + totalWrong + totalBlank;
  double get accuracy =>
      (totalCorrect + totalWrong) > 0
          ? totalCorrect / (totalCorrect + totalWrong)
          : 0;
}

