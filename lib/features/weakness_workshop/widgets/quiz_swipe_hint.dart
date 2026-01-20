// lib/features/weakness_workshop/widgets/quiz_swipe_hint.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Instagram tarzında şık kaydırma ipucu overlay'i
/// İlk kullanımda gösterilir ve soruları kaydırma özelliğini tanıtır
class QuizSwipeHint extends StatefulWidget {
  final VoidCallback onDismiss;

  const QuizSwipeHint({
    super.key,
    required this.onDismiss,
  });

  /// İpucunun daha önce gösterilip gösterilmediğini kontrol eder
  static Future<bool> shouldShow() async {
    final prefs = await SharedPreferences.getInstance();
    return !(prefs.getBool('quiz_swipe_hint_shown') ?? false);
  }

  /// İpucunun gösterildiğini kaydeder
  static Future<void> markAsShown() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('quiz_swipe_hint_shown', true);
  }

  @override
  State<QuizSwipeHint> createState() => _QuizSwipeHintState();
}

class _QuizSwipeHintState extends State<QuizSwipeHint> {
  bool _isVisible = true;

  void _handleDismiss() {
    setState(() {
      _isVisible = false;
    });
    // Animasyon bitiminde callback çağır
    Future.delayed(const Duration(milliseconds: 400), () {
      QuizSwipeHint.markAsShown();
      widget.onDismiss();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_isVisible) {
      return const SizedBox.shrink();
    }

    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: _handleDismiss,
      child: Container(
        color: Colors.black.withOpacity(0.75),
        child: SafeArea(
          child: Stack(
            children: [
              // Ana içerik - merkezi konumlandırma
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Kaydırma animasyonu göstergesi
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              colorScheme.primary,
                              colorScheme.secondary,
                            ],
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: colorScheme.primary.withOpacity(0.3),
                              blurRadius: 24,
                              spreadRadius: 4,
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.swipe_vertical_rounded,
                          size: 40,
                          color: isDark ? Colors.black : Colors.white,
                        ),
                      )
                          .animate(onPlay: (controller) => controller.repeat())
                          .moveY(
                            begin: 0,
                            end: -20,
                            duration: 1500.ms,
                            curve: Curves.easeInOut,
                          )
                          .then()
                          .moveY(
                            begin: -20,
                            end: 0,
                            duration: 1500.ms,
                            curve: Curves.easeInOut,
                          ),

                      const SizedBox(height: 40),

                      // Başlık
                      Text(
                        'Soruları Keşfet',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                        textAlign: TextAlign.center,
                      )
                          .animate()
                          .fadeIn(delay: 200.ms, duration: 600.ms)
                          .slideY(begin: 0.3, end: 0, duration: 600.ms),

                      const SizedBox(height: 16),

                      // Açıklama
                      ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 20,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.2),
                                width: 1,
                              ),
                            ),
                            child: Column(
                              children: [
                                _buildHintItem(
                                  icon: Icons.swipe_up_rounded,
                                  text: 'Yukarı kaydır',
                                  subtext: 'Sonraki soruya geç',
                                ),
                                const SizedBox(height: 16),
                                _buildHintItem(
                                  icon: Icons.swipe_down_rounded,
                                  text: 'Aşağı kaydır',
                                  subtext: 'Önceki soruya dön',
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                          .animate()
                          .fadeIn(delay: 400.ms, duration: 600.ms)
                          .scale(begin: const Offset(0.9, 0.9), end: const Offset(1, 1), duration: 600.ms),

                      const SizedBox(height: 32),

                      // Dokunarak kapat butonu
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              colorScheme.primary,
                              colorScheme.secondary,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: [
                            BoxShadow(
                              color: colorScheme.primary.withOpacity(0.4),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.touch_app_rounded,
                              color: isDark ? Colors.black : Colors.white,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Anladım, Başlayalım',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: isDark ? Colors.black : Colors.white,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                            ),
                          ],
                        ),
                      )
                          .animate()
                          .fadeIn(delay: 600.ms, duration: 600.ms)
                          .shimmer(delay: 1500.ms, duration: 2000.ms),
                    ],
                  ),
                ),
              ),

              // Kapatma ikonu (sağ üst)
              Positioned(
                top: 16,
                right: 16,
                child: GestureDetector(
                  onTap: _handleDismiss,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withOpacity(0.2),
                        width: 1,
                      ),
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
              )
                  .animate()
                  .fadeIn(delay: 800.ms, duration: 400.ms)
                  .scale(begin: const Offset(0, 0), end: const Offset(1, 1), duration: 400.ms),
            ],
          ),
        ),
      )
          .animate()
          .fadeIn(duration: 300.ms),
    );
  }

  Widget _buildHintItem({
    required IconData icon,
    required String text,
    required String subtext,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: Colors.white,
            size: 24,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                text,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtext,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
