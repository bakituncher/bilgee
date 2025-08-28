// lib/features/onboarding/widgets/tutorial_overlay.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bilge_ai/core/theme/app_theme.dart';
import 'package:bilge_ai/features/onboarding/models/tutorial_step.dart';
import 'package:bilge_ai/features/onboarding/providers/tutorial_provider.dart';
import 'tutorial_painter.dart';

class TutorialOverlay extends ConsumerWidget {
  final List<TutorialStep> steps;
  const TutorialOverlay({super.key, required this.steps});

  void _finishTutorial(WidgetRef ref) {
    // DEĞİŞİKLİK: Bitirme mantığı artık merkezi olarak yönetiliyor.
    ref.read(tutorialProvider.notifier).finish();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentStepIndex = ref.watch(tutorialProvider);
    if (currentStepIndex == null) return const SizedBox.shrink();

    final step = steps[currentStepIndex];
    final key = step.highlightKey;
    Rect? highlightRect;

    if (key != null && key.currentContext != null) {
      final renderBox = key.currentContext!.findRenderObject() as RenderBox;
      final offset = renderBox.localToGlobal(Offset.zero);
      highlightRect = Rect.fromLTWH(offset.dx, offset.dy, renderBox.size.width, renderBox.size.height);
    }

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          GestureDetector(
            onTap: () {
              // Sadece navigasyon gerektirmeyen adımlarda ekrana dokunarak ilerle
              if (!step.isNavigational) {
                ref.read(tutorialProvider.notifier).next();
              }
            },
            child: CustomPaint(
              size: MediaQuery.of(context).size,
              painter: TutorialPainter(highlightRect: highlightRect),
              child: ClipPath(
                clipper: _HighlightClipper(highlightRect),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                  child: Container(
                    color: Colors.black.withOpacity(0.7),
                  ),
                ),
              ),
            ),
          ),
          _buildTutorialContent(context, ref, step, highlightRect),
        ],
      ),
    );
  }

  Widget _buildTutorialContent(BuildContext context, WidgetRef ref, TutorialStep step, Rect? rect) {
    final bottomNavBarHeight = kBottomNavigationBarHeight + 20;

    return Positioned.fill(
      child: LayoutBuilder(builder: (context, constraints) {

        double top = constraints.maxHeight / 2 - 150;
        if (rect != null) {
          if(rect.center.dy > constraints.maxHeight / 2){
            top = rect.top - 250;
          } else {
            top = rect.bottom + 20;
          }
          top = top.clamp(40.0, constraints.maxHeight - 270 - bottomNavBarHeight);
        }

        return Stack(
          children: [
            Positioned(
              top: top,
              left: 24,
              right: 24,
              child: _TutorialCard(step: step)
                  .animate()
                  .fadeIn(duration: 400.ms)
                  .slideY(begin: 0.2, duration: 400.ms, curve: Curves.easeOutCubic),
            ),
            Positioned(
              top: 40,
              right: 16,
              child: TextButton(
                onPressed: () => _finishTutorial(ref),
                child: const Text("Turu Atla", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        );
      }),
    );
  }
}

class _TutorialCard extends ConsumerWidget {
  final TutorialStep step;
  const _TutorialCard({required this.step});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: AppTheme.cardColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppTheme.secondaryColor, width: 2),
          boxShadow: [
            BoxShadow(color: AppTheme.secondaryColor.withOpacity(0.3), blurRadius: 20)
          ]
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Image.asset('assets/images/bilge_baykus.png', height: 60),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(step.title, style: Theme.of(context).textTheme.titleLarge?.copyWith(color: AppTheme.secondaryColor, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(step.text, style: const TextStyle(color: AppTheme.textColor, height: 1.5, fontSize: 15)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () => ref.read(tutorialProvider.notifier).next(),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: Text(step.buttonText, textAlign: TextAlign.center),
          )
        ],
      ),
    );
  }
}


class _HighlightClipper extends CustomClipper<Path> {
  final Rect? highlightRect;
  _HighlightClipper(this.highlightRect);

  @override
  Path getClip(Size size) {
    final path = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    if (highlightRect != null) {
      final highlightPath = RRect.fromRectAndRadius(highlightRect!.inflate(8), const Radius.circular(16));
      path.addRRect(highlightPath);
      path.fillType = PathFillType.evenOdd;
    }
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => true;
}