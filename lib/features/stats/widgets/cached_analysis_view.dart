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
import 'package:taktik/core/theme/app_theme.dart';

final _selectedAnalysisTabProvider = StateProvider.autoDispose<int>((ref) => 0);

class CachedAnalysisView extends ConsumerStatefulWidget {
  final String sectionName;
  const CachedAnalysisView({super.key, required this.sectionName});

  @override
  ConsumerState<CachedAnalysisView> createState() => _CachedAnalysisViewState();
}

class _CachedAnalysisViewState extends ConsumerState<CachedAnalysisView> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        ref.read(_selectedAnalysisTabProvider.notifier).state = _tabController.index;
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final analysisAsync = ref.watch(statsAnalysisForSectionProvider(widget.sectionName));
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
    final selectedTab = ref.watch(_selectedAnalysisTabProvider);

    return Column(
      children: [
        // Modern Tab Bar
        Container(
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          decoration: BoxDecoration(
            color: AppTheme.lightSurfaceColor.withOpacity(0.3),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppTheme.secondaryColor.withOpacity(0.1),
              width: 1,
            ),
          ),
          child: TabBar(
            controller: _tabController,
            indicator: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.secondaryColor,
                  AppTheme.secondaryColor.withOpacity(0.85),
                ],
              ),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.secondaryColor.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            indicatorSize: TabBarIndicatorSize.tab,
            dividerColor: Colors.transparent,
            labelColor: AppTheme.primaryColor,
            unselectedLabelColor: AppTheme.secondaryTextColor,
            labelStyle: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              letterSpacing: 0.2,
            ),
            unselectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
            padding: const EdgeInsets.all(4),
            tabs: [
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.analytics_rounded, size: 16),
                    const SizedBox(width: 6),
                    const Text('Özet'),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.auto_awesome_rounded, size: 16),
                    const SizedBox(width: 6),
                    const Text('Taktik'),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.menu_book_rounded, size: 16),
                    const SizedBox(width: 6),
                    const Text('Dersler'),
                  ],
                ),
              ),
            ],
          ),
        ).animate().fadeIn(duration: 300.ms).slideY(begin: -0.1, end: 0),

        // Tab Content
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildOverviewTab(context, analysis),
              _buildTacticsTab(context, analysis),
              _buildSubjectsTab(context, analysis),
            ],
          ),
        ),
      ],
    );
  }

  // Tab 1: Özet (Grafik + Metrikler)
  Widget _buildOverviewTab(BuildContext context, StatsAnalysis analysis) {
    return ListView(
      key: const PageStorageKey('overview-tab'),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      children: [
        const TitleWidget(
          title: 'Kader Çizgin',
          subtitle: 'Netlerinin ve doğruluğunun zamansal analizi',
        ).animate().fadeIn(duration: 300.ms),
        const SizedBox(height: 8),
        NetEvolutionChart(analysis: analysis)
            .animate()
            .fadeIn(delay: 100.ms, duration: 400.ms)
            .slideY(begin: 0.05, end: 0),
        const SizedBox(height: 20),
        const TitleWidget(
          title: 'Zafer Anıtları',
          subtitle: 'Genel performans metriklerin',
        ).animate().fadeIn(delay: 150.ms, duration: 300.ms),
        const SizedBox(height: 8),
        KeyStatsGrid(analysis: analysis)
            .animate()
            .fadeIn(delay: 200.ms, duration: 400.ms)
            .slideY(begin: 0.05, end: 0),
      ],
    );
  }

  // Tab 2: Taktik (AI Önerileri)
  Widget _buildTacticsTab(BuildContext context, StatsAnalysis analysis) {
    return ListView(
      key: const PageStorageKey('tactics-tab'),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      children: [
        const TitleWidget(
          title: 'Taktik Raporun',
          subtitle: 'Sana özel Taktik\'sel rapor ve öneriler',
        ).animate().fadeIn(duration: 300.ms),
        const SizedBox(height: 8),
        AiInsightCard(analysis: analysis)
            .animate()
            .fadeIn(delay: 100.ms, duration: 400.ms)
            .slideY(begin: 0.05, end: 0),
      ],
    );
  }

  // Tab 3: Dersler (Ders Kartları)
  Widget _buildSubjectsTab(BuildContext context, StatsAnalysis analysis) {
    return ListView(
      key: const PageStorageKey('subjects-tab'),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
      children: [
        const TitleWidget(
          title: 'Ders Haritası',
          subtitle: 'Ders kalelerine tıklayarak detaylı istihbarat al',
        ).animate().fadeIn(duration: 300.ms),
        const SizedBox(height: 8),
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
              .fadeIn(delay: (100 + (index * 50)).ms, duration: 350.ms)
              .slideX(begin: 0.05, end: 0);
        }),
      ],
    );
  }
}
