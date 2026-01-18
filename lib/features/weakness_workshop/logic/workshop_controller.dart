// lib/features/weakness_workshop/logic/workshop_controller.dart
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:taktik/features/weakness_workshop/models/workshop_model.dart';
import 'package:taktik/data/providers/firestore_providers.dart';
import 'package:taktik/data/repositories/ai_service.dart';
import 'package:taktik/features/auth/application/auth_controller.dart';
import 'package:taktik/features/weakness_workshop/logic/quiz_quality_guard.dart';
import 'dart:convert';
import 'package:taktik/data/models/topic_performance_model.dart';
import 'package:taktik/features/quests/logic/quest_notifier.dart';

// UI Durumu
enum WorkshopStep { briefing, loading, study, quiz, results, error }

class WorkshopState {
  final WorkshopStep step;
  final WorkshopModel? material;
  final Map<int, int> selectedAnswers;
  final Map<String, String>? selectedTopic; // {subject: ..., topic: ...}
  final String? errorMessage;
  final bool isMastered; // Sonuçta ustalaştı mı?

  WorkshopState({
    this.step = WorkshopStep.briefing,
    this.material,
    this.selectedAnswers = const {},
    this.selectedTopic,
    this.errorMessage,
    this.isMastered = false,
  });

  WorkshopState copyWith({
    WorkshopStep? step,
    WorkshopModel? material,
    Map<int, int>? selectedAnswers,
    Map<String, String>? selectedTopic,
    String? errorMessage,
    bool? isMastered,
    bool clearError = false,
  }) {
    return WorkshopState(
      step: step ?? this.step,
      material: material ?? this.material,
      selectedAnswers: selectedAnswers ?? this.selectedAnswers,
      selectedTopic: selectedTopic ?? this.selectedTopic,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      isMastered: isMastered ?? this.isMastered,
    );
  }
}

class WorkshopController extends AutoDisposeNotifier<WorkshopState> {
  @override
  WorkshopState build() {
    return WorkshopState();
  }

  void selectTopic(Map<String, String> topic) {
    state = state.copyWith(selectedTopic: topic, clearError: true);
    _generateMaterial(topic);
  }

  Future<void> _generateMaterial(Map<String, String> topic, {double? temperature}) async {
    state = state.copyWith(step: WorkshopStep.loading, clearError: true);

    try {
      final user = ref.read(userProfileProvider).value;
      final tests = ref.read(testsProvider).value;
      final performance = ref.read(performanceProvider).value;

      if (user == null || tests == null || performance == null) {
        throw Exception('Analiz için kullanıcı, test veya performans verisi bulunamadı.');
      }

      final aiService = ref.read(aiServiceProvider);

      final jsonString = await aiService.generateStudyGuideAndQuiz(
        user,
        tests,
        performance,
        topicOverride: topic,
        temperature: temperature,
      ).timeout(
        const Duration(seconds: 45),
        onTimeout: () => throw TimeoutException('Yapay zeka çok uzun süredir yanıt vermiyor. Lütfen tekrar deneyin.'),
      );

      final decoded = jsonDecode(jsonString);
      if (decoded.containsKey('error')) throw Exception(decoded['error']);

      final rawModel = WorkshopModel.fromAIJson(decoded);
      final guarded = QuizQualityGuard.apply(rawModel).material;

      state = state.copyWith(step: WorkshopStep.study, material: guarded);
    } catch (e) {
      state = state.copyWith(step: WorkshopStep.error, errorMessage: e.toString());
    }
  }

  void startQuiz() {
    state = state.copyWith(step: WorkshopStep.quiz);
  }

  void selectAnswer(int questionIndex, int answerIndex) {
    final newAnswers = {...state.selectedAnswers, questionIndex: answerIndex};
    state = state.copyWith(selectedAnswers: newAnswers);
  }

  Future<void> submitQuiz() async {
    if (state.material == null) return;

    final material = state.material!;
    final user = ref.read(userProfileProvider).value;
    final performanceSummary = ref.read(performanceProvider).value;

    if (user == null || performanceSummary == null) return;

    final firestore = ref.read(firestoreServiceProvider);

    // 1. İstatistik Hesapla
    int correct = 0;
    int wrong = 0;
    material.quiz.asMap().forEach((idx, q) {
      if (state.selectedAnswers[idx] == q.correctOptionIndex) {
        correct++;
      } else if (state.selectedAnswers.containsKey(idx)) {
        wrong++;
      }
    });
    int blank = material.quiz.length - correct - wrong;

    // 2. Performansı Güncelle
    final sanitizedSubject = firestore.sanitizeKey(material.subject);
    final sanitizedTopic = firestore.sanitizeKey(material.topic);

    final currentPerformance = performanceSummary.topicPerformances[sanitizedSubject]?[sanitizedTopic] ?? TopicPerformanceModel();
    final newPerformance = TopicPerformanceModel(
      correctCount: currentPerformance.correctCount + correct,
      wrongCount: currentPerformance.wrongCount + wrong,
      blankCount: currentPerformance.blankCount + blank,
      questionCount: currentPerformance.questionCount + material.quiz.length,
    );

    await firestore.updateTopicPerformance(
      userId: user.id,
      subject: material.subject,
      topic: material.topic,
      performance: newPerformance,
    );

    // 3. Ustalık Kontrolü
    bool mastered = false;
    final int cumCorrect = newPerformance.correctCount;
    final int cumWrong = newPerformance.wrongCount;
    final int cumAnswered = (cumCorrect + cumWrong);
    final double cumAccuracy = cumAnswered == 0 ? 0.0 : (cumCorrect / cumAnswered);
    final double quizScore = material.quiz.isEmpty ? 0.0 : (correct / material.quiz.length);

    final alreadyMasteredKey = '$sanitizedSubject-$sanitizedTopic';
    final alreadyMastered = performanceSummary.masteredTopics.contains(alreadyMasteredKey);

    if (!alreadyMastered && newPerformance.questionCount >= 20 && cumAccuracy >= 0.75 && quizScore >= 0.85) {
      await firestore.markTopicAsMastered(userId: user.id, subject: material.subject, topic: material.topic);
      mastered = true;
    }

    // 4. Streak Güncelle (SERVİS KULLANILIYOR - ISSUE 4 ÇÖZÜMÜ)
    await firestore.updateUserWorkshopStreak(user.id, user.lastWorkshopDate, user.workshopStreak);

    // 5. Quest bildirimi
    ref.read(questNotifierProvider.notifier).userCompletedWorkshopQuiz(material.subject, material.topic);

    state = state.copyWith(step: WorkshopStep.results, isMastered: mastered);
  }

  void reset() {
    state = WorkshopState(); // Başa dön
  }

  void retry() {
    if (state.selectedTopic != null) {
      _generateMaterial(state.selectedTopic!);
    }
  }
}

final workshopControllerProvider = NotifierProvider.autoDispose<WorkshopController, WorkshopState>(WorkshopController.new);
