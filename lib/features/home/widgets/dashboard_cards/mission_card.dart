// lib/features/home/widgets/dashboard_cards/mission_card.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:bilge_ai/core/theme/app_theme.dart';
// import 'package:bilge_ai/data/models/exam_model.dart';
// import 'package:bilge_ai/features/stats/logic/stats_analysis.dart';
import 'package:bilge_ai/data/models/user_model.dart';
import 'package:bilge_ai/data/models/test_model.dart';
import 'package:bilge_ai/data/providers/firestore_providers.dart';
import 'package:bilge_ai/core/navigation/app_routes.dart';
import 'package:bilge_ai/data/models/performance_summary.dart';
import 'package:bilge_ai/features/stats/logic/stats_analysis_provider.dart';
import 'package:bilge_ai/shared/widgets/logo_loader.dart';

class MissionCard extends ConsumerWidget {
  const MissionCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tests = ref.watch(testsProvider).valueOrNull;
    final user = ref.watch(userProfileProvider).valueOrNull;
    final performance = ref.watch(performanceProvider).value;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      elevation: 4,
      shadowColor: AppTheme.secondaryColor.withOpacity(0.2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: user == null || tests == null || performance == null
          ? const LogoLoader(size: 60)
          : _buildMissionContent(context, ref, user, tests, performance),
    );
  }

  Widget _buildMissionContent(BuildContext context, WidgetRef ref, UserModel user, List<TestModel> tests, PerformanceSummary performance) {
    if (user.selectedExam == null) return const SizedBox.shrink();

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
          padding: const EdgeInsets.all(24.0),
          decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppTheme.secondaryColor.withOpacity(0.1), AppTheme.cardColor],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              )),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  Icon(icon, size: 28, color: AppTheme.secondaryColor),
                  const SizedBox(width: 12),
                  Text(title, style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                ],
              ),
              const Spacer(),
              _buildRichTextFromMarkdown(subtitle,
                  baseStyle: textTheme.bodyLarge?.copyWith(color: AppTheme.secondaryTextColor, height: 1.5),
                  boldStyle: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textColor)),
              const Spacer(),
              if (onTap != null)
                Align(
                  alignment: Alignment.bottomRight,
                  child: ElevatedButton(onPressed: onTap, child: Text(buttonText)),
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