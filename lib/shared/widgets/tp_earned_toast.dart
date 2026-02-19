// lib/shared/widgets/tp_earned_toast.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:taktik/features/quests/logic/tp_earned_notifier.dart';

/// AI Hub özellik kullanımlarında kazanılan TP'yi gösteren toast bildirimi.
/// main.dart builder Stack'inde global olarak gösterilir — tüm sayfalarda çalışır.
class TpEarnedToast extends ConsumerStatefulWidget {
  final int points;
  final String featureLabel;

  const TpEarnedToast({
    super.key,
    required this.points,
    required this.featureLabel,
  });

  @override
  ConsumerState<TpEarnedToast> createState() => _TpEarnedToastState();
}

class _TpEarnedToastState extends ConsumerState<TpEarnedToast>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _slideAnim;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();

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

    // Giriş animasyonu
    _controller.forward();

    // 3.5 saniye sonra çıkış animasyonu başlat, sonra provider'ı temizle
    Future.delayed(const Duration(milliseconds: 3500), () {
      if (!mounted) return;
      _controller.reverse().then((_) {
        if (mounted) {
          ref.read(tpEarnedProvider.notifier).clear();
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

    // Tema uyumlu renkler
    final bgColor = isDark
        ? colorScheme.surface          // slate-800
        : colorScheme.surface;         // white
    final borderColor = colorScheme.primary.withValues(alpha: 0.5); // cyan
    final goldColor = const Color(0xFFFFB020); // AppTheme.goldBrandColor
    final textColor = colorScheme.onSurface;
    final subtitleColor = colorScheme.onSurfaceVariant;

    return Positioned(
      top: MediaQuery.of(context).padding.top + 12,
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
                  color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.10),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                // İkon
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: goldColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.bolt_rounded,
                    color: goldColor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                // Metin
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '+${widget.points} TP Kazandın!',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: goldColor,
                          letterSpacing: 0.1,
                        ),
                      ),
                      if (widget.featureLabel.isNotEmpty)
                        Text(
                          widget.featureLabel,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: subtitleColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                    ],
                  ),
                ),
                // Sağ ikon
                Icon(
                  Icons.star_rounded,
                  color: goldColor,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
