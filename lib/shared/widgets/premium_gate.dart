import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class PremiumGate extends StatelessWidget {
  const PremiumGate({
    super.key,
    required this.isPremium,
    required this.child,
    this.useShade = true,
  });

  final bool isPremium;
  final Widget child;
  final bool useShade;

  @override
  Widget build(BuildContext context) {
    // Premium users get direct access to the feature.
    if (isPremium) {
      return child;
    }

    // Non-premium users see a visually distinct version.
    // Tapping it takes them to the premium invitation screen.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => context.go('/premium'),
      child: useShade
          ? Stack(
              fit: StackFit.expand,
              children: [
                child,
                // A subtle shade to indicate that the feature is part of the
                // premium experience, without using intrusive locks or icons.
                // This aligns with the "Invisible Luxury" principle.
                Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ],
            )
          : child,
    );
  }
}