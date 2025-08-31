// lib/features/weakness_workshop/models/saved_workshop_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:bilge_ai/features/weakness_workshop/models/study_guide_model.dart';

class SavedWorkshopModel {
  final String id;
  final String subject;
  final String topic;
  final String studyGuide;
  final List<Map<String, dynamic>> quiz; // Firestore uyumluluğu için Map listesi
  final Timestamp savedDate;

  SavedWorkshopModel({
    required this.id,
    required this.subject,
    required this.topic,
    required this.studyGuide,
    required this.quiz,
    required this.savedDate,
  });

  // StudyGuideAndQuiz modelinden bu modele dönüşüm
  factory SavedWorkshopModel.fromStudyGuide(String id, StudyGuideAndQuiz guide) {
    // Güvenli kısaltmalar: Firestore 1MB limitine yaklaşmamak için içerik budama
    const int maxStudyGuideChars = 20000; // ~20KB (UTF-16 char sayısı) — pratikte çok daha güvenli
    const int maxExplanationChars = 400;  // her soru açıklaması için üst sınır

    String trimmedStudyGuide = guide.studyGuide;
    if (trimmedStudyGuide.length > maxStudyGuideChars) {
      trimmedStudyGuide = trimmedStudyGuide.substring(0, maxStudyGuideChars) + "\n\n[Not: Çalışma kartı kısaltıldı]";
    }

    final trimmedQuiz = guide.quiz.map((q) {
      final options = q.options;
      String exp = q.explanation;
      if (exp.length > maxExplanationChars) {
        exp = exp.substring(0, maxExplanationChars) + " …";
      }
      return {
        'question': q.question,
        'options': options,
        'correctOptionIndex': q.correctOptionIndex,
        'explanation': exp,
      };
    }).toList();

    return SavedWorkshopModel(
      id: id,
      subject: guide.subject,
      topic: guide.topic,
      studyGuide: trimmedStudyGuide,
      quiz: trimmedQuiz,
      savedDate: Timestamp.now(),
    );
  }

  // YENİ EKLENEN VE HATAYI GİDEREN CONSTRUCTOR
  factory SavedWorkshopModel.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> doc) {
    final map = doc.data()!;
    return SavedWorkshopModel(
      id: doc.id,
      subject: map['subject'] ?? 'Bilinmeyen Ders',
      topic: map['topic'] ?? 'Bilinmeyen Konu',
      studyGuide: map['studyGuide'] ?? '# Anlatım Bulunamadı',
      quiz: List<Map<String, dynamic>>.from(map['quiz'] ?? []),
      savedDate: map['savedDate'] ?? Timestamp.now(),
    );
  }

  // Firestore'a göndermek için Map'e çevirme
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'subject': subject,
      'topic': topic,
      'studyGuide': studyGuide,
      'quiz': quiz,
      'savedDate': savedDate,
    };
  }
}