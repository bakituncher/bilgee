// lib/features/stats/widgets/cached_analysis_view.dart
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:taktik/data/providers/premium_provider.dart';
import 'package:taktik/features/stats/logic/stats_analysis_provider.dart';
import 'package:taktik/features/stats/screens/subject_stats_screen.dart';
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
  bool get wantKeepAlive => true; // Widget'ı cache'de tut

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

    // Önceki veriyi sakla - loading durumunda bile eski veriyi göster
    return analysisAsync.when(
      loading: () {
        // Eğer önceden yüklenmiş veri varsa onu göster, yoksa basit bir progress göster
        final previous = analysisAsync.asData?.value;
        if (previous != null) {
          return _buildBody(context, previous);
        }
        // İlk yükleme için daha minimalist bir loading göstergesi
        return Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Theme.of(context).colorScheme.primary,
          ),
        );
      },
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isPremium = ref.watch(premiumStatusProvider);

    return Column(
      children: [
        // Modern Tab Bar - Enhanced for Light Mode
        Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? [
                Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.25),
              ]
                  : [
                Theme.of(context).cardColor.withValues(alpha: 0.95),
                Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark
                  ? Theme.of(context).colorScheme.secondary.withValues(alpha: 0.15)
                  : Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.06)
                    : Colors.black.withValues(alpha: 0.08),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TabBar(
            controller: _tabController,
            indicator: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.9),
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.75),
                ]
                    : [
                  Theme.of(context).colorScheme.secondary,
                  Theme.of(context).colorScheme.secondary.withValues(alpha: 0.88),
                ],
              ),
              borderRadius: BorderRadius.circular(11),
              boxShadow: [
                BoxShadow(
                  color: isDark
                      ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.4)
                      : Theme.of(context).colorScheme.secondary.withValues(alpha: 0.35),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            indicatorSize: TabBarIndicatorSize.tab,
            dividerColor: Colors.transparent,
            labelColor: isDark ? Colors.black : Colors.black,
            unselectedLabelColor: isDark
                ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)
                : Theme.of(context).colorScheme.onSurfaceVariant,
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
            tabs: [
              const Tab(
                height: 44,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.analytics_rounded, size: 18),
                      SizedBox(width: 6),
                      Text('Özet'),
                    ],
                  ),
                ),
              ),
              Tab(
                height: 44,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.auto_awesome_rounded, size: 18),
                      const SizedBox(width: 6),
                      const Text('Taktik'),
                      if (!isPremium) ...[
                        const SizedBox(width: 4),
                        const Icon(Icons.lock_rounded, size: 12, color: Colors.amber),
                      ],
                    ],
                  ),
                ),
              ),
              Tab(
                height: 44,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.menu_book_rounded, size: 18),
                      const SizedBox(width: 6),
                      const Text('Dersler'),
                      if (!isPremium) ...[
                        const SizedBox(width: 4),
                        const Icon(Icons.lock_rounded, size: 12, color: Colors.amber),
                      ],
                    ],
                  ),
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
              isPremium
                  ? _buildTacticsTab(context, analysis)
                  : _buildLockedTab(context, 'Taktik Raporun', 'AI destekli kişisel analiz ve öneriler', Icons.auto_awesome_rounded),
              isPremium
                  ? _buildSubjectsTab(context, analysis)
                  : _buildLockedTab(context, 'Ders Haritası', 'Ders bazlı detaylı performans analizi', Icons.menu_book_rounded),
            ],
          ),
        ),
      ],
    );
  }

  /// Premium olmayan kullanıcılar için compact kilitli sekme görünümü
  Widget _buildLockedTab(BuildContext context, String title, String description, IconData icon) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Sekme bazlı özellikler
    final features = title == 'Taktik Raporun'
        ? [
      _FeatureItem(Icons.psychology_rounded, 'Yapay Zeka Analizi', 'Performansını derinlemesine analiz et'),
      _FeatureItem(Icons.lightbulb_rounded, 'Kişisel Öneriler', 'Sana özel strateji tavsiyeleri'),
      _FeatureItem(Icons.trending_up_rounded, 'Gelişim Yol Haritası', 'Adım adım ilerleme planı'),
    ]
        : [
      _FeatureItem(Icons.menu_book_rounded, 'Ders Bazlı Analiz', 'Her ders için detaylı istatistik'),
      _FeatureItem(Icons.pie_chart_rounded, 'Konu Dağılımı', 'Güçlü ve zayıf yönlerini keşfet'),
      _FeatureItem(Icons.compare_arrows_rounded, 'Karşılaştırmalı Görünüm', 'Dersler arası performans farkı'),
    ];

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDark
              ? [const Color(0xFF0F172A), const Color(0xFF1E1B4B).withOpacity(0.3)]
              : [const Color(0xFFF8FAFC), const Color(0xFFEEF2FF)],
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Animasyonlu ikon - compact
              Stack(
                alignment: Alignment.center,
                children: [
                  // Dış halka
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.amber.withOpacity(0.15), width: 2),
                    ),
                  ).animate(onPlay: (c) => c.repeat())
                      .scale(begin: const Offset(0.95, 0.95), end: const Offset(1.08, 1.08), duration: 2000.ms, curve: Curves.easeInOut),
                  // Ana ikon
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: Colors.amber.withOpacity(0.4), blurRadius: 16, spreadRadius: 2)],
                    ),
                    child: Icon(icon, color: Colors.white, size: 26),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Gradient Başlık
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [Color(0xFFFFD700), Color(0xFFFFA500), Color(0xFFFF6B35)],
                ).createShader(bounds),
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.5),
                ),
              ).animate().fadeIn(delay: 100.ms),
              const SizedBox(height: 4),

              // Açıklama
              Text(
                description,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: isDark ? Colors.white60 : Colors.black54),
              ).animate().fadeIn(delay: 150.ms),
              const SizedBox(height: 16),

              // Özellik Kartları - Compact
              ...features.asMap().entries.map((entry) {
                final index = entry.key;
                final feature = entry.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _buildCompactFeatureCard(context, feature, isDark, index),
                );
              }),
              const SizedBox(height: 16),

              // CTA Butonu
              GestureDetector(
                onTap: () => context.push('/premium'),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFFFFD700), Color(0xFFFFA500)]),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [BoxShadow(color: Colors.amber.withOpacity(0.35), blurRadius: 12, offset: const Offset(0, 4))],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                        child: const Icon(Icons.lock_open_rounded, color: Colors.white, size: 16),
                      ),
                      const SizedBox(width: 10),
                      const Text('Kilidi Aç', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white)),
                      const SizedBox(width: 6),
                      const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 18),
                    ],
                  ),
                ),
              ).animate()
                  .fadeIn(delay: 350.ms)
                  .slideY(begin: 0.1, duration: 300.ms)
                  .then()
                  .shimmer(duration: 2000.ms, delay: 500.ms, color: Colors.white38),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCompactFeatureCard(BuildContext context, _FeatureItem feature, bool isDark, int index) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [Colors.white.withOpacity(0.06), Colors.white.withOpacity(0.02)]
              : [Colors.white, Colors.grey.shade50],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.white.withOpacity(0.08) : Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.amber.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(feature.icon, color: Colors.amber.shade700, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  feature.title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                Text(
                  feature.subtitle,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white.withOpacity(0.5) : Colors.black45,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.check_circle_rounded, color: Colors.green.shade500, size: 18),
        ],
      ),
    ).animate()
        .fadeIn(delay: Duration(milliseconds: 200 + (index * 60)))
        .slideX(begin: 0.08, duration: 300.ms, curve: Curves.easeOutCubic);
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
        const SizedBox(height: 16),
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

/// Premium özellik kartı için veri modeli
class _FeatureItem {
  final IconData icon;
  final String title;
  final String subtitle;

  _FeatureItem(this.icon, this.title, this.subtitle);
}