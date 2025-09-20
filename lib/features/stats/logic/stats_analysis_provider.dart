// lib/features/stats/logic/stats_analysis_provider.dart
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
  @override
  Future<Map<String, StatsAnalysis>> build() async {
    final UserModel? user = ref.watch(userProfileProvider).valueOrNull;
    final List<TestModel> tests = ref.watch(testsProvider).valueOrNull ?? const <TestModel>[];
    final PerformanceSummary performance = ref.watch(performanceProvider).value ?? const PerformanceSummary();
    final FirestoreService firestoreService = ref.watch(firestoreServiceProvider);

    if (user == null || user.selectedExam == null) return {};
    if (tests.isEmpty && performance.topicPerformances.isEmpty) return {};

    final Exam exam = await ExamData.getExamByType(ExamType.values.byName(user.selectedExam!));

    final Map<String, StatsAnalysis> result = {};

    // Genel analiz (tüm testler)
    result[kAllSectionsKey] = StatsAnalysis(tests, performance, exam, firestoreService, user: user);

    // Bölüm bazlı analizler
    final Map<String, List<TestModel>> grouped = <String, List<TestModel>>{};
    for (final t in tests) {
      (grouped[t.sectionName] ??= <TestModel>[]).add(t);
    }
    for (final entry in grouped.entries) {
      result[entry.key] = StatsAnalysis(entry.value, performance, exam, firestoreService, user: user);
    }

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

