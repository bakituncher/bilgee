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
import 'package:taktik/data/providers/premium_provider.dart';

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
      elevation: isDark ? 6 : 4,
      shadowColor: isDark
          ? Colors.black.withOpacity(0.4)
          : Theme.of(context).colorScheme.primary.withOpacity(0.2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color: isDark
              ? Theme.of(context).colorScheme.primary.withOpacity(0.2)
              : Colors.transparent,
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

    final analysisAsync = ref.watch(overallStatsAnalysisProvider);
    final isPremium = ref.watch(premiumStatusProvider);

    return analysisAsync.when(
      loading: () => const LogoLoader(size: 60),
      error: (e, st) => Center(child: Padding(padding: const EdgeInsets.all(24), child: Text('Analiz yüklenemedi: $e'))),
      data: (analysis) {
        final textTheme = Theme.of(context).textTheme;
        final theme = Theme.of(context);
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
              ? () {
                  if (isPremium) {
                    context.push('${AppRoutes.aiHub}/${AppRoutes.weaknessWorkshop}');
                  } else {
                    // Premium olmayan kullanıcılar için tool offer screen'e yönlendir
                    context.go(
                      '/ai-hub/offer',
                      extra: {
                        'title': 'Cevher Atölyesi',
                        'subtitle': 'En zayıf konunu, kişisel çalışma kartı ve özel test ile işle.',
                        'icon': Icons.construction_rounded,
                        'color': theme.colorScheme.secondary,
                        'heroTag': 'weakness-core',
                        'marketingTitle': 'Zayıf Noktalarınızı Güce Dönüştürün',
                        'marketingSubtitle': 'En çok zorlandığınız konuları tespit edin ve AI destekli özel çalışma materyalleri ile zayıf yanlarınızı güçlü yanlara çevirin.',
                        'redirectRoute': '/ai-hub/weakness-workshop',
                      },
                    );
                  }
                }
              : null;
          buttonText = 'Cevher Atölyesine Git';
          icon = Icons.construction_rounded;
        }

        final isDark = Theme.of(context).brightness == Brightness.dark;

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [
                        Theme.of(context).colorScheme.primary.withOpacity(0.12),
                        Theme.of(context).colorScheme.surfaceContainer.withOpacity(0.7),
                        Theme.of(context).cardColor.withOpacity(0.95),
                      ]
                    : [
                        Theme.of(context).colorScheme.primary.withOpacity(0.15),
                        Theme.of(context).cardColor.withOpacity(0.98),
                        Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
                      ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(
                color: isDark
                    ? Theme.of(context).colorScheme.primary.withOpacity(0.3)
                    : Theme.of(context).colorScheme.primary.withOpacity(0.2),
                width: 1.5,
              ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Theme.of(context).colorScheme.primary,
                          Theme.of(context).colorScheme.primary.withOpacity(0.7),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, size: 20, color: Colors.white),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            letterSpacing: 0.2,
                          ),
                        ),
                        Container(
                          margin: const EdgeInsets.only(top: 2),
                          height: 2,
                          width: 30,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Theme.of(context).colorScheme.primary,
                                Theme.of(context).colorScheme.primary.withOpacity(0),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(1),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Expanded(
                child: SingleChildScrollView(
                  child: _buildRichTextFromMarkdown(subtitle,
                      baseStyle: textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        height: 1.35,
                        fontSize: 11,
                      ),
                      boldStyle: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 11,
                      )),
                ),
              ),
              const SizedBox(height: 10),
              if (onTap != null)
                Align(
                  alignment: Alignment.centerRight,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Theme.of(context).colorScheme.primary,
                          Theme.of(context).colorScheme.primary.withOpacity(0.8),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: onTap,
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                buttonText,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 14),
                            ],
                          ),
                        ),
                      ),
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