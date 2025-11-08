// lib/features/weakness_workshop/logic/quiz_quality_guard.dart
import 'package:taktik/features/weakness_workshop/models/study_guide_model.dart';

class QuizQualityGuardResult {
  final StudyGuideAndQuiz material;
  final List<String> issues;
  QuizQualityGuardResult(this.material, this.issues);
}

class QuizQualityGuard {
  static const int minQuestions = 3;
  static const int minTextLen = 15; // Biraz gevşetildi (18 -> 15)
  static const int minExplLen = 40; // 45 -> 40 denge
  // Otomatik tamir için maksimum ek açıklama uzunluğu
  static const int autoFixMaxExplLen = 220;

  static QuizQualityGuardResult apply(StudyGuideAndQuiz raw) {
    final issues = <String>[];
    final cleaned = <QuizQuestion>[];
    final seenQuestions = <String>{};
    final salvage = <QuizQuestion>[];

    for (final q in raw.quiz) {
      final normQ = _normalize(q.question);
      if (seenQuestions.contains(normQ)) {
        issues.add('Tekrarlanan soru elendi.');
        continue;
      }
      final tmpIssues = <String>[];
      if (_isQuestionValid(q, tmpIssues)) {
        final deduped = _dedupOptions(q);
        cleaned.add(deduped);
        seenQuestions.add(normQ);
      } else {
        final fixed = _autoFix(q);
        if (fixed != null) {
          final retryIssues = <String>[];
          if (_isQuestionValid(fixed, retryIssues)) {
            final deduped = _dedupOptions(fixed);
            cleaned.add(deduped);
            seenQuestions.add(_normalize(deduped.question));
            issues.add('Bir soru otomatik onarıldı.');
            continue;
          } else {
            tmpIssues.addAll(retryIssues);
          }
        }
        issues.addAll(tmpIssues);
      }
    }

    if (cleaned.isEmpty) {
      issues.add('Hiç geçerli soru üretilemedi.');
      throw Exception('Soru kalitesi tamamen yetersiz. Lütfen tekrar deneyin.');
    }
    if (cleaned.length < minQuestions) {
      issues.add('Uyarı: Yeterli sayıda kaliteli soru üretilemedi (${cleaned.length}/$minQuestions). Kısmi set gösteriliyor.');
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
    final lowerQ = trimmedQ.toLowerCase();
    if (lowerQ.contains('[soru') || lowerQ.contains('köşeli parantez') || RegExp(r'^\(.*\.{2,}.*\)$').hasMatch(trimmedQ)) {
      issues.add('Placeholder içerikli soru elendi.');
      return false;
    }

    if (lowerQ.contains('cevap:') || lowerQ.contains('doğru cevap') || lowerQ.contains('[doğru]')) {
      issues.add('Cevap sızıntısı içeren soru elendi.');
      return false;
    }

    if (trimmedExpl.length < minExplLen) {
      issues.add('Yetersiz açıklama nedeniyle soru elendi.');
      return false;
    }

    // Açıklamada gerekçe kelimesi zorunluluğunu esnetiyoruz; sadece tamamen anlamsız mı kontrolü
    final lowerExpl = trimmedExpl.toLowerCase();
    final improbable = lowerExpl.contains('[a şıkkı]') || lowerExpl.contains('...') && trimmedExpl.length < (minExplLen + 5);
    if (improbable) {
      issues.add('Açıklama çok yüzeysel görünüyor.');
      return false;
    }

    if (q.options.isEmpty || q.correctOptionIndex < 0 || q.correctOptionIndex >= q.options.length) {
      issues.add('Geçersiz şık/indeks nedeniyle soru elendi.');
      return false;
    }

    final cleanedOpts = q.options.map(_sanitizeText).where((e) => e.trim().isNotEmpty).toList();
    final filtered = cleanedOpts.where((e) => !_isPlaceholderOption(e)).toList();
    final setLower = filtered.map((e) => e.toLowerCase()).toSet();
    if (setLower.length < 3) {
      issues.add('Tekrarlayan / placeholder şıklar nedeniyle soru elendi.');
      return false;
    }

    if (q.correctOptionIndex >= cleanedOpts.length) {
      issues.add('Doğru şık indeksi hatalı.');
      return false;
    }
    final correct = cleanedOpts[q.correctOptionIndex];
    if (correct.trim().isEmpty || _isPlaceholderOption(correct)) {
      issues.add('Doğru şık geçersiz görünüyor.');
      return false;
    }

    return true;
  }

  // Otomatik tamir: geçersiz soruyu kurtarmaya çalışır; başarılıysa onarılmış soru döner
  static QuizQuestion? _autoFix(QuizQuestion original) {
    final qText = _sanitizeText(original.question)
        .replaceAll(RegExp(r'^\('), '')
        .replaceAll(RegExp(r'\)$'), '')
        .replaceAll(RegExp(r'\[.*?\]'), '')
        .trim();
    if (qText.length < 10) return null; // Çok kısa ise vazgeç

    // Şıkları temizle
    final cleanedOpts = <String>[];
    for (final opt in original.options) {
      var c = _sanitizeText(opt)
          .replaceAll(RegExp(r'\[.*?\]'), '')
          .replaceAll('(…)', '')
          .trim();
      if (c.isEmpty || _isPlaceholderOption(c)) continue;
      cleanedOpts.add(c);
    }
    // Minimum 3 benzersiz şık
    final uniq = cleanedOpts.map((e) => e.toLowerCase()).toSet();
    if (uniq.length < 3) return null;

    // Doğru şık indeksini korumaya çalış
    int correctIndex = original.correctOptionIndex;
    if (correctIndex >= cleanedOpts.length) correctIndex = 0;

    // Açıklama kurtarma
    var expl = _sanitizeText(original.explanation)
        .replaceAll(RegExp(r'\[.*?\]'), '')
        .trim();
    final needsExpansion = expl.length < minExplLen || _isPlaceholderOption(expl) || expl.toLowerCase().contains('...');
    if (needsExpansion) {
      final letters = ['A','B','C','D','E'];
      final correctLetter = letters[correctIndex];
      final correctText = correctIndex < cleanedOpts.length ? cleanedOpts[correctIndex] : 'ifade';
      // Diğer şıkları özetle (ilk 2-3 kelime)
      final others = <String>[];
      for (int i=0;i<cleanedOpts.length;i++) {
        if (i==correctIndex) continue;
        final parts = cleanedOpts[i].split(' ');
        others.add('${letters[i]}: ${parts.take(3).join(' ')}');
      }
      expl = 'Doğru cevap $correctLetter çünkü "$correctText" sorudaki kavramsal koşulları en tutarlı biçimde karşılıyor. Diğer seçenekler ise ${others.join(', ')} ifadeleriyle eksik ya da yanıltıcı kalıyor.';
      if (expl.length > autoFixMaxExplLen) {
        expl = expl.substring(0, autoFixMaxExplLen - 1) + '…';
      }
    }

    if (expl.length < minExplLen) return null; // Hâlâ yetersizse pes et

    return QuizQuestion(
      question: qText,
      options: cleanedOpts,
      correctOptionIndex: correctIndex,
      explanation: expl,
    );
  }

  static bool _isPlaceholderOption(String s) {
    final l = s.trim().toLowerCase();
    if (l.isEmpty) return true;
    if (RegExp(r'^\(.*\.\.\.\)$').hasMatch(l)) return true; // ( ... ) şeklinde
    return l == 'a' || l == 'b' || l == 'c' || l == 'd' || l == 'e' ||
        l.startsWith('seçenek') || l.startsWith('diğer seçenek') || l.startsWith('option') || l.contains('[a şıkkı]');
  }

  static QuizQuestion _dedupOptions(QuizQuestion q) {
    final originalCorrect = _sanitizeText(q.options.length > q.correctOptionIndex ? q.options[q.correctOptionIndex] : '');
    final seen = <String, int>{};
    final cleaned = <String>[];
    for (final opt in q.options) {
      final k = _sanitizeText(opt).trim();
      final lk = k.toLowerCase();
      if (k.isEmpty || _isPlaceholderOption(k)) continue;
      if (!seen.containsKey(lk)) {
        seen[lk] = 1;
        cleaned.add(k);
      }
    }

    // Dinamik minimum: orijinal seçenek sayısı >=5 ise 5, aksi halde 4.
    final minTarget = q.options.length >= 5 ? 5 : 4;
    int fillerIndex = 0;
    while (cleaned.length < minTarget) {
      cleaned.add('Diğer Seçenek ${++fillerIndex}');
    }
    if (cleaned.length > 5) {
      cleaned.removeRange(5, cleaned.length);
    }

    // Doğru şığı koru: mevcut listede bul, yoksa 0.
    int idx = cleaned.indexWhere((e) => e == originalCorrect);
    if (idx == -1 || idx >= cleaned.length) idx = 0;

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
