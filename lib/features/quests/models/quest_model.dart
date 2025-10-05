// lib/features/quests/models/quest_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

// GÜNCELLENDİ: Yeni 'focus' kategorisi eklendi.
enum QuestCategory { study, practice, engagement, consistency, test_submission, focus }

enum QuestType { daily, achievement }

enum QuestProgressType {
  increment,
  set_to_value
}

enum QuestDifficulty { trivial, easy, medium, hard, epic }

enum QuestRoute { home, pomodoro, coach, weeklyPlan, stats, addTest, quests, strategy, workshop, availability, avatar, arena, library, motivationChat, unknown }

QuestRoute questRouteFromPath(String path) {
  switch (path) {
    case '/home': return QuestRoute.home;
    case '/home/pomodoro': return QuestRoute.pomodoro;
    case '/coach': return QuestRoute.coach;
    case '/home/weekly-plan': return QuestRoute.weeklyPlan;
    case '/home/stats': return QuestRoute.stats;
    case '/home/add-test': return QuestRoute.addTest;
    case '/home/quests': return QuestRoute.quests;
    case '/ai-hub/strategic-planning': return QuestRoute.strategy;
    case '/ai-hub/weakness-workshop': return QuestRoute.workshop;
    case '/availability': return QuestRoute.availability;
    case '/profile/avatar-selection': return QuestRoute.avatar;
    case '/arena': return QuestRoute.arena;
    case '/library': return QuestRoute.library;
    case '/ai-hub/motivation-chat': return QuestRoute.motivationChat;
    default: return QuestRoute.unknown;
  }
}

String questRouteToPath(QuestRoute r) {
  switch (r) {
    case QuestRoute.home: return '/home';
    case QuestRoute.pomodoro: return '/home/pomodoro';
    case QuestRoute.coach: return '/coach';
    case QuestRoute.weeklyPlan: return '/home/weekly-plan';
    case QuestRoute.stats: return '/home/stats';
    case QuestRoute.addTest: return '/home/add-test';
    case QuestRoute.quests: return '/home/quests';
    case QuestRoute.strategy: return '/ai-hub/strategic-planning';
    case QuestRoute.workshop: return '/ai-hub/weakness-workshop';
    case QuestRoute.availability: return '/availability';
    case QuestRoute.avatar: return '/profile/avatar-selection';
    case QuestRoute.arena: return '/arena';
    case QuestRoute.library: return '/library';
    case QuestRoute.motivationChat: return '/ai-hub/motivation-chat';
    case QuestRoute.unknown: return '/home';
  }
}

class Quest extends Equatable {
  final String id;
  final String title;
  final String description;
  final QuestType type;
  final QuestCategory category;
  final QuestProgressType progressType;
  final int reward;
  final int goalValue;
  final int currentProgress;
  final bool isCompleted;
  final String actionRoute;
  final Timestamp? completionDate;
  final List<String> tags; // yeni: öncelik/etiket göstergeleri
  final QuestDifficulty difficulty; // yeni: zorluk
  final int? estimatedMinutes; // yeni: tahmini süre
  final List<String> prerequisiteIds; // yeni: önkoşullar
  final List<String> conceptTags; // yeni: kavram etiketleri (öğrenme takibi)
  final String? learningObjectiveId; // yeni: pedagojik hedef referansı
  final String? chainId; // yeni: zincir kimliği
  final int? chainStep; // yeni: zincirdeki adım (1-based)
  final int? chainLength; // yeni: toplam adım sayısı
  final QuestRoute route; // yeni: type-safe rota
  final bool rewardClaimed; // yeni: ödül tahsil edildi mi

  const Quest({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.category,
    required this.progressType,
    required this.reward,
    required this.goalValue,
    this.currentProgress = 0,
    this.isCompleted = false,
    required this.actionRoute,
    this.completionDate,
    this.tags = const [],
    this.difficulty = QuestDifficulty.easy,
    this.estimatedMinutes,
    this.prerequisiteIds = const [],
    this.conceptTags = const [],
    this.learningObjectiveId,
    this.chainId,
    this.chainStep,
    this.chainLength,
    required this.route,
    this.rewardClaimed = false,
  });

  factory Quest.fromMap(Map<String, dynamic> map, String id) {
    // zincir geriye dönük uyumluluk: id pattern
    String? derivedChainId;
    int? derivedChainStep;
    int? derivedChainLength;
    if (map['chainId'] is String) {
      derivedChainId = map['chainId'];
      derivedChainStep = (map['chainStep'] as num?)?.toInt();
      derivedChainLength = (map['chainLength'] as num?)?.toInt();
    } else if (id.startsWith('chain_') && id.split('_').length >= 3) {
      final parts = id.split('_');
      // ör: chain focus 1 => chain_focus_1
      final last = parts.last;
      final step = int.tryParse(last);
      if (step != null) {
        derivedChainStep = step;
        derivedChainId = parts.sublist(0, parts.length - 1).join('_');
        derivedChainLength = 3; // varsayılan eski zincir uzunluğu
      }
    }
    final rawRouteKey = map['routeKey'] as String?; // yeni şema desteği
    final rawAction = map['actionRoute'] ?? '/home';
    // Önce actionRoute'tan türet
    final actionDerived = questRouteFromPath(rawAction);
    // routeKey varsa çöz, fakat 'home' veya 'unknown' ise actionDerived'a öncelik ver
    QuestRoute resolvedRoute;
    if (rawRouteKey != null) {
      final byKey = QuestRoute.values.firstWhere(
        (e) => e.name == rawRouteKey,
        orElse: () => QuestRoute.unknown,
      );
      if (byKey == QuestRoute.unknown || (byKey == QuestRoute.home && actionDerived != QuestRoute.home)) {
        resolvedRoute = actionDerived;
      } else {
        resolvedRoute = byKey;
      }
    } else {
      resolvedRoute = actionDerived;
    }
    return Quest(
      id: id,
      title: map['title'] ?? 'İsimsiz Görev',
      description: map['description'] ?? 'Açıklama yok.',
      type: QuestType.values.byName(map['type'] ?? 'daily'),
      category: QuestCategory.values.byName(map['category'] ?? 'engagement'),
      progressType: QuestProgressType.values.byName(map['progressType'] ?? 'increment'),
      reward: map['reward'] ?? 10,
      goalValue: map['goalValue'] ?? 1,
      currentProgress: map['currentProgress'] ?? 0,
      isCompleted: map['isCompleted'] ?? false,
      actionRoute: rawAction,
      route: resolvedRoute,
      completionDate: map['completionDate'] as Timestamp?,
      tags: (map['tags'] is List) ? List<String>.from(map['tags']) : const [],
      difficulty: QuestDifficulty.values.byName(map['difficulty'] ?? 'easy'),
      estimatedMinutes: (map['estimatedMinutes'] as num?)?.toInt(),
      prerequisiteIds: map['prerequisiteIds'] is List ? List<String>.from(map['prerequisiteIds']) : const [],
      conceptTags: map['conceptTags'] is List ? List<String>.from(map['conceptTags']) : const [],
      learningObjectiveId: map['learningObjectiveId'],
      chainId: derivedChainId,
      chainStep: derivedChainStep,
      chainLength: derivedChainLength,
      rewardClaimed: map['rewardClaimed'] == true,
    );
  }

  static bool includeLegacyIdField = true; // kademeli migration kontrolü
  static void disableLegacyIdField() { includeLegacyIdField = false; }
  static void enableLegacyIdField() { includeLegacyIdField = true; }

  Map<String, dynamic> toMap() {
    return {
      if (includeLegacyIdField) 'id': id, // legacy alan
      'qid': id, // yeni standart alan
      'title': title,
      'description': description,
      'type': type.name,
      'category': category.name,
      'progressType': progressType.name,
      'reward': reward,
      'goalValue': goalValue,
      'currentProgress': currentProgress,
      'isCompleted': isCompleted,
      'actionRoute': actionRoute,
      'completionDate': completionDate,
      'tags': tags,
      'difficulty': difficulty.name,
      if (estimatedMinutes != null) 'estimatedMinutes': estimatedMinutes,
      if (prerequisiteIds.isNotEmpty) 'prerequisiteIds': prerequisiteIds,
      if (conceptTags.isNotEmpty) 'conceptTags': conceptTags,
      if (learningObjectiveId != null) 'learningObjectiveId': learningObjectiveId,
      if (chainId != null) 'chainId': chainId,
      if (chainStep != null) 'chainStep': chainStep,
      if (chainLength != null) 'chainLength': chainLength,
      'routeKey': route.name,
      'schemaVersion': 2,
      'rewardClaimed': rewardClaimed,
    };
  }

  /// YENİ: Dinamik ödül hesaplama - zorluk, süre ve kullanıcı seviyesine göre
  int calculateDynamicReward({
    int? userLevel,
    int? currentStreak,
    bool isStreakBonus = false,
    double difficultyMultiplier = 1.0,
  }) {
    int baseReward = reward;

    // 1. Zorluk çarpanı
    double finalMultiplier = difficultyMultiplier;
    switch (difficulty) {
      case QuestDifficulty.trivial:
        finalMultiplier *= 0.8;
        break;
      case QuestDifficulty.easy:
        finalMultiplier *= 1.0;
        break;
      case QuestDifficulty.medium:
        finalMultiplier *= 1.3;
        break;
      case QuestDifficulty.hard:
        finalMultiplier *= 1.6;
        break;
      case QuestDifficulty.epic:
        finalMultiplier *= 2.0;
        break;
    }

    // 2. Tahmini süre bonusu
    if (estimatedMinutes != null && estimatedMinutes! > 30) {
      finalMultiplier *= 1.2;
    }

    // 3. Kullanıcı seviyesi ölçeklendirmesi
    if (userLevel != null && userLevel > 10) {
      // Yüksek seviyeli kullanıcılar için daha zorlu hedefler, daha fazla ödül
      finalMultiplier *= (1.0 + (userLevel - 10) * 0.05).clamp(1.0, 2.0);
    }

    // 4. Seri bonusu
    if (isStreakBonus && currentStreak != null) {
      if (currentStreak >= 7) {
        finalMultiplier *= 1.15; // %15 bonus
      } else if (currentStreak >= 5) {
        finalMultiplier *= 1.10; // %10 bonus
      } else if (currentStreak >= 3) {
        finalMultiplier *= 1.05; // %5 bonus
      }
    }

    return (baseReward * finalMultiplier).round();
  }

  /// YENİ: Görevin kişiselleştirme koşullarını kontrol et
  bool shouldExcludeForUser(Map<String, dynamic> userConditions) {
    // Bu metod şimdilik client-side kontrol için, asıl mantık server'da olacak
    return false;
  }

  /// YENİ: Görevin tetiklenme koşullarını kontrol et
  bool shouldTriggerForUser(Map<String, dynamic> userConditions) {
    // Bu metod şimdilik client-side kontrol için, asıl mantık server'da olacak
    return true;
  }

  Quest copyWith({
    String? title,
    String? description,
    int? reward,
    int? goalValue,
    int? currentProgress,
    bool? isCompleted,
    Timestamp? completionDate,
    List<String>? tags,
    QuestDifficulty? difficulty,
    int? estimatedMinutes,
    List<String>? prerequisiteIds,
    List<String>? conceptTags,
    String? learningObjectiveId,
    String? chainId,
    int? chainStep,
    int? chainLength,
    QuestRoute? route,
    bool? rewardClaimed,
  }) {
    return Quest(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      type: type,
      category: category,
      progressType: progressType,
      reward: reward ?? this.reward,
      goalValue: goalValue ?? this.goalValue,
      currentProgress: currentProgress ?? this.currentProgress,
      isCompleted: isCompleted ?? this.isCompleted,
      actionRoute: actionRoute,
      completionDate: completionDate ?? this.completionDate,
      tags: tags ?? this.tags,
      difficulty: difficulty ?? this.difficulty,
      estimatedMinutes: estimatedMinutes ?? this.estimatedMinutes,
      prerequisiteIds: prerequisiteIds ?? this.prerequisiteIds,
      conceptTags: conceptTags ?? this.conceptTags,
      learningObjectiveId: learningObjectiveId ?? this.learningObjectiveId,
      chainId: chainId ?? this.chainId,
      chainStep: chainStep ?? this.chainStep,
      chainLength: chainLength ?? this.chainLength,
      route: route ?? this.route,
      rewardClaimed: rewardClaimed ?? this.rewardClaimed,
    );
  }

  @override
  List<Object?> get props => [
    id,
    title,
    description,
    type,
    category,
    progressType,
    reward,
    goalValue,
    currentProgress,
    isCompleted,
    actionRoute,
    completionDate,
    // List'lerde kapsamlı karşılaştırma ihtiyacı yoksa referans bazlı karşılaştırma yeterlidir.
    // Eğer derin karşılaştırma gereksinimi oluşursa collection paketinden DeepCollectionEquality kullanılabilir.
    tags,
    difficulty,
    estimatedMinutes,
    prerequisiteIds,
    conceptTags,
    learningObjectiveId,
    chainId,
    chainStep,
    chainLength,
    route,
    rewardClaimed,
  ];
}
