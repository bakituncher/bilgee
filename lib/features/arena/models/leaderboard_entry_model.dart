// lib/features/arena/models/leaderboard_entry_model.dart

class LeaderboardEntry {
  final String userId;
  final String userName;
  final int score; // GÜNCELLENDİ: averageNet -> score
  final int testCount;
  final String? avatarStyle; // YENİ: Avatar stili eklendi
  final String? avatarSeed; // YENİ: Avatar tohumu eklendi

  LeaderboardEntry({
    required this.userId,
    required this.userName,
    required this.score,
    required this.testCount,
    this.avatarStyle, // YENİ
    this.avatarSeed, // YENİ
  });
}