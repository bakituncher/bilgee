// lib/core/utils/json_text_cleaner.dart
import 'dart:convert';

/// Yapay zeka çıktılarındaki JSON benzeri metinleri sağlamlaştırıp
/// sadece saf JSON metnini döndürür.
/// - Baş/son code-fence (```json, ```, ~~~) ve çevresel metinleri temizler
/// - Preface/epilogue içeren yanıtlarda ilk fenced bloğu tercih eder
/// - İlk dengeli { ... } veya [ ... ] bloğunu tarayıp çıkarır
/// - Dıştaki tırnak veya tek elemanlı liste sargısını soyar
/// - Kaçışlı JSON dizesini (ör. "{\"a\":1}") tek katman çözer
/// - Minimal markdown vurguları ve trailing comma hatalarını düzeltir
class JsonTextCleaner {
  JsonTextCleaner._();

  /// Liste gibi sarmalayıcı yapılardan ilk anlamlı elemanı seçip temizler.
  static String cleanDynamic(dynamic raw) {
    var current = raw;
    // İç içe listelerden ilk elemanı alarak soy
    while (current is List && current.isNotEmpty) {
      current = current.first;
    }
    return cleanString(current?.toString() ?? '');
  }

  /// Saf String girdiyi temizler ve yalnızca JSON metnini döndürmeye çalışır.
  static String cleanString(String input) {
    String text = input.trim();

    // UTF-8 BOM ve görünmez boşlukları kaldır
    text = text
        .replaceAll(RegExp(r"^[\uFEFF\u200B\u200C\u200D\u2060]+"), "")
        .replaceAll(RegExp(r"[\u200B\u200C\u200D\u2060]"), "");

    // Baş/son code-fence (```json, ``` veya ~~~) temizliği
    text = text.replaceFirst(
      RegExp(r'^\s*(```+|~~~+)\s*(jsonc?|json5|JSONC?|JSON5|json|JSON)?\s*\n?'),
      '',
    );
    text = text.replaceFirst(
      RegExp(r'\n?\s*(```+|~~~+)\s*$'),
      '',
    );

    // İçerikte fenced blok varsa ilk bloğun içini tercih et
    final fenceMatch = RegExp(
      r'(```+|~~~+)\s*(jsonc?|json5|json|JSONC?|JSON5|JSON)?\s*([\s\S]*?)\s*(```+|~~~+)',
      multiLine: true,
    ).firstMatch(text);
    if (fenceMatch != null) {
      text = fenceMatch.group(3)!.trim();
    }

    // JSON dışı metni kaldırmak için dengeli ilk JSON bloğunu tara
    String? extractFirstJsonBlock(String src) {
      final s = src.trim();
      int start = -1;
      int end = -1;
      for (int i = 0; i < s.length; i++) {
        final c = s[i];
        if (c == '{' || c == '[') {
          start = i;
          break;
        }
      }
      if (start == -1) return null;

      final openChar = s[start];
      final closeChar = openChar == '{' ? '}' : ']';
      int depth = 0;
      bool inString = false;
      String? stringQuote; // ' veya "
      bool escaped = false;

      for (int i = start; i < s.length; i++) {
        final ch = s[i];
        if (inString) {
          if (escaped) {
            escaped = false;
          } else if (ch == '\\') {
            escaped = true;
          } else if (ch == stringQuote) {
            inString = false;
            stringQuote = null;
          }
          continue;
        } else {
          if (ch == '"' || ch == '\'') {
            inString = true;
            stringQuote = ch;
            continue;
          }
          if (ch == openChar) {
            depth++;
          } else if (ch == closeChar) {
            depth--;
            if (depth == 0) {
              end = i;
              break;
            }
          }
        }
      }

      if (start != -1 && end != -1 && end > start) {
        return s.substring(start, end + 1).trim();
      }
      return null;
    }

    final extractedByScan = extractFirstJsonBlock(text);
    if (extractedByScan != null) {
      text = extractedByScan;
    }

    // Dıştaki tırnak/tek elemanlı liste sarımları
    bool changed = true;
    while (changed && text.isNotEmpty) {
      changed = false;
      if ((text.startsWith("\'") && text.endsWith("\'")) ||
          (text.startsWith('"') && text.endsWith('"'))) {
        text = text.substring(1, text.length - 1).trim();
        changed = true;
      }
      if ((text.startsWith('[') && text.endsWith(']')) &&
          text.contains('{') &&
          text.contains('}')) {
        text = text.substring(1, text.length - 1).trim();
        changed = true;
      }
    }

    // Yedek: hala fenced kaldıysa
    final genericFence = RegExp(r"```\s*([\s\S]*?)\s*```", multiLine: true).firstMatch(text);
    if (genericFence != null) {
      text = genericFence.group(1)!.trim();
    }

    // Kaçışlı JSON dizeleri için tek katman çöz
    if (text.contains('\\"') && text.contains('{') && text.contains('}')) {
      try {
        final unescaped = jsonDecode('"' + text.replaceAll('"', '\\"') + '"');
        if (unescaped is String) {
          text = unescaped;
        }
      } catch (_) {}
    }

    // Minimal markdown vurguları temizle
    text = text.replaceAll(RegExp(r"^[\*_\s]+|[\*_\s]+$"), "").trim();

    // Trailing comma düzeltmeleri
    text = text.replaceAll(RegExp(r",\s*}"), "}").replaceAll(RegExp(r",\s*]"), "]");

    return text.trim();
  }
}

