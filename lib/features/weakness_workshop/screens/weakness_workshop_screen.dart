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
import 'package:taktik/core/safety/ai_content_safety.dart';
import 'package:taktik/features/weakness_workshop/logic/workshop_controller.dart';

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
      contentType: contentType, // İçerik türünü gönder
    ).timeout(
      // Gemini detaylı içerik üretirken 45sn yetmeyebilir, güvenli aralık 90sn'dir.
      const Duration(seconds: 90),
      onTimeout: () => throw TimeoutException('İçerik çok detaylı olduğu için hazırlanması zaman alıyor. Lütfen internet bağlantını kontrol edip tekrar dene.'),
    );

    final decodedJson = jsonDecode(jsonString);
    if (decodedJson.containsKey('error')) {
      throw Exception(decodedJson['error']);
    }
    final raw = WorkshopModel.fromAIJson(decodedJson);
    // Soru kalite güvencesi uygula (yetersizse hata fırlatır)
    final guarded = QuizQualityGuard.apply(raw).material;
    return guarded;
  }

  // 3 kere denemek yerine 2 kere deneyelim ama süreyi uzun tutalım.
  // Sıcaklık ayarını (temperature) düşürmek halüsinasyonu ve bozuk JSON riskini azaltır.
  final attempts = <double?>[0.3, 0.2]; // İlk deneme 0.3, başarısızsa 0.2
  Exception? lastErr;
  for (final t in attempts) {
    try {
      return await attempt(temperature: t);
    } catch (e) {
      lastErr = Exception(e.toString());
      // Hata loglayıp devam et
      debugPrint("Workshop deneme başarısız (Temp: $t): $e");
    }
  }
  throw lastErr ?? Exception('Bağlantı veya AI servisinde yoğunluk var. Lütfen tekrar deneyin.');
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
    setState(() => _currentStep = WorkshopStep.contentSelection);
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
              // AI güvenlik uyarısı
              if (_currentStep != WorkshopStep.briefing)
                AiContentSafety.buildDisclaimerBanner(
                  context,
                  customMessage: 'Çalışma kartı ve sorular AI ile üretilmiştir. Hata tespit ederseniz bildirim yapın.',
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

    if (_currentStep == WorkshopStep.contentSelection) {
      final selectedTopic = ref.watch(_selectedTopicProvider);
      return _ContentSelectionView(
        key: const ValueKey('content_selection'),
        topic: selectedTopic ?? {},
        onContentTypeSelected: _selectContentType,
        onBack: () => setState(() => _currentStep = WorkshopStep.briefing),
      );
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
                Color.lerp(colorScheme.surface, colorScheme.surface, t)!,
                Color.lerp(colorScheme.surface, colorScheme.surface, 1 - t)!,
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

        // Hiç veri yoksa özel ekran göster
        if (suggestions.isEmpty) {
          return _EmptyStateView();
        }

        return ListView(
          padding: const EdgeInsets.all(24.0),
          children: [
            Text("Stratejik Mola", style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text(
              "Taktik Tavşan, performansını analiz etti ve gelişim için en parlak fırsatları belirledi. Aşağıdaki cevherlerden birini seçerek işlemeye başla.",
              style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12), // 👈 Azaltıldı
            // 👈 Kompakt AI Uyarısı
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), // 👈 Daha ince
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.4),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 18, // 👈 Küçültüldü
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Taktik Tavşan hata yapabilir. Üretilen içerikleri kontrol et.",
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 12, // 👈 Küçültüldü
                      ),
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(delay: 100.ms),
            const SizedBox(height: 20), // 👈 Azaltıldı
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
              "Cevher Atölyesi'nin sana özel içerik üretebilmesi için önce ders neti eklemelisin.",
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

// YENİ: İçerik Türü Seçim Ekranı
class _ContentSelectionView extends StatelessWidget {
  final Map<String, String> topic;
  final Function(String) onContentTypeSelected;
  final VoidCallback onBack;

  const _ContentSelectionView({
    super.key,
    required this.topic,
    required this.onContentTypeSelected,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final topicName = topic['topic'] ?? 'Konu';
    final subjectName = topic['subject'] ?? 'Ders';
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            colorScheme.surface,
            colorScheme.surfaceContainerHighest.withOpacity(0.3),
          ],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Başlık bölümü
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
              child: Column(
                children: [
                  Text(
                    "Nasıl Çalışmak İstersin?",
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 24,
                      letterSpacing: -0.5,
                    ),
                    textAlign: TextAlign.center,
                  ).animate().fadeIn(delay: 100.ms).slideY(begin: -0.2),

                  const SizedBox(height: 12),

                  // Seçilen konu bilgisi (şık card)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          colorScheme.primary.withOpacity(0.15),
                          colorScheme.secondary.withOpacity(0.1),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: colorScheme.primary.withOpacity(0.3),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: colorScheme.primary.withOpacity(0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: colorScheme.primary.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.auto_awesome_rounded,
                            color: colorScheme.primary,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Flexible(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                subjectName,
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                topicName,
                                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.primary,
                                  fontSize: 15,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(delay: 200.ms).scale(begin: const Offset(0.95, 0.95)),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Seçenekler (şık kartlar)
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                children: [
                  _ContentTypeCard(
                    icon: Icons.quiz_rounded,
                    emoji: '🎯',
                    title: 'Sadece Sınav',
                    description: 'Direkt pratik yap, 5 soru ile başla',
                    color: const Color(0xFFFF6B35),
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF6B35), Color(0xFFFF8C42)],
                    ),
                    onTap: () => onContentTypeSelected('quizOnly'),
                  ).animate().fadeIn(delay: 300.ms).slideX(begin: 0.3),

                  const SizedBox(height: 14),

                  _ContentTypeCard(
                    icon: Icons.school_rounded,
                    emoji: '📚',
                    title: 'Sadece Konu Anlatımı',
                    description: 'Önce öğren, detaylı açıklamalar al',
                    color: const Color(0xFF4ECDC4),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF4ECDC4), Color(0xFF44A5A0)],
                    ),
                    onTap: () => onContentTypeSelected('studyOnly'),
                  ).animate().fadeIn(delay: 400.ms).slideX(begin: 0.3),

                  const SizedBox(height: 14),

                  _ContentTypeCard(
                    icon: Icons.auto_awesome_rounded,
                    emoji: '⚡',
                    title: 'Konu + Sınav',
                    description: 'Tam paket: Öğren ve test et kendini',
                    color: const Color(0xFF9B5DE5),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF9B5DE5), Color(0xFFB388FF)],
                    ),
                    isRecommended: true,
                    onTap: () => onContentTypeSelected('both'),
                  ).animate()
                    .fadeIn(delay: 500.ms)
                    .slideX(begin: 0.3)
                    .then()
                    .shimmer(duration: 1500.ms, color: Colors.white.withOpacity(0.3)),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContentTypeCard extends StatelessWidget {
  final IconData icon;
  final String emoji;
  final String title;
  final String description;
  final Color color;
  final Gradient? gradient;
  final bool isRecommended;
  final VoidCallback onTap;

  const _ContentTypeCard({
    super.key,
    required this.icon,
    required this.emoji,
    required this.title,
    required this.description,
    required this.color,
    this.gradient,
    this.isRecommended = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: gradient ?? LinearGradient(
          colors: [color, color.withOpacity(0.8)],
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.4),
            blurRadius: isRecommended ? 16 : 12,
            offset: Offset(0, isRecommended ? 6 : 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: isRecommended
                  ? Border.all(
                      color: Colors.white.withOpacity(0.3),
                      width: 2,
                    )
                  : null,
            ),
            child: Row(
              children: [
                // Emoji Container (Premium)
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.3),
                      width: 1.5,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      emoji,
                      style: const TextStyle(fontSize: 28),
                    ),
                  ),
                ),
                const SizedBox(width: 16),

                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                fontSize: 16,
                                letterSpacing: -0.3,
                              ),
                            ),
                          ),
                          if (isRecommended)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.25),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.4),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.star_rounded,
                                    color: Colors.white,
                                    size: 14,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'ÖNERİLEN',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        description,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 13,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 12),

                // Arrow Icon
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.arrow_forward_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
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
      margin: const EdgeInsets.only(bottom: 12), // 👈 Azaltıldı
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: isRecommended
            ? LinearGradient(colors: [colorScheme.secondary.withOpacity(0.2), Colors.transparent])
            : null,
      ),
      child: Card(
        elevation: 4, // 👈 Azaltıldı
        color: colorScheme.surface.withOpacity(0.9),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
              color: isRecommended ? colorScheme.secondary : colorScheme.surfaceContainerHighest,
              width: 1.5),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(14.0), // 👈 Azaltıldı
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (isRecommended)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), // 👈 Daha ince
                        decoration: BoxDecoration(color: colorScheme.secondary, borderRadius: BorderRadius.circular(6)),
                        child: Text(
                          "Taktik Tavşan ÖNERİSİ",
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: colorScheme.onSecondary, fontWeight: FontWeight.bold, letterSpacing: 0.8, fontSize: 10),
                        ),
                      ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: colorScheme.onSurface.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: colorScheme.surfaceContainerHighest),
                      ),
                      child: Row(children: [
                        Icon(Icons.bolt_rounded, size: 14, color: colorScheme.secondary),
                        const SizedBox(width: 4),
                        Text(masteryValue == null || masteryValue < 0 ? 'Keşif' : '%${(masteryValue * 100).toStringAsFixed(0)}',
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(fontSize: 11)),
                      ]),
                    ),
                  ],
                ),
                const SizedBox(height: 10), // 👈 Azaltıldı
                Text(topic['topic']!, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)), // 👈 Küçültüldü
                const SizedBox(height: 2),
                Text(topic['subject']!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant)),
                const SizedBox(height: 10), // 👈 Azaltıldı
                LinearProgressIndicator(
                  value: masteryValue == null || masteryValue < 0 ? null : masteryValue,
                  backgroundColor: colorScheme.surfaceContainerHighest.withOpacity(0.3),
                  color: masteryValue == null || masteryValue < 0
                      ? colorScheme.onSurfaceVariant
                      : Color.lerp(colorScheme.error, colorScheme.secondary, masteryValue),
                  borderRadius: BorderRadius.circular(4),
                  minHeight: 6, // 👈 Daha ince progress bar
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
              label: const Text("Ustalık Sınavına Başla"),
              onPressed: onStartQuiz,
            ),
          ),
      ],
    );
  }
}

class _QuizView extends StatefulWidget {
  final WorkshopModel material;
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
    // Quiz yoksa boş widget döndür
    if (widget.material.quiz == null || widget.material.quiz!.isEmpty) {
      return const Center(child: Text('Quiz bulunamadı'));
    }

    final quizLength = widget.material.quiz!.length;
    bool isCurrentPageAnswered = widget.selectedAnswers.containsKey(_currentPage);
    bool isQuizFinished = widget.selectedAnswers.length == quizLength;

    return Column(
      children: [
        // Progress bar (kompakt)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 12.0),
          child: LinearProgressIndicator(
            value: (_currentPage + 1) / quizLength,
            backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
            color: Theme.of(context).colorScheme.secondary,
            borderRadius: BorderRadius.circular(6),
            minHeight: 6,
          ),
        ),
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: quizLength,
            itemBuilder: (context, index) {
              final question = widget.material.quiz![index];
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
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            child: SafeArea(
              top: false,
              child: ElevatedButton.icon(
                icon: Icon(isQuizFinished ? Icons.assignment_turned_in_rounded : Icons.arrow_forward_ios_rounded, size: 20),
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

class _QuestionCard extends StatefulWidget {
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
  State<_QuestionCard> createState() => _QuestionCardState();
}

class _QuestionCardState extends State<_QuestionCard> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _explanationKey = GlobalKey();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(_QuestionCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Eğer cevap yeni işaretlendiyse ve yanlışsa, açıklamaya scroll yap
    if (oldWidget.selectedOptionIndex == null &&
        widget.selectedOptionIndex != null &&
        widget.selectedOptionIndex != widget.question.correctOptionIndex) {

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToExplanation();
      });
    }
  }

  void _scrollToExplanation() {
    if (_explanationKey.currentContext != null) {
      final RenderBox? renderBox = _explanationKey.currentContext!.findRenderObject() as RenderBox?;
      if (renderBox != null) {
        final position = renderBox.localToGlobal(Offset.zero);
        final scrollOffset = _scrollController.offset + position.dy - 100; // 100px üstten boşluk

        _scrollController.animateTo(
          scrollOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeOutCubic,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Kompakt header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Text(
                    "${widget.questionNumber}/${widget.totalQuestions}",
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: widget.onReportIssue,
                  icon: const Icon(Icons.flag_outlined, size: 18),
                  tooltip: 'Sorunu Bildir',
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Soru kartı
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                width: 1.5,
              ),
            ),
            child: MarkdownWithMath(
              data: widget.question.question,
              styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                p: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          ...List.generate(widget.question.options.length, (index) {
            bool isSelected = widget.selectedOptionIndex == index;
            bool isCorrect = widget.question.correctOptionIndex == index;
            Color? tileColor;
            Color? borderColor;
            IconData? trailingIcon;

            final colorScheme = Theme.of(context).colorScheme;

            if (widget.selectedOptionIndex != null) {
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

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: tileColor ?? colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: borderColor ?? colorScheme.surfaceContainerHighest.withOpacity(0.5),
                  width: 1.5,
                ),
              ),
              child: InkWell(
                onTap: widget.selectedOptionIndex == null ? () => widget.onOptionSelected(index) : null,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                  child: Row(
                    children: [
                      // Şık harf ikonları
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: (borderColor ?? colorScheme.primary).withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            String.fromCharCode(65 + index), // A, B, C, D
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: borderColor ?? colorScheme.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: MarkdownWithMath(
                          data: widget.question.options[index],
                          styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                            p: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontSize: 14,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ),
                      if (trailingIcon != null) ...[
                        const SizedBox(width: 8),
                        Icon(trailingIcon, color: borderColor, size: 22),
                      ],
                    ],
                  ),
                ),
              ),
            );
          }),

          // Açıklama kartı (yanlış cevap için)
          if (widget.selectedOptionIndex != null && widget.selectedOptionIndex != widget.question.correctOptionIndex)
            Container(
              key: _explanationKey, // Global key ile takip ediyoruz
              child: _ExplanationCard(explanation: widget.question.explanation)
                  .animate()
                  .fadeIn(delay: 150.ms, duration: 400.ms)
                  .slideY(begin: 0.15, duration: 400.ms)
                  .then()
                  .shimmer(delay: 200.ms, duration: 1200.ms, color: Theme.of(context).colorScheme.secondary.withOpacity(0.3))
                  .shake(delay: 300.ms, hz: 2, duration: 400.ms),
            ),
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
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.secondary.withOpacity(0.15),
            colorScheme.secondary.withOpacity(0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.secondary.withOpacity(0.4),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.secondary.withOpacity(0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Başlık satırı
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      colorScheme.secondary,
                      colorScheme.secondary.withOpacity(0.8),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: colorScheme.secondary.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.lightbulb_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.auto_awesome_rounded,
                          color: colorScheme.secondary,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          "Usta'nın Açıklaması",
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: colorScheme.secondary,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      "Doğru cevabın detayları",
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Ayırıcı çizgi
          Container(
            height: 2,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  colorScheme.secondary.withOpacity(0.5),
                  colorScheme.secondary.withOpacity(0.1),
                  colorScheme.secondary.withOpacity(0.5),
                ],
              ),
              borderRadius: BorderRadius.circular(1),
            ),
          ),

          const SizedBox(height: 14),

          // Açıklama metni
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colorScheme.surface.withOpacity(0.7),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
                width: 1,
              ),
            ),
            child: MarkdownWithMath(
              data: explanation,
              styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                p: TextStyle(
                  color: colorScheme.onSurface,
                  height: 1.5,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                strong: TextStyle(
                  color: colorScheme.secondary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
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
                      crossAxisAlignment: CrossAxisAlignment.start,
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
              final workshopToSave = widget.material.copyWith(id: const Uuid().v4());
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
  final WorkshopModel material;
  final Map<int, int> selectedAnswers;

  const _QuizReviewView({
    required this.material,
    required this.selectedAnswers,
  });

  @override
  Widget build(BuildContext context) {
    // Quiz yoksa boş durum göster
    if (material.quiz == null || material.quiz!.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Text('Quiz oluşturulmadı.', textAlign: TextAlign.center),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: material.quiz!.length,
      itemBuilder: (context, index) {
        final question = material.quiz![index];
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

class _DeepenWorkshopSheet extends ConsumerWidget {
  final Function(String difficulty, bool invalidate, bool skipStudy) onOptionSelected;
  const _DeepenWorkshopSheet({required this.onOptionSelected});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contentType = ref.watch(_contentTypeProvider);

    // İçerik tipine göre metinler
    String mainActionTitle;
    String mainActionSubtitle;

    if (contentType == 'quizOnly') {
      mainActionTitle = "Yeni Zor Sorular Oluştur";
      mainActionSubtitle = "Daha zorlayıcı sorularla pratik yap";
    } else if (contentType == 'studyOnly') {
      mainActionTitle = "Detaylı Konu Anlatımı";
      mainActionSubtitle = "Konuyu daha derinlemesine öğren";
    } else {
      // both
      mainActionTitle = "Konu + Zor Test Oluştur";
      mainActionSubtitle = "Detaylı anlatım ve zorlayıcı sorular";
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.auto_awesome_rounded,
                color: Theme.of(context).colorScheme.secondary,
                size: 28,
              ),
              const SizedBox(width: 12),
              Text(
                "Derinleşme Modu",
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            "Ustalığını bir sonraki seviyeye taşı",
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),

          // Ana eylem - içerik tipine göre
          _ResultActionCard(
            title: mainActionTitle,
            subtitle: mainActionSubtitle,
            icon: Icons.rocket_launch_rounded,
            onTap: () => onOptionSelected('hard', true, contentType == 'quizOnly'),
            isPrimary: true,
          ),

          // Eğer quiz varsa, konu anlatımını tekrar okuma seçeneği sun
          if (contentType == 'both') ...[
            const SizedBox(height: 12),
            _ResultActionCard(
              title: "Sadece Konuyu Tekrar Gözden Geçir",
              subtitle: "Anlatımı oku, sonra zor teste hazırlan",
              icon: Icons.menu_book_rounded,
              onTap: () => onOptionSelected('hard', false, false),
            ),
          ],
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
          border: Border(top: BorderSide(color: Theme.of(context).colorScheme.surfaceContainerHighest, width: 1)),
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
                border: Border.all(color: Theme.of(context).colorScheme.surfaceContainerHighest),
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
