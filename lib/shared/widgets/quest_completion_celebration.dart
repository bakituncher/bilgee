import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:taktik/core/theme/app_theme.dart';
import 'package:taktik/features/quests/logic/quest_completion_notifier.dart';
import 'package:taktik/features/quests/models/quest_model.dart';

class QuestCompletionCelebration extends ConsumerStatefulWidget {
  final Quest completedQuest;
  const QuestCompletionCelebration({super.key, required this.completedQuest});

  @override
  ConsumerState<QuestCompletionCelebration> createState() => _QuestCompletionCelebrationState();
}

class _QuestCompletionCelebrationState extends ConsumerState<QuestCompletionCelebration> {
  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 1));
    // Play the confetti after a short delay
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        _confettiController.play();
      }
    });
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  void _dismiss() {
    ref.read(questCompletionProvider.notifier).clear();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Full-screen dismissible background
        GestureDetector(
          onTap: _dismiss,
          child: Container(
            color: Colors.black.withOpacity(0.7),
          ),
        ).animate().fadeIn(duration: 300.ms),

        // Main celebration dialog
        _buildCelebrationDialog(context),

        // Confetti cannon
        Align(
          alignment: Alignment.topCenter,
          child: ConfettiWidget(
            confettiController: _confettiController,
            blastDirectionality: BlastDirectionality.explosive,
            shouldLoop: false,
            numberOfParticles: 30,
            gravity: 0.2,
            emissionFrequency: 0.05,
            colors: const [
              AppTheme.goldColor,
              Colors.white,
              AppTheme.secondaryColor,
              Colors.lightBlueAccent,
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCelebrationDialog(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 24),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            colors: [
              AppTheme.primaryColor,
              AppTheme.primaryColor.withOpacity(0.8),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: AppTheme.goldColor.withOpacity(0.5), width: 2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildTrophyIcon(),
            const SizedBox(height: 16),
            const Text(
              'GÖREV TAMAMLANDI!',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppTheme.goldColor,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.completedQuest.title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            _buildRewardChip(),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _dismiss,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.goldColor,
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              child: const Text(
                'Harika!',
                style: TextStyle(fontSize: 18, color: Colors.black),
              ),
            )
          ],
        ),
      ).animate().scale(
        delay: 200.ms,
        duration: 500.ms,
        curve: Curves.elasticOut,
      ).fadeIn(),
    );
  }

  Widget _buildTrophyIcon() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppTheme.goldColor.withOpacity(0.1),
      ),
      child: const Icon(
        Icons.emoji_events_rounded,
        size: 60,
        color: AppTheme.goldColor,
      ),
    ).animate(
      onPlay: (controller) => controller.repeat(reverse: true),
    ).scale(
      duration: 1500.ms,
      curve: Curves.easeInOut,
      begin: const Offset(1, 1),
      end: const Offset(1.1, 1.1),
    ).then(delay: 500.ms);
  }

  Widget _buildRewardChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.secondaryColor.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.secondaryColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded, color: AppTheme.goldColor, size: 24),
          const SizedBox(width: 8),
          Text(
            '+${widget.completedQuest.reward} BP',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    ).animate().scale(delay: 800.ms, duration: 400.ms, curve: Curves.elasticOut);
  }
}
