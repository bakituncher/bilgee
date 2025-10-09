import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:taktik/core/theme/app_theme.dart';

class PremiumLock extends StatelessWidget {
  const PremiumLock({
    super.key,
    required this.isLocked,
    required this.child,
  });

  final bool isLocked;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!isLocked) return child;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => context.go('/premium'),
      child: Stack(
        children: [
          child,
          // Deneyimi tamamen kapatmayan, hafif bir film tabakası
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
          // Sağ üstte şık premium kilit rozeti
          Positioned(
            right: 10,
            top: 10,
            child: _PremiumBadge(),
          ),
        ],
      ),
    );
  }
}

class _PremiumBadge extends StatefulWidget {
  @override
  State<_PremiumBadge> createState() => _PremiumBadgeState();
}

class _PremiumBadgeState extends State<_PremiumBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))
      ..repeat(reverse: true);
    _scale = Tween(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _c, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppTheme.goldColor, AppTheme.secondaryColor],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: AppTheme.goldColor.withOpacity(0.35),
              blurRadius: 10,
              spreadRadius: 0,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.lock_rounded, color: Colors.black, size: 16),
            SizedBox(width: 6),
            Text(
              'Premium',
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w800,
                fontSize: 12,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}