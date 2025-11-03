// lib/features/weakness_workshop/logic/quiz_quality_guard.dart
import 'package:taktik/features/weakness_workshop/models/study_guide_model.dart';

class QuizQualityGuardResult {
  final StudyGuideAndQuiz material;
  final List<String> issues;
  QuizQualityGuardResult(this.material, this.issues);
}

class QuizQualityGuard {
  static const int minQuestions = 3;
  static const int minTextLen = 12;
  static const int minExplLen = 20;

  static QuizQualityGuardResult apply(StudyGuideAndQuiz raw) {
    final issues = <String>[];
    final cleaned = <QuizQuestion>[];
    final seenQuestions = <String>{};

    for (final q in raw.quiz) {
      // Aynı soru tekrarlarını ele
      final normQ = _normalize(q.question);
      if (seenQuestions.contains(normQ)) {
        issues.add('Tekrarlanan soru elendi.');
        continue;
      }
      final tmpIssues = <String>[];
      if (_isQuestionValid(q, tmpIssues)) {
        final deduped = _dedupOptions(q);
        // Yer tutucu/boş şıklar nedeniyle elemek yerine, şıkları temizleyip eksikleri dolduruyoruz
        cleaned.add(deduped);
        seenQuestions.add(normQ);
      } else {
        issues.addAll(tmpIssues);
      }
    }

    if (cleaned.length < minQuestions) {
      issues.add('Soru sayısı kalite kontrolünden sonra yetersiz kaldı (${cleaned.length}/$minQuestions).');
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

    // Cevap sızıntıları (yalnızca açık işaretler)
    final lower = trimmedQ.toLowerCase();
    if (lower.contains('cevap:') || lower.contains('doğru cevap') || lower.contains('[doğru]')) {
      issues.add('Cevap sızıntısı içeren soru elendi.');
      return false;
    }

    // Açıklama yeterliliği (yalnızca uzunluk)
    if (trimmedExpl.length < minExplLen) {
      issues.add('Yetersiz açıklama nedeniyle soru elendi.');
      return false;
    }

    // Şıklar ve indeks
    if (q.options.isEmpty || q.correctOptionIndex < 0 || q.correctOptionIndex >= q.options.length) {
      issues.add('Geçersiz şık/indeks nedeniyle soru elendi.');
      return false;
    }

    // Şıkların temizlik ve benzersizlik kontrolü (en az 3 benzersiz şık)
    final cleaned = q.options.map(_sanitizeText).where((e) => e.trim().isNotEmpty).toList();
    final setLower = cleaned.map((e) => e.toLowerCase()).toSet();
    if (setLower.length < 3) {
      issues.add('Tekrarlayan şıklar nedeniyle soru elendi.');
      return false;
    }

    // Doğru şık boş/placeholder olmasın
    final correct = cleaned[q.correctOptionIndex];
    if (correct.trim().isEmpty || correct.toLowerCase().startsWith('seçenek ') || _isPlaceholderOption(correct)) {
      issues.add('Doğru şık geçersiz görünüyor.');
      return false;
    }

    return true;
  }

  static bool _isPlaceholderOption(String s) {
    final l = s.trim().toLowerCase();
    return l.isEmpty || l == 'a' || l == 'b' || l == 'c' || l == 'd' || l == 'e' ||
        l.startsWith('seçenek') || l.startsWith('diğer seçenek') || l.startsWith('option');
  }

  static QuizQuestion _dedupOptions(QuizQuestion q) {
    final seen = <String, int>{};
    final cleaned = <String>[];
    
    // CRITICAL FIX: Track where the original correct option moves to
    int newCorrectIndex = -1;
    final originalCorrectOption = q.correctOptionIndex >= 0 && q.correctOptionIndex < q.options.length
        ? _sanitizeText(q.options[q.correctOptionIndex]).trim().toLowerCase()
        : '';
    
    for (int i = 0; i < q.options.length; i++) {
      final opt = q.options[i];
      final k = _sanitizeText(opt).trim();
      final lk = k.toLowerCase();
      // Yer tutucu/boş şıkları atla
      if (k.isEmpty || _isPlaceholderOption(k)) continue;
      if (!seen.containsKey(lk)) {
        seen[lk] = 1;
        cleaned.add(k);
        // Track if this is the correct answer
        if (lk == originalCorrectOption && newCorrectIndex == -1) {
          newCorrectIndex = cleaned.length - 1;
        }
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

    // Use the tracked new index, or default to 0 if not found
    int idx = newCorrectIndex >= 0 && newCorrectIndex < cleaned.length ? newCorrectIndex : 0;

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

  static String _normalize(String v) => _sanitizeText(v).toLowerCase();
}
