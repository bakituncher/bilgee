// lib/features/coach/screens/coach_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
final subjectSearchActiveProvider = StateProvider.family<bool, String>((ref, subject) => false);

class CoachScreen extends ConsumerStatefulWidget {
  final String? initialSubject;
  const CoachScreen({super.key, this.initialSubject});

  @override
  ConsumerState<CoachScreen> createState() => _CoachScreenState();
}

class _CoachScreenState extends ConsumerState<CoachScreen>
    with TickerProviderStateMixin {
  TabController? _tabController;
  String? _lastAppliedSubject;

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

  String _normalize(String v) {
    final lower = v.trim().toLowerCase();
    return lower
        .replaceAll('ı', 'i')
        .replaceAll('İ', 'i')
        .replaceAll('ö', 'o')
        .replaceAll('Ö', 'o')
        .replaceAll('ü', 'u')
        .replaceAll('Ü', 'u')
        .replaceAll('ş', 's')
        .replaceAll('Ş', 's')
        .replaceAll('ğ', 'g')
        .replaceAll('Ğ', 'g')
        .replaceAll('ç', 'c')
        .replaceAll('Ç', 'c');
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

  void _applyInitialSubjectIfNeeded(List<String> keys) {
    final incoming = widget.initialSubject;
    if (incoming == null || incoming.trim().isEmpty || _tabController == null) return;
    final normalizedIncoming = _normalize(incoming);
    // Eğer aynı subject zaten uygulanmışsa tekrar deneme
    if (_lastAppliedSubject != null && _normalize(_lastAppliedSubject!) == normalizedIncoming) return;

    final idx = keys.indexWhere((s) => _normalize(s) == normalizedIncoming);
    if (idx != -1 && idx < _tabController!.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _tabController == null) return;
        _tabController!.index = idx;
        ref.read(coachScreenTabProvider.notifier).state = idx; // provider senkron
        _lastAppliedSubject = incoming; // kaydet
      });
    } else {
      _lastAppliedSubject = incoming; // başarısız da olsa kaydediyoruz, tekrar denemesin
    }
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
              _lastAppliedSubject = null; // uzunluk değiştiğinde yeni subject uygulanabilir
            }
            final keys = subjects.keys.toList();
            _applyInitialSubjectIfNeeded(keys);
            return Scaffold(
                resizeToAvoidBottomInset: false,
                appBar: AppBar(
                  title: Text(
                    'Ders Netlerim',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: Theme.of(context).colorScheme.onSurface,
                      letterSpacing: -0.5,
                      fontSize: 20,
                    ),
                  ),
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
  final FocusNode _searchFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    // Widget oluşturulduğunda filtreyi temizle
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(subjectFilterProvider(widget.subjectName).notifier).state = '';
        ref.read(subjectSearchActiveProvider(widget.subjectName).notifier).state = false;
        _searchCtrl.clear();
        _showInstructionsIfNeeded();
      }
    });
  }

  Future<void> _showInstructionsIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    const key = 'coach_screen_instructions_shown';
    final hasShown = prefs.getBool(key) ?? false;

    if (!hasShown && mounted) {
      await prefs.setBool(key, true);
      _showInstructionsBottomSheet();
    }
  }

  void _showInstructionsBottomSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.onSurface.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Icon(
                Icons.touch_app_rounded,
                size: 48,
                color: colorScheme.primary,
              ),
              const SizedBox(height: 20),
              Text(
                'Bir konuya dokunarak test ekleme ekranına gidebilirsiniz.',
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Bir konuya basılı tutarak o konunun detaylı istatistiklerini görebilirsiniz.',
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => Navigator.pop(context),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Anladım'),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final subjectName = widget.subjectName;
    final isSearchActive = ref.watch(subjectSearchActiveProvider(subjectName));
    final firestoreService = ref.read(firestoreServiceProvider);
    final sanitizedSubjectName = firestoreService.sanitizeKey(subjectName);
    final performances = widget.performanceSummary.topicPerformances[sanitizedSubjectName] ?? {};
    int totalQuestions = 0, totalCorrect = 0, totalWrong = 0, totalBlank = 0;
    final relevantSection = widget.exam.sections.firstWhere((s) => s.subjects.containsKey(subjectName), orElse: () => widget.exam.sections.first);
    final penaltyCoefficient = relevantSection.penaltyCoefficient;
    performances.forEach((_, v){ totalQuestions += v.questionCount; totalCorrect += v.correctCount; totalWrong += v.wrongCount; totalBlank += v.blankCount; });
    final overallNet = totalCorrect - (totalWrong * penaltyCoefficient);
    final double overallMastery = totalQuestions==0 ? 0.0 : ((overallNet/totalQuestions).clamp(0.0,1.0));

    // Arka plan rengi - veri yoksa şeffaf, varsa yumuşak geçiş
    final auraColor = totalQuestions == 0
        ? Colors.transparent
        : Color.lerp(
            Theme.of(context).colorScheme.primary.withAlpha(30), // Daha nötr başlangıç
            Colors.green.withAlpha(30), // Daha yumuşak yeşil
            overallMastery,
          )!;

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
      // Minimum 2 kolon, maksimum kart genişliği 160px
      final crossAxisCount = (constraints.maxWidth / 160).floor().clamp(2, 6);
      // Dinamik aspect ratio hesaplama - kart yüksekliği yaklaşık 55-60px olacak şekilde
      final itemWidth = (constraints.maxWidth - (16 * (crossAxisCount - 1))) / crossAxisCount;
      final childAspectRatio = (itemWidth / 58).clamp(2.2, 3.5);

      return GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: childAspectRatio,
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

          return InkWell(
            onTap: ()=> context.go('/coach/update-topic-performance', extra:{'subject': subjectName,'topic': e.topic.name,'performance': e.performance}),
            onLongPress: ()=> _showTopicStats(e),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  colors: isDark
                    ? [
                        Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.25),
                        Theme.of(context).colorScheme.surfaceContainer.withOpacity(0.15),
                      ]
                    : [
                        Colors.white,
                        Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.05),
                      ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(
                  color: isDark 
                    ? Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5)
                    : Theme.of(context).colorScheme.onSurface.withOpacity(0.12),
                  width: isDark ? 1 : 1.5
                ),
                boxShadow: isDark ? null : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(children:[ 
                Expanded(child: Text(e.topic.name, style: const TextStyle(fontWeight: FontWeight.w600))),
                _MasteryPill(mastery: e.mastery),
              ]),
            ),
          );
        },
      );
    }

    final content = switch(viewMode){ GalaxyViewMode.grid=>buildGrid(), GalaxyViewMode.list=>buildList() };
    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(center: Alignment.center, radius: 1, colors: [auraColor, Colors.transparent], stops: const [0,1]),
          ),
          child: GestureDetector(
            onTap: () {
              FocusScope.of(context).unfocus();
              if (isSearchActive && _searchCtrl.text.isEmpty) {
                ref.read(subjectSearchActiveProvider(subjectName).notifier).state = false;
              }
            },
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(20,20,20,110),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children:[
                _SubjectStatsCard(subjectName: subjectName, overallMastery: overallMastery, totalQuestions: totalQuestions, totalCorrect: totalCorrect, totalWrong: totalWrong, totalBlank: totalBlank),
                const SizedBox(height:20),
                _GalaxyToolbar(
                  isSearchActive: isSearchActive,
                  onSearchToggle: () {
                    final newState = !isSearchActive;
                    ref.read(subjectSearchActiveProvider(subjectName).notifier).state = newState;
                    if (newState) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) _searchFocus.requestFocus();
                      });
                    } else {
                      _searchCtrl.clear();
                      ref.read(subjectFilterProvider(subjectName).notifier).state = '';
                      FocusScope.of(context).unfocus();
                    }
                  },
                  currentMode: viewMode,
                  onModeChanged: (m)=> ref.read(subjectViewModeProvider(subjectName).notifier).state = m
                ),
                const SizedBox(height:24),
                content.animate().fadeIn(duration:500.ms, delay:200.ms),
              ]),
            ),
          ),
        ),
        // Üstte açılan arama çubuğu
        if (isSearchActive)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _SearchBar(
              controller: _searchCtrl,
              focusNode: _searchFocus,
              onChanged: (v) => ref.read(subjectFilterProvider(subjectName).notifier).state = v,
              onClose: () {
                ref.read(subjectSearchActiveProvider(subjectName).notifier).state = false;
                _searchCtrl.clear();
                ref.read(subjectFilterProvider(subjectName).notifier).state = '';
                FocusScope.of(context).unfocus();
              },
            ).animate().slideY(
              begin: -1,
              end: 0,
              duration: 300.ms,
              curve: Curves.easeOutCubic,
            ).fadeIn(duration: 200.ms),
          ),
      ],
    );
  }

  void _showTopicStats(_TopicBundle e){
    showDialog(context: context, builder: (_)=> TopicStatsDialog(topicName: e.topic.name, performance: e.performance, mastery: e.mastery));
  }
}

class _TopicBundle { final SubjectTopic topic; final TopicPerformanceModel performance; final double mastery; _TopicBundle({required this.topic, required this.performance, required this.mastery}); }


class _SubjectStatsCard extends StatelessWidget {
  final String subjectName; final double overallMastery; final int totalQuestions; final int totalCorrect; final int totalWrong; final int totalBlank;
  const _SubjectStatsCard({required this.subjectName, required this.overallMastery, required this.totalQuestions, required this.totalCorrect, required this.totalWrong, required this.totalBlank});
  @override
  Widget build(BuildContext context) {
    final masteryPercent = (overallMastery*100).toStringAsFixed(0);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    // Hakimiyet rengi
    final masteryColor = overallMastery < 0.4
      ? theme.colorScheme.error
      : (overallMastery < 0.7 ? theme.colorScheme.primary : Colors.green);

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
        // Başlık ve istatistikler
        Row(crossAxisAlignment: CrossAxisAlignment.center, children:[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    subjectName,
                    maxLines: 1,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Kompakt istatistikler
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: theme.colorScheme.surfaceContainerHighest.withOpacity(isDark ? 0.3 : 0.5),
                    border: Border.all(
                      color: theme.colorScheme.onSurface.withOpacity(isDark ? 0.08 : 0.1),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _CompactStat(
                          icon: Icons.quiz_rounded,
                          value: '$totalQuestions',
                          label: 'soru çözdün',
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 40,
                        color: theme.colorScheme.onSurface.withOpacity(0.1),
                      ),
                      Expanded(
                        child: _CompactStat(
                          icon: Icons.percent_rounded,
                          value: masteryPercent,
                          label: 'hakimsin',
                          color: masteryColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ]),
        const SizedBox(height:16),
        // Progress bar
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            height: 8,
            child: Stack(children: [
              Container(color: theme.colorScheme.surfaceContainerHighest),
              FractionallySizedBox(
                widthFactor: overallMastery,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [theme.colorScheme.error, Colors.green]
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ]),
          ),
        ),
        const SizedBox(height:16),
        // Doğru, Yanlış, Boş
        Row(children:[
          Expanded(child: _StatChip(label:'Doğru', value: totalCorrect.toString(), color: Colors.green, icon: Icons.check_circle_rounded)),
          const SizedBox(width:12),
          Expanded(child: _StatChip(label:'Yanlış', value: totalWrong.toString(), color: theme.colorScheme.error, icon: Icons.cancel_rounded)),
          const SizedBox(width:12),
          Expanded(child: _StatChip(label:'Boş', value: totalBlank.toString(), color: Colors.orange, icon: Icons.radio_button_unchecked_rounded)),
        ]),
      ]),
    );
  }
}

class _CompactStat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _CompactStat({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
                height: 1.1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            height: 1.1,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  final IconData? icon;
  const _StatChip({required this.label, required this.value, this.color, this.icon});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = color ?? theme.colorScheme.primary;

    // Gradient colors
    final gradientStart = isDark
        ? primaryColor.withOpacity(0.25)
        : primaryColor.withOpacity(0.15);
    final gradientEnd = isDark
        ? primaryColor.withOpacity(0.08)
        : primaryColor.withOpacity(0.05);

    // Değer uzunluğuna göre font boyutunu ayarla
    final valueFontSize = value.length > 4 ? 20.0 : (value.length > 3 ? 22.0 : 26.0);

    return Container(
      constraints: const BoxConstraints(
        minHeight: 110, // Minimum yükseklik
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [gradientStart, gradientEnd],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: primaryColor.withOpacity(isDark ? 0.35 : 0.25),
          width: 1.5,
        ),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: primaryColor.withOpacity(0.12),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          if (isDark)
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              color: primaryColor,
              size: 24,
            ),
            const SizedBox(height: 8),
          ],
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: TextStyle(
                  fontSize: valueFontSize,
                  fontWeight: FontWeight.w800,
                  color: primaryColor,
                  letterSpacing: -0.5,
                  height: 1,
                ),
                maxLines: 1,
                overflow: TextOverflow.visible,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface.withOpacity(0.7),
              letterSpacing: 0.3,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _GalaxyToolbar extends StatelessWidget {
  final bool isSearchActive;
  final VoidCallback onSearchToggle;
  final GalaxyViewMode currentMode;
  final ValueChanged<GalaxyViewMode> onModeChanged;

  const _GalaxyToolbar({
    required this.isSearchActive,
    required this.onSearchToggle,
    required this.currentMode,
    required this.onModeChanged
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const chipHeight = 48.0;

    Widget modeChip(GalaxyViewMode m, IconData icon, String label){
      final active = currentMode==m;
      final color = active ? Theme.of(context).colorScheme.onPrimary : Theme.of(context).colorScheme.onSurfaceVariant;
      return InkWell(
        onTap: ()=> onModeChanged(m),
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: chipHeight,
          padding: const EdgeInsets.symmetric(horizontal: 12),
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
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ),
        ),
      );
    }

    Widget searchButton(){
      final active = isSearchActive;
      final textColor = active ? Theme.of(context).colorScheme.onPrimary : Theme.of(context).colorScheme.onSurfaceVariant;
      return InkWell(
        onTap: onSearchToggle,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: chipHeight,
          padding: const EdgeInsets.symmetric(horizontal: 12),
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
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.search, size: 20, color: textColor),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  'Ara...',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Row(crossAxisAlignment: CrossAxisAlignment.center, children:[
      Expanded(child: searchButton()),
      const SizedBox(width:8),
      Expanded(child: modeChip(GalaxyViewMode.grid, Icons.grid_view_rounded, 'Izgara')),
      const SizedBox(width:8),
      Expanded(child: modeChip(GalaxyViewMode.list, Icons.view_list_rounded, 'Liste')),
    ]);
  }
}

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final VoidCallback onClose;

  const _SearchBar({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isDark
          ? Theme.of(context).colorScheme.surface.withOpacity(0.95)
          : Colors.white.withOpacity(0.98),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.5 : 0.15),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ValueListenableBuilder<TextEditingValue>(
        valueListenable: controller,
        builder: (context, value, child) {
          return Row(
            children: [
              Icon(
                Icons.search,
                color: Theme.of(context).colorScheme.primary,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  onChanged: onChanged,
                  autofocus: true,
                  style: TextStyle(
                    fontSize: 16,
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Konu ara...',
                    hintStyle: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.close,
                  color: Theme.of(context).colorScheme.primary,
                  size: 24,
                ),
                onPressed: onClose,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(
                  minWidth: 36,
                  minHeight: 36,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _MasteryPill extends StatelessWidget {
  final double mastery;
  const _MasteryPill({required this.mastery});

  @override
  Widget build(BuildContext context) {
    Color c;
    String level;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (mastery < 0) {
      level = 'Veri Yok';
      c = Theme.of(context).colorScheme.outline;
    } else if (mastery < 0.4) {
      level = 'Zayıf';
      c = Theme.of(context).colorScheme.error;
    } else if (mastery < 0.7) {
      level = 'Gelişiyor';
      c = Theme.of(context).colorScheme.primary;
    } else {
      level = 'Güçlü';
      c = Colors.green;
    }

    return Container(
      constraints: const BoxConstraints(minWidth: 75),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: c.withOpacity(isDark ? 0.15 : 0.12),
        border: Border.all(
          color: c.withOpacity(isDark ? 0.7 : 0.8),
          width: isDark ? 1 : 1.5
        ),
      ),
      child: Text(
        level,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: mastery < 0 ? Theme.of(context).colorScheme.onSurface : c,
          letterSpacing: 0.2,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

