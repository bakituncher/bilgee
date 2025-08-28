// lib/features/profile/logic/rank_service.dart
import 'package:flutter/material.dart';

// Tek bir rütbenin tüm özelliklerini tanımlayan model
class Rank {
  final String name;
  final IconData icon;
  final int requiredScore;
  final Color color;

  const Rank({
    required this.name,
    required this.icon,
    required this.requiredScore,
    required this.color,
  });
}

// Rütbe sistemiyle ilgili tüm bilgileri ve mantığı yöneten merkezi servis
class RankService {
  // Rütbeler en düşükten en yükseğe doğru sıralanmalıdır.
  static const List<Rank> ranks = [
    Rank(name: 'Acemi Kâşif', icon: Icons.explore_outlined, requiredScore: 0, color: Colors.brown),
    Rank(name: 'Çaylak Savaşçı', icon: Icons.shield_outlined, requiredScore: 500, color: Colors.grey),
    Rank(name: 'Gözüpek Taktikçi', icon: Icons.lightbulb_outline_rounded, requiredScore: 1500, color: Colors.blueGrey),
    Rank(name: 'Kıdemli Stratejist', icon: Icons.military_tech_outlined, requiredScore: 3500, color: Color(0xFFC0C0C0)), // Silver
    Rank(name: 'Savaş Lordu', icon: Icons.shield_moon_outlined, requiredScore: 7000, color: Color(0xFFFFD700)), // Gold
    Rank(name: 'Fetih Komutanı', icon: Icons.stars_rounded, requiredScore: 12000, color: Colors.orangeAccent),
    Rank(name: 'Bilgelik Ustası', icon: Icons.auto_stories_rounded, requiredScore: 20000, color: Colors.teal),
    Rank(name: 'Panteon Muhafızı', icon: Icons.security_rounded, requiredScore: 35000, color: Colors.deepPurpleAccent),
    Rank(name: 'Yaşayan Efsane', icon: Icons.workspace_premium_rounded, requiredScore: 60000, color: Colors.redAccent),
    Rank(name: 'Yıldızların Fatihi', icon: Icons.rocket_launch_rounded, requiredScore: 100000, color: Color(0xFF40E0D0)), // Platin/Turquoise
  ];

  /// Verilen puana göre kullanıcının mevcut rütbesini, bir sonraki rütbesini ve ilerlemesini döndürür.
  static ({Rank current, Rank next, double progress}) getRankInfo(int score) {
    Rank currentRank = ranks.first;
    Rank nextRank = ranks[1];

    // Kullanıcının mevcut rütbesini bul
    for (int i = ranks.length - 1; i >= 0; i--) {
      if (score >= ranks[i].requiredScore) {
        currentRank = ranks[i];
        break;
      }
    }

    // Bir sonraki rütbeyi bul (eğer en üst rütbede değilse)
    int nextRankIndex = ranks.indexOf(currentRank) + 1;
    if (nextRankIndex < ranks.length) {
      nextRank = ranks[nextRankIndex];
    } else {
      nextRank = currentRank; // En üst rütbede, sonraki rütbe kendisidir.
    }

    // İlerleme yüzdesini hesapla
    if (currentRank == nextRank) {
      // En üst rütbede ise bar dolu gösterilir.
      return (current: currentRank, next: nextRank, progress: 1.0);
    } else {
      final scoreInCurrentRank = score - currentRank.requiredScore;
      final scoreNeededForNextRank = nextRank.requiredScore - currentRank.requiredScore;
      final progress = scoreInCurrentRank / scoreNeededForNextRank;
      return (current: currentRank, next: nextRank, progress: progress.clamp(0.0, 1.0));
    }
  }
}