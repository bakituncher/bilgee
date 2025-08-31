// lib/features/weakness_workshop/screens/weakness_workshop_screen.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bilge_ai/data/repositories/ai_service.dart';
import 'package:bilge_ai/data/providers/firestore_providers.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:bilge_ai/core/theme/app_theme.dart';
import 'package:bilge_ai/features/weakness_workshop/models/saved_workshop_model.dart';
import 'package:bilge_ai/features/weakness_workshop/models/study_guide_model.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:bilge_ai/data/models/topic_performance_model.dart';
import 'package:go_router/go_router.dart';
import 'package:bilge_ai/data/models/exam_model.dart';
import 'package:bilge_ai/features/stats/logic/stats_analysis.dart';
import 'package:bilge_ai/features/stats/logic/stats_analysis_provider.dart';
import 'package:bilge_ai/features/auth/application/auth_controller.dart';
import 'package:uuid/uuid.dart';
import 'package:bilge_ai/core/navigation/app_routes.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:bilge_ai/features/quests/logic/quest_notifier.dart';
import 'package:bilge_ai/data/models/performance_summary.dart';


enum WorkshopStep { briefing, study, quiz, results }

final _selectedTopicProvider = StateProvider<Map<String, String>?>((ref) => null);
final _difficultyProvider = StateProvider<(String, int)>((ref) => ('normal', 1));

final workshopSessionProvider = FutureProvider.autoDispose<StudyGuideAndQuiz>((ref) async {
  final selectedTopic = ref.watch(_selectedTopicProvider);
  final difficultyInfo = ref.watch(_difficultyProvider);

  if (selectedTopic == null) {
    return Future.error("Konu seçilmedi.");
  }

  final user = ref.read(userProfileProvider).value;
  final tests = ref.read(testsProvider).value;
  final performance = ref.read(performanceProvider).value;

  if (user == null || tests == null || performance == null) {
    return Future.error("Analiz için kullanıcı, test veya performans verisi bulunamadı.");
  }

  final jsonString = await ref.read(aiServiceProvider).generateStudyGuideAndQuiz(
    user,
    tests,
    performance,
    topicOverride: selectedTopic,
    difficulty: difficultyInfo.$1,
    attemptCount: difficultyInfo.$2,
  ).timeout(
    const Duration(seconds: 45),
    onTimeout: () => throw TimeoutException("Yapay zeka çok uzun süredir yanıt vermiyor. Lütfen tekrar deneyin."),
  );

  final decodedJson = jsonDecode(jsonString);
  if (decodedJson.containsKey('error')) {
    throw Exception(decodedJson['error']);
  }
  return StudyGuideAndQuiz.fromJson(decodedJson);
});


class WeaknessWorkshopScreen extends ConsumerStatefulWidget {
  const WeaknessWorkshopScreen({super.key});
  @override
  ConsumerState<WeaknessWorkshopScreen> createState() => _WeaknessWorkshopScreenState();
}

class _WeaknessWorkshopScreenState extends ConsumerState<WeaknessWorkshopScreen> {
  WorkshopStep _currentStep = WorkshopStep.briefing;
  Map<int, int> _selectedAnswers = {};
  bool _skipStudyView = false;

  void _startWorkshop(Map<String, String> topic) {
    ref.read(_selectedTopicProvider.notifier).state = topic;
    ref.read(_difficultyProvider.notifier).state = ('normal', 1);
    _selectedAnswers = {};
    setState(() => _currentStep = WorkshopStep.study);
  }

  void _submitQuiz(StudyGuideAndQuiz material) {
    final user = ref.read(userProfileProvider).value;
    final performanceSummary = ref.read(performanceProvider).value;
    if(user == null || performanceSummary == null) return;

    int correct = 0;
    int wrong = 0;
    material.quiz.asMap().forEach((index, q) {
      if (_selectedAnswers.containsKey(index)) {
        if (_selectedAnswers[index] == q.correctOptionIndex) {
          correct++;
        } else {
          wrong++;
        }
      }
    });
    int blank = material.quiz.length - correct - wrong;

    final firestoreService = ref.read(firestoreServiceProvider);
    final sanitizedSubject = firestoreService.sanitizeKey(material.subject);
    final sanitizedTopic = firestoreService.sanitizeKey(material.topic);

    final currentPerformance = performanceSummary.topicPerformances[sanitizedSubject]?[sanitizedTopic] ?? TopicPerformanceModel();
    final newPerformance = TopicPerformanceModel(
      correctCount: currentPerformance.correctCount + correct,
      wrongCount: currentPerformance.wrongCount + wrong,
      blankCount: currentPerformance.blankCount + blank,
      questionCount: currentPerformance.questionCount + material.quiz.length,
    );

    firestoreService.updateTopicPerformance(
      userId: user.id,
      subject: material.subject,
      topic: material.topic,
      performance: newPerformance,
    );

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    DateTime? last = user.lastWorkshopDate?.toDate();
    int newStreak = user.workshopStreak;
    if (last == null) {
      newStreak = 1;
    } else {
      final lastDay = DateTime(last.year, last.month, last.day);
      final diff = today.difference(lastDay).inDays;
      if (diff == 1) {
        newStreak += 1;
      } else if (diff > 1) {
        newStreak = 1;
      }
    }
    firestoreService.usersCollection.doc(user.id).update({
      'workshopStreak': newStreak,
      'lastWorkshopDate': Timestamp.fromDate(now),
    });

    ref.read(questNotifierProvider.notifier).userCompletedWorkshopQuiz(material.subject, material.topic);

    setState(() => _currentStep = WorkshopStep.results);
  }

  void _resetToBriefing(){
    ref.invalidate(workshopSessionProvider);
    ref.read(_selectedTopicProvider.notifier).state = null;
    setState(() => _currentStep = WorkshopStep.briefing);
  }

  void _handleDeepenRequest() {
    showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => _DeepenWorkshopSheet(
          onOptionSelected: (String difficulty, bool invalidate, bool skipStudy) {
            Navigator.of(context).pop();
            _setDifficultyAndChangeStep(difficulty, invalidate, skipStudy: skipStudy);
          },
        )
    );
  }

  void _setDifficultyAndChangeStep(String difficulty, bool invalidate, {bool skipStudy = false}) {
    ref.read(_difficultyProvider.notifier).update((state) => (difficulty, state.$2 + 1));
    _selectedAnswers = {};

    if(skipStudy) {
      _skipStudyView = true;
    }

    if (invalidate) {
      ref.invalidate(workshopSessionProvider);
    }
    setState(() => _currentStep = WorkshopStep.study);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cevher Atölyesi'),
        leading: _currentStep != WorkshopStep.briefing ? IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: (){
            if(_currentStep == WorkshopStep.results){ setState(() => _currentStep = WorkshopStep.quiz); }
            else if(_currentStep == WorkshopStep.quiz){ setState(() => _currentStep = WorkshopStep.study); }
            else { _resetToBriefing(); }
          },
        ) : null,
        actions: [
          if (_currentStep == WorkshopStep.briefing)
            IconButton(
              icon: const Icon(Icons.bar_chart_rounded),
              tooltip: "Atölye Raporunu Görüntüle",
              onPressed: () => context.push('/ai-hub/weakness-workshop/stats'),
            ),
          IconButton(
            icon: const Icon(Icons.inventory_2_outlined),
            tooltip: "Cevher Kasanı Görüntüle",
            onPressed: () => context.push('/ai-hub/weakness-workshop/${AppRoutes.savedWorkshops}'),
          ),
        ],
      ),
      body: AnimatedSwitcher(
        duration: 300.ms,
        transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: child),
        child: _buildCurrentStepView(),
      ),
      bottomNavigationBar: _currentStep == WorkshopStep.results
          ? _ResultsBottomBar(
              onBackToWorkshop: _resetToBriefing,
              onDeepen: _handleDeepenRequest,
            )
          : null,
    );
  }

  Widget _buildCurrentStepView() {
    if (_currentStep == WorkshopStep.briefing) {
      return _BriefingView(key: const ValueKey('briefing'), onTopicSelected: _startWorkshop);
    }

    final sessionAsync = ref.watch(workshopSessionProvider);
    return sessionAsync.when(
      loading: () => const _LoadingCevherView(key: ValueKey('loading')),
      error: (e, s) {
        if (e.toString().contains("Konu seçilmedi")) {
          return const Center(key: ValueKey('waiting'), child: CircularProgressIndicator());
        }
        return _ErrorView(key: const ValueKey('error'), error: e.toString(), onRetry: (){
          ref.invalidate(workshopSessionProvider);
        });
      },
      data: (material) {
        if (_skipStudyView) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _currentStep = WorkshopStep.quiz;
                _skipStudyView = false;
              });
            }
          });
          return const _LoadingCevherView(key: ValueKey('reloading_quiz'));
        }

        switch (_currentStep) {
          case WorkshopStep.study:
            return _StudyView(key: ValueKey('study_${material.topic}_${ref.read(_difficultyProvider)}'), material: material, onStartQuiz: () => setState(() => _currentStep = WorkshopStep.quiz));
          case WorkshopStep.quiz:
            return _QuizView(
                key: ValueKey('quiz_${material.topic}_${ref.read(_difficultyProvider)}'),
                material: material,
                onSubmit: () => _submitQuiz(material),
                selectedAnswers: _selectedAnswers,
                onAnswerSelected: (q, a) => setState(() => _selectedAnswers[q] = a)
            );
          case WorkshopStep.results:
            return _ResultsView(key: ValueKey('results_${material.topic}'), material: material, selectedAnswers: _selectedAnswers, onNextTopic: _resetToBriefing,
              onRetryHarder: _handleDeepenRequest,
            );
          default: return const SizedBox.shrink();
        }
      },
    );
  }
}

class _LoadingCevherView extends StatelessWidget {
  const _LoadingCevherView({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset('assets/images/bilge_baykus.png', height: 120)
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .moveY(duration: 1500.ms, begin: -10, end: 10, curve: Curves.easeInOut),
          const SizedBox(height: 24),
          Text(
            "Bilge Baykuş senin için\nözel bir çalışma hazırlıyor...",
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(color: AppTheme.secondaryTextColor),
          ),
          const SizedBox(height: 16),
          const SizedBox(
            width: 150,
            child: LinearProgressIndicator(color: AppTheme.secondaryColor),
          ),
        ],
      ),
    );
  }
}

class _BriefingView extends ConsumerWidget {
  final Function(Map<String, String>) onTopicSelected;
  const _BriefingView({super.key, required this.onTopicSelected});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userProfileProvider).value;
    final tests = ref.watch(testsProvider).value;
    final performance = ref.watch(performanceProvider).value;
    // Yeni: Önbellekli analiz
    final analysisAsync = ref.watch(overallStatsAnalysisProvider);

    if (user == null || tests == null || user.selectedExam == null || performance == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return analysisAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(child: Text('Analiz yüklenemedi: $e')),
      data: (analysis) {
        final suggestions = analysis?.getWorkshopSuggestions(count: 3) ?? [];

        return ListView(
          padding: const EdgeInsets.all(24.0),
          children: [
            Text("Stratejik Mola", style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text(
              suggestions.any((s) => s['isSuggestion'] == true)
                  ? "Henüz yeterli verin olmadığı için BilgeAI, yolculuğa başlaman için bazı kilit konuları belirledi. Bunlar 'Keşif Noktaları'dır."
                  : "BilgeAI, performansını analiz etti ve gelişim için en parlak fırsatları belirledi. Aşağıdaki cevherlerden birini seçerek işlemeye başla.",
              style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppTheme.secondaryTextColor),
            ),
            const SizedBox(height: 24),
            if(suggestions.isEmpty)
              const Center(child: Padding(padding: EdgeInsets.all(32.0), child: Text("Harika! Önerilecek bir zayıf nokta veya fethedilmemiş konu kalmadı.", textAlign: TextAlign.center)))
            else
              ...suggestions.asMap().entries.map((entry) {
                int idx = entry.key;
                var topicData = entry.value;
                final topicForSelection = {'subject': topicData['subject'].toString(),'topic': topicData['topic'].toString(),};
                return _TopicCard(
                  topic: topicData,
                  isRecommended: idx == 0,
                  onTap: () => onTopicSelected(topicForSelection),
                ).animate().fadeIn(delay: (200 * idx).ms).slideX(begin: 0.2);
              })
          ],
        );
      },
    );
  }
}
class _TopicCard extends StatelessWidget {
  final Map<String, dynamic> topic;
  final bool isRecommended;
  final VoidCallback onTap;

  const _TopicCard({required this.topic, required this.isRecommended, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final masteryValue = topic['mastery'] as double?;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: isRecommended ? const BorderSide(color: AppTheme.secondaryColor, width: 2) : BorderSide.none,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isRecommended)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                      color: AppTheme.secondaryColor,
                      borderRadius: BorderRadius.circular(8)
                  ),
                  child: Text("BİLGEAI ÖNERİSİ", style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppTheme.primaryColor, fontWeight: FontWeight.bold, letterSpacing: 1)),
                ),
              if (isRecommended) const SizedBox(height: 8),
              Text(topic['topic']!, style: Theme.of(context).textTheme.titleLarge),
              Text(topic['subject']!, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.secondaryTextColor)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Text("Hakimiyet: ", style: Theme.of(context).textTheme.bodySmall),
                  Expanded(
                    child: LinearProgressIndicator(
                      value: masteryValue == null || masteryValue < 0 ? null : masteryValue,
                      backgroundColor: AppTheme.lightSurfaceColor.withOpacity(0.3),
                      color: masteryValue == null || masteryValue < 0 ? AppTheme.secondaryTextColor : Color.lerp(AppTheme.accentColor, AppTheme.successColor, masteryValue),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(masteryValue == null || masteryValue < 0 ? "Keşfet!" : "%${(masteryValue * 100).toStringAsFixed(0)}", style: Theme.of(context).textTheme.bodySmall)
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}

class _StudyView extends StatelessWidget {
  final StudyGuideAndQuiz material;
  final VoidCallback onStartQuiz;
  const _StudyView({super.key, required this.material, required this.onStartQuiz});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: MarkdownBody(
                data: material.studyGuide,
                styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                  p: const TextStyle(fontSize: 16, height: 1.5, color: AppTheme.textColor),
                  h1: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppTheme.secondaryColor),
                  h3: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                )
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(24.0),
          child: ElevatedButton.icon(
            icon: const Icon(Icons.quiz_rounded),
            label: const Text("Ustalık Sınavına Başla"),
            onPressed: onStartQuiz,
          ),
        )
      ],
    );
  }
}

class _QuizView extends StatefulWidget {
  final StudyGuideAndQuiz material;
  final VoidCallback onSubmit;
  final Map<int,int> selectedAnswers;
  final Function(int, int) onAnswerSelected;

  const _QuizView({super.key, required this.material, required this.onSubmit, required this.selectedAnswers, required this.onAnswerSelected});

  @override
  State<_QuizView> createState() => _QuizViewState();
}

class _QuizViewState extends State<_QuizView> {
  late PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _pageController.addListener(() {
      if(_pageController.page!.round() != _currentPage){
        setState(() {
          _currentPage = _pageController.page!.round();
        });
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final quizLength = widget.material.quiz.length;
    bool isCurrentPageAnswered = widget.selectedAnswers.containsKey(_currentPage);
    bool isQuizFinished = widget.selectedAnswers.length == quizLength;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
          child: LinearProgressIndicator(
            value: (_currentPage + 1) / quizLength,
            backgroundColor: AppTheme.lightSurfaceColor.withValues(alpha: AppTheme.lightSurfaceColor.a * 0.3),
            color: AppTheme.secondaryColor,
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: quizLength,
            itemBuilder: (context, index) {
              final question = widget.material.quiz[index];
              return _QuestionCard(
                question: question,
                questionNumber: index + 1,
                totalQuestions: quizLength,
                selectedOptionIndex: widget.selectedAnswers[index],
                onOptionSelected: (optionIndex) {
                  if(!widget.selectedAnswers.containsKey(index)){
                    widget.onAnswerSelected(index, optionIndex);
                  }
                },
              );
            },
          ),
        ),
        if (isCurrentPageAnswered)
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: SafeArea(
              top: false,
              child: ElevatedButton.icon(
                icon: Icon(isQuizFinished ? Icons.assignment_turned_in_rounded : Icons.arrow_forward_ios_rounded),
                label: Text(isQuizFinished ? "Sonuçları Gör" : "Devam Et"),
                onPressed: (){
                  if(isQuizFinished){
                    widget.onSubmit();
                  } else {
                    _pageController.nextPage(duration: 300.ms, curve: Curves.easeOutCubic);
                  }
                },
              ),
            ),
          ).animate().fadeIn().slideY(begin: 0.5),
      ],
    );
  }
}

class _QuestionCard extends StatelessWidget {
  final QuizQuestion question;
  final int questionNumber;
  final int totalQuestions;
  final int? selectedOptionIndex;
  final Function(int) onOptionSelected;

  const _QuestionCard({
    required this.question,
    required this.questionNumber,
    required this.totalQuestions,
    required this.selectedOptionIndex,
    required this.onOptionSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Soru $questionNumber / $totalQuestions", style: const TextStyle(color: AppTheme.secondaryTextColor)),
          const SizedBox(height: 8),
          Text(question.question, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 32),
          ...List.generate(question.options.length, (index) {
            bool isSelected = selectedOptionIndex == index;
            bool isCorrect = question.correctOptionIndex == index;
            Color? tileColor;
            Color? borderColor;
            IconData? trailingIcon;

            if (selectedOptionIndex != null) {
              if (isSelected) {
                tileColor = isCorrect ? AppTheme.successColor.withValues(alpha: AppTheme.successColor.a * 0.2) : AppTheme.accentColor.withValues(alpha: AppTheme.accentColor.a * 0.2);
                borderColor = isCorrect ? AppTheme.successColor : AppTheme.accentColor;
                trailingIcon = isCorrect ? Icons.check_circle_rounded : Icons.cancel_rounded;
              } else if (isCorrect) {
                tileColor = AppTheme.successColor.withValues(alpha: AppTheme.successColor.a * 0.2);
                borderColor = AppTheme.successColor;
                trailingIcon = Icons.check_circle_outline_rounded;
              }
            }

            return Card(
              color: tileColor ?? AppTheme.cardColor,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: borderColor ?? AppTheme.lightSurfaceColor, width: 1.5)),
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                onTap: selectedOptionIndex == null ? () => onOptionSelected(index) : null,
                title: Text(question.options[index]),
                trailing: trailingIcon != null ? Icon(trailingIcon, color: borderColor) : null,
              ),
            );
          }),
          if (selectedOptionIndex != null && selectedOptionIndex != question.correctOptionIndex)
            _ExplanationCard(explanation: question.explanation)
                .animate().fadeIn(delay: 200.ms).slideY(begin: 0.2),
        ],
      ),
    );
  }
}

class _ExplanationCard extends StatelessWidget {
  final String explanation;
  const _ExplanationCard({required this.explanation});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppTheme.primaryColor.withValues(alpha: AppTheme.primaryColor.a * 0.7),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.school_rounded, color: AppTheme.secondaryColor),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Usta'nın Açıklaması", style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppTheme.secondaryColor)),
                  const SizedBox(height: 8),
                  Text(explanation, style: const TextStyle(color: AppTheme.textColor, height: 1.5)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultsView extends StatefulWidget {
  final StudyGuideAndQuiz material;
  final VoidCallback onNextTopic;
  final VoidCallback onRetryHarder;
  final Map<int, int> selectedAnswers;

  const _ResultsView({super.key, required this.material, required this.onNextTopic, required this.onRetryHarder, required this.selectedAnswers});

  @override
  State<_ResultsView> createState() => _ResultsViewState();
}

class _ResultsViewState extends State<_ResultsView> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    int correct = 0;
    widget.material.quiz.asMap().forEach((index, q) {
      if (widget.selectedAnswers[index] == q.correctOptionIndex) correct++;
    });
    final score = widget.material.quiz.isEmpty ? 0.0 : (correct / widget.material.quiz.length) * 100;

    return Column(
      children: [
        TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.secondaryColor,
          tabs: const [
            Tab(text: "Özet"),
            Tab(text: "Sınav Karnesi"),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _SummaryView(
                score: score,
                material: widget.material,
                onNextTopic: widget.onNextTopic,
                onRetryHarder: widget.onRetryHarder,
                onShowReview: () => _tabController.animateTo(1),
              ),
              _QuizReviewView(
                material: widget.material,
                selectedAnswers: widget.selectedAnswers,
              )
            ],
          ),
        ),
      ],
    );
  }
}

class _SummaryView extends ConsumerStatefulWidget {
  final double score;
  final StudyGuideAndQuiz material;
  final VoidCallback onNextTopic;
  final VoidCallback onRetryHarder;
  final VoidCallback onShowReview;

  const _SummaryView({
    required this.score,
    required this.material,
    required this.onNextTopic,
    required this.onRetryHarder,
    required this.onShowReview,
    super.key
  });

  @override
  ConsumerState<_SummaryView> createState() => _SummaryViewState();
}

class _SummaryViewState extends ConsumerState<_SummaryView> {
  bool _isSaving = false;
  bool _isSaved = false;

  @override
  Widget build(BuildContext context) {
    final highScore = widget.score >= 80;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (highScore) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  AppTheme.successColor.withValues(alpha: AppTheme.successColor.a * 0.25),
                  AppTheme.secondaryColor.withValues(alpha: AppTheme.secondaryColor.a * 0.15)
                ]),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.successColor.withValues(alpha: AppTheme.successColor.a * 0.6), width: 1.5),
              ),
              child: Row(
                children: [
                  const Icon(Icons.workspace_premium_rounded, color: AppTheme.successColor, size: 32),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Ustalık Parlıyor!', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppTheme.successColor, fontWeight: FontWeight.bold)),
                        Text('Bu Cevher sınavında %80+ başarıyla ekstra bir yükseliş yakaladın.', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.secondaryTextColor)),
                      ],
                    ),
                  )
                ],
              ),
            ).animate().fadeIn(duration: 500.ms).slideY(begin: -0.2),
            const SizedBox(height: 20),
          ],
          const SizedBox(height: 20),
          Text("Ustalık Sınavı Tamamlandı!", style: Theme.of(context).textTheme.headlineMedium, textAlign: TextAlign.center,),
          const SizedBox(height: 16),
          Text("%${widget.score.toStringAsFixed(0)}", style: Theme.of(context).textTheme.displayLarge?.copyWith(color: AppTheme.successColor, fontWeight: FontWeight.bold), textAlign: TextAlign.center,),
          Text("Başarı Oranı", style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppTheme.secondaryTextColor), textAlign: TextAlign.center,),
          const SizedBox(height: 24),
          _ResultActionCard(
              title: "Sonuçları Değerlendir",
              subtitle: "Başarını veya hatalarını AI koçunla konuş.",
              icon: Icons.forum_rounded,
              onTap: (){
                final reviewContext = {
                  'type': 'workshop_review',
                  'subject': widget.material.subject,
                  'topic': widget.material.topic,
                  'score': widget.score.toStringAsFixed(0),
                };
                context.push('${AppRoutes.aiHub}/${AppRoutes.motivationChat}', extra: reviewContext);
              }
          ),
          const SizedBox(height: 16),
          _ResultActionCard(title: "Derinleşmek İstiyorum", subtitle: "Bu konuyla ilgili daha zor sorularla kendini sına.", icon: Icons.auto_awesome, onTap: widget.onRetryHarder, isPrimary: true),
          const SizedBox(height: 16),
          _ResultActionCard(
            title: "Cevheri Kaydet",
            subtitle: "Bu çalışma kartını daha sonra tekrar et.",
            icon: _isSaved ? Icons.check_circle_rounded : Icons.bookmark_add_rounded,
            onTap: (_isSaving || _isSaved) ? (){} : () async {
              setState(() => _isSaving = true);
              final userId = ref.read(authControllerProvider).value!.uid;
              final workshopToSave = SavedWorkshopModel.fromStudyGuide(const Uuid().v4(), widget.material);
              await ref.read(firestoreServiceProvider).saveWorkshopForUser(userId, workshopToSave);
              if (mounted) {
                setState(() {
                  _isSaving = false;
                  _isSaved = true;
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Cevher başarıyla kasana eklendi!"), backgroundColor: AppTheme.successColor),
                );
              }
            },
            child: (_isSaving) ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator()) : null,
            overrideColor: _isSaved ? AppTheme.successColor : null,
          ),
          const SizedBox(height: 16),
          _ResultActionCard(title: "Sıradaki Cevhere Geç", subtitle: "Başka bir zayıf halkanı güçlendir.", icon: Icons.diamond_outlined, onTap: widget.onNextTopic),
          // Alt çubuk eklendiği için burada Atölyeye Dön butonunu kaldırdık
        ],
      ).animate().fadeIn(duration: 500.ms),
    );
  }
}

class _QuizReviewView extends StatelessWidget {
  final StudyGuideAndQuiz material;
  final Map<int, int> selectedAnswers;

  const _QuizReviewView({
    required this.material,
    required this.selectedAnswers,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: material.quiz.length,
      itemBuilder: (context, index) {
        final question = material.quiz[index];
        final userAnswer = selectedAnswers[index];
        final isCorrect = userAnswer == question.correctOptionIndex;

        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Soru ${index + 1}: ${question.question}", style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 16),
                ...List.generate(question.options.length, (optIndex) {
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      question.options[optIndex],
                      style: TextStyle(
                        color: optIndex == question.correctOptionIndex ? AppTheme.successColor :
                        (optIndex == userAnswer && !isCorrect ? AppTheme.accentColor : AppTheme.textColor),
                      ),
                    ),
                    leading: Icon(
                      optIndex == question.correctOptionIndex ? Icons.check_circle_rounded :
                      (optIndex == userAnswer && !isCorrect ? Icons.cancel_rounded : Icons.radio_button_unchecked_rounded),
                      color: optIndex == question.correctOptionIndex ? AppTheme.successColor :
                      (optIndex == userAnswer && !isCorrect ? AppTheme.accentColor : AppTheme.secondaryTextColor),
                    ),
                  );
                }),
                const Divider(height: 24),
                _ExplanationCard(explanation: question.explanation)
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ResultActionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final bool isPrimary;
  final Widget? child;
  final Color? overrideColor;

  const _ResultActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.isPrimary = false,
    this.child,
    this.overrideColor
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: isPrimary ? AppTheme.secondaryColor.withValues(alpha: AppTheme.secondaryColor.a * 0.2) : AppTheme.cardColor,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: overrideColor ?? (isPrimary ? AppTheme.secondaryColor : AppTheme.lightSurfaceColor), width: 1.5)
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Row(
            children: [
              Icon(icon, color: overrideColor ?? (isPrimary ? AppTheme.secondaryColor : AppTheme.secondaryTextColor), size: 28),
              const SizedBox(width: 16),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleLarge),
                  Text(subtitle, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.secondaryTextColor)),
                ],
              )),
              if(child != null) Padding(padding: const EdgeInsets.only(left: 16), child: child),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _ErrorView({super.key, required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline_rounded, color: AppTheme.accentColor, size: 64),
          const SizedBox(height: 24),
          Text(
            "Bir Sorun Oluştu",
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            "Cevher işlenirken beklenmedik bir sorunla karşılaşıldı. Lütfen tekrar dene.\n\nHata: $error",
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppTheme.secondaryTextColor),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text("Tekrar Dene"),
          )
        ],
      ),
    );
  }
}

class _DeepenWorkshopSheet extends StatelessWidget {
  final Function(String difficulty, bool invalidate, bool skipStudy) onOptionSelected;
  const _DeepenWorkshopSheet({required this.onOptionSelected});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
      decoration: const BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "Derinleşme Modu",
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            "Ustalığını bir sonraki seviyeye taşı.",
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppTheme.secondaryTextColor),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          _ResultActionCard(
            title: "Konuyu Tekrar Oku",
            subtitle: "Anlatımı gözden geçirip zor teste hazırlan.",
            icon: Icons.menu_book_rounded,
            onTap: () => onOptionSelected('hard', false, false),
          ),
          const SizedBox(height: 12),
          _ResultActionCard(
            title: "Yeni Zor Test Oluştur",
            subtitle: "Bilgini en çeldirici sorularla sına.",
            icon: Icons.auto_awesome_motion_rounded,
            onTap: () => onOptionSelected('hard', true, true),
            isPrimary: true,
          ),
        ],
      ),
    );
  }
}

class _ResultsBottomBar extends StatelessWidget {
  final VoidCallback onBackToWorkshop;
  final VoidCallback onDeepen;
  const _ResultsBottomBar({required this.onBackToWorkshop, required this.onDeepen});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        decoration: BoxDecoration(
          color: AppTheme.cardColor,
          border: Border(top: BorderSide(color: AppTheme.lightSurfaceColor, width: 1)),
        ),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onDeepen,
                icon: const Icon(Icons.auto_awesome),
                label: const Text("Derinleş"),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: onBackToWorkshop,
                icon: const Icon(Icons.arrow_back_ios_new_rounded),
                label: const Text("Atölyeye Dön"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


