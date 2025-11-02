// lib/features/weakness_workshop/screens/weakness_workshop_screen.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:taktik/data/repositories/ai_service.dart';
import 'package:taktik/data/providers/firestore_providers.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:taktik/core/theme/app_theme.dart';
import 'package:taktik/features/weakness_workshop/models/saved_workshop_model.dart';
import 'package:taktik/features/weakness_workshop/models/study_guide_model.dart';
import 'package:taktik/shared/widgets/markdown_with_math.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:taktik/data/models/topic_performance_model.dart';
import 'package:go_router/go_router.dart';
import 'package:taktik/features/stats/logic/stats_analysis_provider.dart';
import 'package:taktik/features/auth/application/auth_controller.dart';
import 'package:uuid/uuid.dart';
import 'package:taktik/core/navigation/app_routes.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:taktik/features/quests/logic/quest_notifier.dart';
import 'package:taktik/features/weakness_workshop/logic/quiz_quality_guard.dart';
import 'package:confetti/confetti.dart';
import 'package:lottie/lottie.dart';


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

  Future<StudyGuideAndQuiz> attempt({double? temperature}) async {
    final jsonString = await ref.read(aiServiceProvider).generateStudyGuideAndQuiz(
      user,
      tests,
      performance,
      topicOverride: selectedTopic,
      difficulty: difficultyInfo.$1,
      attemptCount: difficultyInfo.$2,
      temperature: temperature,
    ).timeout(
      const Duration(seconds: 45),
      onTimeout: () => throw TimeoutException("Yapay zeka çok uzun süredir yanıt vermiyor. Lütfen tekrar deneyin."),
    );

    final decodedJson = jsonDecode(jsonString);
    if (decodedJson.containsKey('error')) {
      throw Exception(decodedJson['error']);
    }
    final raw = StudyGuideAndQuiz.fromJson(decodedJson);
    // Soru kalite güvencesi uygula (yetersizse hata fırlatır)
    final guarded = QuizQualityGuard.apply(raw).material;
    return guarded;
  }

  // 1) Varsayılan sıcaklıkla dene -> 2) 0.35 -> 3) 0.25
  final attempts = <double?>[null, 0.35, 0.25];
  Exception? lastErr;
  for (final t in attempts) {
    try {
      return await attempt(temperature: t);
    } catch (e) {
      lastErr = Exception(e.toString());
      // denemeye devam
    }
  }
  throw lastErr ?? Exception('Soru kalitesi yetersiz. Lütfen tekrar deneyin.');
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
  bool _masteredAchieved = false; // bu oturumda ustalık kazan��ldı mı

  void _startWorkshop(Map<String, String> topic) {
    ref.read(_selectedTopicProvider.notifier).state = topic;
    ref.read(_difficultyProvider.notifier).state = ('normal', 1);
    _selectedAnswers = {};
    _masteredAchieved = false;
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

    // Ustalık (konu öğrenildi) koşulları:
    // - En az 20 birikimli soru
    // - Birikimli doğruluk >= %75 (blank hariç)
    // - Bu sınav skoru >= %85
    final int cumCorrect = newPerformance.correctCount;
    final int cumWrong = newPerformance.wrongCount;
    final int cumAnswered = (cumCorrect + cumWrong);
    final double cumAccuracy = cumAnswered == 0 ? 0.0 : (cumCorrect / cumAnswered);
    final double quizScore = material.quiz.isEmpty ? 0.0 : (correct / material.quiz.length);

    _masteredAchieved = false;
    final alreadyMasteredKey = '$sanitizedSubject-$sanitizedTopic';
    final alreadyMastered = performanceSummary.masteredTopics.contains(alreadyMasteredKey);
    if (!alreadyMastered && newPerformance.questionCount >= 20 && cumAccuracy >= 0.75 && quizScore >= 0.85) {
      firestoreService.markTopicAsMastered(userId: user.id, subject: material.subject, topic: material.topic);
      _masteredAchieved = true;
    }

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
    _masteredAchieved = false;
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
    _masteredAchieved = false;

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
      body: Stack(
        children: [
          const _FancyBackground(),
          Column(
            children: [
              _WSHeader(
                showBack: true,
                onBack: (){
                  if(_currentStep == WorkshopStep.briefing){
                    if (Navigator.of(context).canPop()) {
                      context.pop();
                    }
                  } else if(_currentStep == WorkshopStep.results){
                    setState(() => _currentStep = WorkshopStep.quiz);
                  } else if(_currentStep == WorkshopStep.quiz){
                    setState(() => _currentStep = WorkshopStep.study);
                  } else {
                    _resetToBriefing();
                  }
                },
                showStats: _currentStep == WorkshopStep.briefing,
                onStats: () => context.push('/ai-hub/weakness-workshop/stats'),
                onSaved: () => context.push('/ai-hub/weakness-workshop/${AppRoutes.savedWorkshops}'),
                title: 'Cevher Atölyesi',
              ),
              Expanded(
                child: AnimatedSwitcher(
                  duration: 300.ms,
                  transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: child),
                  child: _buildCurrentStepView(),
                ),
              ),
            ],
          ),
        ],
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
            return _StudyView(
              key: ValueKey('study_${material.topic}_${ref.read(_difficultyProvider)}'),
              material: material,
              onStartQuiz: () => setState(() => _currentStep = WorkshopStep.quiz),
            );
          case WorkshopStep.quiz:
            return _QuizView(
              key: ValueKey('quiz_${material.topic}_${ref.read(_difficultyProvider)}'),
              material: material,
              onSubmit: () => _submitQuiz(material),
              selectedAnswers: _selectedAnswers,
              onAnswerSelected: (q, a) => setState(() => _selectedAnswers[q] = a),
              onReportIssue: (qIndex) {
                _openReportSheet(material, qIndex, _selectedAnswers[qIndex]);
              },
            );
          case WorkshopStep.results:
            return _ResultsView(
              key: ValueKey('results_${material.topic}'),
              material: material,
              selectedAnswers: _selectedAnswers,
              onNextTopic: _resetToBriefing,
              onRetryHarder: _handleDeepenRequest,
              masteredAchieved: _masteredAchieved,
            );
          default:
            return const SizedBox.shrink();
        }
      },
    );
  }

  void _openReportSheet(StudyGuideAndQuiz material, int qIndex, int? selected) {
    final q = material.quiz[qIndex];
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _ReportIssueSheet(
        subject: material.subject,
        topic: material.topic,
        question: q.question,
        options: q.options,
        correctIndex: q.correctOptionIndex,
        selectedIndex: selected,
        onSubmit: (reason) async {
          final userId = ref.read(authControllerProvider).value?.uid;
          if (userId == null) return;

          try {
            final result = await ref.read(firestoreServiceProvider).reportQuestionIssue(
                  userId: userId,
                  subject: material.subject,
                  topic: material.topic,
                  question: q.question,
                  options: q.options,
                  correctIndex: q.correctOptionIndex,
                  selectedIndex: selected,
                  reason: reason,
                );

            if (mounted) {
              Navigator.pop(context);

              if (result['success'] == true) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Teşekkürler! İnceleme için iletildi.'),
                    backgroundColor: Theme.of(context).colorScheme.secondary,
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(result['message'] ?? 'Bir hata oluştu'),
                    backgroundColor: Theme.of(context).colorScheme.error,
                    duration: const Duration(seconds: 4),
                  ),
                );
              }
            }
          } catch (e) {
            if (mounted) {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Beklenmeyen bir hata oluştu: ${e.toString()}'),
                  backgroundColor: Theme.of(context).colorScheme.error,
                  duration: const Duration(seconds: 4),
                ),
              );
            }
          }
        },
      ),
    );
  }
}

class _FancyBackground extends StatefulWidget {
  const _FancyBackground();
  @override
  State<_FancyBackground> createState() => _FancyBackgroundState();
}

class _FancyBackgroundState extends State<_FancyBackground> with SingleTickerProviderStateMixin {
  late AnimationController _c;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(seconds: 10))..repeat(reverse: true);
  }
  @override
  void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        final t = _c.value;
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.lerp(colorScheme.background, colorScheme.surface, t)!,
                Color.lerp(colorScheme.surface, colorScheme.background, 1 - t)!,
              ],
            ),
          ),
          child: Stack(
            children: [
              _GlowBlob(
                  top: -40, left: -20, color: colorScheme.secondary.withOpacity(0.25), size: 200 + 40 * t),
              _GlowBlob(
                  bottom: -60, right: -30, color: colorScheme.primary.withOpacity(0.22), size: 240 - 20 * t),
              _GlowBlob(
                  top: 160,
                  right: -40,
                  color: colorScheme.tertiary.withOpacity(0.18),
                  size: 180 + 20 * (1 - t)),
            ],
          ),
        );
      },
    );
  }
}

class _GlowBlob extends StatelessWidget {
  final double? top, left, right, bottom;
  final Color color;
  final double size;
  const _GlowBlob({this.top, this.left, this.right, this.bottom, required this.color, required this.size});
  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top, left: left, right: right, bottom: bottom,
      child: Container(
        width: size, height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: color, blurRadius: 80, spreadRadius: 40)],
        ),
      ),
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
          // Cevher animasyonu
          Container(
            width: 280,
            height: 200,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context).colorScheme.secondary.withOpacity(0.2),
                  blurRadius: 30,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Lottie.asset(
              'assets/lotties/cevher.json',
              fit: BoxFit.contain,
              repeat: true,
            ),
          ).animate(onPlay: (c) => c.repeat(reverse: true))
           .scale(begin: const Offset(0.98, 0.98), end: const Offset(1.02, 1.02), duration: 2000.ms)
           .then()
           .shimmer(duration: 1500.ms, color: Theme.of(context).colorScheme.secondary.withOpacity(0.3)),
          const SizedBox(height: 32),
          Text(
            "İçerik hazırlanıyor...",
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.bold,
            ),
          ).animate(onPlay: (c) => c.repeat())
           .fadeIn(duration: 800.ms)
           .then()
           .fadeOut(duration: 800.ms),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Text(
              "Senin için özel çalışma materyali oluşturuluyor",
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: 220,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                color: Theme.of(context).colorScheme.secondary,
                backgroundColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.1),
                minHeight: 6,
              ),
            ),
          ).animate(onPlay: (c) => c.repeat())
           .shimmer(duration: 1800.ms, color: Theme.of(context).colorScheme.secondary.withOpacity(0.5)),
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
                  ? "Henüz yeterli verin olmadığı için TaktikAI, yolculuğa başlaman için bazı kilit konuları belirledi. Bunlar 'Keşif Noktaları'dır."
                  : "TaktikAI, performansını analiz etti ve gelişim için en parlak fırsatları belirledi. Aşağıdaki cevherlerden birini seçerek işlemeye başla.",
              style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
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

    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: isRecommended
            ? LinearGradient(colors: [colorScheme.secondary.withOpacity(0.25), Colors.transparent])
            : null,
      ),
      child: Card(
        elevation: 6,
        color: colorScheme.surface.withOpacity(0.85),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
              color: isRecommended ? colorScheme.secondary : colorScheme.surfaceVariant,
              width: 1.5),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (isRecommended)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: colorScheme.secondary, borderRadius: BorderRadius.circular(8)),
                        child: Text(
                          "TAKTİKAI ÖNERİSİ",
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: colorScheme.onSecondary, fontWeight: FontWeight.bold, letterSpacing: 1),
                        ),
                      ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: colorScheme.onSurface.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: colorScheme.surfaceVariant),
                      ),
                      child: Row(children: [
                        Icon(Icons.bolt_rounded, size: 16, color: colorScheme.secondary),
                        const SizedBox(width: 6),
                        Text(masteryValue == null || masteryValue < 0 ? 'Keşif' : '%${(masteryValue * 100).toStringAsFixed(0)}',
                            style: Theme.of(context).textTheme.labelSmall),
                      ]),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(topic['topic']!, style: Theme.of(context).textTheme.titleLarge),
                Text(topic['subject']!,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant)),
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: masteryValue == null || masteryValue < 0 ? null : masteryValue,
                  backgroundColor: colorScheme.surfaceVariant.withOpacity(0.3),
                  color: masteryValue == null || masteryValue < 0
                      ? colorScheme.onSurfaceVariant
                      : Color.lerp(colorScheme.error, colorScheme.secondary, masteryValue),
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
            ),
          ),
        ),
      )
    .animate()
    .fadeIn(duration: 350.ms)
    .slideY(begin: 0.1));
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
            child: MarkdownWithMath(
              data: material.studyGuide,
              styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                p: TextStyle(fontSize: 16, height: 1.5, color: Theme.of(context).colorScheme.onSurface),
                h1: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.secondary),
                h3: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface),
              ),
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
  final void Function(int questionIndex) onReportIssue;

  const _QuizView({super.key, required this.material, required this.onSubmit, required this.selectedAnswers, required this.onAnswerSelected, required this.onReportIssue});

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
            backgroundColor: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
            color: Theme.of(context).colorScheme.secondary,
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
                onReportIssue: () {
                  widget.onReportIssue(index);
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
  final void Function()? onReportIssue;

  const _QuestionCard({
    required this.question,
    required this.questionNumber,
    required this.totalQuestions,
    required this.selectedOptionIndex,
    required this.onOptionSelected,
    required this.onReportIssue,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text("Soru $questionNumber / $totalQuestions",
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
              const Spacer(),
              TextButton.icon(
                onPressed: onReportIssue,
                icon: Icon(Icons.flag_outlined, size: 18, color: Theme.of(context).colorScheme.onSurfaceVariant),
                label: Text('Sorunu Bildir', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          MarkdownWithMath(
            data: question.question,
            styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
              p: Theme.of(context).textTheme.headlineSmall,
            ),
          ),
          const SizedBox(height: 32),
          ...List.generate(question.options.length, (index) {
            bool isSelected = selectedOptionIndex == index;
            bool isCorrect = question.correctOptionIndex == index;
            Color? tileColor;
            Color? borderColor;
            IconData? trailingIcon;

            final colorScheme = Theme.of(context).colorScheme;

            if (selectedOptionIndex != null) {
              if (isSelected) {
                tileColor = isCorrect ? colorScheme.secondary.withOpacity(0.2) : colorScheme.error.withOpacity(0.2);
                borderColor = isCorrect ? colorScheme.secondary : colorScheme.error;
                trailingIcon = isCorrect ? Icons.check_circle_rounded : Icons.cancel_rounded;
              } else if (isCorrect) {
                tileColor = colorScheme.secondary.withOpacity(0.2);
                borderColor = colorScheme.secondary;
                trailingIcon = Icons.check_circle_outline_rounded;
              }
            }

            return Card(
              color: tileColor ?? colorScheme.surface,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: borderColor ?? colorScheme.surfaceVariant, width: 1.5)),
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                onTap: selectedOptionIndex == null ? () => onOptionSelected(index) : null,
                title: MarkdownWithMath(
                  data: question.options[index],
                  styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                    p: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
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
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      color: colorScheme.surfaceVariant,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.school_rounded, color: colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Usta'nın Açıklaması",
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(color: colorScheme.primary)),
                  const SizedBox(height: 8),
                  MarkdownWithMath(
                    data: explanation,
                    styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                      p: TextStyle(color: colorScheme.onSurface, height: 1.5),
                    ),
                  ),
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
  final bool masteredAchieved;

  const _ResultsView({super.key, required this.material, required this.onNextTopic, required this.onRetryHarder, required this.selectedAnswers, required this.masteredAchieved});

  @override
  State<_ResultsView> createState() => _ResultsViewState();
}

class _ResultsViewState extends State<_ResultsView> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late ConfettiController _confetti;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _confetti = ConfettiController(duration: const Duration(seconds: 2));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.masteredAchieved) {
        _confetti.play();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _confetti.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    int correct = 0;
    widget.material.quiz.asMap().forEach((index, q) {
      if (widget.selectedAnswers[index] == q.correctOptionIndex) correct++;
    });
    final score = widget.material.quiz.isEmpty ? 0.0 : (correct / widget.material.quiz.length) * 100;

    return Stack(
      children: [
        Column(
          children: [
            TabBar(
              controller: _tabController,
              indicatorColor: Theme.of(context).colorScheme.secondary,
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
                    masteredAchieved: widget.masteredAchieved,
                  ),
                  _QuizReviewView(
                    material: widget.material,
                    selectedAnswers: widget.selectedAnswers,
                  )
                ],
              ),
            ),
          ],
        ),
        Align(
          alignment: Alignment.topCenter,
          child: ConfettiWidget(
            confettiController: _confetti,
            blastDirectionality: BlastDirectionality.explosive,
            numberOfParticles: 24,
            shouldLoop: false,
            colors: [
              Theme.of(context).colorScheme.secondary, // Green
              Theme.of(context).colorScheme.primary,   // Cyan
              Theme.of(context).colorScheme.tertiary   // Gold
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
  final bool masteredAchieved;

  const _SummaryView({
    required this.score,
    required this.material,
    required this.onNextTopic,
    required this.onRetryHarder,
    required this.onShowReview,
    required this.masteredAchieved
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
          if (widget.masteredAchieved) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  Theme.of(context).colorScheme.secondary.withOpacity(0.3),
                  Theme.of(context).colorScheme.secondary.withOpacity(0.15)
                ]),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Theme.of(context).colorScheme.secondary.withOpacity(0.8), width: 1.5),
              ),
              child: Row(
                children: [
                  Icon(Icons.verified_rounded, color: Theme.of(context).colorScheme.secondary, size: 32),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Konu Ustalıkla Öğrenildi',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(color: Theme.of(context).colorScheme.secondary, fontWeight: FontWeight.bold)),
                        Text('Tebrikler! Bu konuda hedeflenen yeterlilik seviyesine ulaştın.',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                      ],
                    ),
                  )
                ],
              ),
            ).animate().fadeIn(duration: 500.ms).slideY(begin: -0.2),
            const SizedBox(height: 20),
          ],
          if (highScore) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  Theme.of(context).colorScheme.secondary.withOpacity(0.25),
                  Theme.of(context).colorScheme.primary.withOpacity(0.15)
                ]),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Theme.of(context).colorScheme.secondary.withOpacity(0.6), width: 1.5),
              ),
              child: Row(
                children: [
                  Icon(Icons.workspace_premium_rounded, color: Theme.of(context).colorScheme.secondary, size: 32),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment.start,
                      children: [
                        Text('Ustalık Parlıyor!',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(color: Theme.of(context).colorScheme.secondary, fontWeight: FontWeight.bold)),
                        Text('Bu Cevher sınavında %80+ başarıyla ekstra bir yükseliş yakaladın.',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                      ],
                    ),
                  )
                ],
              ),
            ).animate().fadeIn(duration: 500.ms).slideY(begin: -0.2),
            const SizedBox(height: 20),
          ],
          Text(
            "Ustalık Sınavı Tamamlandı!",
            style: Theme.of(context).textTheme.headlineMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            "%${widget.score.toStringAsFixed(0)}",
            style: Theme.of(context)
                .textTheme
                .displayLarge
                ?.copyWith(color: Theme.of(context).colorScheme.secondary, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          Text(
            "Başarı Oranı",
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
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
                  SnackBar(
                      content: const Text("Cevher başarıyla kasana eklendi!"),
                      backgroundColor: Theme.of(context).colorScheme.secondary),
                );
              }
            },
            overrideColor: _isSaved ? Theme.of(context).colorScheme.secondary : null,
            child: (_isSaving) ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator()) : null,
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
                MarkdownWithMath(
                  data: "Soru ${index + 1}: ${question.question}",
                  styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                    p: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                const SizedBox(height: 16),
                ...List.generate(question.options.length, (optIndex) {
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: MarkdownWithMath(
                      data: question.options[optIndex],
                      styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                        p: TextStyle(
                      color: optIndex == question.correctOptionIndex
                          ? Theme.of(context).colorScheme.secondary
                          : (optIndex == userAnswer && !isCorrect
                              ? Theme.of(context).colorScheme.error
                              : Theme.of(context).colorScheme.onSurface),
                        ),
                      ),
                    ),
                    leading: Icon(
                  optIndex == question.correctOptionIndex
                      ? Icons.check_circle_rounded
                      : (optIndex == userAnswer && !isCorrect ? Icons.cancel_rounded : Icons.radio_button_unchecked_rounded),
                  color: optIndex == question.correctOptionIndex
                      ? Theme.of(context).colorScheme.secondary
                      : (optIndex == userAnswer && !isCorrect
                          ? Theme.of(context).colorScheme.error
                          : Theme.of(context).colorScheme.onSurfaceVariant),
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
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      color: isPrimary ? colorScheme.secondary.withOpacity(0.2) : colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
            color: overrideColor ?? (isPrimary ? colorScheme.secondary : colorScheme.surfaceVariant),
            width: 1.5),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Row(
            children: [
              Icon(icon,
                  color: overrideColor ?? (isPrimary ? colorScheme.secondary : colorScheme.onSurfaceVariant),
                  size: 28),
              const SizedBox(width: 16),
              Expanded(
                  child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleLarge),
                  Text(subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant)),
                ],
              )),
              if (child != null) Padding(padding: const EdgeInsets.only(left: 16), child: child),
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
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline_rounded, color: colorScheme.error, size: 64),
          const SizedBox(height: 24),
          Text(
            "Bir Sorun Oluştu",
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            "Cevher işlenirken beklenmedik bir sorunla karşılaşıldı. Lütfen tekrar dene.\n\nHata: $error",
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: colorScheme.onSurfaceVariant),
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
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
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
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
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
          color: Theme.of(context).colorScheme.surface,
          border: Border(top: BorderSide(color: Theme.of(context).colorScheme.surfaceVariant, width: 1)),
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

class _ReportIssueSheet extends StatefulWidget {
  final String subject;
  final String topic;
  final String question;
  final List<String> options;
  final int correctIndex;
  final int? selectedIndex;
  final Future<void> Function(String reason) onSubmit;
  const _ReportIssueSheet({required this.subject, required this.topic, required this.question, required this.options, required this.correctIndex, this.selectedIndex, required this.onSubmit});

  @override
  State<_ReportIssueSheet> createState() => _ReportIssueSheetState();
}

class _ReportIssueSheetState extends State<_ReportIssueSheet> {
  String _reason = '';
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.flag_outlined, color: Theme.of(context).colorScheme.secondary),
                const SizedBox(width: 8),
                Text('Sorun Bildir', style: Theme.of(context).textTheme.titleLarge),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8, runSpacing: 8,
              children: [
                _reasonChip('Yanlış cevap anahtarı'),
                _reasonChip('Kötü yazım/ifade'),
                _reasonChip('Müfredat dışı'),
                _reasonChip('Tekrarlayan şıklar'),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              minLines: 2, maxLines: 4,
              decoration: const InputDecoration(hintText: 'İstersen detay ekle...'),
              onChanged: (v) => _reason = v,
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: () async {
                  final r = _reason.isEmpty ? 'Genel rapor' : _reason;
                  await widget.onSubmit(r);
                },
                icon: const Icon(Icons.send_rounded),
                label: const Text('Gönder'),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _reasonChip(String label) {
    return ChoiceChip(
      label: Text(label),
      selected: _reason == label,
      onSelected: (_) => setState(() => _reason = label),
    );
  }
}

class _WSHeader extends StatelessWidget {
  final bool showBack;
  final VoidCallback? onBack;
  final bool showStats;
  final VoidCallback onStats;
  final VoidCallback onSaved;
  final String title;
  const _WSHeader({required this.showBack, required this.onBack, required this.showStats, required this.onStats, required this.onSaved, required this.title});

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Container(
      padding: EdgeInsets.fromLTRB(16, top + 8, 16, 16),
      decoration: const BoxDecoration(
        // arka plan glow ile birleşsin diye şeffaf bırakıldı
        color: Colors.transparent,
      ),
      child: Row(
        children: [
          if (showBack)
            IconButton(
              onPressed: onBack,
              icon: Icon(Icons.arrow_back_ios_new_rounded, color: Theme.of(context).colorScheme.onSurface),
              style: IconButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.08),
                  shape: const CircleBorder()),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Theme.of(context).colorScheme.surfaceVariant),
              ),
              child: Row(
                children: [
                  Icon(Icons.diamond_rounded, color: Theme.of(context).colorScheme.secondary),
                  const SizedBox(width: 8),
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                ],
              ),
            ),
          const Spacer(),
          if (showStats)
            IconButton(
              tooltip: 'Atölye Raporu',
              onPressed: onStats,
              icon: Icon(Icons.bar_chart_rounded, color: Theme.of(context).colorScheme.onSurface),
              style: IconButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.08),
                  shape: const CircleBorder()),
            ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Cevher Kasası',
            onPressed: onSaved,
            icon: Icon(Icons.inventory_2_outlined, color: Theme.of(context).colorScheme.onSurface),
            style: IconButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.08),
                shape: const CircleBorder()),
          ),
        ],
      ),
    );
  }
}
