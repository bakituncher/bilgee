// lib/features/coach/screens/coach_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:taktik/data/providers/firestore_providers.dart';
import 'package:taktik/data/models/exam_model.dart';
import 'package:taktik/data/models/user_model.dart';
import 'package:taktik/data/models/topic_performance_model.dart';
import 'package:taktik/core/theme/app_theme.dart';
import 'package:taktik/features/coach/widgets/mastery_topic_bubble.dart';
import 'package:taktik/features/coach/widgets/topic_stats_dialog.dart';
import 'package:taktik/core/utils/exam_utils.dart';
import 'package:taktik/data/models/performance_summary.dart';
import 'package:taktik/shared/widgets/logo_loader.dart';

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
              appBar: AppBar(title: const Text('Ders Netlerim')),
              body: const Center(
                  child: Text('Lütfen önce profilden bir sınav seçin.')));
        }

        final examType = ExamType.values.byName(user.selectedExam!);

        return FutureBuilder<Exam>(
          future: ExamData.getExamByType(examType),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Scaffold(
                  appBar: AppBar(title: const Text('Ders Netlerim')),
                  body: const LogoLoader());
            }
            if (snapshot.hasError) {
              return Scaffold(
                  appBar: AppBar(title: const Text('Ders Netlerim')),
                  body: Center(
                      child: Text(
                          'Sınav verileri yüklenemedi: ${snapshot.error}')));
            }
            if (!snapshot.hasData) {
              return Scaffold(
                  appBar: AppBar(title: const Text('Ders Netlerim')),
                  body:
                  const Center(child: Text('Sınav verisi bulunamadı.')));
            }

            final exam = snapshot.data!;
            final subjects = _getRelevantSubjects(user, exam);

            if (subjects.isEmpty) {
              return Scaffold(
                  appBar: AppBar(title: const Text('Ders Netlerim')),
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
                  title: const Text('Ders Netlerim'),
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
                  loading: () => const LogoLoader(),
                  error: (e,s) => Center(child: Text("Performans verisi yüklenemedi: $e")),
                )
            );
          },
        );
      },
      loading: () => Scaffold(
          appBar: AppBar(title: const Text('Ders Netlerim')),
          body: const LogoLoader()),
      error: (e, s) => Scaffold(
          appBar: AppBar(title: const Text('Ders Netlerim')),
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
          childAspectRatio: 2.8,
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
          const SizedBox(height:24),
          _GalaxyToolbar(controller: _searchCtrl, onChanged: (v)=> ref.read(subjectFilterProvider(subjectName).notifier).state = v, currentMode: viewMode, onModeChanged: (m)=> ref.read(subjectViewModeProvider(subjectName).notifier).state = m),
          const SizedBox(height:24),
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
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: AppTheme.lightSurfaceColor.withOpacity(0.5),
        border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            spreadRadius: -10,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children:[
        Row(crossAxisAlignment: CrossAxisAlignment.start, children:[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  subjectName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 4),
                Text('Genel Hakimiyet: %$masteryPercent', style: theme.textTheme.titleMedium?.copyWith(color: AppTheme.secondaryTextColor)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _MasteryPill(mastery: overallMastery)
        ]),
        const SizedBox(height:16),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            height: 12,
            child: Stack(children: [
              Container(color: AppTheme.lightSurfaceColor),
              FractionallySizedBox(
                widthFactor: overallMastery,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [AppTheme.accentColor, AppTheme.successColor]),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ]),
          ),
        ),
        const SizedBox(height:16),
        Row(children:[
          Expanded(child: _StatChip(label:'Soru', value: totalQuestions.toString())),
          const SizedBox(width:10),
          Expanded(child: _StatChip(label:'Doğru', value: totalCorrect.toString(), color: AppTheme.successColor)),
          const SizedBox(width:10),
          Expanded(child: _StatChip(label:'Yanlış', value: totalWrong.toString(), color: AppTheme.accentColor))
        ])
      ]),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  const _StatChip({required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppTheme.secondaryTextColor;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: (color ?? AppTheme.lightSurfaceColor).withOpacity(0.15),
        border: Border.all(color: (color ?? AppTheme.lightSurfaceColor).withOpacity(0.4), width: 1),
      ),
      child: Column(
        children: [
          Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color ?? Colors.white)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 12, color: c.withOpacity(0.8))),
        ],
      ),
    );
  }
}

class _GalaxyToolbar extends StatelessWidget {
  final TextEditingController controller; final ValueChanged<String> onChanged; final GalaxyViewMode currentMode; final ValueChanged<GalaxyViewMode> onModeChanged; const _GalaxyToolbar({required this.controller, required this.onChanged, required this.currentMode, required this.onModeChanged});
  @override
  Widget build(BuildContext context) {
    Widget modeChip(GalaxyViewMode m, IconData icon, String label){
      final active = currentMode==m;
      final color = active ? AppTheme.primaryColor : AppTheme.secondaryTextColor;
      return InkWell(
        onTap: ()=> onModeChanged(m),
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal:16, vertical:10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: active ? AppTheme.secondaryColor : AppTheme.lightSurfaceColor.withOpacity(0.5),
            border: Border.all(color: active ? AppTheme.secondaryColor : Colors.white.withOpacity(0.1), width: 1),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children:[
            Icon(icon, size:18, color: color),
            const SizedBox(width:8),
            Text(label, style: TextStyle(fontSize:13, fontWeight: FontWeight.w600, color: color))
          ]),
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
            hintText:'Konu Ara...',
            filled:true,
            fillColor: AppTheme.lightSurfaceColor.withOpacity(0.5),
            prefixIcon: const Icon(Icons.search, size: 20, color: AppTheme.secondaryTextColor),
            hintStyle: const TextStyle(color: AppTheme.secondaryTextColor),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.white.withOpacity(0.1))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.white.withOpacity(0.1))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppTheme.secondaryColor, width: 1.5)),
          ),
        ),
      ),
      const SizedBox(width:12),
      modeChip(GalaxyViewMode.grid, Icons.grid_view_rounded, 'Izgara'),
      const SizedBox(width:8),
      modeChip(GalaxyViewMode.list, Icons.view_list_rounded, 'Liste'),
    ]);
  }
}

class _MasteryPill extends StatelessWidget {
  final double mastery;
  const _MasteryPill({required this.mastery});

  @override
  Widget build(BuildContext context) {
    String txt;
    Color c;
    String level;

    if (mastery < 0) {
      txt = 'N/A';
      level = 'Veri Yok';
      c = AppTheme.lightSurfaceColor;
    } else if (mastery < 0.4) {
      txt = '%${(mastery * 100).toStringAsFixed(0)}';
      level = 'Zayıf';
      c = AppTheme.accentColor;
    } else if (mastery < 0.7) {
      txt = '%${(mastery * 100).toStringAsFixed(0)}';
      level = 'Gelişiyor';
      c = AppTheme.secondaryColor;
    } else {
      txt = '%${(mastery * 100).toStringAsFixed(0)}';
      level = 'Güçlü';
      c = AppTheme.successColor;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        color: c.withOpacity(0.15),
        border: Border.all(color: c.withOpacity(0.7), width: 1),
      ),
      child: Column(
        children: [
          Text(txt, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: c)),
          const SizedBox(height: 2),
          Text(level, style: TextStyle(fontSize: 10, color: c.withOpacity(0.9))),
        ],
      ),
    );
  }
}