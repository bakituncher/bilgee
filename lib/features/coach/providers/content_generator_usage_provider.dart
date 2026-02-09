import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:taktik/data/providers/firestore_providers.dart';
import 'package:taktik/features/auth/application/auth_controller.dart';
import 'package:taktik/features/coach/providers/daily_question_limit_provider.dart'; // trustedTodayProvider için

/// İçerik üretici kullanım sayısı state'i
class ContentGeneratorUsage {
  final int usedCount;
  final int maxFreeCount;
  final bool isPremium;
  final bool isLoading;

  ContentGeneratorUsage({
    required this.usedCount,
    required this.maxFreeCount,
    required this.isPremium,
    this.isLoading = false,
  });

  int get remainingCount => isPremium ? 999 : (maxFreeCount - usedCount).clamp(0, maxFreeCount);
  bool get hasRemainingUsage => isPremium || remainingCount > 0;
  bool get hasReachedLimit => !isPremium && usedCount >= maxFreeCount;

  ContentGeneratorUsage copyWith({
    int? usedCount,
    int? maxFreeCount,
    bool? isPremium,
    bool? isLoading,
  }) {
    return ContentGeneratorUsage(
      usedCount: usedCount ?? this.usedCount,
      maxFreeCount: maxFreeCount ?? this.maxFreeCount,
      isPremium: isPremium ?? this.isPremium,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

/// İçerik üretici günlük kullanım sayısını getiren provider
final contentGeneratorUsageProvider = StreamProvider.autoDispose<ContentGeneratorUsage>((ref) {
  final user = ref.watch(authControllerProvider).value;
  final userProfile = ref.watch(userProfileProvider).value;

  // Sunucu tarihini izle
  final trustedToday = ref.watch(trustedTodayProvider).value;

  if (user == null) {
    return Stream.value(ContentGeneratorUsage(usedCount: 0, maxFreeCount: 3, isPremium: false));
  }

  final isPremium = userProfile?.isPremium ?? false;

  // Premium kullanıcılar için limit kontrolü yapmıyoruz
  if (isPremium) {
    return Stream.value(ContentGeneratorUsage(usedCount: 0, maxFreeCount: 999, isPremium: true));
  }

  // Bugünün tarihini al (GÜVENİLİR SUNUCU TARİHİNE ÖNCELİK VER)
  final today = trustedToday ?? DateTime.now().toIso8601String().substring(0, 10); // 'YYYY-MM-DD'

  return FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .collection('daily_usage')
      .doc(today)
      .snapshots()
      .map((snapshot) {
    final data = snapshot.data();
    final count = data?['content_generated'] ?? 0;
    return ContentGeneratorUsage(
      usedCount: count,
      maxFreeCount: 3,
      isPremium: false,
    );
  });
});



