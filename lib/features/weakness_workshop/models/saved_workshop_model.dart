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
    return SavedWorkshopModel(
      id: id,
      subject: guide.subject,
      topic: guide.topic,
      studyGuide: guide.studyGuide,
      quiz: guide.quiz.map((q) => {
        'question': q.question,
        'options': q.options,
        'correctOptionIndex': q.correctOptionIndex,
        'explanation': q.explanation,
      }).toList(),
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