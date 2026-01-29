import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:taktik/data/providers/firestore_providers.dart';
import 'package:taktik/features/auth/application/auth_controller.dart';

// Günlük soru çözme limitini kontrol eden model
class DailyQuestionLimit {
  final int used;
  final int limit;
  final bool isPremium;

  DailyQuestionLimit({
    required this.used,
    required this.limit,
    required this.isPremium,
  });

  int get remaining => isPremium ? 999 : (limit - used).clamp(0, limit);
  bool get hasReachedLimit => !isPremium && used >= limit;
}

// Günlük soru limitini takip eden provider
final dailyQuestionLimitProvider = StreamProvider.autoDispose<DailyQuestionLimit>((ref) {
  final user = ref.watch(authControllerProvider).value;
  final userProfile = ref.watch(userProfileProvider).value;

  if (user == null) {
    return Stream.value(DailyQuestionLimit(used: 0, limit: 3, isPremium: false));
  }

  final isPremium = userProfile?.isPremium ?? false;

  // Premium kullanıcılar için limit kontrolü yapmıyoruz
  if (isPremium) {
    return Stream.value(DailyQuestionLimit(used: 0, limit: 999, isPremium: true));
  }

  // Bugünün tarihini al (İstanbul zaman dilimi)
  final today = DateTime.now().toIso8601String().substring(0, 10); // 'YYYY-MM-DD'

  return FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .collection('daily_usage')
      .doc(today)
      .snapshots()
      .map((snapshot) {
    final data = snapshot.data();
    final used = data?['questions_solved'] ?? 0;
    return DailyQuestionLimit(used: used, limit: 3, isPremium: false);
  });
});

