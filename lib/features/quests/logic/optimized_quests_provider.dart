// lib/features/quests/logic/optimized_quests_provider.dart
import 'package:flutter/widgets.dart'; // AppLifecycleListener için
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:taktik/data/providers/firestore_providers.dart';
import 'package:taktik/features/quests/models/quest_model.dart';
import 'dart:async';
import 'package:taktik/features/quests/logic/quest_service.dart';

/// Geliştirilmiş Quest Notifier - Günlük görevleri destekler
class OptimizedQuestsNotifier extends StateNotifier<QuestsState> {
  final Ref _ref;
  StreamSubscription<List<Quest>>? _dailySub;

  // Akıllı yenileme için değişkenler
  AppLifecycleListener? _lifecycleListener;
  Timer? _midnightTimer;

  OptimizedQuestsNotifier(this._ref) : super(const QuestsState.loading()) {
    _initializeStreams();
    _setupSmartRefresh();
  }

  /// Stream'leri başlat
  void _initializeStreams() {
    final user = _ref.read(userProfileProvider).value;
    if (user != null) {
      _subscribeToQuests(user.id);
      // UYGULAMA İLK AÇILDIĞINDA BURASI ÇALIŞIR
      Future.microtask(() => _checkDateAndRefresh());
    }

    // User değişikliklerini dinle
    _ref.listen(userProfileProvider, (previous, next) {
      final newUser = next.value;
      if (newUser == null) {
        _clearStreams();
        state = const QuestsState.empty();
        return;
      }
      _subscribeToQuests(newUser.id);

      // EĞER KULLANICI DEĞİŞTİYSE DE KONTROL ET
      if (previous?.value?.id != newUser.id) {
        Future.microtask(() => _checkDateAndRefresh());
      }
    });
  }

  /// Günlük görevleri dinle
  void _subscribeToQuests(String userId) {
    _clearStreams();

    final firestoreService = _ref.read(firestoreServiceProvider);

    try {
      // Günlük görevler
      _dailySub = firestoreService.streamDailyQuests(userId).listen(
        (quests) => _updateDailyQuests(quests),
        onError: (e) => _handleStreamError('daily', e),
      );

    } catch (e) {
      print('[OptimizedQuests] Stream subscription error: $e');
      state = QuestsState.error('Görev akışı başlatılamadı: $e');
    }
  }

  /// Günlük görev güncellemesi
  void _updateDailyQuests(List<Quest> quests) {
    state = state.copyWith(
      dailyQuests: quests,
      lastDailyUpdate: DateTime.now(),
    );
    _checkAllQuestsLoaded();
  }

  /// Tüm görevler yüklendiğinde state'i güncelle
  void _checkAllQuestsLoaded() {
    if (state.dailyQuests != null) {
      state = state.copyWith(
        allQuests: state.dailyQuests,
        questsMap: {for (final q in state.dailyQuests!) q.id: q},
        isLoaded: true,
      );
    }
  }

  /// Stream hatası yönetimi
  void _handleStreamError(String questType, dynamic error) {
    print('[OptimizedQuests] $questType quest stream error: $error');
    // Diğer stream'ler çalışmaya devam etsin
  }

  /// YENİ: Akıllı Yenileme Sistemi
  /// 1. Uygulama öne geldiğinde (Resume) tarihi kontrol eder.
  /// 2. Gece yarısı (00:00) için tek bir hedefli zamanlayıcı kurar.
  void _setupSmartRefresh() {
    // Uygulama arka plandan öne gelince çalışır
    _lifecycleListener = AppLifecycleListener(
      onResume: () => _checkDateAndRefresh(),
    );

    // Gece yarısı tetikleyicisi
    _scheduleMidnightTrigger();
  }

  /// Tarih değiştiyse yenileme yapar
  void _checkDateAndRefresh() {
    final lastUpdate = state.lastDailyUpdate;
    if (lastUpdate == null) {
      refreshQuests();
      return;
    }

    final now = DateTime.now();
    // Eğer son güncelleme bugüne ait değilse yenile
    if (lastUpdate.day != now.day || lastUpdate.month != now.month || lastUpdate.year != now.year) {
      print('[OptimizedQuests] Yeni gün tespit edildi, görevler yenileniyor...');
      refreshQuests();
    }
  }

  /// Sadece bir sonraki gece yarısına (00:00:01) ayarlı tek bir Timer kurar.
  /// Sürekli dönmez, sadece hedef zamanda bir kere çalışır.
  void _scheduleMidnightTrigger() {
    _midnightTimer?.cancel();

    final now = DateTime.now();
    // Ertesi gün 00:00:01'i hedefle
    final nextMidnight = DateTime(now.year, now.month, now.day + 1, 0, 0, 1);
    final duration = nextMidnight.difference(now);

    _midnightTimer = Timer(duration, () {
      print('[OptimizedQuests] Gece yarısı oldu! Görevler yenileniyor.');
      refreshQuests();
      // Bir sonraki gece için tekrar kur
      _scheduleMidnightTrigger();
    });
  }

  /// Manuel yenileme
  Future<void> refreshQuests({bool force = false}) async {
    // Eğer provider dispose edildiyse işlem yapma
    if (!mounted) return;

    final user = _ref.read(userProfileProvider).value;
    if (user == null) return;

    // Throttle: Eğer son 1 dakika içinde yenilendiyse ve zorlama yoksa iptal et (Spam koruması)
    if (!force && state.lastRefresh != null) {
      final diff = DateTime.now().difference(state.lastRefresh!);
      if (diff.inMinutes < 1) return;
    }

    try {
      // 1. Durumu güncellemeden önce kontrol et
      if (mounted) {
        state = state.copyWith(isRefreshing: true);
      }

      // Asenkron işlem (Bu sırada kullanıcı çıkabilir)
      await _ref.read(questServiceProvider).refreshDailyQuestsForUser(user, force: force);

      // 2. İşlem bittikten sonra tekrar kontrol et: Hala mounted mı?
      if (!mounted) return;

      state = state.copyWith(
        isRefreshing: false,
        lastRefresh: DateTime.now(),
      );

    } catch (e) {
      print('[OptimizedQuests] Refresh error: $e');
      // 3. Hata durumunda da kontrol et
      if (mounted) {
        state = state.copyWith(isRefreshing: false, error: 'Yenileme başarısız: $e');
      }
    }
  }


  /// Stream'leri temizle
  void _clearStreams() {
    _dailySub?.cancel();
    _dailySub = null;
  }

  @override
  void dispose() {
    _lifecycleListener?.dispose(); // Listener'ı temizle
    _midnightTimer?.cancel(); // Timer'ı temizle
    _clearStreams();
    super.dispose();
  }
}

/// Geliştirilmiş Quest State
class QuestsState {
  final List<Quest>? dailyQuests;
  final List<Quest>? allQuests;
  final Map<String, Quest>? questsMap;
  final bool isLoaded;
  final bool isRefreshing;
  final String? error;
  final DateTime? lastRefresh;
  final DateTime? lastDailyUpdate;

  const QuestsState({
    this.dailyQuests,
    this.allQuests,
    this.questsMap,
    this.isLoaded = false,
    this.isRefreshing = false,
    this.error,
    this.lastRefresh,
    this.lastDailyUpdate,
  });

  const QuestsState.loading() : this(isRefreshing: true);
  const QuestsState.empty() : this(
    dailyQuests: const [],
    allQuests: const [],
    questsMap: const {},
    isLoaded: true,
  );

  QuestsState.error(String errorMessage) : this(
    error: errorMessage,
    isLoaded: true,
    dailyQuests: const [],
    allQuests: const [],
    questsMap: const {},
  );

  QuestsState copyWith({
    List<Quest>? dailyQuests,
    List<Quest>? allQuests,
    Map<String, Quest>? questsMap,
    bool? isLoaded,
    bool? isRefreshing,
    String? error,
    DateTime? lastRefresh,
    DateTime? lastDailyUpdate,
  }) {
    return QuestsState(
      dailyQuests: dailyQuests ?? this.dailyQuests,
      allQuests: allQuests ?? this.allQuests,
      questsMap: questsMap ?? this.questsMap,
      isLoaded: isLoaded ?? this.isLoaded,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      error: error ?? this.error,
      lastRefresh: lastRefresh ?? this.lastRefresh,
      lastDailyUpdate: lastDailyUpdate ?? this.lastDailyUpdate,
    );
  }

  /// Aktif görevleri filtrele
  List<Quest> get activeQuests {
    return allQuests?.where((q) => !q.isCompleted).toList() ?? [];
  }

  /// Tamamlanan görevleri filtrele
  List<Quest> get completedQuests {
    return allQuests?.where((q) => q.isCompleted).toList() ?? [];
  }

  /// Kategori bazlı filtreleme
  List<Quest> getQuestsByCategory(QuestCategory category) {
    return allQuests?.where((q) => q.category == category).toList() ?? [];
  }

  /// Tip bazlı filtreleme
  List<Quest> getQuestsByType(QuestType type) {
    return allQuests?.where((q) => q.type == type).toList() ?? [];
  }

  /// Route bazlı filtreleme
  List<Quest> getQuestsByRoute(QuestRoute route) {
    return allQuests?.where((q) => q.route == route).toList() ?? [];
  }

  /// Toplam ödül hesaplama
  int get totalReward {
    return completedQuests.fold(0, (sum, quest) => sum + quest.reward);
  }

  /// Tamamlanma oranı
  double get completionRate {
    if (allQuests == null || allQuests!.isEmpty) return 0.0;
    return completedQuests.length / allQuests!.length;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is QuestsState &&
        other.isLoaded == isLoaded &&
        other.isRefreshing == isRefreshing &&
        other.error == error &&
        other.allQuests?.length == allQuests?.length;
  }

  @override
  int get hashCode {
    return Object.hash(
      isLoaded,
      isRefreshing,
      error,
      allQuests?.length,
    );
  }
}

// Provider'ları güncelle
final optimizedQuestsProvider = StateNotifierProvider<OptimizedQuestsNotifier, QuestsState>((ref) {
  return OptimizedQuestsNotifier(ref);
});

// Geriye dönük uyumluluk için günlük görevler provider'ı koru
final optimizedDailyQuestsProvider = Provider<List<Quest>>((ref) {
  final questsState = ref.watch(optimizedQuestsProvider);
  return questsState.dailyQuests ?? [];
});

// YENİ: Tüm görevler provider
final allQuestsProvider = Provider<List<Quest>>((ref) {
  final questsState = ref.watch(optimizedQuestsProvider);
  return questsState.allQuests ?? [];
});

// YENİ: Aktif görevler provider
final activeQuestsProvider = Provider<List<Quest>>((ref) {
  final questsState = ref.watch(optimizedQuestsProvider);
  return questsState.activeQuests;
});

// YENİ: Kategori bazlı görevler provider'ı factory
Provider<List<Quest>> questsByCategoryProvider(QuestCategory category) {
  return Provider<List<Quest>>((ref) {
    final questsState = ref.watch(optimizedQuestsProvider);
    return questsState.getQuestsByCategory(category);
  });
}

// YENİ: Route bazlı görevler provider'ı factory
Provider<List<Quest>> questsByRouteProvider(QuestRoute route) {
  return Provider<List<Quest>>((ref) {
    final questsState = ref.watch(optimizedQuestsProvider);
    return questsState.getQuestsByRoute(route);
  });
}

/// YENİ: Ödülü alınabilir görev olup olmadığını kontrol eden provider
final hasClaimableQuestsProvider = Provider<bool>((ref) {
  final questsState = ref.watch(optimizedQuestsProvider);
  if (questsState.allQuests == null) return false;
  return questsState.allQuests!.any((q) => q.isCompleted && !q.rewardClaimed);
});
