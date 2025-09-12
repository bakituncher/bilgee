// lib/features/quests/screens/quests_screen.dart
import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:bilge_ai/core/analytics/analytics_logger.dart';
import 'package:bilge_ai/core/theme/app_theme.dart';
import 'package:bilge_ai/data/providers/firestore_providers.dart';
import 'package:bilge_ai/features/quests/logic/quest_service.dart';
import 'package:bilge_ai/features/quests/logic/optimized_quests_provider.dart';
import 'package:bilge_ai/features/quests/models/quest_model.dart';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

class QuestsScreen extends ConsumerStatefulWidget {
  const QuestsScreen({super.key});

  @override
  ConsumerState<QuestsScreen> createState() => _QuestsScreenState();
}

class _QuestsScreenState extends ConsumerState<QuestsScreen> with TickerProviderStateMixin {
  late AnimationController _bgController;

  @override
  void initState() {
    super.initState();
    _bgController = AnimationController(vsync: this, duration: const Duration(seconds: 45))..repeat();
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
          Positioned.fill(
            child: CustomPaint(
              painter: StarfieldPainter(_bgController),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
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
      padding: const EdgeInsets.only(top: 20.0, left: 8.0, right: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white70),
            onPressed: () => context.pop(),
          ),
          Text(
            'Fetih Sancağı',
            style: GoogleFonts.orbitron(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              shadows: [
                const Shadow(blurRadius: 10, color: AppTheme.secondaryColor),
                const Shadow(blurRadius: 20, color: AppTheme.secondaryColor),
              ],
            ),
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
    return const Expanded(
      child: Center(
        child: CircularProgressIndicator(color: AppTheme.secondaryColor),
      ),
    );
  }

  Widget _buildQuestList(List<Quest> quests, String userId) {
    if (quests.isEmpty) {
      return _buildEmptyState();
    }

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
        padding: const EdgeInsets.symmetric(horizontal: 8.0),
        itemCount: quests.length,
        itemBuilder: (context, index) {
          final quest = quests[index];
          return ConquestQuestCard(
            key: ValueKey(quest.id),
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
            const Icon(Icons.shield_moon_rounded, size: 100, color: AppTheme.secondaryTextColor),
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

class ConquestQuestCard extends ConsumerStatefulWidget {
  final Quest quest;
  final String userId;

  const ConquestQuestCard({super.key, required this.quest, required this.userId});

  @override
  ConsumerState<ConquestQuestCard> createState() => _ConquestQuestCardState();
}

class _ConquestQuestCardState extends ConsumerState<ConquestQuestCard> {
  late final ConfettiController _confettiController;
  bool _isClaiming = false;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(milliseconds: 400));
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  void _handleQuestTap() {
    ref.read(analyticsLoggerProvider).logQuestEvent(userId: widget.userId, event: 'quest_tap', data: {'questId': widget.quest.id, 'category': widget.quest.category.name});
    String targetRoute = widget.quest.actionRoute;
    if (targetRoute == '/coach') {
      final subjectTag = widget.quest.tags.firstWhere((t) => t.startsWith('subject:'), orElse: () => '');
      if (subjectTag.isNotEmpty) {
        final subject = subjectTag.split(':').sublist(1).join(':');
        targetRoute = Uri(path: '/coach', queryParameters: {'subject': subject}).toString();
      }
    }
    context.go(targetRoute);
  }

  Future<void> _handleClaimReward() async {
    if (_isClaiming) return;
    setState(() => _isClaiming = true);

    _confettiController.play();
    await Future.delayed(const Duration(milliseconds: 300));

    final questService = ref.read(questServiceProvider);
    final success = await questService.claimReward(widget.userId, widget.quest.id);

    if (success && mounted) {
      ref.invalidate(optimizedQuestsProvider);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Ödül alınırken bir hata oluştu.'),
          backgroundColor: AppTheme.accentColor,
        ),
      );
    }
    if (mounted) {
      setState(() => _isClaiming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final quest = widget.quest;
    final progress = quest.goalValue > 0 ? (quest.currentProgress / quest.goalValue).clamp(0.0, 1.0) : (quest.isCompleted ? 1.0 : 0.0);
    final isCompleted = quest.isCompleted;
    final isClaimable = isCompleted && !quest.rewardClaimed;
    final isClaimed = isCompleted && quest.rewardClaimed;

    Color borderColor, iconColor;
    IconData icon;
    bool showShimmer = false;

    if (isClaimable) {
      borderColor = AppTheme.goldColor;
      iconColor = AppTheme.goldColor;
      icon = Icons.military_tech_rounded;
      showShimmer = true;
    } else if (isClaimed) {
      borderColor = AppTheme.successColor.withOpacity(0.5);
      iconColor = AppTheme.successColor;
      icon = Icons.check_circle_rounded;
    } else {
      borderColor = AppTheme.secondaryColor.withOpacity(0.6);
      iconColor = AppTheme.secondaryColor;
      switch (quest.category) {
        case QuestCategory.study: icon = Icons.menu_book_rounded; break;
        case QuestCategory.practice: icon = Icons.edit_note_rounded; break;
        case QuestCategory.engagement: icon = Icons.auto_awesome_rounded; break;
        case QuestCategory.consistency: icon = Icons.event_repeat_rounded; break;
        case QuestCategory.test_submission: icon = Icons.add_chart_rounded; break;
        case QuestCategory.focus: icon = Icons.center_focus_strong; break;
      }
    }

    return Stack(
      alignment: Alignment.topCenter,
      children: [
        GestureDetector(
          onTap: isClaimable ? _handleClaimReward : (isCompleted ? null : _handleQuestTap),
          child: Container(
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                colors: [
                  AppTheme.lightSurfaceColor.withOpacity(isClaimed ? 0.2 : 0.5),
                  AppTheme.cardColor.withOpacity(isClaimed ? 0.3 : 0.8),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(color: borderColor, width: 1.5),
              boxShadow: [
                BoxShadow(color: borderColor.withOpacity(0.3), blurRadius: 12, spreadRadius: 1),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          _buildCategoryIcon(icon, iconColor),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(quest.title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white)),
                                const SizedBox(height: 4),
                                Text(quest.description, style: TextStyle(fontSize: 14, color: AppTheme.secondaryTextColor, height: 1.4)),
                              ],
                            ),
                          ),
                          _buildRewardChip(quest, isClaimable),
                        ],
                      ),
                      if (!isClaimed) ...[
                        const SizedBox(height: 16),
                        isClaimable ? _buildClaimRewardPrompt() : _buildProgressBar(progress, borderColor),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ).animate(onPlay: (c) => showShimmer ? c.repeat() : null)
             .shimmer(delay: 500.ms, duration: 1800.ms, color: Colors.white.withOpacity(0.1))
             .animate() // This re-enables targeting to specific animations below
             .saturate(amount: isClaimed ? 0.2 : 1.0, duration: 400.ms),
        ),
        ConfettiWidget(
          confettiController: _confettiController,
          blastDirectionality: BlastDirectionality.explosive,
          numberOfParticles: 25,
          gravity: 0.1,
        ),
      ],
    );
  }

  Widget _buildCategoryIcon(IconData icon, Color color) {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withOpacity(0.1),
        border: Border.all(color: color.withOpacity(0.5), width: 1),
      ),
      child: Icon(icon, color: color, size: 26),
    );
  }

  Widget _buildRewardChip(Quest quest, bool isClaimable) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppTheme.goldColor.withOpacity(0.15),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: AppTheme.goldColor.withOpacity(0.4)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.star_rounded, color: AppTheme.goldColor, size: 16),
              const SizedBox(width: 6),
              Text('+${quest.reward}', style: const TextStyle(color: AppTheme.goldColor, fontSize: 15, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildClaimRewardPrompt() {
    return Text(
      'ÖDÜLÜ TOPLA',
      style: GoogleFonts.orbitron(
        color: AppTheme.goldColor,
        fontWeight: FontWeight.bold,
        fontSize: 16,
        letterSpacing: 2,
        shadows: [const Shadow(blurRadius: 8, color: AppTheme.goldColor)],
      ),
    );
  }

  Widget _buildProgressBar(double progress, Color color) {
    return Container(
      height: 8,
      decoration: BoxDecoration(
        color: AppTheme.lightSurfaceColor.withOpacity(0.3),
        borderRadius: BorderRadius.circular(4),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Align(
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: progress,
            child: Container(color: color),
          ),
        ),
      ),
    );
  }
}

class StarfieldPainter extends CustomPainter {
  final Animation<double> animation;
  final List<List<Offset>> _stars = [];
  final List<Paint> _starPaints = [];
  final int _starLayers = 3;

  StarfieldPainter(this.animation) : super(repaint: animation) {
    // Create star layers
    final random = Random(123); // Seed for consistency
    for (int i = 0; i < _starLayers; i++) {
      _stars.add([]);
      _starPaints.add(Paint()..color = Colors.white.withOpacity(random.nextDouble() * 0.8 + 0.2));
      for (int j = 0; j < 100 ~/ (_starLayers - i); j++) {
        _stars[i].add(Offset(random.nextDouble(), random.nextDouble()));
      }
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    // Draw background gradient
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF0F172A), Color(0xFF0A0F1E)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );

    // Draw stars
    for (int i = 0; i < _starLayers; i++) {
      double parallaxFactor = (i + 1) * 0.2;
      double xOffset = (animation.value * size.width * parallaxFactor) % size.width;
      double yOffset = (animation.value * size.height * 0.1 * parallaxFactor) % size.height;

      for (var star in _stars[i]) {
        double x = (star.dx * size.width + xOffset) % size.width;
        double y = (star.dy * size.height + yOffset) % size.height;
        double radius = (i + 1) * 0.7;
        canvas.drawCircle(Offset(x, y), radius, _starPaints[i]);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
