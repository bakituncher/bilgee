// lib/core/utils/exam_utils.dart
import 'package:bilge_ai/data/models/exam_model.dart';
import 'package:bilge_ai/data/models/user_model.dart';

class ExamUtils {
  const ExamUtils._();

  static List<ExamSection> getRelevantSectionsForUser(UserModel user, Exam exam) {
    if (user.selectedExam == ExamType.lgs.name) {
      return exam.sections;
    } else if (user.selectedExam == ExamType.yks.name) {
      final tytSection = exam.sections.firstWhere((s) => s.name == 'TYT');
      final userAytSection = exam.sections.firstWhere(
        (s) => s.name == user.selectedExamSection,
        orElse: () => exam.sections.first,
      );
      if (tytSection.name == userAytSection.name) return [tytSection];
      return [tytSection, userAytSection];
    } else {
      final relevantSection = exam.sections.firstWhere(
        (s) => s.name == user.selectedExamSection,
        orElse: () => exam.sections.first,
      );
      return [relevantSection];
    }
  }
}

