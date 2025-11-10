// lib/features/weakness_workshop/logic/quiz_quality_guard.dart
import 'package:taktik/features/weakness_workshop/models/study_guide_model.dart';

class QuizQualityGuardResult {
  final StudyGuideAndQuiz material;
  final List<String> issues;
  final Map<String, dynamic> qualityMetrics;
  QuizQualityGuardResult(this.material, this.issues, this.qualityMetrics);
}

class QuizQualityGuard {
  static const int minQuestions = 3;
  static const int minTextLen = 20; // Increased from 12 for better quality
  static const int minExplLen = 40; // Increased from 20 for detailed explanations
  static const int minOptionLen = 3; // Minimum length for each option
  static const int minUniqueOptions = 4; // Minimum unique options required

  static QuizQualityGuardResult apply(StudyGuideAndQuiz raw) {
    final issues = <String>[];
    final cleaned = <QuizQuestion>[];
    final seenQuestions = <String>{};
    final qualityScores = <Map<String, dynamic>>[];

    for (final q in raw.quiz) {
      // Aynı soru tekrarlarını ele
      final normQ = _normalize(q.question);
      if (seenQuestions.contains(normQ)) {
        issues.add('Tekrarlanan soru elendi: "${_truncate(q.question, 50)}"');
        continue;
      }
      final tmpIssues = <String>[];
      final qualityScore = _calculateQuestionQuality(q, tmpIssues);
      
      if (_isQuestionValid(q, tmpIssues) && qualityScore['totalScore'] >= 70) {
        final deduped = _dedupOptions(q);
        cleaned.add(deduped);
        seenQuestions.add(normQ);
        qualityScores.add(qualityScore);
      } else {
        issues.addAll(tmpIssues);
        if (qualityScore['totalScore'] < 70) {
          issues.add('Soru kalite skoru yetersiz (${qualityScore['totalScore']}/100): "${_truncate(q.question, 50)}"');
        }
      }
    }

    if (cleaned.length < minQuestions) {
      issues.add('Soru sayısı kalite kontrolünden sonra yetersiz kaldı (${cleaned.length}/$minQuestions).');
      throw Exception('Soru kalitesi yetersiz. Lütfen tekrar deneyin. Tespit edilen sorunlar: ${issues.take(3).join(", ")}');
    }

    // Calculate overall quality metrics
    final avgQuality = qualityScores.isEmpty ? 0.0 : 
      qualityScores.map((s) => s['totalScore'] as int).reduce((a, b) => a + b) / qualityScores.length;

    final qualityMetrics = {
      'questionsGenerated': raw.quiz.length,
      'questionsAccepted': cleaned.length,
      'questionsRejected': raw.quiz.length - cleaned.length,
      'averageQualityScore': avgQuality.toStringAsFixed(1),
      'issuesDetected': issues.length,
      'validationTimestamp': DateTime.now().toIso8601String(),
    };

    final guarded = StudyGuideAndQuiz(
      studyGuide: _sanitizeText(raw.studyGuide),
      quiz: cleaned,
      topic: raw.topic,
      subject: raw.subject,
    );
    return QuizQualityGuardResult(guarded, issues, qualityMetrics);
  }

  // NEW: Calculate quality score for each question (0-100)
  static Map<String, dynamic> _calculateQuestionQuality(QuizQuestion q, List<String> issues) {
    int score = 100;
    final details = <String, dynamic>{};

    // Content quality (40 points)
    final questionLen = _sanitizeText(q.question).length;
    final explLen = _sanitizeText(q.explanation).length;
    
    if (questionLen < 30) {
      score -= 15;
      details['questionLength'] = 'too_short';
    } else if (questionLen > 500) {
      score -= 5;
      details['questionLength'] = 'too_long';
    } else {
      details['questionLength'] = 'good';
    }

    if (explLen < 60) {
      score -= 15;
      details['explanationLength'] = 'too_short';
    } else if (explLen > 800) {
      score -= 5;
      details['explanationLength'] = 'too_long';
    } else {
      details['explanationLength'] = 'good';
    }

    // Options quality (30 points)
    final validOptions = q.options.where((o) => _sanitizeText(o).length >= minOptionLen).length;
    if (validOptions < 4) {
      score -= 20;
      details['optionsCount'] = 'insufficient';
    } else if (validOptions >= 5) {
      details['optionsCount'] = 'excellent';
    } else {
      score -= 5;
      details['optionsCount'] = 'acceptable';
    }

    // Check for option diversity (10 points)
    final uniqueOptions = q.options.map((o) => _sanitizeText(o).toLowerCase()).toSet().length;
    if (uniqueOptions < 4) {
      score -= 10;
      details['optionDiversity'] = 'low';
    } else {
      details['optionDiversity'] = 'good';
    }

    // Check for suspicious patterns (20 points)
    final lowerQ = _sanitizeText(q.question).toLowerCase();
    final lowerExpl = _sanitizeText(q.explanation).toLowerCase();
    
    if (_containsAnswerLeak(lowerQ)) {
      score -= 20;
      details['answerLeak'] = true;
    }

    if (_containsPlaceholder(lowerQ) || _containsPlaceholder(lowerExpl)) {
      score -= 15;
      details['placeholder'] = true;
    }

    if (!_hasProperPunctuation(q.question)) {
      score -= 5;
      details['punctuation'] = 'missing';
    }

    details['totalScore'] = score.clamp(0, 100);
    return details;
  }

  static bool _isQuestionValid(QuizQuestion q, List<String> issues) {
    final trimmedQ = _sanitizeText(q.question);
    final trimmedExpl = _sanitizeText(q.explanation);

    if (trimmedQ.length < minTextLen) {
      issues.add('Çok kısa soru elendi (${trimmedQ.length} karakter).');
      return false;
    }

    // Enhanced answer leak detection
    if (_containsAnswerLeak(trimmedQ.toLowerCase())) {
      issues.add('Cevap sızıntısı içeren soru elendi: "${_truncate(trimmedQ, 50)}"');
      return false;
    }

    // Açıklama yeterliliği (increased threshold)
    if (trimmedExpl.length < minExplLen) {
      issues.add('Yetersiz açıklama nedeniyle soru elendi (${trimmedExpl.length} karakter, minimum $minExplLen).');
      return false;
    }

    // Şıklar ve indeks
    if (q.options.isEmpty || q.correctOptionIndex < 0 || q.correctOptionIndex >= q.options.length) {
      issues.add('Geçersiz şık/indeks nedeniyle soru elendi.');
      return false;
    }

    // Şıkların temizlik ve benzersizlik kontrolü (strengthened)
    final cleaned = q.options.map(_sanitizeText).where((e) => e.trim().length >= minOptionLen).toList();
    final setLower = cleaned.map((e) => e.toLowerCase()).toSet();
    if (setLower.length < minUniqueOptions) {
      issues.add('Yetersiz benzersiz şık sayısı (${setLower.length}/$minUniqueOptions).');
      return false;
    }

    // Doğru şık boş/placeholder olmasın (enhanced check)
    if (q.correctOptionIndex >= cleaned.length) {
      issues.add('Doğru cevap indeksi geçersiz.');
      return false;
    }
    
    final correct = cleaned[q.correctOptionIndex];
    if (correct.trim().length < minOptionLen || _isPlaceholderOption(correct)) {
      issues.add('Doğru şık geçersiz veya placeholder: "${_truncate(correct, 30)}"');
      return false;
    }

    // NEW: Check for numerical/factual consistency
    if (!_checkFactualConsistency(q)) {
      issues.add('Sayısal/mantıksal tutarsızlık tespit edildi.');
      return false;
    }

    return true;
  }

  // NEW: Enhanced answer leak detection
  static bool _containsAnswerLeak(String text) {
    final leakPatterns = [
      'cevap:',
      'doğru cevap',
      '[doğru]',
      'yanıt:',
      'şıkkı doğru',
      'correct answer',
      'answer is',
      'şıkkını seç',
      'işaretleyin',
    ];
    return leakPatterns.any((pattern) => text.contains(pattern));
  }

  // NEW: Check for placeholder text
  static bool _containsPlaceholder(String text) {
    final placeholderPatterns = [
      'lorem ipsum',
      'placeholder',
      'yer tutucu',
      'örnek metin',
      '[...]',
      'todo',
      'xxx',
    ];
    return placeholderPatterns.any((pattern) => text.toLowerCase().contains(pattern));
  }

  // NEW: Check punctuation
  static bool _hasProperPunctuation(String text) {
    final trimmed = text.trim();
    return trimmed.isNotEmpty && (trimmed.endsWith('?') || trimmed.endsWith('.') || trimmed.endsWith(':'));
  }

  // NEW: Check for factual consistency (basic version)
  static bool _checkFactualConsistency(QuizQuestion q) {
    // Check if numbers in question match explanation
    final qNumbers = _extractNumbers(q.question);
    final explNumbers = _extractNumbers(q.explanation);
    final correctOption = q.options[q.correctOptionIndex];
    final correctNumbers = _extractNumbers(correctOption);

    // If question has numbers, explanation should reference them
    if (qNumbers.isNotEmpty && explNumbers.isEmpty && correctNumbers.isEmpty) {
      return false; // Explanation should discuss the numbers
    }

    return true; // Basic check passed
  }

  static List<num> _extractNumbers(String text) {
    final regex = RegExp(r'\d+\.?\d*');
    return regex.allMatches(text)
      .map((m) => num.tryParse(m.group(0)!))
      .where((n) => n != null)
      .cast<num>()
      .toList();
  }

  static bool _isPlaceholderOption(String s) {
    final l = s.trim().toLowerCase();
    if (l.length <= 2) return true; // Too short to be meaningful
    
    return l == 'a' || l == 'b' || l == 'c' || l == 'd' || l == 'e' ||
        l.startsWith('seçenek') || l.startsWith('diğer seçenek') || 
        l.startsWith('option') || l.startsWith('şık') ||
        l == 'boş' || l == 'yok' || l == 'none';
  }

  static QuizQuestion _dedupOptions(QuizQuestion q) {
    final seen = <String, int>{};
    final cleaned = <String>[];
    
    for (final opt in q.options) {
      final k = _sanitizeText(opt).trim();
      final lk = k.toLowerCase();
      // Yer tutucu/boş şıkları atla
      if (k.length < minOptionLen || _isPlaceholderOption(k)) continue;
      if (!seen.containsKey(lk)) {
        seen[lk] = 1;
        cleaned.add(k);
      }
    }

    // En az 4 şık garanti et - but use meaningful fillers
    int fillerIndex = 0;
    while (cleaned.length < 4) {
      cleaned.add('Alternatif Cevap ${String.fromCharCode(65 + fillerIndex)}');
      fillerIndex++;
    }
    
    // Limit to 5 options max
    if (cleaned.length > 5) {
      cleaned.removeRange(5, cleaned.length);
    }

    int idx = q.correctOptionIndex;
    if (idx >= cleaned.length) {
      idx = 0; // Fallback to first option if index invalid
    }

    return QuizQuestion(
      question: _sanitizeText(q.question),
      options: cleaned,
      correctOptionIndex: idx,
      explanation: _sanitizeText(q.explanation),
    );
  }

  static String _sanitizeText(String v) {
    return v.replaceAll('\r', '')
      .replaceAll('\t', ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  }

  static String _normalize(String v) => _sanitizeText(v).toLowerCase();
  
  static String _truncate(String text, int maxLen) {
    if (text.length <= maxLen) return text;
    return '${text.substring(0, maxLen)}...';
  }
}
