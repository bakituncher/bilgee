// lib/core/prompts/prompt_remote.dart
import 'dart:async';

class RemotePrompts {
  static final Map<String, String> _cache = <String, String>{};

  static Future<void> preloadAndWatch() async {
    // Firestore'dan veri çekme işlemi devre dışı bırakıldı.
    // Sadece uygulama içi sabit promptlar kullanılacak.
    // Eğer yedek promptlar varsa burada elle ekleyebilirsiniz.
    // Örnek: _cache['example'] = 'örnek içerik';
    return;
  }

  static String? get(String key) => _cache[key];

  static String fillTemplate(String template, Map<String, String> values) {
    var out = template;
    values.forEach((k, v) {
      out = out.replaceAll('{{$k}}', v);
    });
    return out;
  }
}
