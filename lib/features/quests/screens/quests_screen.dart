// lib/features/quests/screens/quests_screen.dart
import 'dart:async';
import 'dart:ui';
import 'package:bilge_ai/core/analytics/analytics_logger.dart';
import 'package:bilge_ai/core/theme/app_theme.dart';
import 'package:bilge_ai/data/providers/firestore_providers.dart';
import 'package:bilge_ai/features/quests/logic/quest_service.dart';
import 'package:bilge_ai/features/quests/logic/optimized_quests_provider.dart';
import 'package:bilge_ai/features/quests/models/quest_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class QuestsScreen extends ConsumerStatefulWidget {
  const QuestsScreen({super.key});

  @override
  ConsumerState<QuestsScreen> createState() => _QuestsScreenState();
}

class _QuestsScreenState extends ConsumerState<QuestsScreen> with SingleTickerProviderStateMixin {
  late AnimationController _bgController;

  @override
  void initState() {
    super.initState();
    _bgController = AnimationController(vsync: this, duration: const Duration(seconds: 20))..repeat();
  }

  void _refreshQuests() async {
    if (!mounted) return;
    final user = ref.read(userProfileProvider).value;
    if (user != null && mounted) {
      await ref.read(questServiceProvider).refreshDailyQuestsForUser(user, force: true);
      if (mounted) {
        ref.invalidate(optimizedQuestsProvider);
      }
    }
  }

  @override
  void dispose() {
    _bgController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final questsState = ref.watch(optimizedQuestsProvider);
    final user = ref.watch(userProfileProvider).value;

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          // Animated Grid Background
          Positioned.fill(
            child: CustomPaint(
              painter: AnimatedGridPainter(_bgController),
            ),
          ),
          // Main Content
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(context),
                  const SizedBox(height: 24),
                  if (questsState.isLoaded && questsState.allQuests != null)
                    _buildQuestList(questsState.allQuests!, user?.id ?? '')
                  else
                    _buildLoadingState(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
                onPressed: () => context.pop(),
              ),
              const SizedBox(width: 8),
              Text(
                'Günlük Emirler',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.sync_rounded, color: AppTheme.secondaryTextColor),
            onPressed: _refreshQuests,
            tooltip: 'Görevleri Yenile',
          ),
        ],
      ),
    ).animate().fadeIn(duration: 500.ms).slideY(begin: -0.2);
  }

  Widget _buildLoadingState() {
    return Expanded(
      child: Center(
        child: const CircularProgressIndicator(color: AppTheme.secondaryColor)
            .animate()
            .scale(),
      ),
    );
  }

  Widget _buildQuestList(List<Quest> quests, String userId) {
    if (quests.isEmpty) {
      return _buildEmptyState();
    }

    // GÖREVLERİ SIRALA
    quests.sort((a, b) {
      final aClaimable = a.isCompleted && !a.rewardClaimed;
      final bClaimable = b.isCompleted && !b.rewardClaimed;
      if (aClaimable && !bClaimable) return -1;
      if (!aClaimable && bClaimable) return 1;

      final aCompleted = a.isCompleted && a.rewardClaimed;
      final bCompleted = b.isCompleted && b.rewardClaimed;
      if (aCompleted && !bCompleted) return 1;
      if (!aCompleted && bCompleted) return -1;

      return 0;
    });

    return Expanded(
      child: ListView.builder(
        padding: EdgeInsets.zero,
        itemCount: quests.length,
        itemBuilder: (context, index) {
          final quest = quests[index];
          return GamifiedQuestCard(
            quest: quest,
            userId: userId,
          )
          .animate()
          .fadeIn(delay: (index * 150).ms, duration: 600.ms)
          .slideY(begin: 0.5, curve: Curves.easeOutCubic);
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Expanded(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.shield_moon_rounded,
              size: 100,
              color: AppTheme.secondaryTextColor,
            ),
            const SizedBox(height: 20),
            Text(
              'Tüm Emirler Tamamlandı!',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.white),
            ),
            const SizedBox(height: 8),
            const Text(
              'Yeni emirler için yarını bekle, Savaşçı.',
              style: TextStyle(color: AppTheme.secondaryTextColor, fontSize: 16),
            ),
          ],
        ).animate().fadeIn(duration: 500.ms),
      ),
    );
  }
}

class GamifiedQuestCard extends ConsumerWidget {
  final Quest quest;
  final String userId;

  const GamifiedQuestCard({
    super.key,
    required this.quest,
    required this.userId,
  });

  void _handleQuestTap(BuildContext context, WidgetRef ref) {
    ref.read(analyticsLoggerProvider).logQuestEvent(userId: userId, event: 'quest_tap', data: {'questId': quest.id, 'category': quest.category.name});
    String targetRoute = quest.actionRoute;
    if (targetRoute == '/coach') {
      final subjectTag = quest.tags.firstWhere((t) => t.startsWith('subject:'), orElse: () => '');
      if (subjectTag.isNotEmpty) {
        final subject = subjectTag.split(':').sublist(1).join(':');
        targetRoute = Uri(path: '/coach', queryParameters: {'subject': subject}).toString();
      }
    }
    context.go(targetRoute);
  }

  Future<void> _handleClaimReward(BuildContext context, WidgetRef ref) async {
    final questService = ref.read(questServiceProvider);
    final success = await questService.claimReward(userId, quest.id);

    if (success && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${quest.reward} BP kazandın!'),
          backgroundColor: AppTheme.successColor,
        ),
      );
      ref.invalidate(optimizedQuestsProvider);
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Ödül alınırken bir hata oluştu.'),
          backgroundColor: AppTheme.accentColor,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = quest.goalValue > 0 ? (quest.currentProgress / quest.goalValue).clamp(0.0, 1.0) : (quest.isCompleted ? 1.0 : 0.0);
    final isCompleted = quest.isCompleted;
    final isClaimable = isCompleted && !quest.rewardClaimed;

    VoidCallback? onTapAction;
    if (isClaimable) {
      onTapAction = () => _handleClaimReward(context, ref);
    } else if (!isCompleted) {
      onTapAction = () => _handleQuestTap(context, ref);
    }

    return GestureDetector(
      onTap: onTapAction,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            decoration: BoxDecoration(
              color: isClaimable ? AppTheme.cardColor.withBlue(170) : AppTheme.cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isClaimable ? AppTheme.goldColor : AppTheme.lightSurfaceColor.withOpacity(0.5),
                width: isClaimable ? 2 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: isClaimable ? AppTheme.goldColor.withOpacity(0.3) : Colors.black.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _buildCategoryIcon(isCompleted, isClaimable),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            quest.title,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            quest.description,
                            style: TextStyle(fontSize: 14, color: AppTheme.secondaryTextColor),
                          ),
                        ],
                      ),
                    ),
                    _buildRewardChip(isClaimable),
                  ],
                ),
                if (!isCompleted || isClaimable) ...[
                  const SizedBox(height: 20),
                  if (isClaimable)
                    _buildClaimRewardPrompt()
                  else
                    _buildProgressBar(progress),
                ],
              ],
            ),
          ),
        );
  }

  Widget _buildCategoryIcon(bool isCompleted, bool isClaimable) {
    IconData icon;
    Color color;

    if (isClaimable) {
      icon = Icons.military_tech_rounded;
      color = AppTheme.goldColor;
    } else if (isCompleted) {
      icon = Icons.check_circle_rounded;
      color = AppTheme.successColor;
    } else {
      switch (quest.category) {
        case QuestCategory.study: icon = Icons.menu_book_rounded; color = Colors.blueAccent; break;
        case QuestCategory.practice: icon = Icons.edit_note_rounded; color = Colors.greenAccent; break;
        case QuestCategory.engagement: icon = Icons.auto_awesome_rounded; color = Colors.purpleAccent; break;
        case QuestCategory.consistency: icon = Icons.event_repeat_rounded; color = Colors.orangeAccent; break;
        case QuestCategory.test_submission: icon = Icons.add_chart_rounded; color = Colors.redAccent; break;
        case QuestCategory.focus: icon = Icons.center_focus_strong; color = AppTheme.secondaryColor; break;
      }
    }

    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withOpacity(0.1),
        border: Border.all(color: color.withOpacity(0.5), width: 2),
      ),
      child: Icon(icon, color: color, size: 28),
    );
  }

  Widget _buildRewardChip(bool isClaimable) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: (isClaimable ? AppTheme.goldColor : AppTheme.goldColor).withOpacity(0.1),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: (isClaimable ? AppTheme.goldColor : AppTheme.goldColor).withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(isClaimable ? Icons.military_tech_rounded : Icons.star_rounded, color: AppTheme.goldColor, size: 18),
          const SizedBox(width: 6),
          Text(
            '+${quest.reward}',
            style: const TextStyle(color: AppTheme.goldColor, fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildClaimRewardPrompt() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Ödülünü Topla!',
          style: TextStyle(
            color: AppTheme.goldColor,
            fontWeight: FontWeight.bold,
            fontSize: 16,
            shadows: [
              Shadow(
                blurRadius: 10.0,
                color: AppTheme.goldColor.withOpacity(0.5),
                offset: const Offset(0, 0),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        const Icon(Icons.touch_app_rounded, color: AppTheme.goldColor),
      ],
    ).animate(onPlay: (controller) => controller.repeat())
     .shimmer(delay: 400.ms, duration: 1800.ms, color: AppTheme.goldColor.withOpacity(0.3));
  }

  Widget _buildProgressBar(double progress) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 8,
            decoration: BoxDecoration(
              color: AppTheme.lightSurfaceColor,
              borderRadius: BorderRadius.circular(4),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: progress,
                  child: Container(color: AppTheme.secondaryColor),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          '${quest.currentProgress} / ${quest.goalValue}',
          style: const TextStyle(color: AppTheme.secondaryTextColor, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}


class AnimatedGridPainter extends CustomPainter {
  final Animation<double> animation;

  AnimatedGridPainter(this.animation) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppTheme.lightSurfaceColor.withOpacity(0.1)
      ..strokeWidth = 1.0;

    final path = Path();
    const gridSize = 50.0;

    // Animate grid lines
    final offset = animation.value * gridSize * 2;

    for (double i = -offset; i < size.width + offset; i += gridSize) {
      path.moveTo(i, -offset);
      path.lineTo(i, size.height + offset);
    }
    for (double i = -offset; i < size.height + offset; i += gridSize) {
      path.moveTo(-offset, i);
      path.lineTo(size.width + offset, i);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
