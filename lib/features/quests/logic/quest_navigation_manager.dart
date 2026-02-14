// lib/features/quests/logic/quest_navigation_manager.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:taktik/features/quests/models/quest_model.dart';
import 'package:flutter/foundation.dart';

/// Görev yönlendirmelerini merkezi olarak yöneten servis
/// Tüm görev tiplerini (günlük, başarım) destekler
class QuestNavigationManager {
  static const QuestNavigationManager _instance = QuestNavigationManager._internal();
  factory QuestNavigationManager() => _instance;
  const QuestNavigationManager._internal();

  /// Route validasyonu ve düzeltme
  String validateAndCorrectRoute(String originalRoute, QuestRoute questRoute) {
    final correctedPath = questRouteToPath(questRoute);

    // Eğer orijinal route farklıysa log'la ve düzelt
    if (originalRoute != correctedPath && originalRoute != '/home') {
      debugPrint('[QuestNavigation] Route düzeltiliyor: $originalRoute -> $correctedPath');
    }

    return correctedPath;
  }

  /// Güvenli navigasyon - route validation ile
  Future<void> navigateToQuest(BuildContext context, Quest quest, Ref ref) async {
    try {
      final correctedRoute = validateAndCorrectRoute(quest.actionRoute, quest.route);

      // Navigation öncesi engagement güncellemesi
      await _updateEngagementForNavigation(ref, quest);

      // Context kontrolü
      if (!context.mounted) return;

      // Tam ekran route'lar (bottom nav ile) -> go kullan
      // Geri tuşu olan alt ekranlar -> push kullan
      // NOT: /home/add-test, /home/quests, /home/stats gibi alt route'lar push ile açılmalı
      final fullScreenRoutes = ['/coach', '/arena', '/profile', '/library'];
      final homeSubRoutes = ['/home/add-test', '/home/quests', '/home/stats', '/home/weekly-plan', '/home/pomodoro'];

      final isHomeSubRoute = homeSubRoutes.any((r) => correctedRoute.startsWith(r));
      final isFullScreen = !isHomeSubRoute && (correctedRoute == '/home' || fullScreenRoutes.any((r) => correctedRoute.startsWith(r)));

      if (isFullScreen) {
        context.go(correctedRoute);
      } else {
        context.push(correctedRoute);
      }

      debugPrint('[QuestNavigation] Navigated to: $correctedRoute for quest: ${quest.title}');

    } catch (e) {
      debugPrint('[QuestNavigation] Navigation error: $e');
      // Fallback navigation
      if (context.mounted) {
        context.go('/home');
      }
    }
  }

  /// Navigation engagement güncellemesi - Artık kullanılmıyor
  Future<void> _updateEngagementForNavigation(Ref ref, Quest quest) async {
    // NOT: Engagement güncellemesi artık quest_notifier.dart üzerinden
    // sunucu fonksiyonlarıyla yapılıyor, bu metod sadece geriye dönük uyumluluk için
    if (kDebugMode) {
      debugPrint('[QuestNavigation] Navigation engagement tracking deprecated');
    }
  }

  /// Route'dan görev kategorisi tahmin etme
  QuestCategory inferCategoryFromRoute(QuestRoute route) {
    switch (route) {
      case QuestRoute.pomodoro:
      case QuestRoute.coach:
      case QuestRoute.weeklyPlan:
      case QuestRoute.contentGenerator:
        return QuestCategory.study;

      case QuestRoute.strategy:
      case QuestRoute.workshop:
      case QuestRoute.arena:
      case QuestRoute.questionSolver:
      case QuestRoute.questionBox:
        return QuestCategory.practice;

      case QuestRoute.stats:
      case QuestRoute.addTest:
        return QuestCategory.test_submission;

      case QuestRoute.motivationChat:
      case QuestRoute.avatar:
      case QuestRoute.library:
      case QuestRoute.mindMap:
        return QuestCategory.engagement;

      case QuestRoute.quests:
        return QuestCategory.consistency;

      default:
        return QuestCategory.engagement;
    }
  }

  /// Görev tipleri için özel yönlendirme kuralları
  Map<QuestType, List<QuestRoute>> getPreferredRoutesForType(QuestType type) {
    switch (type) {
      case QuestType.daily:
        return {
          QuestType.daily: [
            QuestRoute.questionSolver,
            QuestRoute.mindMap,
            QuestRoute.contentGenerator,
            QuestRoute.questionBox,
            QuestRoute.coach,
            QuestRoute.addTest,
            QuestRoute.stats,
          ]
        };

      case QuestType.achievement:
        return {
          QuestType.achievement: QuestRoute.values
        };
    }
  }

  /// Route erişilebilirlik kontrolü
  bool isRouteAccessible(QuestRoute route, {required bool isPremiumUser}) {
    // Premium özellikler - Soru Çözücü, Zihin Haritası, İçerik Üretici artık ücretsiz
    const premiumRoutes = {
      QuestRoute.strategy,
      QuestRoute.workshop,
      QuestRoute.motivationChat,
    };

    if (premiumRoutes.contains(route) && !isPremiumUser) {
      return false;
    }

    return true;
  }

  /// Alternatif route önerisi
  QuestRoute suggestAlternativeRoute(QuestRoute blockedRoute, QuestType questType) {
    final alternatives = getPreferredRoutesForType(questType)[questType] ?? [QuestRoute.home];

    // Engellenen route'u çıkar
    final availableAlternatives = alternatives.where((r) => r != blockedRoute).toList();

    return availableAlternatives.isEmpty ? QuestRoute.home : availableAlternatives.first;
  }
}

/// Provider for dependency injection
final questNavigationManagerProvider = Provider<QuestNavigationManager>((ref) {
  return QuestNavigationManager();
});
