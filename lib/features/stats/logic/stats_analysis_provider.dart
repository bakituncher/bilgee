// lib/features/stats/logic/stats_analysis_provider.dart
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:taktik/data/models/test_model.dart';
import 'package:taktik/data/models/user_model.dart';
import 'package:taktik/data/models/performance_summary.dart';
import 'package:taktik/data/models/exam_model.dart';
import 'package:taktik/data/providers/firestore_providers.dart';
import 'package:taktik/data/repositories/firestore_service.dart';
import 'package:taktik/features/stats/logic/stats_analysis.dart';

const String kAllSectionsKey = '_all_sections_';

final statsAnalysisControllerProvider = AutoDisposeAsyncNotifierProvider<StatsAnalysisController, Map<String, StatsAnalysis>>(
  StatsAnalysisController.new,
);

class StatsAnalysisController extends AutoDisposeAsyncNotifier<Map<String, StatsAnalysis>> {
  // Cache için hash değerleri
  String? _lastCacheKey;
  Map<String, StatsAnalysis>? _cachedResult;

  String _generateCacheKey(List<TestModel> tests, PerformanceSummary performance, String? selectedExam) {
    // Test ID'leri ve tarihlerinden hash oluştur
    final testHash = tests.map((t) => '${t.id}_${t.date.millisecondsSinceEpoch}').join('|');

    // Performance verisinden hash oluştur
    final perfHash = '${performance.topicPerformances.length}_${performance.masteredTopics.length}';

    return '$selectedExam:$testHash:$perfHash';
  }

  @override
  Future<Map<String, StatsAnalysis>> build() async {
    final UserModel? user = ref.watch(userProfileProvider).valueOrNull;
    final List<TestModel> tests = ref.watch(testsProvider).valueOrNull ?? const <TestModel>[];
    final PerformanceSummary performance = ref.watch(performanceProvider).value ?? const PerformanceSummary();
    final FirestoreService firestoreService = ref.watch(firestoreServiceProvider);

    if (user == null || user.selectedExam == null) return {};

    // ÖNEMLI: Artık testler boş olsa bile, performance verisi varsa analiz yapıyoruz
    // Çünkü kullanıcı Coach Screen'de konu bazlı veri giriyor
    if (tests.isEmpty && performance.topicPerformances.isEmpty) return {};

    // CACHE KONTROLÜ: Veri değişmediyse cache'den dön
    final currentCacheKey = _generateCacheKey(tests, performance, user.selectedExam);
    if (_lastCacheKey == currentCacheKey && _cachedResult != null) {
      return _cachedResult!;
    }

    final Exam exam = await ExamData.getExamByType(ExamType.values.byName(user.selectedExam!));

    final Map<String, StatsAnalysis> result = {};

    // Genel analiz (tüm testler) - gerçek performance verisini geçiriyoruz
    result[kAllSectionsKey] = StatsAnalysis(
      tests,
      exam,
      firestoreService,
      user: user,
      externalPerformance: performance, // ← GERÇEK KONU VERİSİ
    );

    // Bölüm bazlı analizler
    final Map<String, List<TestModel>> grouped = <String, List<TestModel>>{};
    for (final t in tests) {
      (grouped[t.sectionName] ??= <TestModel>[]).add(t);
    }

    for (final entry in grouped.entries) {
      result[entry.key] = StatsAnalysis(
        entry.value,
        exam,
        firestoreService,
        user: user,
        externalPerformance: performance, // ← GERÇEK KONU VERİSİ
      );
    }

    // Cache'i güncelle
    _lastCacheKey = currentCacheKey;
    _cachedResult = result;

    return result;
  }
}

final statsAnalysisForSectionProvider = Provider.family<AsyncValue<StatsAnalysis?>, String>((ref, section) {
  final mapAsync = ref.watch(statsAnalysisControllerProvider);
  return mapAsync.whenData((map) => map[section]);
});

final overallStatsAnalysisProvider = Provider<AsyncValue<StatsAnalysis?>>((ref) {
  final mapAsync = ref.watch(statsAnalysisControllerProvider);
  return mapAsync.whenData((map) => map[kAllSectionsKey]);
});

// Workshop İstatistik Analizi (Issue 6 Çözümü) - CACHE'LENEBILIR
final workshopStatsAnalysisProvider = Provider.autoDispose<WorkshopAnalysisData>((ref) {
  // Cache için keepAlive - veri değişmedikçe hesaplamayı tekrar yapma
  final link = ref.keepAlive();

  // 2 dakika sonra cache'i temizle
  Timer(const Duration(minutes: 2), () {
    link.close();
  });

  final performance = ref.watch(performanceProvider).valueOrNull;

  if (performance == null) {
    return WorkshopAnalysisData.empty();
  }

  // Tüm hesaplamalar burada yapılır, build metodunda değil
  final totalQuestionsAnswered = performance.topicPerformances.values
      .expand((subject) => subject.values)
      .map((topic) => topic.questionCount)
      .fold<int>(0, (sum, count) => sum + count);

  final totalCorrectAnswers = performance.topicPerformances.values
      .expand((subject) => subject.values)
      .map((topic) => topic.correctCount)
      .fold<int>(0, (sum, count) => sum + count);

  final uniqueTopicsWorkedOn = performance.topicPerformances.values
      .expand((subject) => subject.keys)
      .toSet()
      .length;

  final overallAccuracy = totalQuestionsAnswered > 0 
      ? (totalCorrectAnswers / totalQuestionsAnswered) 
      : 0.0;

  final masteredCount = performance.masteredTopics.length;

  return WorkshopAnalysisData(
    totalQuestionsAnswered: totalQuestionsAnswered,
    totalCorrectAnswers: totalCorrectAnswers,
    uniqueTopicsWorkedOn: uniqueTopicsWorkedOn,
    overallAccuracy: overallAccuracy,
    masteredTopicsCount: masteredCount,
  );
});

class WorkshopAnalysisData {
  final int totalQuestionsAnswered;
  final int totalCorrectAnswers;
  final int uniqueTopicsWorkedOn;
  final double overallAccuracy;
  final int masteredTopicsCount;

  WorkshopAnalysisData({
    required this.totalQuestionsAnswered,
    required this.totalCorrectAnswers,
    required this.uniqueTopicsWorkedOn,
    required this.overallAccuracy,
    required this.masteredTopicsCount,
  });

  factory WorkshopAnalysisData.empty() => WorkshopAnalysisData(
    totalQuestionsAnswered: 0,
    totalCorrectAnswers: 0,
    uniqueTopicsWorkedOn: 0,
    overallAccuracy: 0.0,
    masteredTopicsCount: 0,
  );
}
