// lib/shared/streak/streak_milestone_overlay.dart
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:confetti/confetti.dart';
import 'streak_milestone_notifier.dart';

class _MilestoneInfo {
  final String emoji;
  final String title;
  final String message;
  final Color color;
  const _MilestoneInfo({
    required this.emoji,
    required this.title,
    required this.message,
    required this.color,
  });
}

_MilestoneInfo _getMilestoneInfo(int streak) {
  if (streak == 1) {
    return const _MilestoneInfo(emoji: '🔥', title: 'Başlangıç!', message: 'İlk gününü tamamladın! Büyük yolculuklar küçük adımlarla başlar.', color: Color(0xFFFF6B35));
  } else if (streak == 2) {
    return const _MilestoneInfo(emoji: '⚡', title: '2 Gün Seri!', message: 'İki gün üst üste giriş yaptın. Alışkanlık oluşmaya başlıyor!', color: Color(0xFFFFC107));
  } else if (streak == 3) {
    return const _MilestoneInfo(emoji: '🌟', title: '3 Günlük Seri!', message: 'Üç gün devam ettin! Bir alışkanlık oluşturmak sadece 21 gün sürer.', color: Color(0xFF4CAF50));
  } else if (streak == 5) {
    return const _MilestoneInfo(emoji: '🏅', title: '5 Günlük Bronz!', message: 'Beş gün boyunca buradaydın! Bu disiplin seni başarıya taşır.', color: Color(0xFFCD7F32));
  } else if (streak == 7) {
    return const _MilestoneInfo(emoji: '🥈', title: '1 Hafta Tamamlandı!', message: 'Bir haftayı eksiksiz tamamladın! Tutarlılık en büyük güçtür.', color: Color(0xFF9E9E9E));
  } else if (streak == 10) {
    return const _MilestoneInfo(emoji: '💎', title: '10 Gün Çalışma Serisi!', message: 'On gün! Artık çalışma bir yaşam biçimi oluyor. Harika gidiyorsun!', color: Color(0xFF00BCD4));
  } else if (streak == 14) {
    return const _MilestoneInfo(emoji: '🚀', title: '2 Hafta Kesintisiz!', message: 'İki hafta boyunca her gün çalıştın. Zirveyesin!', color: Color(0xFF673AB7));
  } else if (streak == 21) {
    return const _MilestoneInfo(emoji: '🧠', title: 'Alışkanlık Ustası!', message: '21 gün! Bilim bu sürenin bir alışkanlık oluşturmak için yeterli olduğunu söylüyor.', color: Color(0xFF3F51B5));
  } else if (streak == 30) {
    return const _MilestoneInfo(emoji: '🥇', title: '30 Günlük Altın Seri!', message: 'Bir ay boyunca her gün! Bu başarı seni diğerlerinden ayırıyor.', color: Color(0xFFFFD700));
  } else if (streak == 50) {
    return const _MilestoneInfo(emoji: '🏆', title: '50 Gün Efsane!', message: '50 gün! Artık sen bir çalışma efsanesisin. Devam et!', color: Color(0xFFFF5722));
  } else if (streak == 75) {
    return const _MilestoneInfo(emoji: '👑', title: '75 Gün Kral!', message: '75 günlük seri! Bu kararlılık her hedefi aşmana yeter.', color: Color(0xFFE91E63));
  } else if (streak == 100) {
    return const _MilestoneInfo(emoji: '💯', title: '100 Gün Tam Puan!', message: '100 gün! Bu inanılmaz bir başarı. Gerçek bir şampiyon oldun!', color: Color(0xFFE53935));
  } else if (streak == 150) {
    return const _MilestoneInfo(emoji: '🌈', title: '150 Gün!', message: '150 gün boyunca buradaydın. Bu özveri seni herkesten ayırıyor!', color: Color(0xFF00897B));
  } else if (streak == 200) {
    return const _MilestoneInfo(emoji: '⭐', title: '200 Gün Süper Yıldız!', message: '200 güne ulaştın! Artık sen bir ilham kaynağısın.', color: Color(0xFF7B1FA2));
  } else if (streak == 365) {
    return const _MilestoneInfo(emoji: '🎓', title: 'Tam Bir Yıl!', message: 'Bir yıl boyunca her gün! Bu başarı tarihe geçiyor. Tebrikler!', color: Color(0xFFD32F2F));
  }
  return _MilestoneInfo(emoji: '🔥', title: '$streak Günlük Seri!', message: '$streak gün boyunca her gün çalıştın. Devam et!', color: const Color(0xFFFF6B35));
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
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
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
        GestureDetector(
          onTap: _dismiss,
          child: Container(
            color: Colors.black.withValues(alpha: 0.7),
            width: double.infinity,
            height: double.infinity,
          ),
        ),
        Positioned(
          top: 0,
          child: ConfettiWidget(
            confettiController: _confettiController,
            blastDirectionality: BlastDirectionality.explosive,
            shouldLoop: false,
            numberOfParticles: 30,
            colors: [info.color, Colors.orange, Colors.yellow, Colors.green, Colors.blue],
          ),
        ),
        Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 32),
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [const Color(0xFF1A1A2E), const Color(0xFF16213E)]
                    : [Colors.white, Colors.grey.shade50],
              ),
              border: Border.all(color: info.color.withValues(alpha: 0.5), width: 2),
              boxShadow: [
                BoxShadow(color: info.color.withValues(alpha: 0.3), blurRadius: 30, spreadRadius: 5),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(info.emoji, style: const TextStyle(fontSize: 64))
                    .animate()
                    .scale(
                      begin: const Offset(0.0, 0.0),
                      end: const Offset(1.0, 1.0),
                      duration: 600.ms,
                      curve: Curves.elasticOut,
                    ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  decoration: BoxDecoration(
                    color: info.color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(50),
                    border: Border.all(color: info.color.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.local_fire_department_rounded, color: info.color, size: 22),
                      const SizedBox(width: 6),
                      Text(
                        '${widget.streak} Günlük Seri',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: info.color),
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: 200.ms, duration: 400.ms),
                const SizedBox(height: 14),
                Text(
                  info.title,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ).animate().fadeIn(delay: 350.ms, duration: 400.ms),
                const SizedBox(height: 10),
                Text(
                  info.message,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.white.withValues(alpha: 0.7) : Colors.black.withValues(alpha: 0.6),
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ).animate().fadeIn(delay: 500.ms, duration: 400.ms),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _dismiss,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: info.color,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Devam Et! 💪',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ).animate().fadeIn(delay: 650.ms, duration: 400.ms),
              ],
            ),
          ),
        ).animate().scale(
              begin: const Offset(0.8, 0.8),
              end: const Offset(1.0, 1.0),
              duration: 400.ms,
              curve: Curves.easeOutBack,
            ),
      ],
    );
  }
}
