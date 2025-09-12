// lib/shared/widgets/quest_completion_toast.dart
import 'dart:async';
import 'dart:ui' as ui; // blur için
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bilge_ai/core/theme/app_theme.dart';
import 'package:bilge_ai/features/quests/logic/quest_completion_notifier.dart';
import 'package:bilge_ai/features/quests/models/quest_model.dart';
import 'package:bilge_ai/data/providers/firestore_providers.dart'; // Provider

class QuestCompletionToast extends ConsumerStatefulWidget {
  final Quest completedQuest;
  const QuestCompletionToast({super.key, required this.completedQuest});

  @override
  ConsumerState<QuestCompletionToast> createState() => _QuestCompletionToastState();
}

class _QuestCompletionToastState extends ConsumerState<QuestCompletionToast> with TickerProviderStateMixin {
  bool _rewardClaimed = false;

  @override
  void initState() {
    super.initState();
    // Otomatik ödül toplama
    _autoClaimReward();
    // Otomatik kapat
    Timer(4.seconds, () { if (mounted) _dismiss(); });
  }

  /// Otomatik ödül toplama sistemi
  void _autoClaimReward() async {
    await Future.delayed(const Duration(milliseconds: 1200)); // gecikme artırıldı
    if (!mounted) return;

    final quest = widget.completedQuest;
    final user = ref.read(userProfileProvider).value;

    try {
      if (user != null) {
        // Backend'e ödül talep et - önce quest durumunu kontrol et
        await ref.read(firestoreServiceProvider).claimQuestReward(user.id, quest);
      }
      if (mounted) {
        setState(() { _rewardClaimed = true; });
        HapticFeedback.lightImpact();
      }
    } catch (e) {
      debugPrint('[QuestToast] Auto reward claim failed: $e');
    }
  }

  void _dismiss() { ref.read(questCompletionProvider.notifier).clear(); }

  @override
  Widget build(BuildContext context) {
    final quest = widget.completedQuest;
    final user = ref.watch(userProfileProvider).value;

    // Dinamik ödül hesap sadece gösterim için
    int finalReward = quest.reward;
    if (user != null) {
      finalReward = quest.calculateDynamicReward(
        userLevel: (user.engagementScore / 100).floor(),
        currentStreak: user.currentQuestStreak,
        isStreakBonus: user.currentQuestStreak >= 3,
      );
    }

    final rewardText = _rewardClaimed ? '✅ +$finalReward BP EKLENDİ!' : '+$finalReward BP';

    return Semantics(
      label: 'Görev tamamlandı: ${quest.title}',
      liveRegion: true,
      readOnly: true,
      child: GestureDetector(
        onTap: _dismiss,
        child: Animate(
          target: ref.watch(questCompletionProvider) == null ? 0 : 1,
          effects: [
            FadeEffect(duration: 350.ms),
            SlideEffect(begin: const Offset(0, .4), curve: Curves.easeOutCubic, duration: 420.ms),
            ScaleEffect(begin: const Offset(.95, .95), end: const Offset(1,1), duration: 420.ms, curve: Curves.easeOutBack),
          ],
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: Material(
                type: MaterialType.transparency,
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                  constraints: const BoxConstraints(maxWidth: 560),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    gradient: LinearGradient(
                      colors: [
                        AppTheme.successColor.withValues(alpha: .20),
                        const Color(0xFF1E2B3D).withValues(alpha: .90),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: Border.all(color: AppTheme.successColor.withValues(alpha: .55), width: 1.3),
                    boxShadow: [
                      BoxShadow(color: AppTheme.successColor.withValues(alpha: .35), blurRadius: 30, spreadRadius: 1, offset: const Offset(0,8)),
                      BoxShadow(color: Colors.black.withValues(alpha: .45), blurRadius: 18, offset: const Offset(0,6)),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Soldaki başarı ikonu
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              AppTheme.successColor.withValues(alpha: .8),
                              AppTheme.successColor.withValues(alpha: .3),
                            ],
                          ),
                        ),
                        child: const Icon(
                          Icons.check_circle_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),

                      const SizedBox(width: 16),

                      // Orta kısım - görev bilgileri
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Görev Tamamlandı!',
                              style: TextStyle(
                                color: AppTheme.successColor,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              quest.title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(width: 12),

                      // Sağ kısım - ödül bilgisi
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          color: _rewardClaimed
                              ? AppTheme.successColor.withValues(alpha: .2)
                              : AppTheme.goldColor.withValues(alpha: .2),
                          border: Border.all(
                            color: _rewardClaimed
                                ? AppTheme.successColor.withValues(alpha: .6)
                                : AppTheme.goldColor.withValues(alpha: .6),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          rewardText,
                          style: TextStyle(
                            color: _rewardClaimed ? AppTheme.successColor : AppTheme.goldColor,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
