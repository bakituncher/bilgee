// lib/features/weakness_workshop/screens/weakness_workshop_screen.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:taktik/data/repositories/ai_service.dart';
import 'package:taktik/data/providers/firestore_providers.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:taktik/features/weakness_workshop/models/workshop_model.dart';
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
import 'package:taktik/features/weakness_workshop/logic/workshop_controller.dart';
import 'package:taktik/data/models/exam_model.dart';
import 'package:taktik/features/weakness_workshop/widgets/quiz_view.dart';

// DEPRECATED: Eski enum ve provider'lar - Artık WorkshopController içinde
// Geriye dönük uyumluluk için kalsın ama yeni kullanmayın
enum WorkshopStep { briefing, contentSelection, study, quiz, results }

final _selectedTopicProvider = StateProvider<Map<String, String>?>((ref) => null);
final _difficultyProvider = StateProvider<(String, int)>((ref) => ('normal', 1));
final _contentTypeProvider = StateProvider<String>((ref) => 'both'); // 'quizOnly', 'studyOnly', 'both'

final workshopSessionProvider = FutureProvider.autoDispose<WorkshopModel>((ref) async {
  final selectedTopic = ref.watch(_selectedTopicProvider);
  final difficultyInfo = ref.watch(_difficultyProvider);
  final contentType = ref.watch(_contentTypeProvider);

  if (selectedTopic == null) {
    return Future.error("Konu seçilmedi.");
  }

  final user = ref.read(userProfileProvider).value;
  final tests = ref.read(testsProvider).value;
  final performance = ref.read(performanceProvider).value;

  if (user == null || tests == null || performance == null) {
    return Future.error("Analiz için kullanıcı, test veya performans verisi bulunamadı.");
  }

  Future<WorkshopModel> attempt({double? temperature}) async {
    final jsonString = await ref.read(aiServiceProvider).generateStudyGuideAndQuiz(
      user,
      tests,
      performance,
      topicOverride: selectedTopic,
      difficulty: difficultyInfo.$1,
      attemptCount: difficultyInfo.$2,
      temperature: temperature,
      contentType: contentType,
    ).timeout(
      const Duration(seconds: 120), // 2 dakika - yeterince uzun
      onTimeout: () => throw TimeoutException('İçerik hazırlanırken zaman aşımı. İnternet bağlantını kontrol edip tekrar dene.'),
    );

    final decodedJson = jsonDecode(jsonString);
    if (decodedJson.containsKey('error')) {
      throw Exception(decodedJson['error']);
    }
    final raw = WorkshopModel.fromAIJson(decodedJson);
    final guarded = QuizQualityGuard.apply(raw).material;
    return guarded;
  }

  // Tek deneme yeterli - timeout yeterince uzun
  try {
    return await attempt(temperature: 0.4);
  } catch (e) {
    // Kullanıcı dostu hata mesajı
    final errorMsg = e.toString();
    if (errorMsg.contains('timeout') || errorMsg.contains('Timeout')) {
      throw Exception('İçerik hazırlanırken zaman aşımı. Lütfen tekrar dene.');
    } else if (errorMsg.contains('Analiz için') || errorMsg.contains('test veya performans')) {
      throw Exception('Etüt Odası\'nı kullanmak için önce deneme çözmelisin.');
    }
    throw Exception('Beklenmeyen bir hata oluştu. Lütfen tekrar dene.');
  }
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
  int _currentQuizPage = 0;

  void _startWorkshop(Map<String, String> topic) {
    ref.read(_selectedTopicProvider.notifier).state = topic;
    ref.read(_difficultyProvider.notifier).state = ('normal', 1);
    _selectedAnswers = {};
    _masteredAchieved = false;

    // Bottom sheet ile içerik türü seçimi göster
    _showContentTypeBottomSheet(context, topic);
  }

  void _showContentTypeBottomSheet(BuildContext context, Map<String, String> topic) {
    final topicName = topic['topic'] ?? 'Konu';
    final colorScheme = Theme.of(context).colorScheme;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Handle bar
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colorScheme.onSurfaceVariant.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                // Başlık
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
                  child: RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                      children: [
                        TextSpan(
                          text: topicName,
                          style: TextStyle(
                            color: colorScheme.primary,
                          ),
                        ),
                        const TextSpan(text: ' konusu için\nnasıl çalışmayı tercih edersin?'),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Seçenekler
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      _buildBottomSheetOption(
                        context,
                        icon: Icons.school_rounded,
                        title: 'Konu Anlatımı ve Sınav',
                        subtitle: 'Hem öğren, hem test et',
                        onTap: () {
                          Navigator.pop(context);
                          _selectContentType('both');
                        },
                      ),

                      const SizedBox(height: 12),

                      _buildBottomSheetOption(
                        context,
                        icon: Icons.quiz_rounded,
                        title: 'Sadece Sınav',
                        subtitle: 'Kendini test et',
                        onTap: () {
                          Navigator.pop(context);
                          _selectContentType('quizOnly');
                        },
                      ),

                      const SizedBox(height: 12),

                      _buildBottomSheetOption(
                        context,
                        icon: Icons.menu_book_rounded,
                        title: 'Sadece Konu',
                        subtitle: 'Konuyu öğren',
                        onTap: () {
                          Navigator.pop(context);
                          _selectContentType('studyOnly');
                        },
                      ),

                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBottomSheetOption(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          splashColor: colorScheme.primary.withValues(alpha: 0.12),
          highlightColor: colorScheme.primary.withValues(alpha: 0.08),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: colorScheme.onSurfaceVariant,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16,
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _selectContentType(String contentType) {
    // contentType: 'quizOnly', 'studyOnly', 'both'
    ref.read(_contentTypeProvider.notifier).state = contentType;
    // Artık workshop provider'ı tetiklenecek
    setState(() => _currentStep = WorkshopStep.study);
  }

  void _submitQuiz(WorkshopModel material) {
    final user = ref.read(userProfileProvider).value;
    final performanceSummary = ref.read(performanceProvider).value;
    if(user == null || performanceSummary == null || material.quiz == null || material.quiz!.isEmpty) return;

    int correct = 0;
    int wrong = 0;
    material.quiz!.asMap().forEach((index, q) {
      if (_selectedAnswers.containsKey(index)) {
        if (_selectedAnswers[index] == q.correctOptionIndex) {
          correct++;
        } else {
          wrong++;
        }
      }
    });
    int blank = (material.quiz?.length ?? 0) - correct - wrong;

    final firestoreService = ref.read(firestoreServiceProvider);
    final sanitizedSubject = firestoreService.sanitizeKey(material.subject);
    final sanitizedTopic = firestoreService.sanitizeKey(material.topic);

    final currentPerformance = performanceSummary.topicPerformances[sanitizedSubject]?[sanitizedTopic] ?? TopicPerformanceModel();
    final newPerformance = TopicPerformanceModel(
      correctCount: currentPerformance.correctCount + correct,
      wrongCount: currentPerformance.wrongCount + wrong,
      blankCount: currentPerformance.blankCount + blank,
      questionCount: currentPerformance.questionCount + (material.quiz?.length ?? 0),
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
    final double quizScore = (material.quiz?.isEmpty ?? true) ? 0.0 : (correct / material.quiz!.length);

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
          // Quiz ve results adımında renkli arka planı gizle - siyah-beyaz tema için
          if (_currentStep != WorkshopStep.quiz && _currentStep != WorkshopStep.results)
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
                    // Quiz'den geri dönüş: contentType'a göre karar ver
                    final contentType = ref.read(_contentTypeProvider);
                    if (contentType == 'quizOnly') {
                      // Sadece quiz modundaysa briefing'e dön
                      _resetToBriefing();
                    } else {
                      // Study varsa study'e dön
                      setState(() => _currentStep = WorkshopStep.study);
                    }
                  } else if(_currentStep == WorkshopStep.study){
                    // Study'den briefing'e dön
                    _resetToBriefing();
                  } else {
                    _resetToBriefing();
                  }
                },
                onSaved: (_currentStep == WorkshopStep.briefing || _currentStep == WorkshopStep.contentSelection)
                    ? () => context.push('/ai-hub/weakness-workshop/${AppRoutes.savedWorkshops}')
                    : null,
                title: 'Etüt Odası',
                center: (_currentStep == WorkshopStep.quiz)
                    ? Consumer(
                        builder: (context, ref, _) {
                          final session = ref.watch(workshopSessionProvider).value;
                          final total = session?.quiz?.length ?? 0;
                          final safeTotal = total <= 0 ? 1 : total;
                          final safeIndex = _currentQuizPage.clamp(0, safeTotal - 1);

                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.06),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Theme.of(context).colorScheme.surfaceContainerHighest),
                            ),
                            child: Text(
                              '${safeIndex + 1}/$total',
                              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context).colorScheme.onSurface,
                                  ),
                            ),
                          );
                        },
                      )
                    : null,
                trailing: (_currentStep == WorkshopStep.quiz)
                    ? Consumer(
                        builder: (context, ref, _) {
                          final session = ref.watch(workshopSessionProvider).value;
                          final total = session?.quiz?.length ?? 0;
                          final safeTotal = total <= 0 ? 1 : total;
                          final safeIndex = _currentQuizPage.clamp(0, safeTotal - 1);

                          return IconButton(
                            tooltip: 'Sorunu Bildir',
                            onPressed: total == 0
                                ? null
                                : () {
                                    final material = session;
                                    if (material == null) return;
                                    _openReportSheet(material, safeIndex, _selectedAnswers[safeIndex]);
                                  },
                            icon: Icon(
                              Icons.flag_outlined,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                            style: IconButton.styleFrom(
                              backgroundColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.08),
                              shape: const CircleBorder(),
                            ),
                          );
                        },
                      )
                    : null,
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
        // ContentType'a göre otomatik adım belirleme
        final contentType = ref.read(_contentTypeProvider);

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

        // quizOnly modundaysa ve hala study adımındaysak, quiz'e geç
        if (contentType == 'quizOnly' && _currentStep == WorkshopStep.study) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() => _currentStep = WorkshopStep.quiz);
            }
          });
          return const _LoadingCevherView(key: ValueKey('loading_quiz'));
        }

        switch (_currentStep) {
          case WorkshopStep.study:
            return _StudyView(
              key: ValueKey('study_${material.topic}_${ref.read(_difficultyProvider)}'),
              material: material,
              onStartQuiz: () => setState(() => _currentStep = WorkshopStep.quiz),
            );
          case WorkshopStep.quiz:
            return QuizView(
              key: ValueKey('quiz_${material.topic}_${ref.read(_difficultyProvider)}'),
              material: material,
              onSubmit: () => _submitQuiz(material),
              selectedAnswers: _selectedAnswers,
              onAnswerSelected: (q, a) => setState(() => _selectedAnswers[q] = a),
              onReportIssue: (qIndex) {
                _openReportSheet(material, qIndex, _selectedAnswers[qIndex]);
              },
              onPageChanged: (page) {
                if (!mounted) return;
                setState(() => _currentQuizPage = page);
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

  void _openReportSheet(WorkshopModel material, int qIndex, int? selected) {
    if (material.quiz == null || qIndex >= material.quiz!.length) return;
    final q = material.quiz![qIndex];
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

class _FancyBackground extends StatelessWidget {
  const _FancyBackground();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      color: colorScheme.surface,
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
            ).animate(onPlay: (c) => c.repeat())
           .shimmer(duration: 1800.ms, color: Theme.of(context).colorScheme.secondary.withOpacity(0.5)),
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
    final analysisAsync = ref.watch(overallStatsAnalysisProvider);
    final firestoreService = ref.read(firestoreServiceProvider);

    if (user == null || tests == null || user.selectedExam == null || performance == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return analysisAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, st) => Center(child: Text('Analiz yüklenemedi: $e')),
      data: (analysis) {
        final suggestions = analysis?.getWorkshopSuggestions(count: 5) ?? [];

        if (suggestions.isEmpty) {
          return _EmptyStateView();
        }

        final colorScheme = Theme.of(context).colorScheme;
        final textTheme = Theme.of(context).textTheme;

        return ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          children: [
            // Başlık
            Center(
              child: Text(
                "Senin İçin Önerilen Konular",
                style: textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Konu kartları
            ...suggestions.asMap().entries.map((entry) {
              final idx = entry.key;
              final topicData = entry.value;
              final subject = topicData['subject']?.toString() ?? '';
              final topic = topicData['topic']?.toString() ?? '';

              // Performance verilerini çek
              final sanitizedSubject = firestoreService.sanitizeKey(subject);
              final sanitizedTopic = firestoreService.sanitizeKey(topic);
              final topicPerformance = performance.topicPerformances[sanitizedSubject]?[sanitizedTopic];

              final int correctCount = topicPerformance?.correctCount ?? 0;
              final int wrongCount = topicPerformance?.wrongCount ?? 0;
              final int questionCount = topicPerformance?.questionCount ?? 0;
              final int answered = correctCount + wrongCount;
              final double accuracy = answered > 0 ? correctCount / answered : 0.0;

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _buildTopicCard(
                  context,
                  subject: subject,
                  topic: topic,
                  accuracy: accuracy,
                  questionCount: questionCount,
                  onTap: () => onTopicSelected({
                    'subject': subject,
                    'topic': topic,
                  }),
                ),
              ).animate().fadeIn(delay: (100 * idx).ms).slideX(begin: 0.1, end: 0);
            }),

            const SizedBox(height: 8),

            // Manuel konu seç butonu
            TextButton.icon(
              onPressed: () => _showManualTopicSelector(context, ref, onTopicSelected),
              icon: const Icon(Icons.search_rounded, size: 20),
              label: const Text("Farklı bir konu seç"),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ).animate().fadeIn(delay: 400.ms),
          ],
        );
      },
    );
  }

  Widget _buildTopicCard(
    BuildContext context, {
    required String subject,
    required String topic,
    required double accuracy,
    required int questionCount,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    // Doğruluk yüzdesine göre renk
    Color getAccuracyColor() {
      if (accuracy >= 0.7) return Colors.green;
      if (accuracy >= 0.5) return Colors.orange;
      return Colors.red;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.5), width: 1),
          ),
          child: Row(
            children: [
              // Sol taraf - Konu bilgisi
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Ders adı
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: colorScheme.secondaryContainer.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        subject,
                        style: textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSecondaryContainer,
                          fontWeight: FontWeight.w600,
                          fontSize: 10,
                        ),
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Konu adı
                    Text(
                      topic,
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),

                    const SizedBox(height: 6),

                    // İstatistikler - konu isminin altında
                    Row(
                      children: [
                        // Doğruluk badge'i
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: getAccuracyColor().withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.check_circle_rounded,
                                size: 12,
                                color: getAccuracyColor(),
                              ),
                              const SizedBox(width: 3),
                              Text(
                                "%${(accuracy * 100).toStringAsFixed(0)} başarı",
                                style: textTheme.labelSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10,
                                  color: getAccuracyColor(),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(width: 4),

                        // Soru sayısı badge'i
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.quiz_outlined,
                                size: 12,
                                color: colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                "$questionCount soru",
                                style: textTheme.labelSmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // Ok ikonu
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 18,
                color: colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showManualTopicSelector(
    BuildContext context,
    WidgetRef ref,
    Function(Map<String, String>) onTopicSelected,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ManualTopicSelectorSheet(
        onTopicSelected: onTopicSelected,
      ),
    );
  }
}
class _EmptyStateView extends StatelessWidget {
  const _EmptyStateView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.insert_chart_outlined_rounded,
                size: 60,
                color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.5),
              ),
            ).animate().fadeIn(duration: 600.ms).scale(delay: 200.ms),
            const SizedBox(height: 16),
            Text(
              "Henüz Ders Neti Yok",
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.3),
            const SizedBox(height: 8),
            Text(
              "Etüt Odası'nın sana özel içerik üretebilmesi için önce ders neti eklemelisin.",
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ).animate().fadeIn(delay: 600.ms),
            const SizedBox(height: 16),
            Card(
              color: Theme.of(context).colorScheme.secondaryContainer.withOpacity(0.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: Theme.of(context).colorScheme.secondary.withOpacity(0.3),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.lightbulb_outline_rounded,
                          size: 24,
                          color: Theme.of(context).colorScheme.secondary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          "Nasıl Başlarım?",
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "1. Ders netlerini ekle\n2. Taktik Tavşan en zayıf konuları analiz edecek\n3. Özel çalışma materyallerine eriş!",
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ).animate().fadeIn(delay: 800.ms).slideY(begin: 0.3),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                context.go(AppRoutes.coach);
              },
              icon: const Icon(Icons.add_chart_rounded, size: 20),
              label: const Text("Ders Neti Ekle"),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ).animate().fadeIn(delay: 1000.ms).scale(),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () {
                if (Navigator.of(context).canPop()) {
                  context.pop();
                } else {
                  context.go(AppRoutes.home);
                }
              },
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 14),
              label: const Text("Ana Sayfaya Dön"),
            ).animate().fadeIn(delay: 1100.ms),
          ],
        ),
      ),
    );
  }
}


class _StudyView extends StatelessWidget {
  final WorkshopModel material;
  final VoidCallback onStartQuiz;
  const _StudyView({super.key, required this.material, required this.onStartQuiz});

  @override
  Widget build(BuildContext context) {
    // StudyGuide yoksa boş durum göster
    if (material.studyGuide == null || material.studyGuide!.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Text('Konu anlatımı oluşturulmadı.', textAlign: TextAlign.center),
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                MarkdownWithMath(
                  data: material.studyGuide!,
                  styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                    p: TextStyle(fontSize: 15, height: 1.5, color: Theme.of(context).colorScheme.onSurface),
                    h1: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.secondary),
                    h2: TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary),
                    h3: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurface),
                    listBullet: TextStyle(fontSize: 15),
                    code: TextStyle(fontSize: 14, backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5)),
                  ),
                ),
              ],
            ),
          ),
        ),
        // Quiz varsa buton göster
        if (material.quiz != null && material.quiz!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            child: ElevatedButton.icon(
              icon: const Icon(Icons.quiz_rounded, size: 20),
              label: const Text("Teste Başla"),
              onPressed: onStartQuiz,
            ),
          ),
      ],
    );
  }
}

class _ResultsView extends StatefulWidget {
  final WorkshopModel material;
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
    if (widget.material.quiz != null) {
      widget.material.quiz!.asMap().forEach((index, q) {
        if (widget.selectedAnswers[index] == q.correctOptionIndex) correct++;
      });
    }
    final score = (widget.material.quiz?.isEmpty ?? true) ? 0.0 : (correct / widget.material.quiz!.length) * 100;

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
                  QuizReviewView(
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
  final WorkshopModel material;
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
                color: Theme.of(context).colorScheme.secondary.withOpacity(0.1),
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
                color: Theme.of(context).colorScheme.secondary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Theme.of(context).colorScheme.secondary.withOpacity(0.6), width: 1.5),
              ),
              child: Row(
                children: [
                  Icon(Icons.workspace_premium_rounded, color: Theme.of(context).colorScheme.secondary, size: 32),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Ustalık Parlıyor!',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(color: Theme.of(context).colorScheme.secondary, fontWeight: FontWeight.bold)),
                        Text('Bu testte %80+ başarıyla ekstra bir yükseliş yakaladın.',
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
            "Test Tamamlandı!",
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
          const SizedBox(height: 32),

          _ResultActionCard(
            title: "Derinleşmek İstiyorum",
            subtitle: "Daha zor sorularla kendini test et",
            icon: Icons.auto_awesome_rounded,
            onTap: widget.onRetryHarder,
            isPrimary: true,
          ),
          const SizedBox(height: 12),
          _ResultActionCard(
            title: "Testi Kaydet",
            subtitle: "Daha sonra tekrar çalışmak için kaydet",
            icon: _isSaved ? Icons.check_circle_rounded : Icons.bookmark_add_rounded,
            onTap: (_isSaving || _isSaved) ? (){} : () async {
              setState(() => _isSaving = true);
              final userId = ref.read(authControllerProvider).value!.uid;
              final workshopToSave = widget.material.copyWith(id: const Uuid().v4());
              await ref.read(firestoreServiceProvider).saveWorkshopForUser(userId, workshopToSave);
              if (mounted) {
                setState(() {
                  _isSaving = false;
                  _isSaved = true;
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content: const Text("Test başarıyla eklendi!"),
                      backgroundColor: Theme.of(context).colorScheme.secondary),
                );
              }
            },
            overrideColor: _isSaved ? Theme.of(context).colorScheme.secondary : null,
            child: (_isSaving) ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator()) : null,
          ),
          const SizedBox(height: 12),
          _ResultActionCard(
            title: "Sıradaki Konuya Geç",
            subtitle: "Başka bir zayıf konu üzerinde çalış",
            icon: Icons.diamond_outlined,
            onTap: widget.onNextTopic,
          ),
        ],
      ).animate().fadeIn(duration: 500.ms),
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
            color: overrideColor ?? (isPrimary ? colorScheme.secondary : colorScheme.surfaceContainerHighest),
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
            "Beklenmedik bir sorunla karşılaşıldı. Lütfen tekrar dene.\n\nHata: $error",
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

class _DeepenWorkshopSheet extends ConsumerWidget {
  final Function(String difficulty, bool invalidate, bool skipStudy) onOptionSelected;
  const _DeepenWorkshopSheet({required this.onOptionSelected});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contentType = ref.watch(_contentTypeProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.auto_awesome_rounded,
                color: colorScheme.secondary,
                size: 28,
              ),
              const SizedBox(width: 12),
              Text(
                "Zorluk Seviyesi Seç",
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            "Daha zorlu sorularla kendini test et",
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),

          // Orta Zorluk
          _DifficultyOption(
            title: "Orta Zorluk",
            subtitle: "Sınav seviyende ama daha zorlayıcı sorular",
            icon: Icons.trending_up_rounded,
            color: Colors.orange,
            onTap: () => onOptionSelected('normal', true, contentType == 'quizOnly'),
          ),
          const SizedBox(height: 12),

          // Zor
          _DifficultyOption(
            title: "Zor",
            subtitle: "Çeldirici ve çok adımlı sorular",
            icon: Icons.whatshot_rounded,
            color: Colors.red,
            isPrimary: true,
            onTap: () => onOptionSelected('hard', true, contentType == 'quizOnly'),
          ),
        ],
      ),
    );
  }
}

class _DifficultyOption extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool isPrimary;

  const _DifficultyOption({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isPrimary
              ? color.withOpacity(0.1)
              : colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isPrimary ? color.withOpacity(0.4) : colorScheme.surfaceContainerHighest,
              width: isPrimary ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: colorScheme.onSurfaceVariant.withOpacity(0.5),
              ),
            ],
          ),
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

  const _ReportIssueSheet({
    required this.subject,
    required this.topic,
    required this.question,
    required this.options,
    required this.correctIndex,
    this.selectedIndex,
    required this.onSubmit,
  });

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
              spacing: 8,
              runSpacing: 8,
              children: [
                _reasonChip('Yanlış cevap anahtarı'),
                _reasonChip('Kötü yazım/ifade'),
                _reasonChip('Müfredat dışı'),
                _reasonChip('Tekrarlayan şıklar'),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              minLines: 2,
              maxLines: 4,
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
  final VoidCallback? onSaved; // Nullable yaptık
  final String title;
  final Widget? trailing;
  final Widget? center;

  const _WSHeader({
    required this.showBack,
    required this.onBack,
    this.onSaved, // Required kaldırdık
    required this.title,
    this.trailing,
    this.center,
  });

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;

    final left = showBack
        ? IconButton(
            onPressed: onBack,
            icon: Icon(Icons.arrow_back_ios_new_rounded, color: Theme.of(context).colorScheme.onSurface),
            style: IconButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.08),
              shape: const CircleBorder(),
            ),
          )
        : Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Theme.of(context).colorScheme.surfaceContainerHighest),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.diamond_rounded, color: Theme.of(context).colorScheme.secondary),
                const SizedBox(width: 8),
                Text(title, style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
          );

    final rightActions = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (trailing != null) ...[
          trailing!,
          const SizedBox(width: 8),
        ],
        if (onSaved != null)
          IconButton(
            tooltip: 'Etüt Geçmişi',
            onPressed: onSaved,
            icon: Icon(Icons.inventory_2_outlined, color: Theme.of(context).colorScheme.onSurface),
            style: IconButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.08),
              shape: const CircleBorder(),
            ),
          ),
      ],
    );

    return Container(
      padding: EdgeInsets.fromLTRB(16, top + 8, 16, 16),
      decoration: const BoxDecoration(color: Colors.transparent),
      child: SizedBox(
        height: 44,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Align(alignment: Alignment.centerLeft, child: left),
            if (center != null) Center(child: center!),
            Align(alignment: Alignment.centerRight, child: rightActions),
          ],
        ),
      ),
    );
  }
}

class _ManualTopicSelectorSheet extends ConsumerStatefulWidget {
  final Function(Map<String, String>) onTopicSelected;

  const _ManualTopicSelectorSheet({required this.onTopicSelected});

  @override
  ConsumerState<_ManualTopicSelectorSheet> createState() => _ManualTopicSelectorSheetState();
}

class _ManualTopicSelectorSheetState extends ConsumerState<_ManualTopicSelectorSheet> {
  String _searchQuery = '';
  String? _selectedSubject;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final user = ref.watch(userProfileProvider).value;
    final tests = ref.watch(testsProvider).value;

    if (user?.selectedExam == null) {
      return _buildErrorContainer(context, 'Sınav türü seçilmemiş');
    }

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: colorScheme.surfaceContainerHighest,
                      width: 1,
                    ),
                  ),
                ),
                child: Column(
                  children: [
                    // Drag handle
                    Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: colorScheme.onSurfaceVariant.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Row(
                      children: [
                        Icon(
                          Icons.search_rounded,
                          color: colorScheme.primary,
                          size: 28,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Konu Seç',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close_rounded),
                          style: IconButton.styleFrom(
                            backgroundColor: colorScheme.surfaceContainerHighest,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Search bar
                    TextField(
                      decoration: InputDecoration(
                        hintText: 'Konu ara...',
                        prefixIcon: const Icon(Icons.search_rounded, size: 20),
                        filled: true,
                        fillColor: colorScheme.surfaceContainerHighest.withOpacity(0.5),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      onChanged: (value) {
                        setState(() => _searchQuery = value.toLowerCase());
                      },
                    ),
                  ],
                ),
              ),

              // Content
              Expanded(
                child: FutureBuilder<Map<String, List<String>>>(
                  future: _loadTopicsBySubject(user!.selectedExam!),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (snapshot.hasError || !snapshot.hasData) {
                      return Center(
                        child: Text(
                          'Konular yüklenemedi',
                          style: TextStyle(color: colorScheme.onSurfaceVariant),
                        ),
                      );
                    }

                    final topicsBySubject = snapshot.data!;
                    final filteredTopics = _filterTopics(topicsBySubject);

                    return ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.all(16),
                      children: filteredTopics.entries.map((entry) {
                        final subject = entry.key;
                        final topics = entry.value;

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Ders başlığı
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 12,
                              ),
                              child: Text(
                                subject,
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.primary,
                                ),
                              ),
                            ),
                            // Konular
                            ...topics.map((topic) => _buildTopicTile(
                              context,
                              subject,
                              topic,
                            )),
                            const SizedBox(height: 8),
                          ],
                        );
                      }).toList(),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTopicTile(BuildContext context, String subject, String topic) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: colorScheme.surfaceContainerHighest,
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: () {
          Navigator.pop(context);
          widget.onTopicSelected({
            'subject': subject,
            'topic': topic,
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.bookmark_outline_rounded,
                  size: 20,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  topic,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: colorScheme.onSurfaceVariant.withOpacity(0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorContainer(BuildContext context, String message) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Center(
        child: Text(
          message,
          style: Theme.of(context).textTheme.bodyLarge,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Future<Map<String, List<String>>> _loadTopicsBySubject(String examType) async {
    try {
      final ExamType examEnum = ExamType.values.byName(examType);
      final examData = await ExamData.getExamByType(examEnum);

      final Map<String, List<String>> topicsBySubject = {};

      // Her section'ı gez
      for (var section in examData.sections) {
        // Her section içindeki subjects'i gez
        for (var subjectEntry in section.subjects.entries) {
          final subjectName = subjectEntry.key;
          final subjectDetails = subjectEntry.value;

          final topics = subjectDetails.topics.map((topic) => topic.name).toList();

          if (topics.isNotEmpty) {
            // Eğer aynı ders başka section'da da varsa birleştir
            if (topicsBySubject.containsKey(subjectName)) {
              topicsBySubject[subjectName]!.addAll(topics);
              // Tekrarları kaldır
              topicsBySubject[subjectName] = topicsBySubject[subjectName]!.toSet().toList();
            } else {
              topicsBySubject[subjectName] = topics;
            }
          }
        }
      }

      return topicsBySubject;
    } catch (e) {
      debugPrint('Error loading topics: $e');
      return {};
    }
  }

  Map<String, List<String>> _filterTopics(Map<String, List<String>> allTopics) {
    if (_searchQuery.isEmpty) {
      return allTopics;
    }

    final filtered = <String, List<String>>{};

    for (var entry in allTopics.entries) {
      final subject = entry.key;
      final topics = entry.value;

      // Ders adında arama
      final subjectMatches = subject.toLowerCase().contains(_searchQuery);

      // Konularda arama
      final matchingTopics = topics.where((topic) {
        return topic.toLowerCase().contains(_searchQuery);
      }).toList();

      if (subjectMatches) {
        // Ders adı eşleşiyorsa tüm konuları göster
        filtered[subject] = topics;
      } else if (matchingTopics.isNotEmpty) {
        // Sadece eşleşen konuları göster
        filtered[subject] = matchingTopics;
      }
    }

    return filtered;
  }
}
