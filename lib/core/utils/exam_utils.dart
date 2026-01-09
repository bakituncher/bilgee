// lib/core/utils/exam_utils.dart
import 'package:taktik/data/models/exam_model.dart';
import 'package:taktik/data/models/user_model.dart';

class ExamUtils {
  const ExamUtils._();

  static List<ExamSection> getRelevantSectionsForUser(UserModel user, Exam exam) {
    if (user.selectedExam == ExamType.lgs.name) {
      return exam.sections;
    } else if (user.selectedExam == ExamType.yks.name) {
      final tytSection = exam.sections.firstWhere((s) => s.name == 'TYT');

      // TYT seçildiyse sadece TYT döndür
      if (user.selectedExamSection == 'TYT') {
        return [tytSection];
      }

      // YDT seçildiyse TYT ve YDT'yi döndür (YDT öğrencileri her ikisine de girer)
      if (user.selectedExamSection == 'YDT') {
        final ydtSection = exam.sections.firstWhere(
          (s) => s.name == 'YDT',
          orElse: () => exam.sections.first,
        );
        return [tytSection, ydtSection];
      }

      final userAytSection = exam.sections.firstWhere(
        (s) => s.name == user.selectedExamSection,
        orElse: () => exam.sections.first,
      );
      if (tytSection.name == userAytSection.name) return [tytSection];
      return [tytSection, userAytSection];
    } else if (user.selectedExam == ExamType.ags.name) {
      // --- AGS GÜNCELLEMESİ ---

      // 1. Ortak Oturumu Bul
      final commonSection = exam.sections.firstWhere(
        (s) => s.name == 'AGS Ortak',
        orElse: () => exam.sections.first,
      );

      // 2. Kullanıcının Branşını (Alan Oturumu) Bul
      // user.selectedExamSection kullanıcının branş ismini tutar (Örn: "Türkçe Öğretmenliği")
      final branchSection = exam.sections.firstWhere(
        (s) => s.name == user.selectedExamSection,
        orElse: () => commonSection,
      );

      // Eğer branş bulunamazsa veya bir hata varsa sadece ortak oturumu dön
      if (commonSection.name == branchSection.name) {
        return [commonSection];
      }

      // 3. Her iki oturumu da listede döndür (UI'da iki kart çıkmasını sağlar)
      return [commonSection, branchSection];
    } else {
      final relevantSection = exam.sections.firstWhere(
        (s) => s.name == user.selectedExamSection,
        orElse: () => exam.sections.first,
      );
      return [relevantSection];
    }
  }
}
