// lib/data/models/user_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:taktik/features/quests/models/quest_model.dart';

class UserModel {
  final String id;
  final String email;
  @Deprecated('Use firstName and lastName instead')
  final String? name;

  // Yeni Profil Alanları
  final String firstName;
  final String lastName;
  final String username;
  final String? gender;
  final DateTime? dateOfBirth;

  final bool isAdmin;
  final String? goal;
  final List<String>? challenges;
  final double? weeklyStudyGoal;
  final bool profileCompleted;
  final bool tutorialCompleted;
  final int streak;
  final DateTime? lastStreakUpdate;
  final String? selectedExam;
  final String? selectedExamSection;
  final String? selectedYdtLanguage;
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

  // TAKIP SİSTEMİ SAYAÇLARI
  final int? followerCount;
  final int? followingCount;

  // Premium Durumu
  final bool isPremium;

  UserModel({
    required this.id,
    required this.email,
    this.name,
    // Yeni Alanlar
    required this.firstName,
    required this.lastName,
    required this.username,
    this.gender,
    this.dateOfBirth,
    this.isAdmin = false,
    this.goal,
    this.challenges,
    this.weeklyStudyGoal,
    this.profileCompleted = false,
    this.tutorialCompleted = false,
    this.streak = 0,
    this.lastStreakUpdate,
    this.selectedExam,
    this.selectedExamSection,
    this.selectedYdtLanguage,
    this.testCount = 0,
    this.totalNetSum = 0.0,
    this.engagementScore = 0,
    this.weeklyAvailability = const {},
    this.activeWeeklyCampaign,
    this.lastQuestRefreshDate,
    this.unlockedAchievements = const {},
    this.avatarStyle,
    this.avatarSeed,
    this.dailyQuestPlanSignature,
    this.lastScheduleCompletionRatio,
    this.dailyScheduleStreak = 0,
    this.lastWeeklyReport,
    this.dynamicDifficultyFactorToday,
    this.weeklyPlanCompletedAt,
    this.workshopStreak = 0,
    this.lastWorkshopDate,
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
    this.followerCount,
    this.followingCount,
    this.isPremium = false,
  });

  UserModel copyWith({
    String? id,
    String? email,
    String? name,
    String? firstName,
    String? lastName,
    String? username,
    String? gender,
    DateTime? dateOfBirth,
    bool? isAdmin,
    String? goal,
    List<String>? challenges,
    double? weeklyStudyGoal,
    bool? profileCompleted,
    bool? tutorialCompleted,
    int? streak,
    DateTime? lastStreakUpdate,
    String? selectedExam,
    String? selectedExamSection,
    String? selectedYdtLanguage,
    int? testCount,
    double? totalNetSum,
    int? engagementScore,
    Map<String, List<String>>? weeklyAvailability,
    Quest? activeWeeklyCampaign,
    Timestamp? lastQuestRefreshDate,
    Map<String, Timestamp>? unlockedAchievements,
    String? avatarStyle,
    String? avatarSeed,
    String? dailyQuestPlanSignature,
    double? lastScheduleCompletionRatio,
    int? dailyScheduleStreak,
    Map<String, dynamic>? lastWeeklyReport,
    double? dynamicDifficultyFactorToday,
    Timestamp? weeklyPlanCompletedAt,
    int? workshopStreak,
    Timestamp? lastWorkshopDate,
    bool? hasCreatedStrategicPlan,
    Timestamp? lastStrategyCreationDate,
    int? completedWorkshopCount,
    bool? hasUsedPomodoro,
    bool? hasSubmittedTest,
    bool? hasCompletedWeeklyPlan,
    Map<String, bool>? usedFeatures,
    int? currentQuestStreak,
    Timestamp? lastQuestCompletionDate,
    int? followerCount,
    int? followingCount,
    bool? isPremium,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      username: username ?? this.username,
      gender: gender ?? this.gender,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      isAdmin: isAdmin ?? this.isAdmin,
      goal: goal ?? this.goal,
      challenges: challenges ?? this.challenges,
      weeklyStudyGoal: weeklyStudyGoal ?? this.weeklyStudyGoal,
      profileCompleted: profileCompleted ?? this.profileCompleted,
      tutorialCompleted: tutorialCompleted ?? this.tutorialCompleted,
      streak: streak ?? this.streak,
      lastStreakUpdate: lastStreakUpdate ?? this.lastStreakUpdate,
      selectedExam: selectedExam ?? this.selectedExam,
      selectedExamSection: selectedExamSection ?? this.selectedExamSection,
      selectedYdtLanguage: selectedYdtLanguage ?? this.selectedYdtLanguage,
      testCount: testCount ?? this.testCount,
      totalNetSum: totalNetSum ?? this.totalNetSum,
      engagementScore: engagementScore ?? this.engagementScore,
      weeklyAvailability: weeklyAvailability ?? this.weeklyAvailability,
      activeWeeklyCampaign: activeWeeklyCampaign ?? this.activeWeeklyCampaign,
      lastQuestRefreshDate: lastQuestRefreshDate ?? this.lastQuestRefreshDate,
      unlockedAchievements: unlockedAchievements ?? this.unlockedAchievements,
      avatarStyle: avatarStyle ?? this.avatarStyle,
      avatarSeed: avatarSeed ?? this.avatarSeed,
      dailyQuestPlanSignature: dailyQuestPlanSignature ?? this.dailyQuestPlanSignature,
      lastScheduleCompletionRatio: lastScheduleCompletionRatio ?? this.lastScheduleCompletionRatio,
      dailyScheduleStreak: dailyScheduleStreak ?? this.dailyScheduleStreak,
      lastWeeklyReport: lastWeeklyReport ?? this.lastWeeklyReport,
      dynamicDifficultyFactorToday: dynamicDifficultyFactorToday ?? this.dynamicDifficultyFactorToday,
      weeklyPlanCompletedAt: weeklyPlanCompletedAt ?? this.weeklyPlanCompletedAt,
      workshopStreak: workshopStreak ?? this.workshopStreak,
      lastWorkshopDate: lastWorkshopDate ?? this.lastWorkshopDate,
      hasCreatedStrategicPlan: hasCreatedStrategicPlan ?? this.hasCreatedStrategicPlan,
      lastStrategyCreationDate: lastStrategyCreationDate ?? this.lastStrategyCreationDate,
      completedWorkshopCount: completedWorkshopCount ?? this.completedWorkshopCount,
      hasUsedPomodoro: hasUsedPomodoro ?? this.hasUsedPomodoro,
      hasSubmittedTest: hasSubmittedTest ?? this.hasSubmittedTest,
      hasCompletedWeeklyPlan: hasCompletedWeeklyPlan ?? this.hasCompletedWeeklyPlan,
      usedFeatures: usedFeatures ?? this.usedFeatures,
      currentQuestStreak: currentQuestStreak ?? this.currentQuestStreak,
      lastQuestCompletionDate: lastQuestCompletionDate ?? this.lastQuestCompletionDate,
      followerCount: followerCount ?? this.followerCount,
      followingCount: followingCount ?? this.followingCount,
      isPremium: isPremium ?? this.isPremium,
    );
  }

  factory UserModel.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;

    // --- Null/type-safe helpers (Firestore şema drift/eksik alanlar için) ---
    String _asString(dynamic v, {String fallback = ''}) {
      if (v == null) return fallback;
      if (v is String) return v;
      return v.toString();
    }

    String? _asNullableString(dynamic v) {
      if (v == null) return null;
      if (v is String) return v;
      return v.toString();
    }

    // KALDIRILDI: completedDailyTasks parse

    // KALDIRILDI: activeDailyQuests
    Quest? weeklyCampaign;
    if (data['activeWeeklyCampaign'] is Map<String, dynamic>) {
      final campaignData = data['activeWeeklyCampaign'] as Map<String, dynamic>;
      final dynamic rawId = campaignData['qid'] ?? campaignData['id'];
      if (rawId != null) {
        weeklyCampaign = Quest.fromMap(campaignData, rawId.toString());
      }
    }

    // Geriye dönük uyumluluk için name'den firstName/lastName türetme
    String fName = _asString(data['firstName']);
    String lName = _asString(data['lastName']);
    final legacyName = _asNullableString(data['name']);
    if (fName.isEmpty && lName.isEmpty && legacyName != null && legacyName.isNotEmpty) {
      final parts = legacyName.split(' ');
      fName = parts.isNotEmpty ? parts.first : '';
      lName = parts.length > 1 ? parts.sublist(1).join(' ') : '';
    }

    // Bazı eski/bozuk dokümanlarda email/name null olabiliyor. UI/stream çökmesin diye güvenli parse.
    final email = _asString(data['email']);
    final name = _asString(data['name'], fallback: legacyName ?? '');

    return UserModel(
      id: doc.id,
      email: email,
      name: name,
      firstName: fName,
      lastName: lName,
      username: _asString(data['username']),
      gender: _asNullableString(data['gender']),
      dateOfBirth: (data['dateOfBirth'] as Timestamp?)?.toDate(),
      goal: _asNullableString(data['goal']),
      challenges: List<String>.from(data['challenges'] ?? []),
      weeklyStudyGoal: (data['weeklyStudyGoal'] as num?)?.toDouble(),
      profileCompleted: data['profileCompleted'] ?? false,
      tutorialCompleted: data['tutorialCompleted'] ?? false,
      streak: data['streak'] ?? 0,
      lastStreakUpdate: (data['lastStreakUpdate'] as Timestamp?)?.toDate(),
      selectedExam: _asNullableString(data['selectedExam']),
      selectedExamSection: _asNullableString(data['selectedExamSection']),
      selectedYdtLanguage: _asNullableString(data['selectedYdtLanguage']),
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
      avatarStyle: _asString(data['avatarStyle'], fallback: 'bottts'),
      avatarSeed: _asString(data['avatarSeed'], fallback: doc.id),
      dailyQuestPlanSignature: _asNullableString(data['dailyQuestPlanSignature']),
      lastScheduleCompletionRatio: (data['lastScheduleCompletionRatio'] as num?)?.toDouble(),
      // KALDIRILDI: dailyPlanBonuses
      dailyScheduleStreak: data['dailyScheduleStreak'] ?? 0,
      lastWeeklyReport: data['lastWeeklyReport'] as Map<String,dynamic>?,
      dynamicDifficultyFactorToday: (data['dynamicDifficultyFactorToday'] as num?)?.toDouble(),
      weeklyPlanCompletedAt: data['weeklyPlanCompletedAt'] as Timestamp?,
      workshopStreak: data['workshopStreak'] ?? 0,
      lastWorkshopDate: data['lastWorkshopDate'] as Timestamp?,

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
      followerCount: data['followerCount'] as int?,
      followingCount: data['followingCount'] as int?,
      isPremium: data['isPremium'] ?? false,
    );
  }

  // Geriye dönük uyumluluk: Artık veri user_activity alt koleksiyonunda. Boş değer döndür.
  Map<String, List<String>> get completedDailyTasks => const {};
  List<Timestamp> get dailyVisits => const [];
  Map<String,int> get recentPracticeVolumes => const {};

  String get fullName => '$firstName $lastName'.trim();

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'name': fullName,
      'firstName': firstName,
      'lastName': lastName,
      'username': username,
      'gender': gender,
      'dateOfBirth': dateOfBirth != null ? Timestamp.fromDate(dateOfBirth!) : null,
      'goal': goal,
      'challenges': challenges,
      'weeklyStudyGoal': weeklyStudyGoal,
      'profileCompleted': profileCompleted,
      'tutorialCompleted': tutorialCompleted,
      'streak': streak,
      'lastStreakUpdate': lastStreakUpdate != null ? Timestamp.fromDate(lastStreakUpdate!) : null,
      'selectedExam': selectedExam,
      'selectedExamSection': selectedExamSection,
      'selectedYdtLanguage': selectedYdtLanguage,
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
      'hasCreatedStrategicPlan': hasCreatedStrategicPlan,
      'lastStrategyCreationDate': lastStrategyCreationDate,
      'completedWorkshopCount': completedWorkshopCount,
      'hasUsedPomodoro': hasUsedPomodoro,
      'hasSubmittedTest': hasSubmittedTest,
      'hasCompletedWeeklyPlan': hasCompletedWeeklyPlan,
      'usedFeatures': usedFeatures,
      'currentQuestStreak': currentQuestStreak,
      'lastQuestCompletionDate': lastQuestCompletionDate,
      'followerCount': followerCount,
      'followingCount': followingCount,
      'isPremium': isPremium,
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
      firstName: firstName,
      lastName: lastName,
      username: username,
      gender: gender,
      dateOfBirth: dateOfBirth,
      isAdmin: isAdmin,
      goal: goal,
      challenges: challenges,
      weeklyStudyGoal: weeklyStudyGoal,
      profileCompleted: profileCompleted,
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
      isPremium: isPremium,
    );
  }
}