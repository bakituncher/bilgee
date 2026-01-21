// lib/features/weakness_workshop/logic/quiz_quality_guard.dart
import 'package:taktik/features/weakness_workshop/models/workshop_model.dart';

class QuizQualityGuardResult {
  final WorkshopModel material;
  final List<String> issues;
  QuizQualityGuardResult(this.material, this.issues);
}

class QuizQualityGuard {
  // SEKTÖR STANDARDI: AI çıktısına güven, sadece teknik çökme risklerini engelle.
  // Gereksiz filtreler, şık eklemeler ve yapay zeka müdahaleleri kaldırıldı.

  static QuizQualityGuardResult apply(WorkshopModel raw) {
    // Sadece loglama için liste, kullanıcıya hata göstermek için değil.
    final issues = <String>[];

    // Eğer quiz modu değilse veya boşsa direkt geç.
    if (raw.quiz == null || raw.quiz!.isEmpty) {
      return QuizQualityGuardResult(raw, issues);
    }

    final validQuestions = <QuizQuestion>[];

    for (int i = 0; i < raw.quiz!.length; i++) {
      final q = raw.quiz![i];

      // 1. Teknik Bütünlük Kontrolü:
      // Soru metni veya şıklar tamamen boşsa bu soruyu atla (Çökmemesi için).
      if (q.question.trim().isEmpty || q.options.isEmpty) {
        issues.add('Soru ${i + 1}: İçerik boş olduğu için atlandı.');
        continue;
      }

      // 2. Index Güvenliği (Crash Önleyici):
      // AI bazen 4 şık verir ama doğru cevaba 5. şık (index 4) der. Bunu düzelt.
      int safeIndex = q.correctOptionIndex;
      if (safeIndex < 0 || safeIndex >= q.options.length) {
        safeIndex = 0; // Hatalıysa varsayılan olarak A şıkkını (0) seç.
        issues.add('Soru ${i + 1}: Cevap anahtarı düzeltildi.');
      }

      // 3. Basit Temizlik (Trim):
      // İçeriğe karışma, sadece baştaki/sondaki boşlukları al.
      validQuestions.add(QuizQuestion(
        question: q.question.trim(),
        options: q.options.map((o) => o.trim()).toList(),
        correctOptionIndex: safeIndex,
        explanation: q.explanation.trim().isEmpty ? "Detaylı açıklama panelde." : q.explanation.trim(),
      ));
    }

    // Eğer hiç soru kalmadıysa hata fırlatmak yerine (ki app çökmesin),
    // raw (ham) halini veya boş listeyi döndür.
    // NOT: Bu senaryo guard gevşetildiği için neredeyse imkansızdır.

    final guarded = WorkshopModel(
      id: raw.id,
      studyGuide: raw.studyGuide, // Konu anlatımına hiç dokunma
      quiz: validQuestions,
      topic: raw.topic,
      subject: raw.subject,
      savedDate: raw.savedDate,
    );

    return QuizQualityGuardResult(guarded, issues);
  }
}
