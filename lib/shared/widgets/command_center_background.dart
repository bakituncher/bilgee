// lib/shared/widgets/command_center_background.dart
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:taktik/core/theme/app_theme.dart';

/// Decorative animated background for the dashboard experience.
///
/// The previous design relied on a flat scaffold background which made the
/// dense dashboard blocks feel boxed-in. This layered background adds soft
/// radial glows and a subtle vignette that reacts to scroll, giving the home
/// screen more depth without hurting readability.
class CommandCenterBackground extends StatelessWidget {
  const CommandCenterBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF0B1222),
                AppTheme.scaffoldBackgroundColor,
                Color(0xFF111B30),
              ],
            ),
          ),
          child: Stack(
            children: [
              Align(
                alignment: const Alignment(-0.85, -1.1),
                child: _GlowOrb(
                  color: AppTheme.secondaryColor.withOpacity(0.18),
                  size: 340,
                  blur: 140,
                ),
              ),
              Align(
                alignment: const Alignment(0.9, -0.8),
                child: _GlowOrb(
                  color: AppTheme.successColor.withOpacity(0.12),
                  size: 260,
                  blur: 110,
                ),
              ),
              Align(
                alignment: const Alignment(-1.1, 0.75),
                child: _GlowOrb(
                  color: AppTheme.goldColor.withOpacity(0.10),
                  size: 280,
                  blur: 120,
                ),
              ),
              Align(
                alignment: const Alignment(0.8, 1.1),
                child: _GlowOrb(
                  color: AppTheme.secondaryColor.withOpacity(0.08),
                  size: 320,
                  blur: 140,
                ),
              ),
              // Vignette overlay to keep content readable near the edges.
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      radius: 1.2,
                      center: const Alignment(0, -0.1),
                      colors: [
                        Colors.transparent,
                        AppTheme.primaryColor.withOpacity(0.45),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  const _GlowOrb({
    required this.color,
    required this.size,
    required this.blur,
  });

  final Color color;
  final double size;
  final double blur;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color, color.withOpacity(0.0)],
          ),
        ),
        child: ClipOval(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: blur / 40, sigmaY: blur / 40),
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
  }
}
