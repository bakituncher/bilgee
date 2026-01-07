// lib/core/prompts/tone_utils.dart
class ToneUtils {
  static String toneByExam(String? examName) {
    final name = (examName ?? '').toLowerCase();
    if (name.contains('lgs')) {
      return 'Ton: sıcak, gündelik ve motive edici; 8. sınıf/LGS bağlamı. Açık, kısa, net cümleler.';
    } else if (name.contains('yks') || name.contains('tyt') || name.contains('ayt') || name.contains('ydt')) {
      return 'Ton: sakin, stratejik ve sonuç odaklı; TYT/AYT/YDT ritmine uygun, minimal ve net.';
    } else if (name.contains('kpss')) {
      return 'Ton: olgun, profesyonel ve sürdürülebilirlik odaklı; süreklilik ve ölçülebilirlik vurgusu.';
    }
    return 'Ton: destekleyici, net ve sade; sınav bağlamına uyumlu, gereksiz süs yok.';
  }
}

