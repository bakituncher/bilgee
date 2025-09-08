// lib/data/models/user_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:bilge_ai/features/quests/models/quest_model.dart';

class UserModel {
  final String id;
  final String email;
  final String? name;
  final String? goal;
  final List<String>? challenges;
  final double? weeklyStudyGoal;
  final bool onboardingCompleted;
  final bool tutorialCompleted;
  final int streak;
  final DateTime? lastStreakUpdate;
  final String? selectedExam;
  final String? selectedExamSection;
  final int testCount;
  final double totalNetSum;
  final int engagementScore;
  // ARTIK KULLANILMIYOR: final Map<String, Map<String, TopicPerformanceModel>> topicPerformances;
  // KALDIRILDI: completedDailyTasks -> user_activity alt koleksiyonuna taşındı
  // ARTIK KULLANILMIYOR: final String? studyPacing;
  // ARTIK KULLANILMIYOR: final String? longTermStrategy;
  // ARTIK KULLANILMIYOR: final Map<String, dynamic>? weeklyPlan;
  final Map<String, List<String>> weeklyAvailability;
  // ARTIK KULLANILMIYOR: final List<String> masteredTopics;
  // KALDIRILDI: activeDailyQuests
  final Quest? activeWeeklyCampaign;
  final Timestamp? lastQuestRefreshDate;
  final Map<String, Timestamp> unlockedAchievements;
  // KALDIRILDI: dailyVisits -> user_activity alt koleksiyonuna taşındı
  final String? avatarStyle;
  final String? avatarSeed;
  final String? dailyQuestPlanSignature; // YENİ: bugünkü plan imzası
  final double? lastScheduleCompletionRatio; // YENİ: dünkü program tamamlama oranı
  // KALDIRILDI: dailyPlanBonuses -> user_activity alt koleksiyonuna taşındı
  final int dailyScheduleStreak; // YENİ: art arda tamamlanan plan görevi sayısı (bugün)
  final Map<String,dynamic>? lastWeeklyReport; // YENİ: geçen hafta raporu
  final double? dynamicDifficultyFactorToday; // YENİ: bugünkü dinamik zorluk çarpanı
  final Timestamp? weeklyPlanCompletedAt; // YENİ: haftalık plan tamamlanma anı
  final int workshopStreak; // YENİ: art arda günlerde Cevher Atölyesi seansı
  final Timestamp? lastWorkshopDate; // YENİ: son Cevher seansı tarihi (UTC gün)

  // GÖREV KİŞİSELLEŞTİRME İÇİN YENİ ALANLAR
  final bool hasCreatedStrategicPlan; // Stratejik plan oluşturdu mu?
  final Timestamp? lastStrategyCreationDate; // Son strateji oluşturma tarihi
  final int completedWorkshopCount; // Toplam tamamlanmış atölye sayısı
  final bool hasUsedPomodoro; // Pomodoro kullandı mı?
  final bool hasSubmittedTest; // Test sonucu gönderdi mi?
  final bool hasCompletedWeeklyPlan; // Haftalık plan tamamladı mı?
  final Map<String, bool> usedFeatures; // Kullanılan özellikler {"strategy": true, "workshop": true}
  final int currentQuestStreak; // Mevcut görev tamamlama serisi
  final Timestamp? lastQuestCompletionDate; // Son görev tamamlama tarihi

  UserModel({
    required this.id,
    required this.email,
    this.name,
    this.goal,
    this.challenges,
    this.weeklyStudyGoal,
    this.onboardingCompleted = false,
    this.tutorialCompleted = false,
    this.streak = 0,
    this.lastStreakUpdate,
    this.selectedExam,
    this.selectedExamSection,
    this.testCount = 0,
    this.totalNetSum = 0.0,
    this.engagementScore = 0,
    // this.topicPerformances = const {},
    // this.completedDailyTasks = const {},
    // this.studyPacing,
    // this.longTermStrategy,
    // this.weeklyPlan,
    this.weeklyAvailability = const {},
    // this.masteredTopics = const [],
    // KALDIRILDI: activeDailyQuests
    this.activeWeeklyCampaign,
    this.lastQuestRefreshDate,
    this.unlockedAchievements = const {},
    // this.dailyVisits = const [], // KALDIRILDI
    this.avatarStyle, // YENİ
    this.avatarSeed, // YENİ
    this.dailyQuestPlanSignature,
    this.lastScheduleCompletionRatio,
    // KALDIRILDI: dailyPlanBonuses
    this.dailyScheduleStreak = 0,
    this.lastWeeklyReport,
    this.dynamicDifficultyFactorToday,
    this.weeklyPlanCompletedAt,
    this.workshopStreak = 0, // yeni
    this.lastWorkshopDate, // yeni

    // YENİ PARAMETRELER
    this.hasCreatedStrategicPlan = false,
    this.lastStrategyCreationDate,
    this.completedWorkshopCount = 0,
    this.hasUsedPomodoro = false,
    this.hasSubmittedTest = false,
    this.hasCompletedWeeklyPlan = false,
    this.usedFeatures = const {},
    this.currentQuestStreak = 0,
    this.lastQuestCompletionDate,
  });

  factory UserModel.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;

    // Bu alanlar artık alt koleksiyonlardan okunacak, bu yüzden burada parse etmeye gerek yok.
    // final Map<String, Map<String, TopicPerformanceModel>> safeTopicPerformances = {};

    // KALDIRILDI: completedDailyTasks parse

    // KALDIRILDI: activeDailyQuests parse
    Quest? weeklyCampaign;
    if (data['activeWeeklyCampaign'] is Map<String, dynamic>) {
      final campaignData = data['activeWeeklyCampaign'] as Map<String, dynamic>;
      final dynamic rawId = campaignData['qid'] ?? campaignData['id'];
      if (rawId != null) {
        weeklyCampaign = Quest.fromMap(campaignData, rawId.toString());
      }
    }

    return UserModel(
      id: doc.id,
      email: data['email'],
      name: data['name'],
      goal: data['goal'],
      challenges: List<String>.from(data['challenges'] ?? []),
      weeklyStudyGoal: (data['weeklyStudyGoal'] as num?)?.toDouble(),
      onboardingCompleted: data['onboardingCompleted'] ?? false,
      tutorialCompleted: data['tutorialCompleted'] ?? false,
      streak: data['streak'] ?? 0,
      lastStreakUpdate: (data['lastStreakUpdate'] as Timestamp?)?.toDate(),
      selectedExam: data['selectedExam'],
      selectedExamSection: data['selectedExamSection'],
      testCount: data['testCount'] ?? 0,
      totalNetSum: (data['totalNetSum'] as num?)?.toDouble() ?? 0.0,
      engagementScore: data['engagementScore'] ?? 0,
      // topicPerformances: safeTopicPerformances,
      // completedDailyTasks: {},
      // studyPacing: data['studyPacing'],
      // longTermStrategy: data['longTermStrategy'],
      // weeklyPlan: data['weeklyPlan'] as Map<String, dynamic>?,
      weeklyAvailability: Map<String, List<String>>.from(
        (data['weeklyAvailability'] ?? {}).map(
              (key, value) => MapEntry(key, List<String>.from(value)),
        ),
      ),
      // masteredTopics: List<String>.from(data['masteredTopics'] ?? []),
      // KALDIRILDI: activeDailyQuests
      activeWeeklyCampaign: weeklyCampaign,
      lastQuestRefreshDate: data['lastQuestRefreshDate'] as Timestamp?,
      unlockedAchievements: Map<String, Timestamp>.from(data['unlockedAchievements'] ?? {}),
      // dailyVisits: List<Timestamp>.from(data['dailyVisits'] ?? []), // KALDIRILDI
      avatarStyle: data['avatarStyle'],
      avatarSeed: data['avatarSeed'],
      dailyQuestPlanSignature: data['dailyQuestPlanSignature'],
      lastScheduleCompletionRatio: (data['lastScheduleCompletionRatio'] as num?)?.toDouble(),
      // KALDIRILDI: dailyPlanBonuses
      dailyScheduleStreak: data['dailyScheduleStreak'] ?? 0,
      lastWeeklyReport: data['lastWeeklyReport'] as Map<String,dynamic>?,
      dynamicDifficultyFactorToday: (data['dynamicDifficultyFactorToday'] as num?)?.toDouble(),
      weeklyPlanCompletedAt: data['weeklyPlanCompletedAt'] as Timestamp?,
      workshopStreak: data['workshopStreak'] ?? 0, // yeni
      lastWorkshopDate: data['lastWorkshopDate'] as Timestamp?, // yeni

      // GÖREV KİŞİSELLEŞTİRME İÇİN YENİ ALANLAR
      hasCreatedStrategicPlan: data['hasCreatedStrategicPlan'] ?? false,
      lastStrategyCreationDate: data['lastStrategyCreationDate'] as Timestamp?,
      completedWorkshopCount: data['completedWorkshopCount'] ?? 0,
      hasUsedPomodoro: data['hasUsedPomodoro'] ?? false,
      hasSubmittedTest: data['hasSubmittedTest'] ?? false,
      hasCompletedWeeklyPlan: data['hasCompletedWeeklyPlan'] ?? false,
      usedFeatures: Map<String, bool>.from(data['usedFeatures'] ?? {}),
      currentQuestStreak: data['currentQuestStreak'] ?? 0,
      lastQuestCompletionDate: data['lastQuestCompletionDate'] as Timestamp?,
    );
  }

  // Geriye dönük uyumluluk: Artık veri user_activity alt koleksiyonunda. Boş değer döndür.
  Map<String, List<String>> get completedDailyTasks => const {};
  List<Timestamp> get dailyVisits => const [];
  Map<String,int> get recentPracticeVolumes => const {};

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'goal': goal,
      'challenges': challenges,
      'weeklyStudyGoal': weeklyStudyGoal,
      'onboardingCompleted': onboardingCompleted,
      'tutorialCompleted': tutorialCompleted,
      'streak': streak,
      'lastStreakUpdate': lastStreakUpdate != null ? Timestamp.fromDate(lastStreakUpdate!) : null,
      'selectedExam': selectedExam,
      'selectedExamSection': selectedExamSection,
      'testCount': testCount,
      'totalNetSum': totalNetSum,
      'engagementScore': engagementScore,
      // 'topicPerformances': topicPerformances.map((key, value) => MapEntry(key, value.map((k, v) => MapEntry(k, v.toMap())))),
      // 'completedDailyTasks': completedDailyTasks,
      // 'studyPacing': studyPacing,
      // 'longTermStrategy': longTermStrategy,
      // 'weeklyPlan': weeklyPlan,
      'weeklyAvailability': weeklyAvailability,
      // 'masteredTopics': masteredTopics,
      // KALDIRILDI: activeDailyQuests
      'activeWeeklyCampaign': activeWeeklyCampaign?.toMap(),
      'lastQuestRefreshDate': lastQuestRefreshDate,
      'unlockedAchievements': unlockedAchievements,
      // 'dailyVisits': dailyVisits, // KALDIRILDI
      'avatarStyle': avatarStyle,
      'avatarSeed': avatarSeed,
      'dailyQuestPlanSignature': dailyQuestPlanSignature,
      'lastScheduleCompletionRatio': lastScheduleCompletionRatio,
      // KALDIRILDI: dailyPlanBonuses
      'dailyScheduleStreak': dailyScheduleStreak,
      'lastWeeklyReport': lastWeeklyReport,
      'dynamicDifficultyFactorToday': dynamicDifficultyFactorToday,
      'weeklyPlanCompletedAt': weeklyPlanCompletedAt,
      'workshopStreak': workshopStreak,
      'lastWorkshopDate': lastWorkshopDate,
      // 'recentPracticeVolumes': recentPracticeVolumes, // KALDIRILDI
    };
  }

  // Stats değerlerini ayrı dokümandan birleştirmek için yardımcı
  UserModel withStats({
    int? streak,
    int? testCount,
    double? totalNetSum,
    int? engagementScore,
    DateTime? lastStreakUpdate,
  }) {
    return UserModel(
      id: id,
      email: email,
      name: name,
      goal: goal,
      challenges: challenges,
      weeklyStudyGoal: weeklyStudyGoal,
      onboardingCompleted: onboardingCompleted,
      tutorialCompleted: tutorialCompleted,
      streak: streak ?? this.streak,
      lastStreakUpdate: lastStreakUpdate ?? this.lastStreakUpdate,
      selectedExam: selectedExam,
      selectedExamSection: selectedExamSection,
      testCount: testCount ?? this.testCount,
      totalNetSum: totalNetSum ?? this.totalNetSum,
      engagementScore: engagementScore ?? this.engagementScore,
      weeklyAvailability: weeklyAvailability,
      activeWeeklyCampaign: activeWeeklyCampaign,
      lastQuestRefreshDate: lastQuestRefreshDate,
      unlockedAchievements: unlockedAchievements,
      avatarStyle: avatarStyle,
      avatarSeed: avatarSeed,
      dailyQuestPlanSignature: dailyQuestPlanSignature,
      lastScheduleCompletionRatio: lastScheduleCompletionRatio,
      dailyScheduleStreak: dailyScheduleStreak,
      lastWeeklyReport: lastWeeklyReport,
      dynamicDifficultyFactorToday: dynamicDifficultyFactorToday,
      weeklyPlanCompletedAt: weeklyPlanCompletedAt,
      workshopStreak: workshopStreak,
      lastWorkshopDate: lastWorkshopDate,
    );
  }
}