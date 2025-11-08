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
  static const int minExplLen = 40; // 45 -> 40 denge (kurtarma ekleniyor)
  static const int softExplLen = 55; // Tam kalite eşiği
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
        final deduped = _dedupOptions(q, issues); // issues aktarılıyor
        cleaned.add(deduped);
        seenQuestions.add(normQ);
      } else {
        final fixed = _autoFix(q);
        if (fixed != null) {
          final retryIssues = <String>[];
          if (_isQuestionValid(fixed, retryIssues)) {
            final deduped = _dedupOptions(fixed, issues);
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

  // Türkçe karakterleri sadeleştirme (ortografi hatalarını normalize karşılaştırma)
  static String _stripDiacritics(String s) {
    const map = {
      'ş':'s','Ş':'S','ı':'i','İ':'I','ğ':'g','Ğ':'G','ü':'u','Ü':'U','ö':'o','Ö':'O','ç':'c','Ç':'C','â':'a','î':'i','û':'u'
    };
    final sb = StringBuffer();
    for (final r in s.runes) {
      final ch = String.fromCharCode(r);
      sb.write(map[ch] ?? ch);
    }
    return sb.toString();
  }

  static bool _looksOrthographyError(String text) {
    final norm = _stripDiacritics(text.toLowerCase());
    // Normalize edilmiş hata kalıpları
    final patterns = [
      'suuralti', // şuuraltı yanlış
      'suur alti',
      'su ur alti',
      'yarin ki', // ayrı yazım
      'yariniki', // bitişik bozuk
      'yanlz', 'yanliz', 'yanliz', 'yanliz', // yalnız hataları
      'bir sey', 'birsey',
      'herkez',
      'aparmak',
      'yanrin ki'
    ];
    return patterns.any((p) => norm.contains(p.replaceAll(' ', '')) || norm.contains(p));
  }

  static bool _isQuestionValid(QuizQuestion q, List<String> issues) {
    final trimmedQ = _sanitizeText(q.question);
    final trimmedExplRaw = _sanitizeText(q.explanation);
    var trimmedExpl = trimmedExplRaw;

    // Esnek açıklama kurtarma: kısa ama içinde "çünkü" + en az iki ayırıcı varsa kabul et
    if (trimmedExpl.length < minExplLen) {
      final sentenceSeparators = RegExp(r'[.;]');
      final countSeparators = sentenceSeparators.allMatches(trimmedExpl).length;
      final hasCunku = trimmedExpl.toLowerCase().contains('çünkü');
      if (hasCunku && countSeparators >= 2) {
        issues.add('INFO: Açıklama kısa ama yapısal olarak kabul edildi.');
        trimmedExpl = trimmedExpl.padRight(minExplLen, ' '); // uzunluk eşiği için yumuşatma
      } else {
        issues.add('ERROR: Yetersiz açıklama nedeniyle soru elendi.');
        return false;
      }
    }

    // Uydurma/atıf/link kontrolü (halüsinasyonu azalt)
    final bannedTokens = ['http://','https://','www.','kaynak:','referans:','reference:','source:','url:','wikipedia','chatgpt','openai'];
    final lq = trimmedQ.toLowerCase();
    final le = trimmedExpl.toLowerCase();
    if (bannedTokens.any((t) => lq.contains(t) || le.contains(t))) {
      issues.add('ERROR: Uydurma/atıf/link içerikli ifade elendi.');
      return false;
    }

    if (trimmedQ.length < minTextLen) {
      issues.add('ERROR: Çok kısa soru elendi.');
      return false;
    }
    final lowerQ = trimmedQ.toLowerCase();
    if ((lowerQ.contains('[soru') || lowerQ.contains('köşeli parantez')) && trimmedQ.length < 80) {
      issues.add('WARN: Placeholder izleri nedeniyle soru elendi.');
      return false;
    }

    if (lowerQ.contains('cevap:') || lowerQ.contains('doğru cevap') || lowerQ.contains('[doğru]')) {
      issues.add('ERROR: Cevap sızıntısı içeren soru elendi.');
      return false;
    }

    // Yüzeysellik kontrolünü yumuşat: sadece çok kısa + "..." durumunda
    final lowerExpl = trimmedExpl.toLowerCase();
    final improbable = lowerExpl.contains('...') && trimmedExpl.length < (minExplLen + 5);
    if (improbable) {
      issues.add('WARN: Açıklama çok yüzeysel görünüyor (reddedildi).');
      return false;
    }

    if (q.options.isEmpty || q.correctOptionIndex < 0 || q.correctOptionIndex >= q.options.length) {
      issues.add('ERROR: Geçersiz şık/indeks nedeniyle soru elendi.');
      return false;
    }

    final cleanedOpts = q.options.map(_sanitizeText).where((e) => e.trim().isNotEmpty).toList();
    final filtered = cleanedOpts.where((e) => !_isPlaceholderOption(e)).toList();
    final setLower = filtered.map((e) => e.toLowerCase()).toSet();
    if (setLower.length < 3) {
      issues.add('ERROR: Tekrarlayan / placeholder şıklar nedeniyle soru elendi.');
      return false;
    }

    if (q.correctOptionIndex >= cleanedOpts.length) {
      issues.add('ERROR: Doğru şık indeksi hatalı.');
      return false;
    }
    final correct = cleanedOpts[q.correctOptionIndex];
    if (correct.trim().isEmpty || _isPlaceholderOption(correct)) {
      issues.add('ERROR: Doğru şık geçersiz görünüyor.');
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

    // Açıklama kurtarma sonrası ortografi soru türü ise biçimi uyarlayalım
    final isOrthography = original.question.toLowerCase().contains('yazım yanlışı') || original.question.toLowerCase().contains('imla');
    if (isOrthography && !expl.toLowerCase().contains('yanlış')) {
      final correctText = correctIndex < cleanedOpts.length ? cleanedOpts[correctIndex] : 'ifade';
      expl = 'Bu şıkta yanlış kullanım: "${correctText}" biçimi hatalı ise doğru yazımı burada açıkla; doğru biçim ile farkını belirt. Eğer zaten doğruysa sorunun türüyle çelişki var, yeniden yazılmalı.';
    }

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

  static QuizQuestion _dedupOptions(QuizQuestion q, List<String> issues) {
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
    final minTarget = q.options.length >= 5 ? 5 : 4;
    int fillerIndex = 0;
    while (cleaned.length < minTarget) {
      cleaned.add('Diğer Seçenek ${++fillerIndex}');
    }
    if (cleaned.length > 5) {
      cleaned.removeRange(5, cleaned.length);
    }
    int idx = cleaned.indexWhere((e) => e == originalCorrect);
    if (idx == -1 || idx >= cleaned.length) idx = 0;

    idx = _orthographyConsistencyCheck(q, idx, cleaned, issues: issues); // tutarlılık kontrolü

    return QuizQuestion(
      question: _sanitizeText(q.question),
      options: cleaned,
      correctOptionIndex: idx,
      explanation: _sanitizeText(q.explanation),
    );
  }

  // Ortografi tutarlılık kontrolü: Soru yazım/imla hatası soruyorsa açıklama ile indeks uyumunu doğrular.
  static int _orthographyConsistencyCheck(QuizQuestion original, int currentIdx, List<String> cleanedOpts, {required List<String> issues}) {
    final qLower = original.question.toLowerCase();
    final isOrthography = (qLower.contains('yazım yanlışı') || qLower.contains('imla') || (qLower.contains('hangisinde') && qLower.contains('yanlış')));
    if (!isOrthography) return currentIdx;

    final explLower = original.explanation.toLowerCase();
    final selectedText = cleanedOpts.isNotEmpty && currentIdx < cleanedOpts.length ? cleanedOpts[currentIdx] : '';

    bool selectedLooksError = _looksOrthographyError(selectedText);

    final declaresCorrect = explLower.contains('doğru cevap') || (explLower.contains('doğru') && (explLower.contains('yazılır') || explLower.contains('bitişik')));
    final mentionsYanlis = explLower.contains('yanlış');

    if (declaresCorrect && !mentionsYanlis && !selectedLooksError) {
      for (int i=0; i<cleanedOpts.length; i++) {
        if (_looksOrthographyError(cleanedOpts[i])) {
          issues.add('INFO: Ortografi çelişkisi düzeltildi: indeks $currentIdx -> $i');
          return i;
        }
      }
      issues.add('WARN: Ortografi çelişkisi: Seçilen şık açıklamada doğru; alternatif hata bulunamadı.');
    }
    return currentIdx;
  }

  static String _sanitizeText(String v) {
    // URL, atıf ve olası uydurmaları temizle
    String s = v
        .replaceAll(RegExp(r'https?://\S+'), '')
        .replaceAll(RegExp(r'\b(wikipedia|chatgpt|openai|gpt-\d)\b', caseSensitive: false), '');
    final filteredLines = s.split('\n').where((line){
      final l = line.trim().toLowerCase();
      if (l.startsWith('kaynak:') || l.startsWith('referans:') || l.startsWith('reference:') || l.startsWith('source:') || l.startsWith('url:') || l.startsWith('bkz:')) return false;
      return true;
    }).toList();
    s = filteredLines.join('\n');

    return s.replaceAll('\r', '').replaceAll('\t', ' ').replaceAll('  ', ' ').trim();
  }

  static String _normalize(String v) => _sanitizeText(v).toLowerCase();
}
