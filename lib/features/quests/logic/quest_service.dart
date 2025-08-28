// lib/features/quests/logic/quest_service.dart
import 'dart:math';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bilge_ai/data/models/user_model.dart';
import 'package:bilge_ai/data/providers/firestore_providers.dart';
import 'package:bilge_ai/features/quests/models/quest_model.dart';
import 'package:bilge_ai/features/quests/quest_armory.dart';
import 'package:bilge_ai/features/stats/logic/stats_analysis.dart';
import 'package:uuid/uuid.dart';
import 'package:bilge_ai/data/models/exam_model.dart';
import 'package:bilge_ai/data/models/plan_model.dart';
import 'package:flutter/foundation.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:bilge_ai/data/models/test_model.dart';
import 'package:bilge_ai/features/quests/logic/quest_templates.dart';
import 'package:bilge_ai/data/models/performance_summary.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:bilge_ai/core/app_check/app_check_helper.dart';

final questServiceProvider = Provider<QuestService>((ref) {
  return QuestService(ref);
});
final questGenerationIssueProvider = StateProvider<bool>((_) => false);

class QuestService {
  final Ref _ref;
  QuestService(this._ref);

  bool _inProgress = false;

  Future<List<Quest>> refreshDailyQuestsForUser(UserModel user, {bool force = false}) async {
    if (_inProgress) {
      return await _ref.read(firestoreServiceProvider).getDailyQuestsOnce(user.id);
    }
    _inProgress = true;
    try {
      final today = DateTime.now();
      await _maybeGenerateWeeklyReport(user, today);
      final lastRefresh = user.lastQuestRefreshDate?.toDate();

      // Mevcut görevleri oku
      List<Quest> existingQuests = [];
      try {
        existingQuests = await _ref.read(firestoreServiceProvider).getDailyQuestsOnce(user.id);
      } on FirebaseException catch (e) {
        if (e.code == 'permission-denied') {
          if (kDebugMode) debugPrint('[QuestService] daily_quests permission-denied');
          _ref.read(questGenerationIssueProvider.notifier).state = true;
          return [];
        }
        rethrow;
      }

      // Bugün zaten üretilmiş ve force değilse direkt dön
      if (!force && lastRefresh != null && lastRefresh.year == today.year && lastRefresh.month == today.month && lastRefresh.day == today.day && existingQuests.isNotEmpty) {
        return existingQuests;
      }

      // Sunucu tarafı yeniden üretim (callable function)
      try {
        // App Check tokenının hazır olduğundan emin ol
        await ensureAppCheckTokenReady();
        final functions = _ref.read(functionsProvider);
        final callable = functions.httpsCallable('regenerateDailyQuests');
        await callable.call(<String, dynamic>{});
        // Üretim sonrası tekrar oku
        final refreshed = await _ref.read(firestoreServiceProvider).getDailyQuestsOnce(user.id);
        _ref.read(questGenerationIssueProvider.notifier).state = false;
        return refreshed;
      } catch (e, st) {
        if (kDebugMode) {
          debugPrint('[QuestService] server generation failed: $e');
          debugPrint(st.toString());
        }
        // Sunucu başarısızsa mevcutu döner (UX bozulmasın)
        _ref.read(questGenerationIssueProvider.notifier).state = true;
        return existingQuests;
      }
    } finally {
      _inProgress = false;
    }
  }

  // Aşağıdaki local üretim fonksiyonları artık kullanılmıyor ancak ileride geri dönüş için korunuyor.
  Future<List<Quest>> _generateQuestsForUser(UserModel user, List<Quest> existingQuests) async {
    return existingQuests; // NO-OP: sunucu tarafı üretim devrede
  }

  double? _lastDifficultyFactor;

  void _maybeInjectPlateauBreaker(UserModel user, List<Quest> quests, StatsAnalysis? analysis, List<TestModel> tests){
    if (tests.length < 3) return;
    final last3 = tests.take(3).toList();
    last3.sort((a,b)=> b.date.compareTo(a.date));
    final nets = last3.map((t)=> t.totalNet).toList();
    final avg = nets.fold<double>(0,(s,e)=>s+e)/nets.length;
    final variance = nets.map((n)=> (n-avg)*(n-avg)).fold<double>(0,(s,e)=>s+e)/nets.length;
    final trendNearbyFlat = (analysis?.trend.abs() ?? 0) < 0.5;
    if (variance < 2.0 && trendNearbyFlat) {
      final exists = quests.any((q)=> q.id=='plateau_breaker_1');
      if(!exists){
        quests.add(_personalizeQuest(Quest(
            id: 'plateau_breaker_1',
            title: 'Net Sıçratma Hamlesi',
            description: 'Son denemelerde ilerleme plato yaptı. 3 farklı dersten toplam 30 hız odaklı soru çöz (10+10+10).',
            type: QuestType.daily,
            category: QuestCategory.practice,
            progressType: QuestProgressType.increment,
            reward: 85,
            goalValue: 30,
            actionRoute: '/coach',
            route: questRouteFromPath('/coach'),
            tags: ['variety','plateau','personal']
        ), user, analysis, _ref.read(performanceProvider).value!));
      }
    }
  }

  void _maybeInjectMasteryChain(UserModel user, List<Quest> quests, StatsAnalysis? analysis){
    final strong = analysis?.strongestSubjectByNet;
    if (strong==null || strong=='Belirlenemedi') return;
    final hasChain = quests.any((q)=> q.id.startsWith('chain_mastery_'));
    if (hasChain) return;
    final idBase = 'chain_mastery_${strong.hashCode}';
    quests.add(_personalizeQuest(Quest(
        id: '${idBase}_1',
        title: 'Ustalık Zinciri I: $strong Temel Tarama',
        description: '$strong kalesinde 20 seçilmiş soru ile ritmi kur. Hız değil doğruluk öncelik. ',
        type: QuestType.daily,
        category: QuestCategory.practice,
        progressType: QuestProgressType.increment,
        reward: 60,
        goalValue: 20,
        actionRoute: '/coach',
        route: questRouteFromPath('/coach'),
        tags: ['chain','strength','subject:$strong','mastery_chain']
    ), user, analysis, _ref.read(performanceProvider).value!));
  }

  Quest _personalizeQuest(Quest q, UserModel user, StatsAnalysis? analysis, PerformanceSummary performance) {
    String reason = '';
    int rewardDelta = 0;
    int? newGoal;

    final weak = analysis?.weakestSubjectByNet;
    final strong = analysis?.strongestSubjectByNet;
    final streak = user.streak;
    final planRatio = user.lastScheduleCompletionRatio ?? 0.0;
    final recentPracticeAvg = _computeRecentPracticeAverage(user);

    if (q.tags.contains('weakness')) {
      if (weak != null && weak != 'Belirlenemedi' && !q.title.contains(weak)) {
        q = q.copyWith(title: q.title.replaceAll('{subject}', weak));
      }
      reason = 'Zayıf noktanı güçlendirmek için seçildi.';
      rewardDelta += 10;
      if (q.category == QuestCategory.practice && q.goalValue >= 40) {
        newGoal = (q.goalValue * 0.8).round().clamp(1, q.goalValue);
      }
    }
    else if (q.tags.contains('strength')) {
      if (strong != null && strong != 'Belirlenemedi' && !q.title.contains(strong)) {
        q = q.copyWith(title: q.title.replaceAll('{subject}', strong));
      }
      reason = 'Güçlü yanını hız ve doğrulukla pekiştirmek için.';
      rewardDelta += 5;
      if (q.category == QuestCategory.practice && q.goalValue >= 25) {
        newGoal = (q.goalValue * 1.1).round();
      }
    }
    else if (q.tags.contains('neglected')) {
      reason = 'Uzun süredir ihmal edilen cepheyi yeniden aktive et.';
      rewardDelta += 12;
    }
    else if (q.tags.contains('plateau')) {
      reason = 'Net eğrisi yatay. Çeşitlilik ile sıçrama hedefleniyor.';
      rewardDelta += 10;
    }
    else if (q.tags.contains('mastery_chain')) {
      reason = 'Güçlü kalede derinlemesine ustalık inşası.';
      rewardDelta += 8;
    }
    else if (q.id.startsWith('schedule_')) {
      if (planRatio < 0.5) {
        reason = 'Program ritmini yeniden ayağa kaldırman için önceliklendirildi.';
        rewardDelta += 8;
      } else if (planRatio >= 0.85) {
        reason = 'Yüksek plan uyumunu sürdürmek için ritmi koru.';
      }
    }

    if (reason.isEmpty && streak >= 3) {
      reason = 'Serini (streak: $streak) canlı tutan yapıtaşı.';
    }
    if (reason.isEmpty) {
      if (q.category == QuestCategory.practice) reason = 'Günlük soru ritmini desteklemek için.'; else if (q.category == QuestCategory.focus) reason = 'Odak kasını sistemli geliştirmek için.'; else reason = 'Gelişim dengesini korumak için.';
    }

    if (!q.description.contains('Kişisel Not:')) {
      final personalizedDescription = q.description + '\n---\nKişisel Not: ' + reason;
      q = q.copyWith(description: personalizedDescription);
    }

    if (q.category == QuestCategory.practice && newGoal == null) {
      if (planRatio < 0.5 && q.goalValue >= 20) newGoal = (q.goalValue * 0.85).round();
      else if (planRatio >= 0.85 && q.goalValue >= 15) newGoal = (q.goalValue * 1.05).round();
      if (recentPracticeAvg > 0) {
        final target = (recentPracticeAvg * 1.12).round();
        if (target > 5 && (target - q.goalValue).abs() / q.goalValue > 0.1) {
          final baseGoal = newGoal ?? q.goalValue;
          int adaptiveGoal;
          if (target > baseGoal) {
            adaptiveGoal = min(target, (baseGoal * 1.25).round());
          } else {
            adaptiveGoal = max(target, (baseGoal * 0.75).round());
          }
          newGoal = adaptiveGoal.clamp(1, 400);
        }
      }
    }

    int newReward = (q.reward + rewardDelta).clamp(1, 999);
    if (newGoal != null && newGoal != q.goalValue) {
      q = q.copyWith(goalValue: newGoal);
    }
    if (newReward != q.reward) q = q.copyWith(reward: newReward);

    final updatedTags = Set<String>.from(q.tags);
    if (q.tags.contains('weakness')) updatedTags.add('personal');
    if (planRatio < 0.5 && q.id.startsWith('schedule_')) updatedTags.add('plan_recovery');
    if (streak >= 3) updatedTags.add('streak');
    if (updatedTags.length != q.tags.length) q = q.copyWith(tags: updatedTags.toList());

    return q;
  }

  void _maybeInjectNeglectedSubjectQuest(UserModel user, List<Quest> quests, StatsAnalysis? analysis, PerformanceSummary performance) {
    if (quests.length >= 6) return;
    final neglected = _detectNeglectedSubjects(performance);
    if (neglected.isEmpty) return;
    final subject = neglected.first;
    final exists = quests.any((q)=> q.tags.contains('neglected') && q.tags.any((t)=> t == 'subject:$subject'));
    if (exists) return;
    final id = 'reengage_${subject.hashCode}';
    if (quests.any((q)=> q.id == id)) return;
    final quest = Quest(
      id: id,
      title: 'Geri Dönüş Operasyonu: $subject',
      description: '$subject cephesini yeniden aktive et. 15 odaklı soru çöz ve temelini tazele.',
      type: QuestType.daily,
      category: QuestCategory.practice,
      progressType: QuestProgressType.increment,
      reward: 55,
      goalValue: 15,
      actionRoute: '/coach',
      route: questRouteFromPath('/coach'),
      tags: ['neglected','subject:$subject','weakness','personal'],
    );
    quests.add(_personalizeQuest(quest, user, analysis, performance));
  }

  List<String> _detectNeglectedSubjects(PerformanceSummary performance) {
    if (performance.topicPerformances.isEmpty) return [];
    final Map<String,int> totals = {};
    performance.topicPerformances.forEach((subject, topics) {
      int sum = 0;
      topics.forEach((_, perf) { sum += (perf.correctCount + perf.wrongCount + perf.blankCount); });
      totals[subject] = sum;
    });
    if (totals.isEmpty) return [];
    final maxVal = totals.values.fold<int>(0,(m,v)=> v>m? v:m);
    if (maxVal <= 0) return [];
    final threshold = (maxVal * 0.3).ceil();
    final neglected = totals.entries.where((e)=> e.value>0 && e.value < threshold).map((e)=> e.key).toList();
    neglected.sort((a,b)=> totals[a]!.compareTo(totals[b]!));
    return neglected;
  }

  double _computeRecentPracticeAverage(UserModel user,{int days=7}) {
    if (user.recentPracticeVolumes.isEmpty) return 0;
    final now = DateTime.now();
    int sum = 0; int count = 0;
    user.recentPracticeVolumes.forEach((dateKey, value) {
      final dt = DateTime.tryParse(dateKey);
      if (dt != null) {
        final diff = now.difference(dt).inDays;
        if (diff >=0 && diff < days) {
          sum += value; count++;
        }
      }
    });
    if (sum==0 || count==0) return 0;
    return sum / count.toDouble();
  }

  Future<void> _injectScheduleBasedQuests(UserModel user, List<Quest> quests, {required List<TestModel> tests}) async {
    // PLAN TABANLI GÖREVLER KALDIRILDI
    return;
  }

  void _normalizeDailyRewards(List<Quest> quests) {
    final user = _ref.read(userProfileProvider).value;
    double difficultyFactor = 1.0;
    if (user != null) {
      final ratio = user.lastScheduleCompletionRatio ?? 0.0;
      if (ratio >= 0.85) difficultyFactor = 0.9; else if (ratio < 0.5) difficultyFactor = 1.15;
      if (user.dailyScheduleStreak >= 6) difficultyFactor *= 1.05;
    }
    _lastDifficultyFactor = difficultyFactor;
    for (var i=0;i<quests.length;i++) {
      final q = quests[i];
      if (q.id.startsWith('schedule_')) {
        final scaled = (q.reward * difficultyFactor).round();
        final newReward = scaled.clamp(10, 999);
        quests[i] = q.copyWith(reward: newReward);
      }
    }
    final scheduleQuests = quests.where((q) => q.id.startsWith('schedule_')).toList();
    if (scheduleQuests.isEmpty) return;
    const int scheduleRewardCap = 300;
    final int currentSum = scheduleQuests.fold(0, (s, q) => s + q.reward);
    if (currentSum <= scheduleRewardCap) return;
    final double scale = scheduleRewardCap / currentSum;
    for (var i = 0; i < quests.length; i++) {
      final q = quests[i];
      if (q.id.startsWith('schedule_')) {
        final newReward = (q.reward * scale).floor().clamp(10, q.reward);
        quests[i] = q.copyWith(reward: newReward);
      }
    }
  }

  Quest _createQuestFromTemplate(Map<String, dynamic> template, {Map<String, String>? variables}) {
    String title = template['title'] ?? 'İsimsiz Görev';
    String description = template['description'] ?? 'Açıklama bulunamadı.';
    String actionRoute = template['actionRoute'] ?? '/home';

    if (variables != null) {
      variables.forEach((key, value) {
        title = title.replaceAll(key, value);
        description = description.replaceAll(key, value);
      });
    }

    final rawTags = template['tags'];
    List<String> tagList = rawTags is List
        ? rawTags.map((e) => e.toString().split('.').last).toList()
        : <String>[];

    if (variables != null && variables.containsKey('{subject}')) {
      final subj = variables['{subject}'];
      if (subj != null && subj.isNotEmpty) {
        tagList.add('subject:$subj');
      }
    }

    final quest = Quest(
      id: template['id'] ?? const Uuid().v4(),
      title: title,
      description: description,
      type: QuestType.values.byName(template['type'] ?? 'daily'),
      category: QuestCategory.values.byName(template['category'] ?? 'engagement'),
      progressType: QuestProgressType.values.byName(template['progressType'] ?? 'increment'),
      reward: (template['reward'] as num).toInt(),
      goalValue: (template['goalValue'] as num).toInt(),
      actionRoute: actionRoute,
      route: questRouteFromPath(actionRoute),
      tags: tagList,
    );
    return _autoTagQuest(quest);
  }

  QuestCategory _mapScheduleTypeToCategory(String type) {
    switch (type.toLowerCase()) {
      case 'practice':
      case 'soru':
        return QuestCategory.practice;
      case 'test':
      case 'exam':
        return QuestCategory.test_submission;
      case 'focus':
        return QuestCategory.focus;
      case 'analysis':
        return QuestCategory.engagement;
      default:
        return QuestCategory.study;
    }
  }

  int _estimateReward(ScheduleItem item, QuestCategory cat) {
    int base;
    switch (cat) {
      case QuestCategory.test_submission: base = 150; break;
      case QuestCategory.practice: base = 60; break;
      case QuestCategory.focus: base = 50; break;
      case QuestCategory.study: base = 45; break;
      case QuestCategory.engagement: base = 40; break;
      case QuestCategory.consistency: base = 35; break;
    }
    if (item.activity.length > 25) base += 10;
    return base;
  }

  String _buildDynamicTitle(ScheduleItem item) {
    final lower = item.activity.toLowerCase();
    if (lower.contains('tekrar')) return 'Tekrar Görevi';
    if (lower.contains('deneme')) return 'Planlı Deneme';
    if (lower.contains('test')) return 'Planlı Test';
    if (lower.contains('soru')) return 'Soru Serisi';
    return 'Plan Görevi';
  }

  String _inferRoute(ScheduleItem item, {required bool isTestLike}) {
    if (isTestLike) return '/home/add-test';
    final lower = item.activity.toLowerCase();
    if (lower.contains('pomodoro') || lower.contains('odak')) return '/home/pomodoro';
    if (lower.contains('konu') || lower.contains('soru') || lower.contains('tekrar')) return '/coach';
    return '/home';
  }

  String _dateKey(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';


  String? _computeTodayPlanSignature() {
    final planDoc = _ref.read(planProvider).value;
    if (planDoc?.weeklyPlan == null) return null;
    try {
      final weekly = WeeklyPlan.fromJson(planDoc!.weeklyPlan!);
      final today = DateTime.now();
      final weekdayIndex = today.weekday - 1;
      if (weekdayIndex < 0 || weekdayIndex >= weekly.plan.length) return null;
      final dayName = ['Pazartesi','Salı','Çarşamba','Perşembe','Cuma','Cumartesi','Pazar'][weekdayIndex];
      final daily = weekly.plan.firstWhere((d) => d.day == dayName, orElse: () => DailyPlan(day: dayName, schedule: []));
      final buffer = StringBuffer();
      for (final s in daily.schedule) {
        buffer.write('${s.time}|${s.activity}|${s.type}||');
      }
      final bytes = utf8.encode(buffer.toString());
      return md5.convert(bytes).toString();
    } catch (_) {
      return null;
    }
  }

  Future<void> _maybeGenerateWeeklyReport(UserModel user, DateTime now) async {
    final planDoc = _ref.read(planProvider).value;
    if (planDoc?.weeklyPlan == null) return;
    DateTime startOfWeek(DateTime d){return d.subtract(Duration(days: d.weekday-1));}
    final thisWeekStart = startOfWeek(now);
    final lastReport = user.lastWeeklyReport;
    if (lastReport != null) {
      final lastWeekStartStr = lastReport['weekStart'] as String?;
      if (lastWeekStartStr != null) {
        final lastWeekStart = DateTime.tryParse(lastWeekStartStr);
        if (lastWeekStart != null && lastWeekStart.isAtSameMomentAs(thisWeekStart)) return;
      }
    }
    if (now.weekday != DateTime.monday && lastReport != null) return;

    try {
      final weekly = WeeklyPlan.fromJson(planDoc!.weeklyPlan!);
      int planned = 0; int completed = 0; Map<String,int> dayPlanned = {}; Map<String,int> dayCompleted = {};
      for (int i=0;i<weekly.plan.length;i++) {
        final dp = weekly.plan[i];
        planned += dp.schedule.length;
        dayPlanned[dp.day] = dp.schedule.length;
        final date = thisWeekStart.add(Duration(days: i));
        final compList = await _ref.read(firestoreServiceProvider).getCompletedTasksForDate(user.id, date);
        completed += compList.length;
        dayCompleted[dp.day] = compList.length;
      }
      double overallRate = planned>0? completed/planned : 0.0;
      String topDay = '';
      String lowDay = '';
      double bestRate = -1; double worstRate = 2;
      dayPlanned.forEach((day, p){
        final c = dayCompleted[day] ?? 0;
        final r = p>0? c/p:0.0;
        if (r>bestRate){bestRate=r; topDay=day;}
        if (r<worstRate){worstRate=r; lowDay=day;}
      });
      final report = {
        'weekStart': _dateKey(thisWeekStart),
        'planned': planned,
        'completed': completed,
        'overallRate': overallRate,
        'topDay': topDay,
        'topRate': bestRate,
        'lowDay': lowDay,
        'lowRate': worstRate,
        'generatedAt': DateTime.now().toIso8601String(),
      };
      await _ref.read(firestoreServiceProvider).usersCollection.doc(user.id).update({'lastWeeklyReport': report});
    } catch(_) {}
  }

  Quest _autoTagQuest(Quest q) {
    final newTags = Set<String>.from(q.tags);
    if (q.reward >= 120) newTags.add('high_value');
    if (q.difficulty == QuestDifficulty.hard || q.difficulty == QuestDifficulty.epic) newTags.add('high_value');
    if (q.reward < 30 && q.goalValue <= 2) newTags.add('quick_win');
    if ((q.estimatedMinutes != null && q.estimatedMinutes! <= 5) || (q.goalValue == 1 && q.reward <= 25)) newTags.add('micro');
    if (q.category == QuestCategory.focus) newTags.add('focus');
    if (q.id.startsWith('schedule_')) newTags.add('plan');
    if (newTags.difference(q.tags.toSet()).isEmpty) return q;
    return q.copyWith(tags: newTags.toList());
  }
}

final dailyQuestsProvider = FutureProvider.autoDispose<List<Quest>>((ref) async {
  final user = ref.watch(userProfileProvider).value;
  if (user == null) return [];
  final questService = ref.read(questServiceProvider);
  final result = await questService.refreshDailyQuestsForUser(user).catchError((e) async {
    if (kDebugMode) debugPrint('[dailyQuestsProvider] hata: $e');
    return <Quest>[];
  });
  return result;
});
