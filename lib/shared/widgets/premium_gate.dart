import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// A widget that guards premium features.
///
/// If the user `isPremium`, it returns the `child` directly, unlocking the feature.
/// If the user is not premium, it displays the `child` but overlays a stylish
/// badge and handles navigation to a specified offer screen on tap, without
/// obstructing the view of the feature itself.
class PremiumGate extends StatelessWidget {
  const PremiumGate({
    super.key,
    required this.isPremium,
    required this.child,
    this.onTap,
  });

  final bool isPremium;
  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    // Premium users get direct, un-gated access to the feature.
    if (isPremium) {
      return child;
    }

    // For non-premium users, show the feature but gate it.
    // Tapping anywhere on the widget will execute the provided onTap callback
    // or navigate to the generic premium screen if no callback is provided.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap ?? () => context.go('/premium'),
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

          // A centered lock icon to indicate the feature is premium.
          Positioned.fill(
            child: Center(
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black.withOpacity(0.4),
                ),
                child: const Icon(
                  Icons.lock_outline_rounded,
                  color: Colors.white,
                  size: 32,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}