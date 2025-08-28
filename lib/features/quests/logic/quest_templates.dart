// lib/features/quests/logic/quest_templates.dart
import 'package:bilge_ai/data/models/test_model.dart';
import 'package:bilge_ai/data/models/user_model.dart';
import 'package:bilge_ai/features/stats/logic/stats_analysis.dart';
import 'package:bilge_ai/features/quests/models/quest_model.dart';

/// Görev şablonları için bağlam nesnesi
class QuestContext {
  final List<TestModel> tests;
  final double yesterdayPlanRatio;
  final bool wasInactiveYesterday;
  final int todayCompletedPlanTasks;
  final Set<String> completedCategoriesToday; // enum adları string olarak
  final List<Quest> activeQuests; // yeni

  QuestContext({
    required this.tests,
    required this.yesterdayPlanRatio,
    required this.wasInactiveYesterday,
    required this.todayCompletedPlanTasks,
    required this.completedCategoriesToday,
    required this.activeQuests,
  });
}

abstract class QuestTemplate {
  Map<String, dynamic> get data;

  String get id => (data['id'] ?? '').toString();
  String get category => (data['category'] ?? 'engagement').toString();

  /// Kullanıcı için uygunluk kontrolü
  bool isEligible(UserModel user, StatsAnalysis? analysis, QuestContext ctx);

  /// Puan hesaplama (önem derecesi). Uygun değilse 0 döndür.
  int calculateScore(UserModel user, StatsAnalysis? analysis, QuestContext ctx);

  /// Şablon-değişkenleri (örn. {subject}) çözümle
  Map<String, String> resolveVariables(UserModel user, StatsAnalysis? analysis, QuestContext ctx) => <String, String>{};
}

/// Varsayılan/Genel şablon sınıfı: Eski mantığı birebir uygular
class GenericQuestTemplate extends QuestTemplate {
  @override
  final Map<String, dynamic> data;
  GenericQuestTemplate(this.data);

  Map<String, dynamic> get _triggers => (data['triggerConditions'] as Map<String, dynamic>?) ?? const {};

  bool _passesSpecialTriggers(UserModel user, QuestContext ctx) {
    // wasInactiveYesterday
    if (_triggers.containsKey('wasInactiveYesterday') && _triggers['wasInactiveYesterday'] == true && !ctx.wasInactiveYesterday) {
      return false;
    }
    // lowYesterdayPlanRatio
    if (_triggers.containsKey('lowYesterdayPlanRatio') && _triggers['lowYesterdayPlanRatio'] == true && !(ctx.yesterdayPlanRatio < 0.5)) {
      return false;
    }
    // highYesterdayPlanRatio
    if (_triggers.containsKey('highYesterdayPlanRatio') && _triggers['highYesterdayPlanRatio'] == true && !(ctx.yesterdayPlanRatio >= 0.85)) {
      return false;
    }
    // afterQuest -> aktif günlük görevler içinde önceki görevin tamamlanmış olması gerekir
    if (_triggers.containsKey('afterQuest')) {
      final prevId = _triggers['afterQuest'];
      final prevList = ctx.activeQuests.where((q) => q.id == prevId).toList();
      if (prevList.isEmpty || !prevList.first.isCompleted) return false;
    }
    // comboEligible
    if (_triggers.containsKey('comboEligible') && _triggers['comboEligible'] == true && !(ctx.todayCompletedPlanTasks >= 2)) {
      return false;
    }
    // multiCategoryDay
    if (_triggers.containsKey('multiCategoryDay') && _triggers['multiCategoryDay'] == true && !((ctx.completedCategoriesToday.length >= 2) && (ctx.completedCategoriesToday.length < 4))) {
      return false;
    }
    // streakAtRisk
    if (_triggers.containsKey('streakAtRisk') && _triggers['streakAtRisk'] == true) {
      final risk = user.dailyScheduleStreak > 0 && ctx.todayCompletedPlanTasks == 0;
      if (!risk) return false;
    }
    // reflectionNotDone -> şimdilik her zaman uygun (eski mantık)
    return true;
  }

  bool _passesClassicConditions(StatsAnalysis? analysis, QuestContext ctx) {
    final conditions = (data['triggerConditions'] as Map<String, dynamic>?) ?? const {};
    // hasWeakSubject
    if (conditions['hasWeakSubject'] == true) {
      final ws = analysis?.weakestSubjectByNet;
      if (ws == null || ws == 'Belirlenemedi') return false;
    }
    // hasStrongSubject
    if (conditions['hasStrongSubject'] == true) {
      final ss = analysis?.strongestSubjectByNet;
      if (ss == null || ss == 'Belirlenemedi') return false;
    }
    // noRecentTest
    if (conditions['noRecentTest'] == true) {
      final lastTestDate = ctx.tests.isNotEmpty ? ctx.tests.first.date : null;
      if (lastTestDate != null && DateTime.now().difference(lastTestDate).inDays <= 3) return false;
    }
    return true;
  }

  @override
  bool isEligible(UserModel user, StatsAnalysis? analysis, QuestContext ctx) {
    if (!_passesSpecialTriggers(user, ctx)) return false;
    if (!_passesClassicConditions(analysis, ctx)) return false;
    return true;
  }

  @override
  int calculateScore(UserModel user, StatsAnalysis? analysis, QuestContext ctx) {
    if (!isEligible(user, analysis, ctx)) return 0;
    int score = 100;
    final conditions = (data['triggerConditions'] as Map<String, dynamic>?) ?? const {};
    if (conditions['hasWeakSubject'] == true) {
      score += 250;
    }
    if (conditions['hasStrongSubject'] == true) {
      score += 100;
    }
    if (conditions['noRecentTest'] == true) {
      final lastTestDate = ctx.tests.isNotEmpty ? ctx.tests.first.date : null;
      if (lastTestDate == null || DateTime.now().difference(lastTestDate).inDays > 3) {
        score += 200;
      }
    }
    return score;
  }

  @override
  Map<String, String> resolveVariables(UserModel user, StatsAnalysis? analysis, QuestContext ctx) {
    final vars = <String, String>{};
    final conditions = (data['triggerConditions'] as Map<String, dynamic>?) ?? const {};
    if (conditions['hasWeakSubject'] == true) {
      final ws = analysis?.weakestSubjectByNet;
      if (ws != null && ws != 'Belirlenemedi') vars['{subject}'] = ws;
    }
    if (conditions['hasStrongSubject'] == true) {
      final ss = analysis?.strongestSubjectByNet;
      if (ss != null && ss != 'Belirlenemedi') vars['{subject}'] = ss;
    }
    return vars;
  }
}

class ConsistencyQuestTemplate extends GenericQuestTemplate {
  ConsistencyQuestTemplate(Map<String, dynamic> data) : super(data);
}

class PracticeQuestTemplate extends GenericQuestTemplate {
  PracticeQuestTemplate(Map<String, dynamic> data) : super(data);
}

class EngagementQuestTemplate extends GenericQuestTemplate {
  EngagementQuestTemplate(Map<String, dynamic> data) : super(data);
}

class StudyQuestTemplate extends GenericQuestTemplate {
  StudyQuestTemplate(Map<String, dynamic> data) : super(data);
}

class TestSubmissionQuestTemplate extends GenericQuestTemplate {
  TestSubmissionQuestTemplate(Map<String, dynamic> data) : super(data);
}

class QuestTemplateFactory {
  static QuestTemplate fromMap(Map<String, dynamic> map) {
    final category = (map['category'] ?? 'engagement').toString();
    switch (category) {
      case 'consistency':
        return ConsistencyQuestTemplate(map);
      case 'practice':
        return PracticeQuestTemplate(map);
      case 'study':
        return StudyQuestTemplate(map);
      case 'test_submission':
        return TestSubmissionQuestTemplate(map);
      case 'engagement':
      default:
        return EngagementQuestTemplate(map);
    }
  }
}
