// lib/features/stats/widgets/premium_hero_card.dart
import 'package:flutter/material.dart';
import 'package:taktik/core/theme/app_theme.dart';
import 'package:taktik/data/models/test_model.dart';
import 'package:taktik/data/models/user_model.dart';
import 'package:taktik/features/stats/widgets/premium_stat_item.dart';

/// Premium Hero Kartı - Sektör seviyesinde tasarım
class PremiumHeroCard extends StatelessWidget {
  final UserModel user;
  final List<TestModel> tests;
  final bool isDark;
  final int streak;
  final String avgNet;

  const PremiumHeroCard({
    super.key,
    required this.user,
    required this.tests,
    required this.isDark,
    required this.streak,
    required this.avgNet,
  });

  @override
  Widget build(BuildContext context) {
    final motivationMessage = _getMotivationMessage();
    final motivationColor = _getMotivationColor();
    final progressPercentage = _calculateProgress();

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF10B981),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF10B981).withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 3),
            spreadRadius: -1,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            // Arka plan gradient
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    motivationColor.withOpacity(0.15),
                    motivationColor.withOpacity(0.05),
                    isDark ? const Color(0xFF0F172A) : Colors.white,
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),

            // Animasyonlu arka plan desenleri
            Positioned(
              right: -40,
              top: -40,
              child: Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      motivationColor.withOpacity(0.1),
                      motivationColor.withOpacity(0.0),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: -30,
              bottom: -30,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      motivationColor.withOpacity(0.08),
                      motivationColor.withOpacity(0.0),
                    ],
                  ),
                ),
              ),
            ),

            // İçerik
            SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Container(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Üst kısım - Karşılama ve durum
                    Row(
                    children: [
                      // Avatar
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [motivationColor, motivationColor.withOpacity(0.7)],
                          ),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withOpacity(isDark ? 0.1 : 0.3),
                            width: 2.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: motivationColor.withOpacity(0.4),
                              blurRadius: 12,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: _getMotivationIcon() == Icons.rocket_launch_rounded
                            ? ClipOval(
                                child: Padding(
                                  padding: const EdgeInsets.all(5.0),
                                  child: Image.asset(
                                    'assets/images/bunnyy.png',
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              )
                            : Icon(
                                _getMotivationIcon(),
                                color: Colors.white,
                                size: 20,
                              ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Hoş Geldin, ${user.firstName.isNotEmpty ? user.firstName : 'Öğrenci'}',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? Colors.white.withOpacity(0.55)
                                    : Colors.black.withOpacity(0.45),
                                letterSpacing: 0.3,
                              ),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              motivationMessage,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                                height: 1.2,
                                letterSpacing: -0.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Durum rozeti
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [motivationColor, motivationColor.withOpacity(0.8)],
                          ),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: motivationColor.withOpacity(0.35),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _getStatusIcon(),
                              color: Colors.white,
                              size: 12,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              _getStatusText(),
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // İstatistik kartları - Grid
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: PremiumStatItem(
                            icon: Icons.assignment_turned_in_rounded,
                            label: 'Deneme',
                            value: '${tests.length}',
                            color: const Color(0xFF8B5CF6),
                            isDark: isDark,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: PremiumStatItem(
                            icon: Icons.trending_up_rounded,
                            label: 'Ort. Net',
                            value: avgNet,
                            color: const Color(0xFF10B981),
                            isDark: isDark,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: PremiumStatItem(
                            icon: Icons.local_fire_department_rounded,
                            label: 'Seri',
                            value: '$streak',
                            suffix: 'gün',
                            color: const Color(0xFFEF4444),
                            isDark: isDark,
                            isHighlight: streak >= 3,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: PremiumStatItem(
                            icon: Icons.emoji_events_rounded,
                            label: 'Puan',
                            value: '${user.engagementScore ?? 0}',
                            color: AppTheme.goldBrandColor,
                            isDark: isDark,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 10),

                  // İlerleme barı
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Haftalık İlerleme',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: isDark
                                  ? Colors.white.withOpacity(0.55)
                                  : Colors.black.withOpacity(0.45),
                              letterSpacing: 0.3,
                            ),
                          ),
                          Text(
                            '${(progressPercentage * 100).toInt()}%',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              color: motivationColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Stack(
                        children: [
                          Container(
                            height: 5,
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white.withOpacity(0.1)
                                  : Colors.black.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(2.5),
                            ),
                          ),
                          FractionallySizedBox(
                            widthFactor: progressPercentage.clamp(0.0, 1.0),
                            child: Container(
                              height: 5,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    motivationColor,
                                    motivationColor.withOpacity(0.7),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(2.5),
                                boxShadow: [
                                  BoxShadow(
                                    color: motivationColor.withOpacity(0.4),
                                    blurRadius: 6,
                                    offset: const Offset(0, 1.5),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
    );
  }

  String _getMotivationMessage() {
    if (tests.isEmpty) return 'İlk denemeni ekle';
    if (streak >= 7) return 'Muhteşem performans! 🔥';
    if (streak >= 3) return 'Harika gidiyorsun! 💪';
    if (tests.length >= 20) return 'Süper çalışkansın! 📚';
    if (tests.length >= 10) return 'İyi ilerliyorsun! 🎯';
    return 'Yolculuğuna devam et! 🚀';
  }

  Color _getMotivationColor() {
    if (streak >= 7) return const Color(0xFFEF4444);
    if (streak >= 3) return const Color(0xFFF97316);
    if (tests.length >= 20) return const Color(0xFF8B5CF6);
    if (tests.length >= 10) return const Color(0xFF10B981);
    return AppTheme.primaryBrandColor;
  }

  IconData _getMotivationIcon() {
    if (streak >= 7) return Icons.emoji_events_rounded;
    if (streak >= 3) return Icons.local_fire_department_rounded;
    if (tests.length >= 20) return Icons.military_tech_rounded;
    if (tests.length >= 10) return Icons.trending_up_rounded;
    return Icons.rocket_launch_rounded;
  }

  IconData _getStatusIcon() {
    if (streak >= 7) return Icons.auto_awesome_rounded;
    if (streak >= 3) return Icons.bolt_rounded;
    if (tests.length >= 10) return Icons.star_rounded;
    return Icons.thumb_up_rounded;
  }

  String _getStatusText() {
    if (streak >= 7) return 'ÇOK İYİ';
    if (streak >= 3) return 'GÜZEL';
    if (tests.length >= 10) return 'AKTİF';
    return 'YENİ';
  }

  double _calculateProgress() {
    if (tests.isEmpty) return 0.0;
    // Haftalık hedef: 5 test
    final weeklyGoal = 5;
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final weekTests = tests.where((t) => t.date.isAfter(weekStart)).length;
    return (weekTests / weeklyGoal).clamp(0.0, 1.0);
  }
}
