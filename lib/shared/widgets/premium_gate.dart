import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:taktik/core/theme/app_theme.dart';

/// A widget that guards premium features.
///
/// If the user `isPremium`, it returns the `child` directly, unlocking the feature.
/// If the user is not premium, it displays the `child` but overlays a stylish
/// badge and handles navigation to the premium screen on tap, without
/// obstructing the view of the feature itself.
class PremiumGate extends StatelessWidget {
  const PremiumGate({
    super.key,
    required this.isPremium,
    required this.child,
  });

  final bool isPremium;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // Premium users get direct, un-gated access to the feature.
    if (isPremium) {
      return child;
    }

    // For non-premium users, show the feature but gate it with a badge.
    // Tapping anywhere on the widget will navigate to the premium screen.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => context.go('/premium'),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // The feature UI is visible but non-interactive behind the gate.
          child,

          // A subtle gradient overlay to hint at the locked state without
          // being as intrusive as a full-color shade.
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20), // Match the tile's border radius
                gradient: LinearGradient(
                  begin: Alignment.bottomRight,
                  end: Alignment.topLeft,
                  colors: [
                    Colors.black.withOpacity(0.1),
                    Colors.black.withOpacity(0.3),
                  ],
                  stops: const [0.0, 0.7],
                ),
              ),
            ),
          ),

          // The elegant premium badge, positioned at the top right.
          const Positioned(
            top: 10,
            right: 10,
            child: _PremiumBadge(),
          ),
        ],
      ),
    );
  }
}

/// A stylish, animated badge to indicate a premium feature.
class _PremiumBadge extends StatefulWidget {
  const _PremiumBadge();

  @override
  State<_PremiumBadge> createState() => _PremiumBadgeState();
}

class _PremiumBadgeState extends State<_PremiumBadge> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _scale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.1), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.1, end: 1.0), weight: 50),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppTheme.goldColor, AppTheme.secondaryColor],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: AppTheme.goldColor.withOpacity(0.5),
              blurRadius: 8,
              offset: const Offset(0, 2),
            )
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.workspace_premium_rounded, color: Colors.black, size: 14),
            SizedBox(width: 5),
            Text(
              'Premium',
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w800,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}