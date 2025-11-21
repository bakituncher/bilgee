// lib/features/coach/screens/coach_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:taktik/data/providers/firestore_providers.dart';
import 'package:taktik/data/models/exam_model.dart';
import 'package:taktik/data/models/user_model.dart';
import 'package:taktik/data/models/topic_performance_model.dart';
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
    final auraColor = Color.lerp(Theme.of(context).colorScheme.error, Colors.green, overallMastery)!.withOpacity(0.12);
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
          index: i, // Staggered animasyon için index
        );},
      );
    });

    Widget buildList(){
      final isDark = Theme.of(context).brightness == Brightness.dark;
      
      return ListView.separated(
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        itemCount: processed.length,
        separatorBuilder: (_,__)=> const SizedBox(height:12),
        itemBuilder: (c,i){ 
          final e=processed[i]; 
          final masteryPercent = e.mastery<0 ? '—' : '%${(e.mastery*100).toStringAsFixed(0)}';
          
          return InkWell(
            onTap: ()=> context.go('/coach/update-topic-performance', extra:{'subject': subjectName,'topic': e.topic.name,'performance': e.performance}),
            onLongPress: ()=> _showTopicStats(e),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: isDark 
                  ? Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.35)
                  : Colors.white,
                border: Border.all(
                  color: isDark 
                    ? Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.55)
                    : Theme.of(context).colorScheme.onSurface.withOpacity(0.15), 
                  width: isDark ? 1 : 1.5
                ),
                boxShadow: isDark ? null : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(children:[ 
                Expanded(child: Text(e.topic.name, style: const TextStyle(fontWeight: FontWeight.w600))), 
                _MasteryPill(mastery: e.mastery), 
                const SizedBox(width:12), 
                Text(masteryPercent, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)) 
              ]),
            ),
          );
        },
      );
    }

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
    final isDark = theme.brightness == Brightness.dark;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: isDark 
          ? theme.colorScheme.surfaceContainerHighest.withOpacity(0.5)
          : Colors.white,
        border: Border.all(
          color: isDark 
            ? theme.colorScheme.onSurface.withOpacity(0.1)
            : theme.colorScheme.onSurface.withOpacity(0.15), 
          width: isDark ? 1 : 1.5
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: isDark ? 20 : 12,
            spreadRadius: isDark ? -10 : 0,
            offset: isDark ? const Offset(0, 10) : const Offset(0, 4),
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
                  style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface),
                ),
                const SizedBox(height: 4),
                Text('Genel Hakimiyet: %$masteryPercent', style: theme.textTheme.titleMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
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
              Container(color: Theme.of(context).colorScheme.surfaceContainerHighest),
              FractionallySizedBox(
                widthFactor: overallMastery,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [Theme.of(context).colorScheme.error, Colors.green]),
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
          Expanded(child: _StatChip(label:'Doğru', value: totalCorrect.toString(), color: Colors.green)),
          const SizedBox(width:10),
          Expanded(child: _StatChip(label:'Yanlış', value: totalWrong.toString(), color: Theme.of(context).colorScheme.error))
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
    final c = color ?? Theme.of(context).colorScheme.onSurfaceVariant;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = color ?? Theme.of(context).colorScheme.surfaceContainerHighest;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: bgColor.withOpacity(isDark ? 0.15 : 0.12),
        border: Border.all(
          color: bgColor.withOpacity(isDark ? 0.4 : 0.5), 
          width: isDark ? 1 : 1.5
        ),
      ),
      child: Column(
        children: [
          Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color ?? Theme.of(context).colorScheme.onSurface)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 12, color: c.withOpacity(0.8))),
        ],
      ),
    );
  }
}

class _GalaxyToolbar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final GalaxyViewMode currentMode;
  final ValueChanged<GalaxyViewMode> onModeChanged;

  const _GalaxyToolbar({
    required this.controller,
    required this.onChanged,
    required this.currentMode,
    required this.onModeChanged
  });

  double _calculateFontSize(BuildContext context, String text, double maxWidth) {
    const minFontSize = 11.0;
    const maxFontSize = 14.0;

    // TextPainter ile metin genişliğini hesapla
    for (double fontSize = maxFontSize; fontSize >= minFontSize; fontSize -= 0.5) {
      final textPainter = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(fontSize: fontSize),
        ),
        maxLines: 1,
        textDirection: TextDirection.ltr,
      )..layout();

      if (textPainter.width <= maxWidth) {
        return fontSize;
      }
    }

    return minFontSize;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    Widget modeChip(GalaxyViewMode m, IconData icon, String label){
      final active = currentMode==m;
      final color = active ? Theme.of(context).colorScheme.onPrimary : Theme.of(context).colorScheme.onSurfaceVariant;
      return InkWell(
        onTap: ()=> onModeChanged(m),
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal:16, vertical:10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: active 
              ? Theme.of(context).colorScheme.primary 
              : (isDark 
                  ? Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5)
                  : Colors.white),
            border: Border.all(
              color: active 
                ? Theme.of(context).colorScheme.primary 
                : Theme.of(context).colorScheme.onSurface.withOpacity(isDark ? 0.1 : 0.2), 
              width: isDark ? 1 : 1.5
            ),
            boxShadow: (!active && !isDark) ? [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ] : null,
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
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Dinamik hint text boyutu hesaplama
            final availableWidth = constraints.maxWidth - 70; // prefixIcon + padding için alan
            final hintText = 'Ara...';
            final fontSize = _calculateFontSize(context, hintText, availableWidth);

            return TextField(
              controller: controller,
              onChanged: onChanged,
              style: TextStyle(fontSize: fontSize),
              decoration: InputDecoration(
                isDense:true,
                hintText: hintText,
                filled:true,
                fillColor: isDark
                  ? Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5)
                  : Colors.white,
                prefixIcon: Icon(Icons.search, size: 20, color: Theme.of(context).colorScheme.onSurfaceVariant),
                hintStyle: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: fontSize,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(isDark ? 0.1 : 0.2),
                    width: isDark ? 1 : 1.5
                  )
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(isDark ? 0.1 : 0.2),
                    width: isDark ? 1 : 1.5
                  )
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2)
                ),
              ),
            );
          }
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (mastery < 0) {
      txt = 'N/A';
      level = 'Veri Yok';
      c = Theme.of(context).colorScheme.surfaceContainerHighest;
    } else if (mastery < 0.4) {
      txt = '%${(mastery * 100).toStringAsFixed(0)}';
      level = 'Zayıf';
      c = Theme.of(context).colorScheme.error;
    } else if (mastery < 0.7) {
      txt = '%${(mastery * 100).toStringAsFixed(0)}';
      level = 'Gelişiyor';
      c = Theme.of(context).colorScheme.primary;
    } else {
      txt = '%${(mastery * 100).toStringAsFixed(0)}';
      level = 'Güçlü';
      c = Colors.green;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        color: c.withOpacity(isDark ? 0.15 : 0.12),
        border: Border.all(
          color: c.withOpacity(isDark ? 0.7 : 0.8), 
          width: isDark ? 1 : 1.5
        ),
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