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

final _selectedAnalysisTabProvider = StateProvider.autoDispose<int>((ref) => 0);

class CachedAnalysisView extends ConsumerStatefulWidget {
  final String sectionName;
  const CachedAnalysisView({super.key, required this.sectionName});

  @override
  ConsumerState<CachedAnalysisView> createState() => _CachedAnalysisViewState();
}

class _CachedAnalysisViewState extends ConsumerState<CachedAnalysisView> with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  late TabController _tabController;

  @override
  bool get wantKeepAlive => false; // PageView cache'ini devre dışı bırak

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
    super.build(context); // AutomaticKeepAliveClientMixin için gerekli
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
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.35),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: Theme.of(context).colorScheme.secondary.withOpacity(0.15),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TabBar(
            controller: _tabController,
            indicator: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).colorScheme.secondary,
                  Theme.of(context).colorScheme.secondary.withOpacity(0.88),
                ],
              ),
              borderRadius: BorderRadius.circular(11),
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context).colorScheme.secondary.withOpacity(0.35),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            indicatorSize: TabBarIndicatorSize.tab,
            dividerColor: Colors.transparent,
            labelColor: Theme.of(context).colorScheme.primary,
            unselectedLabelColor: Theme.of(context).colorScheme.onSurfaceVariant,
            labelStyle: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              letterSpacing: 0.3,
            ),
            unselectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 12.5,
            ),
            padding: const EdgeInsets.all(5),
            tabs: const [
              Tab(
                height: 44,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.analytics_rounded, size: 18),
                    SizedBox(width: 6),
                    Text('Özet'),
                  ],
                ),
              ),
              Tab(
                height: 44,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.auto_awesome_rounded, size: 18),
                    SizedBox(width: 6),
                    Text('Taktik'),
                  ],
                ),
              ),
              Tab(
                height: 44,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.menu_book_rounded, size: 18),
                    SizedBox(width: 6),
                    Text('Dersler'),
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
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
      children: [
        const TitleWidget(
          title: 'Kader Çizgin',
          subtitle: 'Netlerinin ve doğruluğunun zamansal analizi',
        ).animate().fadeIn(duration: 300.ms),
        const SizedBox(height: 12),
        NetEvolutionChart(
          key: ValueKey('chart-${widget.sectionName}-${analysis.tests.length}-${analysis.averageNet}'),
          analysis: analysis,
        )
            .animate()
            .fadeIn(delay: 100.ms, duration: 400.ms)
            .slideY(begin: 0.05, end: 0),
        const SizedBox(height: 24),
        const TitleWidget(
          title: 'Zafer Anıtları',
          subtitle: 'Genel performans metriklerin',
        ).animate().fadeIn(delay: 150.ms, duration: 300.ms),
        const SizedBox(height: 12),
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
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
      children: [
        const TitleWidget(
          title: 'Taktik Raporun',
          subtitle: 'Sana özel Taktik\'sel rapor ve öneriler',
        ).animate().fadeIn(duration: 300.ms),
        const SizedBox(height: 12),
        AiInsightCard(analysis: analysis)
            .animate()
            .fadeIn(delay: 100.ms, duration: 400.ms)
            .slideY(begin: 0.05, end: 0),
      ],
    );
  }
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
