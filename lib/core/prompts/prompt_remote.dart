// lib/core/prompts/prompt_remote.dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';

class RemotePrompts {
  static final Map<String, String> _cache = <String, String>{};
  static StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _sub;

  static Future<void> preloadAndWatch() async {
    try {
      final col = FirebaseFirestore.instance.collection('prompts');
      // İlk yükleme
      final qs = await col.get();
      for (final d in qs.docs) {
        final data = d.data();
        final String? content = (data['content'] as String?)?.trim();
        final bool active = (data['active'] as bool?) ?? true;
        if (active && content != null && content.isNotEmpty) {
          _cache[d.id] = content;
        }
      }
      // Canlı dinleyici
      _sub?.cancel();
      _sub = col.snapshots().listen((snap) {
        for (final ch in snap.docChanges) {
          final id = ch.doc.id;
          final data = ch.doc.data();
          if (data == null) continue;
          final String? content = (data['content'] as String?)?.trim();
          final bool active = (data['active'] as bool?) ?? true;
          if (!active || content == null || content.isEmpty) {
            _cache.remove(id);
          } else {
            _cache[id] = content;
          }
        }
      });
    } catch (_) {
      // Sessiz: varlıklar yedek olarak kullanılacak
    }
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

