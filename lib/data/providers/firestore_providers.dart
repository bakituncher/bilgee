// lib/data/providers/firestore_providers.dart

import 'package:flutter_riverpod/flutter_riverpod.dart'; // EKLENDİ
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:taktik/data/models/user_model.dart';
import 'package:taktik/data/models/test_model.dart';
import 'package:taktik/features/arena/models/leaderboard_entry_model.dart'; // EKLENDİ
import 'package:taktik/features/auth/application/auth_controller.dart';
import 'package:taktik/features/profile/screens/user_search_screen.dart'; // SearchType enum için
import '../repositories/firestore_service.dart';
import 'package:taktik/data/models/plan_document.dart';
import 'package:taktik/data/models/performance_summary.dart';
import 'package:taktik/data/models/app_state.dart';
import 'package:cloud_functions/cloud_functions.dart'; // SUNUCU GÖREVLERİ İÇİN
import 'package:taktik/shared/notifications/in_app_notification_model.dart';
import 'package:taktik/data/models/user_stats_model.dart';
import 'package:taktik/data/models/focus_session_model.dart';
import 'package:taktik/data/providers/cache_provider.dart'; // CACHE SUPPORT / CACHE DESTEĞİ

final firestoreProvider = Provider<FirebaseFirestore>((ref) => FirebaseFirestore.instance);

final firestoreServiceProvider = Provider<FirestoreService>((ref) {
  return FirestoreService(ref.watch(firestoreProvider));
});

final userProfileProvider = StreamProvider.autoDispose<UserModel?>((ref) {
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


// NEW: Daily and Weekly full ranking snapshot providers (optimized + CACHED)
// YENİ: Günlük ve Haftalık tam sıralama anlık görüntü sağlayıcıları (optimize edilmiş + ÖNBELLEKLENMİŞ)
final leaderboardDailyProvider = FutureProvider.family.autoDispose<List<LeaderboardEntry>, String>((ref, examType) async {
  final cache = ref.watch(cacheManagerProvider);
  final cacheKey = CacheKeys.leaderboard(examType, 'daily');
  
  // Try from cache / Önbellekten dene
  final cached = cache.get<List<LeaderboardEntry>>(cacheKey);
  if (cached != null) return cached;
  
  // Fetch from Firestore / Firestore'dan getir
  final data = await ref.watch(firestoreServiceProvider).getLeaderboardSnapshot(examType, period: 'daily');
  
  // Cache for 5 minutes / 5 dakika önbellek
  cache.set(cacheKey, data, CacheTTL.short);
  
  return data;
});

final leaderboardWeeklyProvider = FutureProvider.family.autoDispose<List<LeaderboardEntry>, String>((ref, examType) async {
  final cache = ref.watch(cacheManagerProvider);
  final cacheKey = CacheKeys.leaderboard(examType, 'weekly');
  
  // Try from cache / Önbellekten dene
  final cached = cache.get<List<LeaderboardEntry>>(cacheKey);
  if (cached != null) return cached;
  
  // Fetch from Firestore / Firestore'dan getir
  final data = await ref.watch(firestoreServiceProvider).getLeaderboardSnapshot(examType, period: 'weekly');
  
  // Cache for 5 minutes / 5 dakika önbellek
  cache.set(cacheKey, data, CacheTTL.short);
  
  return data;
});

// KALDIRILDI: Bu sağlayıcı artık kullanılmıyor. Sıralama ve komşular
// doğrudan anlık görüntüden (snapshot) alınıyor ve istemci tarafında işleniyor.
// final leaderboardRankProvider = ...

final planProvider = StreamProvider<PlanDocument?>((ref) {
  final user = ref.watch(authControllerProvider).value;
  if (user != null) {
    return ref.watch(firestoreServiceProvider).getPlansStream(user.uid);
  }
  return Stream.value(null);
});

final performanceProvider = FutureProvider.autoDispose<PerformanceSummary?>((ref) async {
  final user = ref.watch(authControllerProvider).value;
  if (user == null) return null;
  
  final cache = ref.watch(cacheManagerProvider);
  final cacheKey = CacheKeys.performanceSummary(user.uid);
  
  // Try from cache / Önbellekten dene
  final cached = cache.get<PerformanceSummary?>(cacheKey);
  if (cached != null) return cached;
  
  // Fetch from Firestore / Firestore'dan getir
  final data = await ref.watch(firestoreServiceProvider).getPerformanceSummaryOnce(user.uid);
  
  // Cache for 10 minutes / 10 dakika önbellek
  cache.set(cacheKey, data, CacheTTL.medium);
  
  return data;
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

final inAppNotificationsProvider = StreamProvider<List<InAppNotification>>((ref) {
  final user = ref.watch(authControllerProvider).value;
  if (user != null) {
    return ref.watch(firestoreServiceProvider).streamInAppNotifications(user.uid, limit: 100);
  }
  return const Stream<List<InAppNotification>>.empty();
});

final unreadInAppCountProvider = StreamProvider<int>((ref) {
  final user = ref.watch(authControllerProvider).value;
  if (user != null) {
    return ref.watch(firestoreServiceProvider).streamUnreadInAppCount(user.uid);
  }
  return const Stream<int>.empty();
});

// YENİ: Kullanıcı istatistik akışı (streak, engagementScore, focusMinutes, bp, pomodoroSessions)
final userStatsStreamProvider = StreamProvider<UserStats?>((ref) {
  final user = ref.watch(authControllerProvider).value;
  if (user != null) {
    return ref.watch(firestoreServiceProvider).getUserStatsStream(user.uid);
  }
  return const Stream<UserStats?>.empty();
});

// YENİ: Son N günün odak dakikaları (focusMinutes) – haftalık/aylık grafikler için
final focusMinutesForLastDaysProvider = FutureProvider.family.autoDispose<Map<String, int>, int>((ref, days) async {
  final user = ref.watch(authControllerProvider).value;
  if (user == null) return {};
  final today = DateTime.now();
  final start = DateTime(today.year, today.month, today.day).subtract(Duration(days: days - 1));
  return ref.read(firestoreServiceProvider).getFocusMinutesInRange(user.uid, start: start, end: today);
});

// YENI: Odaklanma seansları akışı (genel kullanım için)
final focusSessionsStreamProvider = StreamProvider.autoDispose<List<FocusSessionModel>>((ref) {
  final user = ref.watch(authControllerProvider).value;
  if (user != null) {
    return ref.watch(firestoreProvider)
        .collection('focusSessions')
        .where('userId', isEqualTo: user.uid)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => FocusSessionModel.fromSnapshot(doc as DocumentSnapshot<Map<String, dynamic>>)).toList());
  }
  return Stream.value(const <FocusSessionModel>[]);
});

// TAKIP: Mevcut kullanıcının hedef kullanıcıyı takip edip etmediği
final isFollowingProvider = StreamProvider.family.autoDispose<bool, String>((ref, targetUserId) {
  final me = ref.watch(authControllerProvider).value;
  if (me == null) return const Stream<bool>.empty();
  return ref.watch(firestoreServiceProvider).streamIsFollowing(me.uid, targetUserId);
});

// TAKIP: Belirli bir kullanıcının takipçi/takip sayısı (Optimize Edilmiş)
final followCountsProvider = StreamProvider.family.autoDispose<(int, int), String>((ref, userId) {
  // userProfileByIdProvider zaten kullanıcı dokümanını dinliyor.
  // .stream'i izleyerek AsyncValue yerine doğrudan Stream'i map'liyoruz.
  return ref.watch(userProfileByIdProvider(userId).stream).map((user) {
    return (user.followerCount ?? 0, user.followingCount ?? 0);
  });
});

// TAKIP: Listeleme için ID akışları
final followerIdsProvider = StreamProvider.family.autoDispose<List<String>, String>((ref, userId) {
  return ref.watch(firestoreServiceProvider).streamFollowerIds(userId);
});
final followingIdsProvider = StreamProvider.family.autoDispose<List<String>, String>((ref, userId) {
  return ref.watch(firestoreServiceProvider).streamFollowingIds(userId);
});

// ID'ye göre kullanıcı profili akışı
final userProfileByIdProvider = StreamProvider.family.autoDispose<UserModel, String>((ref, userId) {
  return ref.watch(firestoreServiceProvider).getUserProfile(userId);
});

// Herhangi bir kullanıcı için UserStats akışı
final userStatsForUserProvider = StreamProvider.family.autoDispose<UserStats?, String>((ref, userId) {
  return ref.watch(firestoreServiceProvider).getUserStatsStream(userId);
});

// PUBLIC: public profile summary via public_profiles (name, avatar, stats) - CACHED
// PUBLIC: public_profiles üzerinden herkese açık profil özeti (isim, avatar, stats özet) - ÖNBELLEKLENMİŞ
final publicProfileRawProvider = FutureProvider.family.autoDispose<Map<String, dynamic>?, String>((ref, userId) async {
  final cache = ref.watch(cacheManagerProvider);
  final cacheKey = CacheKeys.publicProfile(userId);
  
  // Try from cache / Önbellekten dene
  final cached = cache.get<Map<String, dynamic>?>(cacheKey);
  if (cached != null) return cached;
  
  final svc = ref.watch(firestoreServiceProvider);
  final data = await svc.getPublicProfileRaw(userId);
  if (data != null) {
    // Cache for 10 minutes (public profiles rarely change) / 10 dakika önbellek (public profiller sık değişmez)
    cache.set(cacheKey, data, CacheTTL.medium);
    return data;
  }
  final myExam = ref.watch(userProfileProvider).value?.selectedExam;
  if (myExam != null) {
    final leaderboardData = await svc.getLeaderboardUserRaw(myExam, userId);
    if (leaderboardData != null) {
      cache.set(cacheKey, leaderboardData, CacheTTL.medium);
    }
    return leaderboardData;
  }
  return null;
});

// YENİ: Kullanıcı arama provider'ı
final userSearchProvider = FutureProvider.family.autoDispose<List<Map<String, dynamic>>, String>((ref, query) async {
  if (query.trim().isEmpty) return [];
  final svc = ref.watch(firestoreServiceProvider);
  final searchType = ref.watch(searchTypeProvider);
  return await svc.searchUsersByName(query, searchType: searchType);
});

// YENİ: Kullanıcı arama sonuçları için state provider
final userSearchQueryProvider = StateProvider<String>((ref) => '');

// YENİ: Arama tipi provider'ı
final searchTypeProvider = StateProvider<SearchType>((ref) => SearchType.name);

// YENİ: Arama sonuçlarını reaktif olarak getiren provider
final searchResultsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final query = ref.watch(userSearchQueryProvider);
  final searchType = ref.watch(searchTypeProvider);
  if (query.trim().isEmpty) return [];
  return ref.watch(userSearchProvider(query).future);
});
