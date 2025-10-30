// lib/features/stats/widgets/cached_analysis_view.dart
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:taktik/features/stats/logic/stats_analysis_provider.dart';
import 'package:taktik/features/stats/screens/subject_stats_screen.dart';
import 'package:taktik/shared/widgets/logo_loader.dart';
import 'package:taktik/features/stats/widgets/title_widget.dart';
import 'package:taktik/features/stats/widgets/net_evolution_chart.dart';
import 'package:taktik/features/stats/widgets/key_stats_grid.dart';
import 'package:taktik/features/stats/widgets/ai_insight_card.dart';
import 'package:taktik/features/stats/widgets/subject_stat_card.dart';
import 'package:taktik/features/stats/logic/stats_analysis.dart';

class CachedAnalysisView extends ConsumerWidget {
  final String sectionName;
  const CachedAnalysisView({super.key, required this.sectionName});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analysisAsync = ref.watch(statsAnalysisForSectionProvider(sectionName));
    final previous = analysisAsync.asData?.value;

    return analysisAsync.when(
      loading: () => previous != null
          ? _buildBody(context, previous)
          : const LogoLoader(),
      error: (e, st) => Center(child: Text('Analiz yüklenemedi: $e')),
      data: (analysis) {
        if (analysis == null) {
          return const Center(child: Text('Gösterilecek analiz bulunamadı.'));
        }
        return _buildBody(context, analysis);
      },
    );
  }

  Widget _buildBody(BuildContext context, StatsAnalysis analysis) {
    return RepaintBoundary(
      child: ListView(
        key: PageStorageKey('analysis-$sectionName'),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          const SizedBox(height: 8),
          const TitleWidget(
            title: 'Kader Çizgin',
            subtitle: 'Netlerinin ve doğruluğunun zamansal analizi',
          ).animate().fadeIn(duration: 300.ms).slideX(begin: -0.1, end: 0),
          const SizedBox(height: 12),
          NetEvolutionChart(analysis: analysis)
              .animate()
              .fadeIn(delay: 100.ms, duration: 400.ms)
              .slideY(begin: 0.1, end: 0),
          const SizedBox(height: 32),
          const TitleWidget(
            title: 'Zafer Anıtları',
            subtitle: 'Genel performans metriklerin',
          ).animate().fadeIn(delay: 150.ms, duration: 300.ms).slideX(begin: -0.1, end: 0),
          const SizedBox(height: 12),
          KeyStatsGrid(analysis: analysis)
              .animate()
              .fadeIn(delay: 200.ms, duration: 400.ms)
              .slideY(begin: 0.1, end: 0),
          const SizedBox(height: 32),
          const TitleWidget(
            title: 'Taktik Raporun',
            subtitle: 'Sana özel Taktik\'sel rapor',
          ).animate().fadeIn(delay: 250.ms, duration: 300.ms).slideX(begin: -0.1, end: 0),
          const SizedBox(height: 12),
          AiInsightCard(analysis: analysis)
              .animate()
              .fadeIn(delay: 300.ms, duration: 400.ms)
              .slideY(begin: 0.1, end: 0),
          const SizedBox(height: 32),
          const TitleWidget(
            title: 'Ders Haritası',
            subtitle: 'Ders kalelerine tıklayarak detaylı istihbarat al',
          ).animate().fadeIn(delay: 350.ms, duration: 300.ms).slideX(begin: -0.1, end: 0),
          const SizedBox(height: 12),
          ...analysis.sortedSubjects.asMap().entries.map((entry) {
            final index = entry.key;
            final subjectEntry = entry.value;
            final subjectAnalysis = analysis.getAnalysisForSubject(subjectEntry.key);
            return SubjectStatCard(
              subjectName: subjectEntry.key,
              analysis: subjectAnalysis,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SubjectStatsScreen(
                      subjectName: subjectEntry.key,
                      analysis: subjectAnalysis,
                    ),
                  ),
                );
              },
            )
                .animate()
                .fadeIn(delay: (400 + (index * 50)).ms, duration: 350.ms)
                .slideX(begin: 0.1, end: 0);
          }),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
