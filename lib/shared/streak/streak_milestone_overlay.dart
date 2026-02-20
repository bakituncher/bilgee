// lib/shared/streak/streak_milestone_overlay.dart
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:confetti/confetti.dart';
import 'package:taktik/core/theme/app_theme.dart';
import 'streak_milestone_notifier.dart';

class _MilestoneInfo {
  final String emoji;
  final String title;
  final String subtitle;
  final String message;
  final Color accentColor;
  final IconData badgeIcon;

  const _MilestoneInfo({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.message,
    required this.accentColor,
    required this.badgeIcon,
  });
}

_MilestoneInfo _getMilestoneInfo(int streak) {
  switch (streak) {
    case 1:
      return const _MilestoneInfo(
        emoji: '🔥',
        title: 'İlk Adım Atıldı!',
        subtitle: '1 Günlük Seri',
        message: 'Her büyük başarı bir ilk adımla başlar. Yarın da burada olmayı unutma.',
        accentColor: Color(0xFF22D3EE), // cyan
        badgeIcon: Icons.local_fire_department_rounded,
      );
    case 2:
      return const _MilestoneInfo(
        emoji: '⚡',
        title: 'Momentum Başlıyor!',
        subtitle: '2 Günlük Seri',
        message: 'İki gün üst üste. Alışkanlık oluşmaya başladı — sınav gününe kadar bırakma.',
        accentColor: Color(0xFF34D399), // emerald
        badgeIcon: Icons.bolt_rounded,
      );
    case 3:
      return const _MilestoneInfo(
        emoji: '🌟',
        title: '3 Gün Kesintisiz!',
        subtitle: '3 Günlük Seri',
        message: 'Üç gün disiplin, farkı yaratmaya yeter. Şimdi soru sormaya devam et.',
        accentColor: Color(0xFF34D399), // emerald
        badgeIcon: Icons.star_rounded,
      );
    case 5:
      return const _MilestoneInfo(
        emoji: '🏅',
        title: '5 Günlük Bronz!',
        subtitle: 'Küçük Seri Madalyası',
        message: 'Beş gün devam ettin. Rakiplerin dinlenirken sen çalışmaya devam ediyorsun.',
        accentColor: Color(0xFFCD7F32),
        badgeIcon: Icons.military_tech_rounded,
      );
    case 7:
      return const _MilestoneInfo(
        emoji: '🥈',
        title: '1 Tam Hafta!',
        subtitle: 'Haftalık Seri Madalyası',
        message: 'Bir haftayı eksiksiz tamamladın. Bu tutarlılık seni sıralamada yukarı taşır.',
        accentColor: Color(0xFF94A3B8),
        badgeIcon: Icons.emoji_events_rounded,
      );
    case 10:
      return const _MilestoneInfo(
        emoji: '💎',
        title: '10 Gün Elmas Seri!',
        subtitle: '10 Günlük Elmas Madalya',
        message: '10 günde kazandığın alışkanlık, sınav günü seni rahatlatacak. Harika gidiyorsun!',
        accentColor: Color(0xFF22D3EE), // cyan
        badgeIcon: Icons.diamond_rounded,
      );
    case 14:
      return const _MilestoneInfo(
        emoji: '🚀',
        title: '2 Hafta Roket Hızı!',
        subtitle: '14 Günlük Seri',
        message: 'İki haftadır her gün buradaydın. Artık bu bir alışkanlık değil, bir yaşam biçimi.',
        accentColor: Color(0xFF8B5CF6),
        badgeIcon: Icons.rocket_launch_rounded,
      );
    case 21:
      return const _MilestoneInfo(
        emoji: '🧠',
        title: 'Alışkanlık Kilidi Açıldı!',
        subtitle: '21 Günlük Seri',
        message: 'Bilim insanları 21 günün yeni bir alışkanlık oluşturmak için yeterli olduğunu söylüyor. Sen başardın!',
        accentColor: Color(0xFF3B82F6),
        badgeIcon: Icons.psychology_rounded,
      );
    case 30:
      return const _MilestoneInfo(
        emoji: '🥇',
        title: 'Bir Ay Altın Seri!',
        subtitle: '30 Günlük Altın Madalya',
        message: 'Bir ay boyunca her gün çalıştın. Sınav sonuçları bu tutarsızlığı asla unutmayacak.',
        accentColor: Color(0xFFFFB020), // gold
        badgeIcon: Icons.workspace_premium_rounded,
      );
    case 50:
      return const _MilestoneInfo(
        emoji: '🏆',
        title: 'Efsane 50 Gün!',
        subtitle: '50 Günlük Efsane Serisi',
        message: '50 gün! Artık sen ortalama bir öğrenci değilsin. Hedefe bu inançla ulaşırsın.',
        accentColor: Color(0xFFFF6B35),
        badgeIcon: Icons.emoji_events_rounded,
      );
    case 75:
      return const _MilestoneInfo(
        emoji: '👑',
        title: '75 Gün Taç!',
        subtitle: '75 Günlük Şampiyon Serisi',
        message: '75 günlük özveri — bu kararlılık seni sıralamada çok yukarılara taşır. Dur.',
        accentColor: Color(0xFFE91E63),
        badgeIcon: Icons.military_tech_rounded,
      );
    case 100:
      return const _MilestoneInfo(
        emoji: '💯',
        title: '100 Gün Tam Not!',
        subtitle: '100 Günlük Yüzde Yüz Serisi',
        message: '100 gün! Bu artık çalışkanlık değil, karakter. Sınav günü bu gücü hissedeceksin.',
        accentColor: Color(0xFFFFB020), // gold
        badgeIcon: Icons.star_rounded,
      );
    case 150:
      return const _MilestoneInfo(
        emoji: '🌈',
        title: '150 Gün Gökkuşağı!',
        subtitle: '150 Günlük Eşsiz Seri',
        message: 'Yarım yılı aşkın bir süre boyunca her gün. Bu özveri herkese nasip olmaz.',
        accentColor: Color(0xFF00897B),
        badgeIcon: Icons.auto_awesome_rounded,
      );
    case 200:
      return const _MilestoneInfo(
        emoji: '⭐',
        title: '200 Gün Yıldız!',
        subtitle: '200 Günlük Süper Seri',
        message: '200 günde öğrendiğin disiplin, hayatın geri kalanında işine yarayacak. Bir yıldızsın.',
        accentColor: Color(0xFF7B1FA2),
        badgeIcon: Icons.star_rate_rounded,
      );
    case 365:
      return const _MilestoneInfo(
        emoji: '🎓',
        title: 'Tam Bir Yıl! Mezun!',
        subtitle: '365 Günlük Efsanevi Seri',
        message: 'Bir yıl boyunca her gün. Bu başarı tarihe geçiyor. Sen zaten kazandın.',
        accentColor: AppTheme.secondaryBrandColor, // cyan
        badgeIcon: Icons.school_rounded,
      );
    default:
      return _MilestoneInfo(
        emoji: '🔥',
        title: '$streak Günlük Seri!',
        subtitle: '$streak Günlük Çalışma Serisi',
        message: '$streak gün boyunca her gün buradaydın. Bu kararlılık seni öne taşır.',
        accentColor: AppTheme.secondaryBrandColor,
        badgeIcon: Icons.local_fire_department_rounded,
      );
  }
}

class StreakMilestoneOverlay extends ConsumerStatefulWidget {
  final int streak;
  const StreakMilestoneOverlay({super.key, required this.streak});

  @override
  ConsumerState<StreakMilestoneOverlay> createState() => _StreakMilestoneOverlayState();
}

class _StreakMilestoneOverlayState extends ConsumerState<StreakMilestoneOverlay> {
  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 4));
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) _confettiController.play();
    });
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  void _dismiss() {
    ref.read(streakMilestoneProvider.notifier).dismiss();
  }

  @override
  Widget build(BuildContext context) {
    final info = _getMilestoneInfo(widget.streak);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    // Arka plan renkleri uygulamanın slate paletinden
    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final surfaceBg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9);

    return Stack(
      alignment: Alignment.center,
      children: [
        // Arkaplan overlay
        GestureDetector(
          onTap: _dismiss,
          child: Container(
            color: Colors.black.withValues(alpha: 0.75),
            width: double.infinity,
            height: double.infinity,
          ),
        ).animate().fadeIn(duration: 250.ms),

        // Konfeti
        Positioned(
          top: 0,
          child: ConfettiWidget(
            confettiController: _confettiController,
            blastDirectionality: BlastDirectionality.explosive,
            shouldLoop: false,
            numberOfParticles: 40,
            gravity: 0.15,
            emissionFrequency: 0.04,
            colors: [
              info.accentColor,
              AppTheme.secondaryBrandColor,
              AppTheme.goldBrandColor,
              AppTheme.successBrandColor,
              Colors.white,
            ],
          ),
        ),

        // Ana kart
        Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 28),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: info.accentColor.withValues(alpha: 0.4),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: info.accentColor.withValues(alpha: 0.25),
                    blurRadius: 40,
                    spreadRadius: 2,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Üst renkli şerit
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          info.accentColor.withValues(alpha: 0.15),
                          info.accentColor.withValues(alpha: 0.05),
                        ],
                      ),
                    ),
                    padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
                    child: Column(
                      children: [
                        // Büyük emoji + badge ikonu birlikte
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              width: 88,
                              height: 88,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: info.accentColor.withValues(alpha: 0.12),
                                border: Border.all(
                                  color: info.accentColor.withValues(alpha: 0.3),
                                  width: 2,
                                ),
                              ),
                            ),
                            Text(
                              info.emoji,
                              style: const TextStyle(fontSize: 52),
                            ),
                          ],
                        )
                            .animate()
                            .scale(
                              begin: const Offset(0.3, 0.3),
                              end: const Offset(1.0, 1.0),
                              duration: 600.ms,
                              curve: Curves.elasticOut,
                            ),
                        const SizedBox(height: 16),

                        // Streak badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: info.accentColor,
                            borderRadius: BorderRadius.circular(50),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.local_fire_department_rounded,
                                color: Colors.white,
                                size: 16,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                '${widget.streak} Günlük Seri',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  fontFamily: 'Montserrat',
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ],
                          ),
                        ).animate().fadeIn(delay: 300.ms, duration: 350.ms),
                      ],
                    ),
                  ),

                  // Alt içerik
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                    child: Column(
                      children: [
                        // Başlık
                        Text(
                          info.title,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                            fontFamily: 'Montserrat',
                            letterSpacing: -0.5,
                          ),
                          textAlign: TextAlign.center,
                        ).animate().fadeIn(delay: 400.ms, duration: 350.ms),

                        const SizedBox(height: 10),

                        // Alt başlık (subtitle)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: surfaceBg,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            info.subtitle,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: info.accentColor,
                              fontFamily: 'Montserrat',
                              letterSpacing: 0.5,
                            ),
                          ),
                        ).animate().fadeIn(delay: 450.ms, duration: 350.ms),

                        const SizedBox(height: 14),

                        // Açıklama mesajı — ince ayraçla ayrılmış
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: surfaceBg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isDark
                                  ? const Color(0xFF334155)
                                  : const Color(0xFFE2E8F0),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.format_quote_rounded,
                                color: info.accentColor,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  info.message,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: isDark
                                        ? const Color(0xFF94A3B8)
                                        : const Color(0xFF64748B),
                                    height: 1.55,
                                    fontFamily: 'Montserrat',
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ).animate().fadeIn(delay: 500.ms, duration: 350.ms),

                        const SizedBox(height: 20),

                        // Devam butonu — uygulamanın standart button stili
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _dismiss,
                            icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                            label: const Text(
                              'Çalışmaya Devam Et',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                fontFamily: 'Montserrat',
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: info.accentColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                              elevation: 0,
                            ),
                          ),
                        ).animate().fadeIn(delay: 620.ms, duration: 350.ms),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        )
            .animate()
            .scale(
              begin: const Offset(0.85, 0.85),
              end: const Offset(1.0, 1.0),
              duration: 400.ms,
              curve: Curves.easeOutBack,
            )
            .fadeIn(duration: 300.ms),
      ],
    );
  }
}
