// lib/core/prompts/default_motivation_prompts.dart
import 'package:taktik/data/models/user_model.dart';
import 'package:taktik/data/models/test_model.dart';
import 'package:taktik/features/stats/logic/stats_analysis.dart';
import 'tone_utils.dart';
import 'package:taktik/core/prompts/prompt_remote.dart';

class DefaultMotivationPrompts {
  static String _commonHeader(String? examName) =>
      "Sen Taktik Tavşan'sın; samimi ve yetişkin bir koç gibi konuş. ${ToneUtils.toneByExam(examName)} Düz metin yaz, emoji/markdown yok. 5-6 CÜMLE YAZ, fazlası kesilir.";

  static String welcome({
    required UserModel user,
    required List<TestModel> tests,
    required StatsAnalysis? analysis,
    required String? examName,
    String conversationHistory = '',
    String lastUserMessage = '',
  }) {
    final userName = user.name ?? 'Komutan';
    final avgNet = (analysis?.averageNet ?? 0).toStringAsFixed(2);

    final remote = RemotePrompts.get('welcome');
    if (remote != null && remote.isNotEmpty) {
      return RemotePrompts.fillTemplate(remote, {
        'USER_NAME': userName,
        'EXAM_NAME': examName ?? '—',
        'AVG_NET': avgNet,
        'LAST_USER_MESSAGE': lastUserMessage.trim().isEmpty ? '—' : lastUserMessage.trim(),
        'CONVERSATION_HISTORY': conversationHistory.trim().isEmpty ? '—' : conversationHistory.trim(),
        'TONE': ToneUtils.toneByExam(examName),
      });
    }

    return '''
${_commonHeader(examName)}
Hoş geldin. Kullanıcı: $userName | Sınav: $examName | Ort Net: $avgNet
Son Mesaj: ${lastUserMessage.trim().isEmpty ? '—' : lastUserMessage.trim()}
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
    final last = tests.isNotEmpty ? tests.first.totalNet.toStringAsFixed(2) : '—';
    final avgNet = (analysis?.averageNet ?? 0).toStringAsFixed(2);

    final remote = RemotePrompts.get('new_test_bad');
    if (remote != null && remote.isNotEmpty) {
      return RemotePrompts.fillTemplate(remote, {
        'LAST_NET': last,
        'AVG_NET': avgNet,
        'EXAM_NAME': examName ?? '—',
        'LAST_USER_MESSAGE': lastUserMessage.trim().isEmpty ? '—' : lastUserMessage.trim(),
        'CONVERSATION_HISTORY': conversationHistory.trim().isEmpty ? '—' : conversationHistory.trim(),
        'TONE': ToneUtils.toneByExam(examName),
      });
    }

    return '''
${_commonHeader(examName)}
Ortalama altı deneme sonrası toparlama. Son Net: $last | Ort Net: $avgNet
Duyguyu kabul et, neden kalıcı olmadığını açıkla, somut adım öner.
Son Mesaj: ${lastUserMessage.trim().isEmpty ? '—' : lastUserMessage.trim()}
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
    final last = tests.isNotEmpty ? tests.first.totalNet.toStringAsFixed(2) : '—';
    final avgNet = (analysis?.averageNet ?? 0).toStringAsFixed(2);

    final remote = RemotePrompts.get('new_test_good');
    if (remote != null && remote.isNotEmpty) {
      return RemotePrompts.fillTemplate(remote, {
        'LAST_NET': last,
        'AVG_NET': avgNet,
        'EXAM_NAME': examName ?? '—',
        'LAST_USER_MESSAGE': lastUserMessage.trim().isEmpty ? '—' : lastUserMessage.trim(),
        'CONVERSATION_HISTORY': conversationHistory.trim().isEmpty ? '—' : conversationHistory.trim(),
        'TONE': ToneUtils.toneByExam(examName),
      });
    }

    return '''
${_commonHeader(examName)}
Ortalama üstü deneme sonrası kutlama. Son Net: $last | Ort Net: $avgNet
Başarıyı kutla, emeği takdir et, sonraki adım için heyecan yarat.
Son Mesaj: ${lastUserMessage.trim().isEmpty ? '—' : lastUserMessage.trim()}
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

    final remote = RemotePrompts.get('proactive_encouragement');
    if (remote != null && remote.isNotEmpty) {
      return RemotePrompts.fillTemplate(remote, {
        'STREAK': streak.toString(),
        'EXAM_NAME': examName ?? '—',
        'LAST_USER_MESSAGE': lastUserMessage.trim().isEmpty ? '—' : lastUserMessage.trim(),
        'CONVERSATION_HISTORY': conversationHistory.trim().isEmpty ? '—' : conversationHistory.trim(),
        'TONE': ToneUtils.toneByExam(examName),
      });
    }

    return '''
${_commonHeader(examName)}
Tempo düşüşünde hatırlatma. Günlük Seri: $streak
Molalar normal, ama harekete geçmeyi teşvik et, kolay bir adım öner.
Son Mesaj: ${lastUserMessage.trim().isEmpty ? '—' : lastUserMessage.trim()}
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
    final subject = (workshopContext?['subject'] ?? '—').toString();
    final topic = (workshopContext?['topic'] ?? '—').toString();
    final score = (workshopContext?['score'] ?? '—').toString();

    final remote = RemotePrompts.get('workshop_review');
    if (remote != null && remote.isNotEmpty) {
      return RemotePrompts.fillTemplate(remote, {
        'SUBJECT': subject,
        'TOPIC': topic,
        'SCORE': score,
        'EXAM_NAME': examName ?? '—',
        'LAST_USER_MESSAGE': lastUserMessage.trim().isEmpty ? '—' : lastUserMessage.trim(),
        'CONVERSATION_HISTORY': conversationHistory.trim().isEmpty ? '—' : conversationHistory.trim(),
        'TONE': ToneUtils.toneByExam(examName),
      });
    }

    return '''
${_commonHeader(examName)}
Etüt Odası değerlendirmesi. Ders: $subject | Konu: $topic | Başarı: %$score
Skora göre kutla veya destek ol, sonraki adımı öner.
Son Mesaj: ${lastUserMessage.trim().isEmpty ? '—' : lastUserMessage.trim()}
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
    final firstName = user.firstName.isNotEmpty ? user.firstName : 'Komutan';
    final userName = firstName[0].toUpperCase() + firstName.substring(1).toLowerCase();

    final remote = RemotePrompts.get('user_chat');
    if (remote != null && remote.isNotEmpty) {
      return RemotePrompts.fillTemplate(remote, {
        'USER_NAME': userName,
        'EXAM_NAME': examName ?? '—',
        'LAST_USER_MESSAGE': lastUserMessage.trim().isEmpty ? '—' : lastUserMessage.trim(),
        'CONVERSATION_HISTORY': conversationHistory.trim().isEmpty ? '—' : conversationHistory.trim(),
        'TONE': ToneUtils.toneByExam(examName),
      });
    }

    return '''
${_commonHeader(examName)}
Serbest sohbet. Kullanıcı: $userName
Son Mesaj: ${lastUserMessage.trim().isEmpty ? '—' : lastUserMessage.trim()}
''';
  }
}
