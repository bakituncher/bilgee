import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:taktik/data/providers/firestore_providers.dart';
import 'package:taktik/features/auth/application/auth_controller.dart';

/// İçerik üretici kullanım sayısı state'i
class ContentGeneratorUsage {
  final int usedCount;
  final int maxFreeCount;
  final bool isLoading;

  ContentGeneratorUsage({
    required this.usedCount,
    required this.maxFreeCount,
    this.isLoading = false,
  });

  int get remainingCount => maxFreeCount - usedCount;
  bool get hasRemainingUsage => remainingCount > 0;

  ContentGeneratorUsage copyWith({
    int? usedCount,
    int? maxFreeCount,
    bool? isLoading,
  }) {
    return ContentGeneratorUsage(
      usedCount: usedCount ?? this.usedCount,
      maxFreeCount: maxFreeCount ?? this.maxFreeCount,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

/// İçerik üretici kullanım sayısını getiren provider
final contentGeneratorUsageProvider = StreamProvider.autoDispose<ContentGeneratorUsage>((ref) {
  final firestore = ref.watch(firestoreProvider);
  final user = ref.watch(authControllerProvider).value;

  if (user == null) {
    return Stream.value(ContentGeneratorUsage(usedCount: 0, maxFreeCount: 3));
  }

  return firestore
      .collection('users')
      .doc(user.uid)
      .collection('lifetime_usage')
      .doc('content_generator')
      .snapshots()
      .map((snapshot) {
    final data = snapshot.data();
    final count = data?['count'] as int? ?? 0;
    return ContentGeneratorUsage(
      usedCount: count,
      maxFreeCount: 3,
    );
  });
});



