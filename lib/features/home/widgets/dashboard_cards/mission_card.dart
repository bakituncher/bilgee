// lib/features/home/widgets/dashboard_cards/mission_card.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
// import 'package:taktik/data/models/exam_model.dart';
// import 'package:taktik/features/stats/logic/stats_analysis.dart';
import 'package:taktik/data/models/user_model.dart';
import 'package:taktik/data/models/test_model.dart';
import 'package:taktik/data/providers/firestore_providers.dart';
import 'package:taktik/core/navigation/app_routes.dart';
import 'package:taktik/data/models/performance_summary.dart';
import 'package:taktik/features/stats/logic/stats_analysis_provider.dart';
import 'package:taktik/shared/widgets/logo_loader.dart';

class MissionCard extends ConsumerWidget {
  const MissionCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tests = ref.watch(testsProvider).valueOrNull;
    final user = ref.watch(userProfileProvider).valueOrNull;
    final performance = ref.watch(performanceProvider).value;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      elevation: isDark ? 6 : 5,
      shadowColor: isDark 
        ? Colors.black.withOpacity(0.35)
        : Theme.of(context).colorScheme.primary.withOpacity(0.15),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
        side: BorderSide(
          color: isDark 
            ? Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.25)
            : Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.35),
          width: 1.5,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: user == null || tests == null || performance == null
          ? const LogoLoader(size: 60)
          : _buildMissionContent(context, ref, user, tests, performance),
    );
  }

  Widget _buildMissionContent(BuildContext context, WidgetRef ref, UserModel user, List<TestModel> tests, PerformanceSummary performance) {
    if (user.selectedExam == null) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final analysisAsync = ref.watch(overallStatsAnalysisProvider);

    return analysisAsync.when(
      loading: () => const LogoLoader(size: 60),
      error: (e, st) => Center(child: Padding(padding: const EdgeInsets.all(24), child: Text('Analiz yüklenemedi: $e'))),
      data: (analysis) {
        final textTheme = Theme.of(context).textTheme;
        IconData icon;
        String title;
        String subtitle;
        VoidCallback? onTap;
        String buttonText;

        if (tests.isEmpty || analysis == null) {
          title = 'Yolculuğa Başla';
          subtitle = 'Potansiyelini ortaya çıkarmak için ilk deneme sonucunu ekle.';
          onTap = () => context.go('${AppRoutes.home}/${AppRoutes.addTest}');
          buttonText = 'İlk Denemeni Ekle';
          icon = Icons.add_chart_rounded;
        } else {
          final weakestTopicInfo = analysis.getWeakestTopicWithDetails();
          title = 'Günün Önceliği';
          subtitle = weakestTopicInfo != null
              ? 'TaktikAI, en zayıf noktanın **\'${weakestTopicInfo['subject']}\'** dersindeki **\'${weakestTopicInfo['topic']}\'** konusu olduğunu tespit etti. Bu cevheri işlemeye hazır mısın?'
              : 'Harika gidiyorsun! Şu an belirgin bir zayıf noktan tespit edilmedi. Yeni konu verileri girerek analizi derinleştirebilirsin.';
          onTap = weakestTopicInfo != null
              ? () => context.push('${AppRoutes.aiHub}/${AppRoutes.weaknessWorkshop}')
              : null;
          buttonText = 'Cevher Atölyesine Git';
          icon = Icons.construction_rounded;
        }

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(26.0),
          decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                  ? [
                      Theme.of(context).colorScheme.primary.withOpacity(0.12),
                      Theme.of(context).cardColor,
                      Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.08),
                    ]
                  : [
                      Theme.of(context).colorScheme.primary.withOpacity(0.08),
                      Theme.of(context).cardColor,
                      Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.05),
                    ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              )),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withOpacity(isDark ? 0.18 : 0.12),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.primary.withOpacity(isDark ? 0.4 : 0.5),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(12),
                    child: Icon(icon, size: 26, color: Theme.of(context).colorScheme.primary),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      title, 
                      style: textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              _buildRichTextFromMarkdown(
                subtitle,
                baseStyle: textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant, 
                  height: 1.6,
                  fontSize: 15,
                ),
                boldStyle: TextStyle(
                  fontWeight: FontWeight.w700, 
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const Spacer(),
              if (onTap != null)
                Align(
                  alignment: Alignment.bottomRight,
                  child: ElevatedButton.icon(
                    onPressed: onTap, 
                    icon: const Icon(Icons.arrow_forward_rounded, size: 20),
                    label: Text(buttonText),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      elevation: isDark ? 6 : 4,
                    ),
                  ),
                )
            ],
          ),
        );
      },
    );
  }

  Widget _buildRichTextFromMarkdown(String text, {TextStyle? baseStyle, TextStyle? boldStyle}) {
    List<TextSpan> spans = [];
    final RegExp regExp = RegExp(r'\*\*(.*?)\*\*');
    text.splitMapJoin(regExp, onMatch: (m) {
      spans.add(TextSpan(text: m.group(1), style: boldStyle ?? baseStyle?.copyWith(fontWeight: FontWeight.bold)));
      return '';
    }, onNonMatch: (n) {
      spans.add(TextSpan(text: n));
      return '';
    });
    return RichText(text: TextSpan(style: baseStyle, children: spans));
  }
}