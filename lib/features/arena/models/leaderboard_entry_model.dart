// lib/features/arena/models/leaderboard_entry_model.dart

class LeaderboardEntry {
  final String userId;
  final String userName;
  final String? username;
  final int score;
  final int testCount;
  final String? avatarStyle;
  final String? avatarSeed;
  final int rank; // YENİ: Sıralama alanı eklendi

  LeaderboardEntry({
    required this.userId,
    required this.userName,
    this.username,
    required this.score,
    required this.testCount,
    this.avatarStyle,
    this.avatarSeed,
    this.rank = 0, // YENİ: Varsayılan değer
  });
}