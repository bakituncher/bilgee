// lib/features/coach/screens/coach_screen.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:bilge_ai/data/providers/firestore_providers.dart';
import 'package:bilge_ai/data/models/exam_model.dart';
import 'package:bilge_ai/data/models/user_model.dart';
import 'package:bilge_ai/data/models/topic_performance_model.dart';
import 'package:bilge_ai/core/theme/app_theme.dart';
import 'package:bilge_ai/features/coach/widgets/mastery_topic_bubble.dart';
import 'package:bilge_ai/features/coach/widgets/topic_stats_dialog.dart';
import 'package:bilge_ai/core/utils/exam_utils.dart';
import 'package:bilge_ai/data/models/performance_summary.dart';

final coachScreenTabProvider = StateProvider<int>((ref) => 0);

enum GalaxyViewMode { grid, list }
final subjectFilterProvider = StateProvider.family<String, String>((ref, subject) => '');
final subjectViewModeProvider = StateProvider.family<GalaxyViewMode, String>((ref, subject) => GalaxyViewMode.grid);

class CoachScreen extends ConsumerStatefulWidget {
  final String? initialSubject;
  const CoachScreen({super.key, this.initialSubject});

  @override
  ConsumerState<CoachScreen> createState() => _CoachScreenState();
}

class _CoachScreenState extends ConsumerState<CoachScreen>
    with TickerProviderStateMixin {
  TabController? _tabController;
  bool _appliedInitialSubject = false;

  Map<String, List<SubjectTopic>> _getRelevantSubjects(
      UserModel user, Exam exam) {
    final subjects = <String, List<SubjectTopic>>{};
    final relevantSections = ExamUtils.getRelevantSectionsForUser(user, exam);
    for (var section in relevantSections) {
      section.subjects.forEach((subjectName, subjectDetails) {
        subjects[subjectName] = subjectDetails.topics;
      });
    }
    return subjects;
  }

  void _setupTabController(int length) {
    final initialIndex = ref.read(coachScreenTabProvider);
    _tabController = TabController(
      initialIndex: initialIndex < length ? initialIndex : 0,
      length: length,
      vsync: this,
    );
    _tabController!.addListener(() {
      if (_tabController!.indexIsChanging) {
        ref.read(coachScreenTabProvider.notifier).state =
            _tabController!.index;
      }
    });
  }

  void _showGalaxyGuide(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const _GalaxyGuideDialog(),
    );
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userProfileAsync = ref.watch(userProfileProvider);
    final performanceAsync = ref.watch(performanceProvider);

    return userProfileAsync.when(
      data: (user) {
        if (user == null || user.selectedExam == null) {
          return Scaffold(
              appBar: AppBar(title: const Text('Bilgi Galaksisi')),
              body: const Center(
                  child: Text('Lütfen önce profilden bir sınav seçin.')));
        }

        final examType = ExamType.values.byName(user.selectedExam!);

        return FutureBuilder<Exam>(
          future: ExamData.getExamByType(examType),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Scaffold(
                  appBar: AppBar(title: const Text('Bilgi Galaksisi')),
                  body: const Center(
                      child: CircularProgressIndicator(
                          color: AppTheme.secondaryColor)));
            }
            if (snapshot.hasError) {
              return Scaffold(
                  appBar: AppBar(title: const Text('Bilgi Galaksisi')),
                  body: Center(
                      child: Text(
                          'Sınav verileri yüklenemedi: ${snapshot.error}')));
            }
            if (!snapshot.hasData) {
              return Scaffold(
                  appBar: AppBar(title: const Text('Bilgi Galaksisi')),
                  body:
                  const Center(child: Text('Sınav verisi bulunamadı.')));
            }

            final exam = snapshot.data!;
            final subjects = _getRelevantSubjects(user, exam);

            if (subjects.isEmpty) {
              return Scaffold(
                  appBar: AppBar(title: const Text('Bilgi Galaksisi')),
                  body: const Center(
                      child: Text('Bu sınav için konu bulunamadı.')));
            }

            if (_tabController == null ||
                _tabController!.length != subjects.length) {
              _setupTabController(subjects.length);
              _appliedInitialSubject = false;
            }
            if (!_appliedInitialSubject && widget.initialSubject != null && widget.initialSubject!.trim().isNotEmpty && _tabController != null) {
              final keys = subjects.keys.toList();
              final idx = keys.indexWhere((s) => s.toLowerCase() == widget.initialSubject!.toLowerCase());
              if (idx != -1 && idx < _tabController!.length) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted && _tabController != null) {
                    _tabController!.index = idx;
                  }
                });
              }
              _appliedInitialSubject = true;
            }
            return Scaffold(
                appBar: AppBar(
                  title: const Text('Bilgi Galaksisi'),
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.info_outline_rounded),
                      tooltip: "Rehber",
                      onPressed: () => _showGalaxyGuide(context),
                    ),
                  ],
                  bottom: TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    tabs: subjects.keys
                        .map((subjectName) => Tab(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 140),
                        child: Text(
                          subjectName,
                          overflow: TextOverflow.ellipsis,
                          softWrap: false,
                        ),
                      ),
                    ))
                        .toList(),
                  ),
                ),
                body: performanceAsync.when(
                  data: (performance) => TabBarView(
                    controller: _tabController,
                    children: subjects.entries.map((entry) {
                      final subjectName = entry.key;
                      final topics = entry.value;
                      return _SubjectGalaxyView(
                        key: ValueKey(subjectName),
                        user: user,
                        exam: exam,
                        subjectName: subjectName,
                        topics: topics,
                        performanceSummary: performance ?? const PerformanceSummary(),
                      );
                    }).toList(),
                  ),
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e,s) => Center(child: Text("Performans verisi yüklenemedi: $e")),
                )
            );
          },
        );
      },
      loading: () => Scaffold(
          appBar: AppBar(title: const Text('Bilgi Galaksisi')),
          body: const Center(
              child:
              CircularProgressIndicator(color: AppTheme.secondaryColor))),
      error: (e, s) => Scaffold(
          appBar: AppBar(title: const Text('Bilgi Galaksisi')),
          body:
          Center(child: Text('Veriler yüklenirken bir hata oluştu: $e'))),
    );
  }
}

class _SubjectGalaxyView extends ConsumerStatefulWidget {
  final UserModel user;
  final Exam exam;
  final String subjectName;
  final List<SubjectTopic> topics;
  final PerformanceSummary performanceSummary;
  const _SubjectGalaxyView({super.key, required this.user, required this.exam, required this.subjectName, required this.topics, required this.performanceSummary});
  @override
  ConsumerState<_SubjectGalaxyView> createState() => _SubjectGalaxyViewState();
}

class _SubjectGalaxyViewState extends ConsumerState<_SubjectGalaxyView> {
  final TextEditingController _searchCtrl = TextEditingController();
  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final subjectName = widget.subjectName;
    final firestoreService = ref.read(firestoreServiceProvider);
    final sanitizedSubjectName = firestoreService.sanitizeKey(subjectName);
    final performances = widget.performanceSummary.topicPerformances[sanitizedSubjectName] ?? {};
    int totalQuestions = 0, totalCorrect = 0, totalWrong = 0;
    final relevantSection = widget.exam.sections.firstWhere((s) => s.subjects.containsKey(subjectName), orElse: () => widget.exam.sections.first);
    final penaltyCoefficient = relevantSection.penaltyCoefficient;
    performances.forEach((_, v){ totalQuestions += v.questionCount; totalCorrect += v.correctCount; totalWrong += v.wrongCount; });
    final overallNet = totalCorrect - (totalWrong * penaltyCoefficient);
    final double overallMastery = totalQuestions==0 ? 0.0 : ((overallNet/totalQuestions).clamp(0.0,1.0));
    final auraColor = Color.lerp(AppTheme.accentColor, AppTheme.successColor, overallMastery)!.withOpacity(0.12);
    final viewMode = ref.watch(subjectViewModeProvider(subjectName));
    final filter = ref.watch(subjectFilterProvider(subjectName));
    final processed = widget.topics.map((t){
      final perf = performances[firestoreService.sanitizeKey(t.name)] ?? TopicPerformanceModel();
      final net = perf.correctCount - (perf.wrongCount * penaltyCoefficient);
      final double mastery = perf.questionCount < 5 ? -1.0 : ((net / perf.questionCount).clamp(0.0,1.0));
      return _TopicBundle(topic: t, performance: perf, mastery: mastery);
    }).where((e)=> filter.isEmpty || e.topic.name.toLowerCase().contains(filter.toLowerCase())).toList()
      ..sort((a,b)=> (a.mastery<0?2:a.mastery).compareTo(b.mastery<0?2:b.mastery));

    Widget buildGrid()=> LayoutBuilder(builder:(c,constraints){
      final crossAxisCount = (constraints.maxWidth/170).floor().clamp(1,6);
      return GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 2.6,
        ),
        itemCount: processed.length,
        itemBuilder:(c,i){ final e=processed[i]; return MasteryTopicBubble(
          topic:e.topic,
          performance:e.performance,
          penaltyCoefficient: penaltyCoefficient,
          onTap: ()=> context.go('/coach/update-topic-performance', extra:{'subject': subjectName,'topic': e.topic.name,'performance': e.performance}),
          onLongPress: ()=> _showTopicStats(e),
          compact: true,
        );},
      );
    });

    Widget buildList()=> ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: processed.length,
      separatorBuilder: (_,__)=> const SizedBox(height:12),
      itemBuilder: (c,i){ final e=processed[i]; final masteryPercent = e.mastery<0 ? '—' : '%${(e.mastery*100).toStringAsFixed(0)}'; return InkWell(
        onTap: ()=> context.go('/coach/update-topic-performance', extra:{'subject': subjectName,'topic': e.topic.name,'performance': e.performance}),
        onLongPress: ()=> _showTopicStats(e),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: AppTheme.lightSurfaceColor.withOpacity(0.35),
            border: Border.all(color: AppTheme.lightSurfaceColor.withOpacity(0.55), width: 1),
          ),
          child: Row(children:[ Expanded(child: Text(e.topic.name, style: const TextStyle(fontWeight: FontWeight.w600))), _MasteryPill(mastery: e.mastery), const SizedBox(width:12), Text(masteryPercent, style: const TextStyle(color: AppTheme.secondaryTextColor)) ]),
        ),
      );},
    );

    final content = switch(viewMode){ GalaxyViewMode.grid=>buildGrid(), GalaxyViewMode.list=>buildList() };
    return Container(
      decoration: BoxDecoration(
        gradient: RadialGradient(center: Alignment.center, radius: 1, colors: [auraColor, Colors.transparent], stops: const [0,1]),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20,20,20,110),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children:[
          _SubjectStatsCard(subjectName: subjectName, overallMastery: overallMastery, totalQuestions: totalQuestions, totalCorrect: totalCorrect, totalWrong: totalWrong),
          const SizedBox(height:16),
          _GalaxyToolbar(controller: _searchCtrl, onChanged: (v)=> ref.read(subjectFilterProvider(subjectName).notifier).state = v, currentMode: viewMode, onModeChanged: (m)=> ref.read(subjectViewModeProvider(subjectName).notifier).state = m),
          const SizedBox(height:12),
          const _ColorLegend(),
          const SizedBox(height:20),
          content.animate().fadeIn(duration:500.ms, delay:200.ms),
        ]),
      ),
    );
  }

  void _showTopicStats(_TopicBundle e){
    showDialog(context: context, builder: (_)=> TopicStatsDialog(topicName: e.topic.name, performance: e.performance, mastery: e.mastery));
  }
}

class _TopicBundle { final SubjectTopic topic; final TopicPerformanceModel performance; final double mastery; _TopicBundle({required this.topic, required this.performance, required this.mastery}); }

class _SubjectStatsCard extends StatelessWidget {
  final String subjectName; final double overallMastery; final int totalQuestions; final int totalCorrect; final int totalWrong;
  const _SubjectStatsCard({required this.subjectName, required this.overallMastery, required this.totalQuestions, required this.totalCorrect, required this.totalWrong});
  @override
  Widget build(BuildContext context) {
    final masteryPercent = (overallMastery*100).toStringAsFixed(0);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [AppTheme.lightSurfaceColor.withOpacity(0.55), AppTheme.lightSurfaceColor.withOpacity(0.25)]),
        border: Border.all(color: Colors.white.withOpacity(0.06), width: 1),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children:[
        Row(children:[
          Expanded(
            child: Text(
              subjectName,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 12),
          _MasteryPill(mastery: overallMastery)
        ]),
        const SizedBox(height:8),
        Text('Genel net hakimiyet: %$masteryPercent', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppTheme.secondaryTextColor)),
        const SizedBox(height:14),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            height: 14,
            child: Stack(children: [
              Container(color: AppTheme.lightSurfaceColor.withOpacity(0.4)),
              FractionallySizedBox(
                widthFactor: overallMastery,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [AppTheme.accentColor, AppTheme.successColor]),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ]),
          ),
        ),
        const SizedBox(height:14),
        Row(children:[ _StatChip(label:'Soru', value: totalQuestions.toString()), const SizedBox(width:8), _StatChip(label:'Doğru', value: totalCorrect.toString(), color: AppTheme.successColor), const SizedBox(width:8), _StatChip(label:'Yanlış', value: totalWrong.toString(), color: AppTheme.accentColor) ])
      ]),
    );
  }
}

class _StatChip extends StatelessWidget { final String label; final String value; final Color? color; const _StatChip({required this.label, required this.value, this.color}); @override Widget build(BuildContext context){ final c = color ?? AppTheme.secondaryColor; return Container(padding: const EdgeInsets.symmetric(horizontal:12, vertical:8), decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), color: c.withOpacity(0.18), border: Border.all(color: c.withOpacity(0.6), width:1)), child: Row(children:[ Text(label, style: const TextStyle(fontSize:12, color: AppTheme.secondaryTextColor)), const SizedBox(width:6), Text(value, style: const TextStyle(fontWeight: FontWeight.bold)) ])); }}
class _GalaxyToolbar extends StatelessWidget {
  final TextEditingController controller; final ValueChanged<String> onChanged; final GalaxyViewMode currentMode; final ValueChanged<GalaxyViewMode> onModeChanged; const _GalaxyToolbar({required this.controller, required this.onChanged, required this.currentMode, required this.onModeChanged});
  @override
  Widget build(BuildContext context) {
    Widget modeChip(GalaxyViewMode m, IconData icon, String label){
      final active = currentMode==m;
      return InkWell(
        onTap: ()=> onModeChanged(m),
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds:180),
          padding: const EdgeInsets.symmetric(horizontal:14, vertical:8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: active? AppTheme.secondaryColor.withOpacity(0.25): AppTheme.lightSurfaceColor.withOpacity(0.20),
            border: Border.all(color: active? AppTheme.secondaryColor: AppTheme.lightSurfaceColor.withOpacity(0.55), width:1),
            boxShadow: active? [BoxShadow(color: AppTheme.secondaryColor.withOpacity(0.25), blurRadius:8, offset: const Offset(0,2))]:[],
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children:[ Icon(icon, size:18, color: active? AppTheme.secondaryColor: AppTheme.secondaryTextColor), const SizedBox(width:6), Text(label, style: TextStyle(fontSize:12, fontWeight: FontWeight.w600, color: active? AppTheme.secondaryColor: AppTheme.secondaryTextColor)) ]),
        ),
      );
    }
    return Row(children:[
      Expanded(
        child: TextField(
          controller: controller,
          onChanged: onChanged,
          decoration: InputDecoration(
            isDense:true,
            hintText:'Konu ara...',
            filled:true,
            fillColor: AppTheme.lightSurfaceColor.withOpacity(0.35),
            prefixIcon: const Icon(Icons.search,size:20),
            contentPadding: const EdgeInsets.symmetric(horizontal:14, vertical:10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
          ),
        ),
      ),
      const SizedBox(width:14),
      Container(
        padding: const EdgeInsets.symmetric(horizontal:10, vertical:6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: AppTheme.lightSurfaceColor.withOpacity(0.30),
          border: Border.all(color: AppTheme.lightSurfaceColor.withOpacity(0.50), width:1),
        ),
        child: Row(children:[
          modeChip(GalaxyViewMode.grid, Icons.grid_view_rounded, 'Izgara'),
          const SizedBox(width:8),
          modeChip(GalaxyViewMode.list, Icons.view_list_rounded, 'Liste'),
        ]),
      )
    ]);
  }
}

class _ColorLegend extends StatelessWidget { const _ColorLegend(); Color _c(double v){ if(v<0) return AppTheme.lightSurfaceColor; if(v<0.4) return AppTheme.accentColor; if(v<0.7) return AppTheme.secondaryColor; return AppTheme.successColor; } @override Widget build(BuildContext context){ final items=[{'t':'Yetersiz Veri','v':-1.0},{'t':'Zayıf','v':0.2},{'t':'Gelişiyor','v':0.55},{'t':'Güçlü','v':0.85}]; return Wrap(spacing:12, runSpacing:8, children: items.map((e)=> Container(padding: const EdgeInsets.symmetric(horizontal:10, vertical:6), decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), color: (_c(e['v'] as double)).withOpacity(0.18), border: Border.all(color: _c(e['v'] as double), width:1)), child: Row(mainAxisSize: MainAxisSize.min, children:[ Container(width:10,height:10, decoration: BoxDecoration(color: _c(e['v'] as double), shape: BoxShape.circle)), const SizedBox(width:6), Text(e['t'] as String, style: const TextStyle(fontSize:12, color: AppTheme.secondaryTextColor)) ]) )).toList()); }}

class _MasteryPill extends StatelessWidget { final double mastery; const _MasteryPill({super.key, required this.mastery}); @override Widget build(BuildContext context){ String txt; Color c; if(mastery<0){ txt='VERİ YOK'; c=AppTheme.lightSurfaceColor; } else if(mastery<0.4){ txt='%${(mastery*100).toStringAsFixed(0)}'; c=AppTheme.accentColor; } else if(mastery<0.7){ txt='%${(mastery*100).toStringAsFixed(0)}'; c=AppTheme.secondaryColor; } else { txt='%${(mastery*100).toStringAsFixed(0)}'; c=AppTheme.successColor; } return Container(padding: const EdgeInsets.symmetric(horizontal:12, vertical:6), decoration: BoxDecoration(borderRadius: BorderRadius.circular(30), color: c.withOpacity(0.22), border: Border.all(color:c,width:1)), child: Text(txt, style: const TextStyle(fontSize:12, fontWeight: FontWeight.bold))); }}
class _GalaxyGuideDialog extends StatelessWidget {
  const _GalaxyGuideDialog();
  @override
  Widget build(BuildContext context) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
      child: AlertDialog(
        backgroundColor: AppTheme.cardColor.withOpacity(0.95),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Row(
          children: [
            Icon(Icons.auto_awesome, color: AppTheme.secondaryColor),
            SizedBox(width: 12),
            Expanded(child: Text("Bilgi Galaksisi Rehberi")),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              _GuideDetailRow(
                icon: Icons.explore_rounded,
                title: "Galaksiyi Keşfet",
                subtitle: "Her ders bir sistem, her konu bir gezegen. Kişisel bilgi evrenini düzenli takip et.",
              ),
              _GuideDetailRow(
                icon: Icons.palette_rounded,
                title: "Gezegen Renkleri",
                subtitle: "Renk hakimiyet seviyeni gösterir. Kırmızı zayıf, sarı gelişiyor, yeşil güçlü.",
              ),
              _GuideDetailRow(
                icon: Icons.touch_app_rounded,
                title: "Hızlı Güncelle",
                subtitle: "Kısa dokunuşla son test doğru/yanlış girişini yap ve ilerlemeni anında güncelle.",
              ),
              _GuideDetailRow(
                icon: Icons.analytics_rounded,
                title: "Detaylı Analiz",
                subtitle: "Uzun basarak konu istatistikleri ve yapay zeka yorumunu aç.",
              ),
            ].animate(interval: 100.ms).fadeIn(duration: 500.ms).slideX(begin: 0.4),
          ),
        ),
        actions: [
          TextButton(onPressed: ()=> Navigator.of(context).pop(), child: const Text("Kapat")),
        ],
      ),
    );
  }
}

class _GuideDetailRow extends StatelessWidget {
  final IconData icon; final String title; final String subtitle;
  const _GuideDetailRow({required this.icon, required this.title, required this.subtitle});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18.0),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children:[
        Icon(icon, color: AppTheme.secondaryTextColor, size: 28),
        const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children:[
          Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(subtitle, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.secondaryTextColor, height: 1.35)),
        ])),
      ]),
    );
  }
}