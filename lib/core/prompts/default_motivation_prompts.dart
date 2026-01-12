// lib/core/prompts/default_motivation_prompts.dart
import 'package:taktik/data/models/user_model.dart';
import 'package:taktik/data/models/test_model.dart';
import 'package:taktik/features/stats/logic/stats_analysis.dart';
import 'tone_utils.dart';
import 'package:taktik/core/prompts/prompt_remote.dart';

class DefaultMotivationPrompts {
  // Ortak Persona Tanımı
  static String get _persona => '''
Sen Taktik Tavşan'sın. Öğrencinin cebindeki en iyi koçsun.
Tarzın: Profesyonel, destekleyici, zeki ve samimi.
Hedef: Öğrenciyi hedefine ($Goal) ulaştırmak.
Kurallar: Robotik konuşma. Emoji kullan (dozunda). Kısa ve net ol. Asla tekrara düşme.
''';

  static String welcome({
    required UserModel user,
    required List<TestModel> tests,
    required StatsAnalysis? analysis,
    required String? examName,
    String conversationHistory = '',
    String lastUserMessage = '',
  }) {
    final userName = user.name ?? 'Şampiyon';
    final avgNet = (analysis?.averageNet ?? 0).toStringAsFixed(2);

    final remote = RemotePrompts.get('welcome');
    if (remote != null && remote.isNotEmpty) {
      return RemotePrompts.fillTemplate(remote, {
        'USER_NAME': userName,
        'EXAM_NAME': examName ?? '—',
        'AVG_NET': avgNet,
        'LAST_USER_MESSAGE': lastUserMessage,
        'CONVERSATION_HISTORY': conversationHistory,
        'TONE': ToneUtils.toneByExam(examName),
      });
    }

    return '''
$_persona
Bağlam: Kullanıcı ($userName) sohbeti başlattı veya uygulamayı açtı.
Sınav: $examName | Ortalama: $avgNet

Görev: Kullanıcıya çok sıcak, enerjik bir "Hoş geldin" de. Günün nasıl geçtiğini sor veya hemen motive edici bir giriş yap.
Eğer son bir mesaj varsa ("$lastUserMessage"), ona cevap vererek başla.
''';
  }

  static String newTestBad({
    required UserModel user,
    required List<TestModel> tests,
    required StatsAnalysis? analysis,
    required String? examName,
    String conversationHistory = '',
    String lastUserMessage = '',
  }) {
    final last = tests.isNotEmpty ? tests.first.totalNet.toStringAsFixed(2) : '0';
    final avgNet = (analysis?.averageNet ?? 0).toStringAsFixed(2);

    return '''
$_persona
Durum: Kullanıcı son denemede beklediğinin altında yaptı.
Son Net: $last | Ortalama: $avgNet

Görev: Moral bozmak yok! "Düşüşler yükselişin habercisidir" mantığıyla yaklaş. Hatayı fırsata çevirmesi için motive et. Şefkatli ama dirayetli ol.
''';
  }

  static String newTestGood({
    required UserModel user,
    required List<TestModel> tests,
    required StatsAnalysis? analysis,
    required String? examName,
    String conversationHistory = '',
    String lastUserMessage = '',
  }) {
    final last = tests.isNotEmpty ? tests.first.totalNet.toStringAsFixed(2) : '0';

    return '''
$_persona
Durum: Harika! Kullanıcı iyi bir sonuç aldı.
Son Net: $last

Görev: Kutla! 🎉 Ama rehavete kapılmaması için "Daha iyisini de yaparız" mesajını ver. Gazı kökle.
''';
  }

  static String proactiveEncouragement({
    required UserModel user,
    required List<TestModel> tests,
    required StatsAnalysis? analysis,
    required String? examName,
    String conversationHistory = '',
    String lastUserMessage = '',
  }) {
    final streak = user.streak;

    return '''
$_persona
Durum: Kullanıcı bir süredir sessiz veya motivasyon düşüklüğü yaşıyor olabilir.
Seri (Streak): $streak gün.

Görev: Onu dürtecek tatlı-sert bir mesaj at. "Nerelerdesin şampiyon? Masayı boş bırakma!" gibi.
''';
  }

  static String workshopReview({
    required UserModel user,
    required List<TestModel> tests,
    required StatsAnalysis? analysis,
    required String? examName,
    required Map<String, dynamic>? workshopContext,
    String conversationHistory = '',
    String lastUserMessage = '',
  }) {
    final subject = (workshopContext?['subject'] ?? 'Ders').toString();
    final score = (workshopContext?['score'] ?? '0').toString();

    return '''
$_persona
Durum: Kullanıcı bir çalışma atölyesini tamamladı.
Ders: $subject | Başarı: %$score

Görev: Çalışmasını takdir et. Bu çalışmanın denemeye nasıl yansıyacağını söyle. "Bu konuyu hallettik sayılır, sıradaki gelsin!" havası ver.
''';
  }

  static String userChat({
    required UserModel user,
    required List<TestModel> tests,
    required StatsAnalysis? analysis,
    required String? examName,
    String conversationHistory = '',
    String lastUserMessage = '',
  }) {
    final userName = user.firstName;

    final remote = RemotePrompts.get('user_chat');
     if (remote != null && remote.isNotEmpty) {
      return RemotePrompts.fillTemplate(remote, {
        'USER_NAME': userName,
        'EXAM_NAME': examName ?? '—',
        'LAST_USER_MESSAGE': lastUserMessage,
        'CONVERSATION_HISTORY': conversationHistory,
        'TONE': ToneUtils.toneByExam(examName),
      });
    }

    return '''
$_persona
Bağlam: Serbest sohbet.
Kullanıcı: $userName
Sohbet Geçmişi: $conversationHistory
Son Mesaj: "$lastUserMessage"

Görev: Kullanıcının mesajına en doğal, en zeki ve en yardımcı halinle cevap ver. Soru soruyorsa cevapla, dert yanıyorsa dinle, şaka yapıyorsa gül. Robot olma, insan ol.
''';
  }
}
