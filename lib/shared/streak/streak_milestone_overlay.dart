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
  final List<Color> gradient;

  const _MilestoneInfo({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.message,
    required this.accentColor,
    required this.gradient,
  });
}

_MilestoneInfo _getMilestoneInfo(int streak) {
  switch (streak) {
    case 1:
      return const _MilestoneInfo(
        emoji: '🌱',
        title: 'Tohum Atıldı!',
        subtitle: 'Yolculuğun İlk Günü',
        message: 'Büyük değişimler tek bir kararla başlar. Bugün o kararı verdin, harikasın!',
        accentColor: Color(0xFF22D3EE),
        gradient: [Color(0xFF0891B2), Color(0xFF22D3EE)],
      );
    case 2:
      return const _MilestoneInfo(
        emoji: '⚡',
        title: 'Kıvılcım Çıktı!',
        subtitle: '2 Günlük Seri',
        message: 'Dün geldin, bugün de buradasın. Momentum kazanmaya başladın bile!',
        accentColor: Color(0xFF34D399),
        gradient: [Color(0xFF059669), Color(0xFF34D399)],
      );
    case 3:
      return const _MilestoneInfo(
        emoji: '🔥',
        title: 'Alev Alıyor!',
        subtitle: '3 Günlük Seri',
        message: 'Üç gün üst üste! Artık sadece bir heves olmadığını kanıtlıyorsun.',
        accentColor: Color(0xFFFB923C),
        gradient: [Color(0xFFEA580C), Color(0xFFFB923C)],
      );
    case 5:
      return const _MilestoneInfo(
        emoji: '🏅',
        title: 'Beşlik Çak!',
        subtitle: '5 Günlük Bronz Seri',
        message: 'Hafta içini devirdin. Rakiplerin yorulurken sen hala sahadasın!',
        accentColor: Color(0xFFCD7F32),
        gradient: [Color(0xFF92400E), Color(0xFFCD7F32)],
      );
    case 7:
      return const _MilestoneInfo(
        emoji: '🥈',
        title: 'Haftanın Galibi!',
        subtitle: '7 Günlük Gümüş Seri',
        message: 'Tam bir hafta! Bu disiplinle aşamayacağın hiçbir engel yok.',
        accentColor: Color(0xFF94A3B8),
        gradient: [Color(0xFF475569), Color(0xFF94A3B8)],
      );
    case 10:
      return const _MilestoneInfo(
        emoji: '💎',
        title: 'On Numara İlerleme!',
        subtitle: '10 Günlük Elmas Seri',
        message: 'Çift hanelere ulaştın! Çalışma düzenin bir elmas gibi parlıyor.',
        accentColor: Color(0xFF38BDF8),
        gradient: [Color(0xFF0284C7), Color(0xFF38BDF8)],
      );
    case 14:
      return const _MilestoneInfo(
        emoji: '🚀',
        title: 'Roket Modu!',
        subtitle: '14 Günlük Seri',
        message: 'İki haftadır her gün! Artık seni durdurmak imkansıza yakın.',
        accentColor: Color(0xFF818CF8),
        gradient: [Color(0xFF4F46E5), Color(0xFF818CF8)],
      );
    case 21:
      return const _MilestoneInfo(
        emoji: '🧠',
        title: 'Zihin Ustası!',
        subtitle: '21 Günlük Seri',
        message: 'Bilim der ki; bir alışkanlık 21 günde oluşur. Tebrikler, sen artık bir "çalışkansın"!',
        accentColor: Color(0xFF3B82F6),
        gradient: [Color(0xFF1D4ED8), Color(0xFF3B82F6)],
      );
    case 30:
      return const _MilestoneInfo(
        emoji: '🥇',
        title: 'Altın Ay!',
        subtitle: '30 Günlük Altın Seri',
        message: 'Dile kolay, tam bir ay! Sınavı kazananlar işte bu 30 günlük disiplinden çıkıyor.',
        accentColor: Color(0xFFFFB020),
        gradient: [Color(0xFFB45309), Color(0xFFFFB020)],
      );
    case 50:
      return const _MilestoneInfo(
        emoji: '🏆',
        title: 'Yolun Yarısı!',
        subtitle: '50 Günlük Efsane Seri',
        message: '50 gün boyunca pes etmedin. Sen artık diğer öğrencilerin ilham kaynağısın!',
        accentColor: Color(0xFFF43F5E),
        gradient: [Color(0xFFBE123C), Color(0xFFF43F5E)],
      );
    case 75:
      return const _MilestoneInfo(
        emoji: '👑',
        title: 'Krallara Layık!',
        subtitle: '75 Günlük Şampiyon Seri',
        message: '75 gündür her sabah bu amaçla uyanıyorsun. Başarı seni bekliyor, durma!',
        accentColor: Color(0xFFA855F7),
        gradient: [Color(0xFF7E22CE), Color(0xFFA855F7)],
      );
    case 100:
      return const _MilestoneInfo(
        emoji: '💯',
        title: 'Dalya Dedik!',
        subtitle: '100 Günlük Kusursuz Seri',
        message: '100 GÜN! Bu artık bir seri değil, bir karakter meselesi. Sen gerçek bir şampiyonsun.',
        accentColor: Color(0xFFF59E0B),
        gradient: [Color(0xFFD97706), Color(0xFFF59E0B)],
      );
    case 150:
      return const _MilestoneInfo(
        emoji: '🌈',
        title: 'Gökkuşağı Etkisi!',
        subtitle: '150 Günlük Eşsiz Seri',
        message: 'Yarım yılı devirmek üzeresin. Kararlılığın karşısında tüm zorluklar eğiliyor.',
        accentColor: Color(0xFF10B981),
        gradient: [Color(0xFF047857), Color(0xFF10B981)],
      );
    case 200:
      return const _MilestoneInfo(
        emoji: '⭐',
        title: 'Süper Nova!',
        subtitle: '200 Günlük Yıldız Seri',
        message: '200 gün... Seninle gurur duyuyoruz. Bu azim seni hayallerindeki o bölüme götürecek.',
        accentColor: Color(0xFFEC4899),
        gradient: [Color(0xFFBE185D), Color(0xFFEC4899)],
      );
    case 365:
      return const _MilestoneInfo(
        emoji: '🎓',
        title: 'Efsanevi Yıl!',
        subtitle: '365 Günlük Tarihi Seri',
        message: 'Tam 1 yıl! Sen sadece sınavı değil, kendi sınırlarını da kazandın. Efsanesin!',
        accentColor: Color(0xFF6366F1),
        gradient: [Color(0xFF4338CA), Color(0xFF6366F1)],
      );
    default:
      return _MilestoneInfo(
        emoji: '🔥',
        title: 'Harika Gidiyorsun!',
        subtitle: '$streak Günlük Seri',
        message: 'Her gün üstüne koyarak ilerliyorsun. Bu kararlılık seni zirveye taşıyacak.',
        accentColor: AppTheme.secondaryBrandColor,
        gradient: [const Color(0xFF0F172A), AppTheme.secondaryBrandColor],
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
    Future.delayed(const Duration(milliseconds: 300), () {
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

    return Stack(
      alignment: Alignment.center,
      children: [
        // 1. Derinlik: Karartılmış Arka Plan
        GestureDetector(
          onTap: _dismiss,
          child: Container(
            color: Colors.black.withValues(alpha: 0.85),
            width: double.infinity,
            height: double.infinity,
          ),
        ).animate().fadeIn(duration: 400.ms),

        // 2. Derinlik: Arka Plan Işığı (Glow)
        IgnorePointer(
          child: Container(
            width: 300,
            height: 300,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: info.accentColor.withValues(alpha: 0.15),
            ),
          ).animate(onPlay: (c) => c.repeat(reverse: true)).scale(
            begin: const Offset(1, 1),
            end: const Offset(1.4, 1.4),
            duration: 2.seconds,
            curve: Curves.easeInOut,
          ),
        ),

        // 3. Derinlik: Konfeti
        Positioned(
          top: -50,
          child: ConfettiWidget(
            confettiController: _confettiController,
            blastDirectionality: BlastDirectionality.explosive,
            shouldLoop: false,
            numberOfParticles: 50,
            gravity: 0.1,
            colors: [...info.gradient, Colors.white],
          ),
        ),

        // 4. Derinlik: Ana Kart
        Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 30),
              width: double.infinity,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(32),
                boxShadow: [
                  BoxShadow(
                    color: info.accentColor.withValues(alpha: 0.3),
                    blurRadius: 50,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Kart Başlığı (Gradient alan)
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            info.gradient[0].withValues(alpha: 0.8),
                            info.gradient[1].withValues(alpha: 0.9),
                          ],
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Column(
                        children: [
                          // Emoji ve Halo Efekti
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              Container(
                                width: 110,
                                height: 110,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white.withValues(alpha: 0.2),
                                ),
                              ).animate().scale(
                                duration: 1.seconds,
                                curve: Curves.elasticOut,
                              ),
                              Text(
                                info.emoji,
                                style: const TextStyle(fontSize: 60),
                              ).animate().shake(delay: 500.ms),
                            ],
                          ),
                          const SizedBox(height: 20),
                          // Rozet (Badge)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.1),
                                  blurRadius: 10,
                                ),
                              ],
                            ),
                            child: Text(
                              info.subtitle.toUpperCase(),
                              style: TextStyle(
                                color: info.gradient[0],
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.2,
                                fontFamily: 'Montserrat',
                              ),
                            ),
                          ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.5, end: 0),
                        ],
                      ),
                    ),

                    // Kart İçeriği
                    Padding(
                      padding: const EdgeInsets.fromLTRB(30, 24, 30, 32),
                      child: Column(
                        children: [
                          Text(
                            info.title,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                              fontFamily: 'Montserrat',
                            ),
                          ).animate().fadeIn(delay: 600.ms),
                          const SizedBox(height: 12),
                          Text(
                            info.message,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 15,
                              height: 1.5,
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.7)
                                  : const Color(0xFF64748B),
                              fontFamily: 'Montserrat',
                              fontWeight: FontWeight.w500,
                            ),
                          ).animate().fadeIn(delay: 800.ms),
                          const SizedBox(height: 32),

                          // Şık Devam Butonu
                          Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              gradient: LinearGradient(colors: info.gradient),
                              boxShadow: [
                                BoxShadow(
                                  color: info.accentColor.withValues(alpha: 0.4),
                                  blurRadius: 15,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: ElevatedButton(
                              onPressed: _dismiss,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                foregroundColor: Colors.white,
                                shadowColor: Colors.transparent,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: const Text(
                                'HARİKA, DEVAM ET!',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  fontFamily: 'Montserrat',
                                  letterSpacing: 1,
                                ),
                              ),
                            ),
                          ).animate().fadeIn(delay: 1.seconds).scale(
                            begin: const Offset(0.9, 0.9),
                            end: const Offset(1, 1),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ).animate().scale(
          begin: const Offset(0.7, 0.7),
          end: const Offset(1.0, 1.0),
          duration: 500.ms,
          curve: Curves.easeOutBack,
        ),
      ],
    );
  }
}