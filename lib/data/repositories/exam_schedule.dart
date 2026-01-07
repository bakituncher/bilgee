// lib/data/repositories/exam_schedule.dart
import 'package:taktik/data/models/exam_model.dart';

/// Sınav tarihlerini tek bir merkezde tutan ve gün bazında farkı hesaplayan yardımcı.
/// İleride Firestore/Remote Config ile güncellenebilir; şimdilik varsayılan takvim kullanılır.
class ExamSchedule {
  // Varsayılan takvim (YYYY, MM, DD)
  // Not: Eğer bugünkü tarih bu tarihin sonrasına düşerse, otomatik olarak bir sonraki yıla taşınır.
  static final Map<ExamType, (int year, int month, int day)> _defaults = {
    ExamType.yks: (0, 6, 21), // Haziran ortası (güncel yıl otomatik verilir)
    ExamType.lgs: (0, 6, 15),
    ExamType.ags: (0, 7, 12), // AGS: 12 Temmuz
    ExamType.kpssLisans: (0, 9, 7),
    ExamType.kpssOnlisans: (0, 9, 7),
    ExamType.kpssOrtaogretim: (0, 9, 21),
  };

  /// İstenen sınavın bir sonraki gerçekleşeceği tarihi döndürür.
  static DateTime getNextExamDate(ExamType type) {
    final now = DateTime.now();
    final def = _defaults[type]!;
    final year = def.$1 == 0 ? now.year : def.$1;
    var examDate = DateTime(year, def.$2, def.$3);
    if (!now.isBefore(examDate)) {
      examDate = DateTime(year + 1, def.$2, def.$3);
    }
    return examDate;
  }

  /// Sınava kaç gün kaldığını verir.
  static int daysUntilExam(ExamType type) {
    final now = DateTime.now();
    final examDate = getNextExamDate(type);
    return examDate.difference(now).inDays;
  }
}

