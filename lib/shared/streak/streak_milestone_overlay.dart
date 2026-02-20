// lib/shared/streak/streak_milestone_overlay.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lottie/lottie.dart';
import 'streak_milestone_notifier.dart';

class _MilestoneInfo {
  final String title;
  final String subtitle;
  final Color accentColor;

  const _MilestoneInfo({
    required this.title,
    required this.subtitle,
    required this.accentColor,
  });
}

_MilestoneInfo _getMilestoneInfo(int streak) {
  final rand = Random();

  // Sınav hazırlık odaklı kısa motivasyon cümleleri
  final randomSubtitles = [
    "Her gün çözdükçe sıralaman yükseliyor!",
    "Düzenli çalışma fark yaratır, devam et!",
    "Hedefine bir adım daha yaklaştın.",
    "Disiplinli çalışma meyvesini verecek!",
    "Rakiplerinden bir adım öndesin.",
    "Çalışma rutinin oturdu, harika gidiyorsun!",
  ];

  String getRandomSubtitle() => randomSubtitles[rand.nextInt(randomSubtitles.length)];

  const fireAccent = Color(0xFFF97316);

  switch (streak) {
    case 1:
      return const _MilestoneInfo(
        title: '🔥 İlk Adım Atıldı!',
        subtitle: 'Çalışma serisi başladı, devam et!',
        accentColor: Color(0xFF22D3EE),
      );
    case 3:
      return const _MilestoneInfo(
        title: '🔥 3 Gün Serisi!',
        subtitle: 'Ritim yakalandı, böyle sürsün!',
        accentColor: fireAccent,
      );
    case 7:
      return const _MilestoneInfo(
        title: '🔥 7 Günlük Seri!',
        subtitle: 'Tam bir hafta aralıksız çalıştın.',
        accentColor: Color(0xFF94A3B8),
      );
    case 14:
      return const _MilestoneInfo(
        title: '🔥 14 Günlük Seri!',
        subtitle: 'İki haftadır düzenli ilerliyorsun.',
        accentColor: Color(0xFF818CF8),
      );
    case 21:
      return const _MilestoneInfo(
        title: '🔥 21 Gün — Alışkanlık!',
        subtitle: 'Artık çalışmak senin rutinin.',
        accentColor: Color(0xFF3B82F6),
      );
    case 30:
      return const _MilestoneInfo(
        title: '🔥 30 Günlük Seri!',
        subtitle: 'Bir aydır aralıksız, başarı kaçınılmaz.',
        accentColor: Color(0xFFFFB020),
      );
    case 50:
      return const _MilestoneInfo(
        title: '🔥 50 Günlük Seri!',
        subtitle: 'Azmin çelikten güçlü, tebrikler!',
        accentColor: Color(0xFFF43F5E),
      );
    case 75:
      return const _MilestoneInfo(
        title: '🔥 75 Günlük Seri!',
        subtitle: 'Zirveye koşar adım gidiyorsun.',
        accentColor: Color(0xFFA855F7),
      );
    case 100:
      return const _MilestoneInfo(
        title: '🔥 100 Gün — Efsane!',
        subtitle: 'Bu bir seri değil, yaşam tarzı.',
        accentColor: Color(0xFFF59E0B),
      );
    case 150:
      return const _MilestoneInfo(
        title: '🔥 150 Günlük Seri!',
        subtitle: 'Sınırlarını çoktan aştın, durma!',
        accentColor: Color(0xFF10B981),
      );
    case 200:
      return const _MilestoneInfo(
        title: '🔥 200 Günlük Seri!',
        subtitle: 'Geleceğini her gün inşa ediyorsun.',
        accentColor: Color(0xFFEC4899),
      );
    case 365:
      return const _MilestoneInfo(
        title: '🔥 365 Gün — Tarih Yazdın!',
        subtitle: 'Tam bir yıl aralıksız, efsanesin!',
        accentColor: Color(0xFF6366F1),
      );
    default:
      return _MilestoneInfo(
        title: '🔥 $streak Günlük Seri!',
        subtitle: getRandomSubtitle(),
        accentColor: fireAccent,
      );
  }
}

class StreakMilestoneOverlay extends ConsumerStatefulWidget {
  final int streak;
  const StreakMilestoneOverlay({super.key, required this.streak});

  @override
  ConsumerState<StreakMilestoneOverlay> createState() => _StreakMilestoneOverlayState();
}

class _StreakMilestoneOverlayState extends ConsumerState<StreakMilestoneOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _slideAnim;
  late final Animation<double> _fadeAnim;
  late final _MilestoneInfo info;

  @override
  void initState() {
    super.initState();
    info = _getMilestoneInfo(widget.streak);

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _slideAnim = Tween<double>(begin: -1.0, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
      ),
    );

    _controller.forward();

    // 3 saniye sonra otomatik kapat
    Future.delayed(const Duration(milliseconds: 3000), () {
      if (!mounted) return;
      _controller.reverse().then((_) {
        if (mounted) {
          ref.read(streakMilestoneProvider.notifier).dismiss();
        }
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final bgColor = isDark ? colorScheme.surface : colorScheme.surface;
    final borderColor = info.accentColor.withValues(alpha: 0.5);
    final subtitleColor = colorScheme.onSurfaceVariant;

    return Positioned(
      top: MediaQuery.of(context).padding.top + kToolbarHeight + 8,
      left: 16,
      right: 16,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(0, _slideAnim.value * 80),
            child: Opacity(
              opacity: _fadeAnim.value.clamp(0.0, 1.0),
              child: child,
            ),
          );
        },
        child: GestureDetector(
          onTap: () {
            _controller.reverse().then((_) {
              if (mounted) {
                ref.read(streakMilestoneProvider.notifier).dismiss();
              }
            });
          },
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderColor, width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: info.accentColor.withValues(alpha: isDark ? 0.25 : 0.15),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Sol: Başlık ve açıklama
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          info.title,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: info.accentColor,
                            letterSpacing: 0.1,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          info.subtitle,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: subtitleColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Sağ: Lottie Animasyonu
                  SizedBox(
                    width: 48,
                    height: 48,
                    child: Lottie.asset(
                      'assets/lotties/fire.json',
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return Icon(
                          Icons.local_fire_department_rounded,
                          size: 32,
                          color: info.accentColor,
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

