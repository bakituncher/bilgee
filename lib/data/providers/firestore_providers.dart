// lib/data/providers/firestore_providers.dart

import 'package:flutter_riverpod/flutter_riverpod.dart'; // EKLENDİ
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:bilge_ai/data/models/user_model.dart';
import 'package:bilge_ai/data/models/test_model.dart';
import 'package:bilge_ai/features/arena/models/leaderboard_entry_model.dart'; // EKLENDİ
import 'package:bilge_ai/features/auth/application/auth_controller.dart';
import '../repositories/firestore_service.dart';
import 'package:bilge_ai/data/models/plan_document.dart';
import 'package:bilge_ai/data/models/performance_summary.dart';
import 'package:bilge_ai/data/models/app_state.dart';
import 'package:cloud_functions/cloud_functions.dart'; // SUNUCU GÖREVLERİ İÇİN

final firestoreProvider = Provider<FirebaseFirestore>((ref) => FirebaseFirestore.instance);

final firestoreServiceProvider = Provider<FirestoreService>((ref) {
  return FirestoreService(ref.watch(firestoreProvider));
});

final userProfileProvider = StreamProvider<UserModel?>((ref) {
  final user = ref.watch(authControllerProvider).value;
  if (user != null) {
    // KÖK + STATS birleşik akış
    return ref.watch(firestoreServiceProvider).streamCombinedUserModel(user.uid);
  }
  return Stream.value(null);
});

final testsProvider = FutureProvider<List<TestModel>>((ref) async {
  final user = ref.watch(authControllerProvider).value;
  if (user != null) {
    // İlk sayfayı 20 kayıtla getirir
    return ref.watch(firestoreServiceProvider).getTestResultsPaginated(user.uid, limit: 20);
  }
  return <TestModel>[];
});

// Artık 'FutureProvider.family' doğru şekilde tanınıyor.
final leaderboardProvider = FutureProvider.family.autoDispose<List<LeaderboardEntry>, String>((ref, examType) async {
  final firestoreService = ref.watch(firestoreServiceProvider);
  final entries = await firestoreService.getLeaderboardUsers(examType);
  return entries;
});

final planProvider = StreamProvider<PlanDocument?>((ref) {
  final user = ref.watch(authControllerProvider).value;
  if (user != null) {
    return ref.watch(firestoreServiceProvider).getPlansStream(user.uid);
  }
  return Stream.value(null);
});

final performanceProvider = FutureProvider.autoDispose<PerformanceSummary?>((ref) {
  final user = ref.watch(authControllerProvider).value;
  if (user != null) {
    return ref.watch(firestoreServiceProvider).getPerformanceSummaryOnce(user.uid);
  }
  return Future.value(null);
});

final appStateProvider = StreamProvider<AppState?>((ref) {
  final user = ref.watch(authControllerProvider).value;
  if (user != null) {
    return ref.watch(firestoreServiceProvider).getAppStateStream(user.uid);
  }
  return Stream.value(null);
});

final completedTasksForDateProvider = FutureProvider.family<List<String>, DateTime>((ref, date) async {
  final user = ref.watch(authControllerProvider).value;
  if (user == null) return [];
  return ref.read(firestoreServiceProvider).getCompletedTasksForDate(user.uid, date);
});

// YENI: Haftalık toplu sağlayıcı (7 günlük tek okuma; ay sınırında en fazla iki okuma)
final completedTasksForWeekProvider = FutureProvider.family.autoDispose<Map<String, List<String>>, DateTime>((ref, weekStart) async {
  final user = ref.watch(authControllerProvider).value;
  if (user == null) return {};
  return ref.read(firestoreServiceProvider).getCompletedTasksForWeek(user.uid, weekStart);
});

final functionsProvider = Provider<FirebaseFunctions>((ref) {
  // Bölge sabit: backend onCall fonksiyonları us-central1
  return FirebaseFunctions.instanceFor(region: 'us-central1');
});
