// lib/features/weakness_workshop/logic/quiz_quality_guard.dart
import 'package:bilge_ai/features/weakness_workshop/models/study_guide_model.dart';

class QuizQualityGuardResult {
  final StudyGuideAndQuiz material;
  final List<String> issues;
  QuizQualityGuardResult(this.material, this.issues);
}

class QuizQualityGuard {
  static const int minQuestions = 5;
  static const int minTextLen = 20;

  static QuizQualityGuardResult apply(StudyGuideAndQuiz raw) {
    final issues = <String>[];
    final cleaned = <QuizQuestion>[];

    for (final q in raw.quiz) {
      if (_isQuestionValid(q, issues)) {
        cleaned.add(_dedupOptions(q));
      }
    }

    if (cleaned.length < minQuestions) {
      issues.add('Soru sayısı kalite kontrolünden sonra yetersiz kaldı (${cleaned.length}/$minQuestions).');
      // Soru kalitesi güvence altına alınamadı -> üst katman bu durumu yakalayıp yeniden deneyecek
      throw Exception('Soru kalitesi yetersiz. Lütfen tekrar deneyin.');
    }

    final guarded = StudyGuideAndQuiz(
      studyGuide: _sanitizeText(raw.studyGuide),
      quiz: cleaned,
      topic: raw.topic,
      subject: raw.subject,
    );
    return QuizQualityGuardResult(guarded, issues);
  }

  static bool _isQuestionValid(QuizQuestion q, List<String> issues) {
    final trimmedQ = _sanitizeText(q.question);
    final trimmedExpl = _sanitizeText(q.explanation);

    if (trimmedQ.length < minTextLen) {
      issues.add('Çok kısa soru elendi.');
      return false;
    }

    // Açık cevap işareti ya da "cevap:" sızıntıları
    final lower = trimmedQ.toLowerCase();
    if (lower.contains('cevap:') || lower.contains('doğru cevap') || lower.contains('(c)') || lower.contains('[doğru]')) {
      issues.add('Cevap sızıntısı içeren soru elendi.');
      return false;
    }

    if (trimmedExpl.length < minTextLen || trimmedExpl.toLowerCase().contains('bulunamadı')) {
      issues.add('Yetersiz açıklama nedeniyle soru elendi.');
      return false;
    }

    if (q.options.isEmpty || q.correctOptionIndex < 0 || q.correctOptionIndex >= q.options.length) {
      issues.add('Geçersiz şık/indeks nedeniyle soru elendi.');
      return false;
    }

    // Şıkların temizlik ve benzersizlik kontrolü
    final cleaned = q.options.map(_sanitizeText).toList();
    final setLower = cleaned.map((e) => e.toLowerCase()).toSet();
    if (setLower.length < 4) {
      issues.add('Tekrarlayan şıklar nedeniyle soru elendi.');
      return false;
    }

    // Doğru şık boş/placeholder olmasın
    final correct = cleaned[q.correctOptionIndex];
    if (correct.trim().isEmpty || correct.toLowerCase().startsWith('seçenek ')) {
      issues.add('Doğru şık geçersiz görünüyor.');
      return false;
    }

    return true;
  }

  static QuizQuestion _dedupOptions(QuizQuestion q) {
    final seen = <String, int>{};
    final cleaned = <String>[];
    for (final opt in q.options) {
      final k = _sanitizeText(opt).trim();
      final lk = k.toLowerCase();
      if (!seen.containsKey(lk)) {
        seen[lk] = 1;
        cleaned.add(k);
      }
    }

    // En az 4 şık garanti et
    int fillerIndex = 0;
    while (cleaned.length < 4) {
      cleaned.add('Diğer Seçenek ${++fillerIndex}');
    }
    if (cleaned.length > 5) {
      cleaned.removeRange(5, cleaned.length);
    }

    int idx = q.correctOptionIndex;
    if (idx >= cleaned.length) idx = 0;

    return QuizQuestion(
      question: _sanitizeText(q.question),
      options: cleaned,
      correctOptionIndex: idx,
      explanation: _sanitizeText(q.explanation),
    );
  }

  static String _sanitizeText(String v) {
    return v.replaceAll('\r', '').replaceAll('\t', ' ').replaceAll('  ', ' ').trim();
  }
}

