// lib/features/coach/widgets/topic_stats_dialog.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:bilge_ai/core/theme/app_theme.dart';
import 'package:bilge_ai/data/models/topic_performance_model.dart';

class TopicStatsDialog extends StatelessWidget {
  final String topicName;
  final TopicPerformanceModel performance;
  final double mastery;

  const TopicStatsDialog({
    super.key,
    required this.topicName,
    required this.performance,
    required this.mastery,
  });

  String getAiVerdict() {
    if (mastery < 0) {
      return "Bu konu henüz senin için keşfedilmemiş bir diyar. İlk verileri girerek bu topraklara ilk adımı at ve fetih başlasın!";
    } else if (mastery < 0.4) {
      return "Bu cephede zorlanıyorsun. Unutma, her yanlış bir derstir. Konu tekrarı ve bol soru çözümü ile bu kaleyi düşürebilirsin. Cevher Atölyesi seni bekliyor!";
    } else if (mastery < 0.7) {
      return "İstikrarlı bir ilerleme kaydediyorsun. Temellerin sağlam ama daha fazla pratikle zirveye oynayabilirsin. Sakın pes etme!";
    } else if (mastery < 0.9) {
      return "Harika gidiyorsun! Bu konuya hakimsin. Hızını ve doğruluğunu artırmak için zor seviye sorularla kendini test etme zamanı.";
    } else {
      return "Mükemmel! Bu konu artık senin kalen. Bu hakimiyetini korumak için ara sıra tekrar yapmayı unutma. Sen bir efsanesin!";
    }
  }

  @override
  Widget build(BuildContext context) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
      child: Dialog(
        backgroundColor: Colors.transparent,
        child: Animate(
          effects: const [
            FadeEffect(duration: Duration(milliseconds: 300)),
            ScaleEffect(duration: Duration(milliseconds: 400), curve: Curves.elasticOut)
          ],
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
                color: AppTheme.cardColor.withOpacity(0.95),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppTheme.secondaryColor, width: 2),
                boxShadow: [
                  BoxShadow(
                      color: AppTheme.secondaryColor.withOpacity(0.3),
                      blurRadius: 20)
                ]),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildMasteryGauge(context, mastery),
                const SizedBox(height: 16),
                Text(topicName,
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center),
                const SizedBox(height: 24),
                _buildStatsRow(context),
                const Divider(height: 32),
                _buildAiVerdictCard(context),
                const SizedBox(height: 24),
                TextButton(
                  child: const Text("Anlaşıldı"),
                  onPressed: () => Navigator.of(context).pop(),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMasteryGauge(BuildContext context, double masteryValue) {
    final displayMastery = masteryValue < 0 ? 0.0 : masteryValue;
    return SizedBox(
      width: 150,
      height: 150,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: displayMastery),
        duration: 800.ms,
        curve: Curves.easeInOut,
        builder: (context, value, child) {
          final color =
          Color.lerp(AppTheme.accentColor, AppTheme.successColor, value)!;
          return Stack(
            fit: StackFit.expand,
            children: [
              CircularProgressIndicator(
                value: value,
                strokeWidth: 10,
                backgroundColor: AppTheme.lightSurfaceColor.withOpacity(0.5),
                valueColor: AlwaysStoppedAnimation<Color>(color),
                strokeCap: StrokeCap.round,
              ),
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      masteryValue < 0
                          ? "?"
                          : "%${(value * 100).toStringAsFixed(0)}",
                      style: Theme.of(context)
                          .textTheme
                          .displaySmall
                          ?.copyWith(fontWeight: FontWeight.bold, color: color),
                    ),
                    Text(
                      "Net Hakimiyet",
                      style: Theme.of(context)
                          .textTheme
                          .bodyLarge
                          ?.copyWith(color: AppTheme.secondaryTextColor),
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

  Widget _buildStatsRow(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _StatItem(
              label: "Toplam", value: performance.questionCount.toString()),
          const VerticalDivider(color: AppTheme.lightSurfaceColor),
          _StatItem(
              label: "Doğru",
              value: performance.correctCount.toString(),
              color: AppTheme.successColor),
          const VerticalDivider(color: AppTheme.lightSurfaceColor),
          _StatItem(
              label: "Yanlış",
              value: performance.wrongCount.toString(),
              color: AppTheme.accentColor),
        ],
      ),
    );
  }

  Widget _buildAiVerdictCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.auto_awesome, color: AppTheme.secondaryColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("BilgeAI Yorumu",
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(color: AppTheme.secondaryColor)),
                const SizedBox(height: 8),
                Text(getAiVerdict(),
                    style: const TextStyle(
                        color: AppTheme.secondaryTextColor, height: 1.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;

  const _StatItem({required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(value,
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(color: color ?? Colors.white)),
        Text(label,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppTheme.secondaryTextColor)),
      ],
    );
  }
}