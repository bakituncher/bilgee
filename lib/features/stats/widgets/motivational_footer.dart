// lib/features/stats/widgets/motivational_footer.dart
import 'package:flutter/material.dart';
import 'package:taktik/data/models/test_model.dart';

/// Motivasyonel Alt Bilgi - Kullanıcıyı teşvik eden mesajlar
class MotivationalFooter extends StatelessWidget {
  final List<TestModel> tests;
  final int streak;
  final bool isDark;

  const MotivationalFooter({
    super.key,
    required this.tests,
    required this.streak,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final message = _getFooterMessage();
    final icon = _getFooterIcon();
    final color = _getFooterColor();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withOpacity(0.15),
            color.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
            spreadRadius: -2,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color, color.withOpacity(0.7)],
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message.title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: color,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  message.subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? Colors.white.withOpacity(0.7)
                        : Colors.black.withOpacity(0.6),
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  ({String title, String subtitle}) _getFooterMessage() {
    // Branş denemelerini hariç tutarak ana deneme sayısını hesapla
    final mainTestCount = tests.where((test) => !test.isBranchTest).length;

    if (streak >= 7) {
      return (
        title: 'Durmak yok! 🔥',
        subtitle: '$streak günlük serinle harika gidiyorsun. Bu temponu koru!'
      );
    }
    if (streak >= 3) {
      return (
        title: 'Süper gidiyorsun! 💪',
        subtitle: 'Çalışma temponu mükemmel. Böyle devam et!'
      );
    }
    if (mainTestCount >= 20) {
      return (
        title: 'İnanılmaz çalışkansın! 📚',
        subtitle: '$mainTestCount deneme çözdün. Başarı yakın!'
      );
    }
    if (mainTestCount >= 10) {
      return (
        title: 'Güzel bir ilerleme! 🎯',
        subtitle: 'Çalışmalarına devam et, başarı seni bekliyor!'
      );
    }
    if (tests.isEmpty) {
      return (
        title: 'Hadi başlayalım! 🚀',
        subtitle: 'İlk denemeni ekle ve yolculuğuna başla!'
      );
    }
    return (
      title: 'Doğru yoldasın! ⭐',
      subtitle: 'Her deneme seni hedefe bir adım daha yaklaştırıyor!'
    );
  }

  IconData _getFooterIcon() {
    final mainTestCount = tests.where((test) => !test.isBranchTest).length;

    if (streak >= 7) return Icons.local_fire_department_rounded;
    if (streak >= 3) return Icons.bolt_rounded;
    if (mainTestCount >= 20) return Icons.emoji_events_rounded;
    if (mainTestCount >= 10) return Icons.trending_up_rounded;
    if (tests.isEmpty) return Icons.rocket_launch_rounded;
    return Icons.star_rounded;
  }

  Color _getFooterColor() {
    final mainTestCount = tests.where((test) => !test.isBranchTest).length;

    if (streak >= 7) return Colors.deepOrange;
    if (streak >= 3) return const Color(0xFFF97316);
    if (mainTestCount >= 20) return const Color(0xFF8B5CF6);
    if (mainTestCount >= 10) return const Color(0xFF10B981);
    if (tests.isEmpty) return const Color(0xFF3B82F6);
    return const Color(0xFFF59E0B);
  }
}

