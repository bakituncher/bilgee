// lib/features/coach/screens/update_topic_performance_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:taktik/data/models/topic_performance_model.dart';
import 'package:taktik/data/providers/firestore_providers.dart';
import 'package:taktik/features/auth/application/auth_controller.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:taktik/shared/widgets/score_slider.dart';
import 'package:taktik/features/quests/logic/quest_notifier.dart';
import 'package:lottie/lottie.dart';
import 'package:taktik/core/navigation/app_routes.dart';
import 'package:taktik/data/providers/premium_provider.dart';
import 'package:taktik/data/providers/monetization_provider.dart';
import 'package:taktik/core/services/monetization_manager.dart';
import 'package:taktik/core/services/admob_service.dart';

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
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(topic),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: Column(
                children: [
                  // Mod Seçici - Kompakt
                  _buildCompactModeSelector(context, ref),
                  const SizedBox(height: 20),

                  // Mastery Gauge & Stats - Yan yana
                  _buildMasterySection(context, mastery, correct, wrong, blank),
                  const SizedBox(height: 24),

                  // Slider'lar - Optimize edilmiş
                  _buildSlidersSection(context, ref, sessionQuestions, correct, wrong, isAddingMode),
                ],
              ),
            ),
          ),

          // Kaydet Butonu - Sabit Alt
          _buildSaveButton(context, ref, isAddingMode, correct, wrong, blank, sessionQuestions),
        ],
      ),
    );
  }

  Widget _buildCompactModeSelector(BuildContext context, WidgetRef ref) {
    final isAddingMode = ref.watch(_updateModeProvider);
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _CompactModeOption(
              title: "Üzerine Ekle",
              icon: Icons.add_circle_outline_rounded,
              isSelected: isAddingMode,
              onTap: () => ref.read(_updateModeProvider.notifier).state = true,
            ),
          ),
          Container(width: 1, height: 48, color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3)),
          Expanded(
            child: _CompactModeOption(
              title: "Değiştir",
              icon: Icons.sync_rounded,
              isSelected: !isAddingMode,
              onTap: () => ref.read(_updateModeProvider.notifier).state = false,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: -0.2, duration: 300.ms);
  }

  Widget _buildMasterySection(BuildContext context, double mastery, int correct, int wrong, int blank) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.secondary.withOpacity(0.15),
            Theme.of(context).primaryColor.withOpacity(0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          // Circular Gauge
          SizedBox(
            width: 120,
            height: 120,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: mastery < 0 ? 0 : mastery),
              duration: 600.ms,
              curve: Curves.easeOutCubic,
              builder: (context, value, child) {
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    CircularProgressIndicator(
                      value: value,
                      strokeWidth: 10,
                      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Color.lerp(Theme.of(context).colorScheme.error, Theme.of(context).colorScheme.secondary, value)!,
                      ),
                      strokeCap: StrokeCap.round,
                    ),
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "%${(value * 100).toStringAsFixed(0)}",
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          Text(
                            "Hakimiyet",
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(width: 24),

          // Stats Grid
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _QuickStat(
                  icon: Icons.check_circle_rounded,
                  label: "Doğru",
                  value: correct.toString(),
                  color: Theme.of(context).colorScheme.secondary,
                ),
                const SizedBox(height: 8),
                _QuickStat(
                  icon: Icons.cancel_rounded,
                  label: "Yanlış",
                  value: wrong.toString(),
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(height: 8),
                _QuickStat(
                  icon: Icons.radio_button_unchecked,
                  label: "Boş",
                  value: blank.toString(),
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 100.ms, duration: 400.ms).slideY(begin: 0.1, duration: 400.ms);
  }

  Widget _buildSlidersSection(BuildContext context, WidgetRef ref, int sessionQuestions, int correct, int wrong, bool isAddingMode) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.tune_rounded, color: Theme.of(context).colorScheme.secondary, size: 20),
              const SizedBox(width: 8),
              Text(
                isAddingMode ? "Test Detayları" : "Yeni Değerler",
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ScoreSlider(
            label: "Toplam Soru",
            value: sessionQuestions.toDouble(),
            max: 200,
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
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
          const SizedBox(height: 4),
          ScoreSlider(
            label: "Doğru",
            value: correct.toDouble(),
            max: sessionQuestions.toDouble(),
            color: Theme.of(context).colorScheme.secondary,
            onChanged: (value) {
              final newCorrect = value.toInt();
              ref.read(_correctCountProvider.notifier).state = newCorrect;
              if (newCorrect + ref.read(_wrongCountProvider) > sessionQuestions) {
                ref.read(_wrongCountProvider.notifier).state = sessionQuestions - newCorrect;
              }
            },
          ),
          const SizedBox(height: 4),
          ScoreSlider(
            label: "Yanlış",
            value: wrong.toDouble(),
            max: (sessionQuestions - correct).toDouble(),
            color: Theme.of(context).colorScheme.error,
            onChanged: (value) {
              ref.read(_wrongCountProvider.notifier).state = value.toInt();
            },
          ),
        ],
      ),
    ).animate().fadeIn(delay: 200.ms, duration: 400.ms).slideY(begin: 0.1, duration: 400.ms);
  }

  Widget _buildSaveButton(BuildContext context, WidgetRef ref, bool isAddingMode, int correct, int wrong, int blank, int sessionQuestions) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.black.withOpacity(0.1)
                : Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.secondary,
                foregroundColor: Colors.black,
                elevation: 0,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                  HapticFeedback.mediumImpact();
                  // Başarı Lottie diyaloğunu göster
                  await _showSuccessDialog(context);

                  // Akıllı monetizasyon sistemi: Her 5 ders netinin 4'ü reklam, 1'i paywall
                  final isPremium = ref.read(premiumStatusProvider);

                  if (!isPremium && context.mounted) {
                    // Premium değilse, akıllı sistem karar verir
                    final monetizationManager = ref.read(monetizationManagerProvider);
                    final action = monetizationManager.getActionAfterLessonNetSubmission();
                    final user = ref.read(userProfileProvider).value;

                    switch (action) {
                      case MonetizationAction.showPaywall:
                        // Paywall göster
                        await context.push(AppRoutes.aiToolsOffer);
                        break;
                      case MonetizationAction.showAd:
                        // Reklam göster
                        await AdMobService().showInterstitialAd(
                          isPremium: isPremium,
                          dateOfBirth: user?.dateOfBirth,
                        );
                        break;
                      case MonetizationAction.showNothing:
                        // Hiçbir şey gösterme (cooldown aktif)
                        break;
                    }
                  }

                  if (context.mounted) context.pop();
                }
              },
              child: Text(
                "Kaydet",
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ),
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
}

// Başarı animasyonu için küçük ve şık bir dialog (Ders Netlerim akışına özel)
Future<void> _showSuccessDialog(BuildContext context) async {
  await showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => const _SuccessDialog(),
  );
}

class _SuccessDialog extends StatefulWidget {
  const _SuccessDialog();

  @override
  State<_SuccessDialog> createState() => _SuccessDialogState();
}

class _SuccessDialogState extends State<_SuccessDialog> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: theme.colorScheme.surface,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Lottie.asset(
              'assets/lotties/Check blue.json',
              repeat: false,
              onLoaded: (composition) {
                Future.delayed(composition.duration + const Duration(milliseconds: 200), () {
                  if (mounted) Navigator.of(context).pop();
                });
              },
              width: 160,
              height: 160,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 8),
            Text('Kaydedildi!', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('Ders netlerin başarıyla güncellendi.', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _CompactModeOption extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _CompactModeOption({
    required this.title,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Theme.of(context).colorScheme.secondary.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? Theme.of(context).colorScheme.secondary : Theme.of(context).colorScheme.onSurfaceVariant,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Theme.of(context).colorScheme.secondary : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _QuickStat({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}