// lib/features/onboarding/widgets/app_tour_widget.dart

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class AppTourWidget extends StatefulWidget {
  final VoidCallback onComplete;
  final List<GlobalKey> targetKeys;
  final List<TourStep> steps;

  const AppTourWidget({
    super.key,
    required this.onComplete,
    required this.targetKeys,
    required this.steps,
  });

  @override
  State<AppTourWidget> createState() => _AppTourWidgetState();
}

class _AppTourWidgetState extends State<AppTourWidget>
    with TickerProviderStateMixin {
  int currentStep = 0;
  late AnimationController _overlayController;
  late AnimationController _bubbleController;

  @override
  void initState() {
    super.initState();
    _overlayController = AnimationController(
      duration: Duration(milliseconds: 500),
      vsync: this,
    );
    _bubbleController = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startTour();
    });
  }

  @override
  void dispose() {
    _overlayController.dispose();
    _bubbleController.dispose();
    super.dispose();
  }

  void _startTour() {
    _overlayController.forward();
    Future.delayed(Duration(milliseconds: 300), () {
      _bubbleController.forward();
    });
  }

  void _nextStep() {
    if (currentStep < widget.steps.length - 1) {
      _bubbleController.reverse().then((_) {
        setState(() {
          currentStep++;
        });
        _bubbleController.forward();
      });
    } else {
      _completeTour();
    }
  }

  void _completeTour() {
    _bubbleController.reverse().then((_) {
      _overlayController.reverse().then((_) {
        widget.onComplete();
      });
    });
  }

  Rect? _getTargetRect() {
    if (currentStep >= widget.targetKeys.length) return null;

    final RenderBox? renderBox = widget.targetKeys[currentStep]
        .currentContext
        ?.findRenderObject() as RenderBox?;

    if (renderBox == null) return null;

    final position = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    return Rect.fromLTWH(
      position.dx,
      position.dy,
      size.width,
      size.height,
    );
  }

  @override
  Widget build(BuildContext context) {
    final targetRect = _getTargetRect();
    final step = widget.steps[currentStep];

    return AnimatedBuilder(
      animation: _overlayController,
      builder: (context, child) {
        return Opacity(
          opacity: _overlayController.value,
          child: Material(
            color: Colors.black.withOpacity(0.7),
            child: Stack(
              children: [
                // Tıklanabilir overlay
                GestureDetector(
                  onTap: _nextStep,
                  child: Container(
                    width: double.infinity,
                    height: double.infinity,
                    color: Colors.transparent,
                  ),
                ),

                // Hedef alanı highlight
                if (targetRect != null)
                  Positioned(
                    left: targetRect.left - 8,
                    top: targetRect.top - 8,
                    child: Container(
                      width: targetRect.width + 16,
                      height: targetRect.height + 16,
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white,
                          width: 3,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.white.withOpacity(0.3),
                            blurRadius: 20,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                    ),
                  )
                  .animate(controller: _bubbleController)
                  .scale(begin: Offset(0.8, 0.8), end: Offset(1, 1))
                  .fadeIn(),

                // Açıklama balonu
                _buildTooltip(context, step, targetRect),

                // Atla butonu
                Positioned(
                  top: 50,
                  right: 20,
                  child: TextButton(
                    onPressed: _completeTour,
                    style: TextButton.styleFrom(
                      backgroundColor: Colors.white.withOpacity(0.2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Atla',
                          style: TextStyle(color: Colors.white),
                        ),
                        Icon(Icons.close, color: Colors.white, size: 16),
                      ],
                    ),
                  ),
                ),

                // İlerleme göstergesi
                Positioned(
                  bottom: 50,
                  left: 0,
                  right: 0,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      widget.steps.length,
                      (index) => Container(
                        margin: EdgeInsets.symmetric(horizontal: 4),
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: index <= currentStep
                              ? Colors.white
                              : Colors.white.withOpacity(0.3),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTooltip(BuildContext context, TourStep step, Rect? targetRect) {
    final screenSize = MediaQuery.of(context).size;
    double top = 100;
    double left = 20;
    double right = 20;

    if (targetRect != null) {
      final centerX = targetRect.center.dx;
      final isInTopHalf = targetRect.center.dy < screenSize.height / 2;

      if (isInTopHalf) {
        // Hedef üst yarıdaysa, tooltip'i altına koy
        top = targetRect.bottom + 20;
      } else {
        // Hedef alt yarıdaysa, tooltip'i üstüne koy
        top = targetRect.top - 200;
      }

      // Yatay konumlandırma
      if (centerX < screenSize.width / 3) {
        left = 20;
        right = screenSize.width / 2;
      } else if (centerX > 2 * screenSize.width / 3) {
        left = screenSize.width / 2;
        right = 20;
      }
    }

    return Positioned(
      top: top,
      left: left,
      right: right,
      child: AnimatedBuilder(
        animation: _bubbleController,
        builder: (context, child) {
          return Transform.scale(
            scale: _bubbleController.value,
            child: Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 10,
                    offset: Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        step.icon,
                        color: Theme.of(context).colorScheme.primary,
                        size: 24,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          step.title,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  Text(
                    step.description,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[700],
                      height: 1.4,
                    ),
                  ),
                  SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${currentStep + 1}/${widget.steps.length}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[500],
                        ),
                      ),
                      ElevatedButton(
                        onPressed: _nextStep,
                        style: ElevatedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          padding: EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 8,
                          ),
                        ),
                        child: Text(
                          currentStep < widget.steps.length - 1
                              ? 'Devam'
                              : 'Tamam',
                          style: TextStyle(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class TourStep {
  final String title;
  final String description;
  final IconData icon;

  const TourStep({
    required this.title,
    required this.description,
    required this.icon,
  });
}
