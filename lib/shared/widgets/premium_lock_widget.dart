import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

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
    if (!isLocked) {
      return child;
    }

    return GestureDetector(
      onTap: () => context.go('/premium'),
      child: Stack(
        children: [
          child,
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20), // Match the card's border radius
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                child: Container(
                  color: Colors.black.withOpacity(0.3),
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.lock_rounded,
                        color: Colors.white,
                        size: 40,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Premium Kilidi',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}