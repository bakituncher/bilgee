// lib/features/onboarding/widgets/tutorial_overlay.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:taktik/features/onboarding/models/tutorial_step.dart';
import 'package:taktik/features/onboarding/providers/tutorial_provider.dart';
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
              painter: TutorialPainter(highlightRect: highlightRect, highlightColor: Theme.of(context).colorScheme.secondary),
              child: ClipPath(
                clipper: _HighlightClipper(highlightRect),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.7),
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
    const bottomNavBarHeight = kBottomNavigationBarHeight + 20;
    final currentStepIndex = ref.watch(tutorialProvider) ?? 0;

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
              child: _TutorialCard(
                step: step,
                currentStep: currentStepIndex,
                totalSteps: steps.length,
              )
                  .animate()
                  .fadeIn(duration: 400.ms)
                  .slideY(begin: 0.2, duration: 400.ms, curve: Curves.easeOutCubic),
            ),
            // Enhanced skip button with icon
            Positioned(
              top: 40,
              right: 16,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
                ),
                child: TextButton.icon(
                  onPressed: () => _finishTutorial(ref),
                  icon: const Icon(Icons.close, color: Colors.white, size: 18),
                  label: const Text("Atla", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  ),
                ),
              ),
            ),
            // Progress indicator at bottom
            Positioned(
              bottom: bottomNavBarHeight + 10,
              left: 0,
              right: 0,
              child: _buildProgressIndicator(context, currentStepIndex, steps.length),
            ),
          ],
        );
      }),
    );
  }

  Widget _buildProgressIndicator(BuildContext context, int current, int total) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ...List.generate(total, (index) {
                final isActive = index <= current;
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: isActive ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: isActive ? Colors.white : Colors.white.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(4),
                  ),
                )
                    .animate(key: ValueKey('dot_$index'))
                    .fadeIn(duration: 300.ms)
                    .scale(delay: (index * 50).ms);
              }),
              const SizedBox(width: 12),
              Text(
                '${current + 1}/$total',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TutorialCard extends ConsumerWidget {
  final TutorialStep step;
  final int currentStep;
  final int totalSteps;
  
  const _TutorialCard({
    required this.step,
    required this.currentStep,
    required this.totalSteps,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isLastStep = currentStep == totalSteps - 1;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.cardColor,
            theme.cardColor.withOpacity(0.95),
          ],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: colorScheme.secondary.withOpacity(0.5),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.secondary.withOpacity(0.3),
            blurRadius: 30,
            spreadRadius: 5,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Icon and title row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      colorScheme.secondary,
                      colorScheme.secondary.withOpacity(0.7),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: colorScheme.secondary.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  _getStepIcon(currentStep),
                  color: colorScheme.onSecondary,
                  size: 28,
                ),
              )
                  .animate()
                  .scale(delay: 200.ms, duration: 400.ms)
                  .shimmer(delay: 600.ms, duration: 800.ms),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      step.title,
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: colorScheme.secondary,
                        fontWeight: FontWeight.w800,
                        fontSize: 20,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Description
          Text(
            step.text,
            style: TextStyle(
              color: colorScheme.onSurface.withOpacity(0.85),
              height: 1.6,
              fontSize: 15,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 24),
          // Action button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Previous button (only show after first step)
              if (currentStep > 0)
                OutlinedButton.icon(
                  onPressed: () => ref.read(tutorialProvider.notifier).finish(),
                  icon: const Icon(Icons.arrow_back, size: 18),
                  label: const Text('Geri'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    side: BorderSide(color: colorScheme.secondary.withOpacity(0.3)),
                  ),
                )
              else
                const SizedBox(),
              // Next/Finish button
              ElevatedButton.icon(
                onPressed: () => ref.read(tutorialProvider.notifier).next(),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  elevation: 8,
                  shadowColor: colorScheme.secondary.withOpacity(0.5),
                  backgroundColor: colorScheme.secondary,
                  foregroundColor: colorScheme.onSecondary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: Icon(
                  isLastStep ? Icons.check_circle : Icons.arrow_forward,
                  size: 20,
                ),
                label: Text(
                  step.buttonText,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              )
                  .animate()
                  .shimmer(delay: 1000.ms, duration: 1500.ms)
                  .then()
                  .shake(hz: 2, duration: 500.ms),
            ],
          ),
        ],
      ),
    );
  }

  IconData _getStepIcon(int step) {
    // Map step indices to appropriate icons
    const icons = [
      Icons.waving_hand_rounded, // Welcome
      Icons.dashboard_rounded, // Dashboard
      Icons.add_circle_outline_rounded, // Add test
      Icons.school_rounded, // Coach
      Icons.psychology_rounded, // AI Hub
      Icons.emoji_events_rounded, // Arena
      Icons.person_rounded, // Profile
      Icons.celebration_rounded, // Completion
    ];
    return step < icons.length ? icons[step] : Icons.info_rounded;
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