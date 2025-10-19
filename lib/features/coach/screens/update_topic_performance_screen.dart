// lib/features/coach/screens/update_topic_performance_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:taktik/data/models/topic_performance_model.dart';
import 'package:taktik/data/providers/firestore_providers.dart';
import 'package:taktik/features/auth/application/auth_controller.dart';
import 'package:taktik/core/theme/app_theme.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:taktik/shared/widgets/score_slider.dart';
import 'package:taktik/features/quests/logic/quest_notifier.dart';

final _updateModeProvider = StateProvider.autoDispose<bool>((ref) => true);
final _sessionQuestionCountProvider = StateProvider.autoDispose<int>((ref) => 20);
final _correctCountProvider = StateProvider.autoDispose<int>((ref) => 0);
final _wrongCountProvider = StateProvider.autoDispose<int>((ref) => 0);

class UpdateTopicPerformanceScreen extends ConsumerWidget {
  final String subject;
  final String topic;
  final TopicPerformanceModel initialPerformance;

  const UpdateTopicPerformanceScreen({
    super.key,
    required this.subject,
    required this.topic,
    required this.initialPerformance,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final isAddingMode = ref.watch(_updateModeProvider);
    final sessionQuestions = ref.watch(_sessionQuestionCountProvider);
    final correct = ref.watch(_correctCountProvider);
    final wrong = ref.watch(_wrongCountProvider);
    final blank = sessionQuestions - correct - wrong;
    const double penaltyCoefficient = 0.25;

    final double mastery = _calculateMastery(isAddingMode, initialPerformance, correct, wrong, sessionQuestions, penaltyCoefficient);

    return Scaffold(
      appBar: AppBar(title: Text(topic)),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  _buildModeSelector(context, ref),
                  const SizedBox(height: 32),
                  _buildMasteryGauge(context, mastery),
                  const SizedBox(height: 32),
                  Text(
                    isAddingMode ? "Çözdüğün Testi Ekle" : "Yeni Değerleri Gir",
                    style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 24),
                  ScoreSlider(
                    label: "Toplam Soru",
                    value: sessionQuestions.toDouble(),
                    max: 200,
                    color: AppTheme.lightSurfaceColor,
                    onChanged: (value) {
                      final int newTotal = value.toInt();
                      ref.read(_sessionQuestionCountProvider.notifier).state = newTotal;
                      if (ref.read(_correctCountProvider) > newTotal) {
                        ref.read(_correctCountProvider.notifier).state = newTotal;
                      }
                      if (ref.read(_wrongCountProvider) > newTotal - ref.read(_correctCountProvider)) {
                        ref.read(_wrongCountProvider.notifier).state = newTotal - ref.read(_correctCountProvider);
                      }
                    },
                  ),
                  ScoreSlider(
                    label: "Doğru",
                    value: correct.toDouble(),
                    max: sessionQuestions.toDouble(),
                    color: AppTheme.successColor,
                    onChanged: (value) {
                      final newCorrect = value.toInt();
                      ref.read(_correctCountProvider.notifier).state = newCorrect;
                      if (newCorrect + ref.read(_wrongCountProvider) > sessionQuestions) {
                        ref.read(_wrongCountProvider.notifier).state = sessionQuestions - newCorrect;
                      }
                    },
                  ),
                  ScoreSlider(
                    label: "Yanlış",
                    value: wrong.toDouble(),
                    max: (sessionQuestions - correct).toDouble(),
                    color: AppTheme.accentColor,
                    onChanged: (value) {
                      ref.read(_wrongCountProvider.notifier).state = value.toInt();
                    },
                  ),
                  const SizedBox(height: 24),
                  _StatDisplay(label: "Boş", value: blank.toString()),
                  const SizedBox(height: 48),
                ],
              ),
            ),
          ),
          // Sabit Buton Alanı
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                onPressed: () async {
                  final userId = ref.read(authControllerProvider).value!.uid;
                  TopicPerformanceModel newPerformance;
                  if (isAddingMode) {
                    newPerformance = TopicPerformanceModel(
                      correctCount: initialPerformance.correctCount + correct,
                      wrongCount: initialPerformance.wrongCount + wrong,
                      blankCount: initialPerformance.blankCount + blank,
                      questionCount: initialPerformance.questionCount + sessionQuestions,
                    );
                  } else {
                    newPerformance = TopicPerformanceModel(
                      correctCount: correct,
                      wrongCount: wrong,
                      blankCount: blank,
                      questionCount: sessionQuestions,
                    );
                  }

                  await ref.read(firestoreServiceProvider).updateTopicPerformance(
                    userId: userId,
                    subject: subject,
                    topic: topic,
                    performance: newPerformance,
                  );

                  ref.invalidate(performanceProvider);
                  ref.read(questNotifierProvider.notifier).userUpdatedTopicPerformance(subject, topic, sessionQuestions);
                  if (context.mounted) {
                    HapticFeedback.lightImpact();
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Konu istatistikleri güncellendi.')));
                    context.pop();
                  }
                },
                child: const Text("Kaydet"),
              ),
            ),
          ),
        ],
      ),
    );
  }

  double _calculateMastery(bool isAddingMode, TopicPerformanceModel initial, int correct, int wrong, int total, double penalty) {
    if (isAddingMode) {
      final finalCorrect = initial.correctCount + correct;
      final finalWrong = initial.wrongCount + wrong;
      final finalTotal = initial.questionCount + total;
      final netCorrect = finalCorrect - (finalWrong * penalty);
      return finalTotal == 0 ? 0.0 : (netCorrect / finalTotal).clamp(0.0, 1.0);
    } else {
      final netCorrect = correct - (wrong * penalty);
      return total == 0 ? 0.0 : (netCorrect / total).clamp(0.0, 1.0);
    }
  }

  Widget _buildModeSelector(BuildContext context, WidgetRef ref) {
    final isAddingMode = ref.watch(_updateModeProvider);
    return Row(
      children: [
        Expanded(
          child: _ModeCard(
            title: "Üzerine Ekle",
            subtitle: "Mevcut istatistiklere ekleme yap.",
            icon: Icons.add_circle_outline_rounded,
            isSelected: isAddingMode,
            onTap: () {
              ref.read(_updateModeProvider.notifier).state = true;
            },
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _ModeCard(
            title: "Değiştir",
            subtitle: "Tüm istatistikleri sıfırdan gir.",
            icon: Icons.sync_rounded,
            isSelected: !isAddingMode,
            onTap: () {
              ref.read(_updateModeProvider.notifier).state = false;
            },
          ),
        ),
      ],
    ).animate().fadeIn(duration: 400.ms);
  }

  Widget _buildMasteryGauge(BuildContext context, double mastery) {
    final textTheme = Theme.of(context).textTheme;
    return SizedBox(
      width: 180,
      height: 180,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: mastery < 0 ? 0 : mastery),
        duration: 400.ms,
        curve: Curves.easeInOut,
        builder: (context, value, child) {
          return Stack(
            fit: StackFit.expand,
            children: [
              CircularProgressIndicator(
                value: value,
                strokeWidth: 12,
                backgroundColor: AppTheme.lightSurfaceColor.withValues(alpha: AppTheme.lightSurfaceColor.a * 0.5),
                valueColor: AlwaysStoppedAnimation<Color>(
                  Color.lerp(AppTheme.accentColor, AppTheme.successColor, value)!,
                ),
                strokeCap: StrokeCap.round,
              ),
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "%${(value * 100).toStringAsFixed(0)}",
                      style: textTheme.displaySmall?.copyWith(fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    Text(
                      "Net Hakimiyet",
                      style: textTheme.bodyLarge?.copyWith(color: AppTheme.secondaryTextColor),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  final String title, subtitle;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _ModeCard({required this.title, required this.subtitle, required this.icon, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: 200.ms,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.secondaryColor.withValues(alpha: AppTheme.secondaryColor.a * 0.2) : AppTheme.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppTheme.secondaryColor : AppTheme.lightSurfaceColor,
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? AppTheme.secondaryColor : AppTheme.secondaryTextColor, size: 32),
            const SizedBox(height: 8),
            Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(subtitle, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.secondaryTextColor)),
          ],
        ),
      ),
    );
  }
}

class _StatDisplay extends StatelessWidget {
  final String label;
  final String value;
  const _StatDisplay({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: Theme.of(context).textTheme.headlineMedium),
        Text(label, style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppTheme.secondaryTextColor)),
      ],
    );
  }
}
