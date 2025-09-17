// lib/features/onboarding/widgets/welcome_step_widget.dart

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lottie/lottie.dart';

class WelcomeStepWidget extends StatelessWidget {
  final VoidCallback onContinue;

  const WelcomeStepWidget({
    super.key,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.primary.withOpacity(0.1),
            theme.colorScheme.secondary.withOpacity(0.1),
          ],
        ),
      ),
      child: Column(
        children: [
          Expanded(
            flex: 3,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Ana logo animasyonu
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: theme.colorScheme.primary,
                      boxShadow: [
                        BoxShadow(
                          color: theme.colorScheme.primary.withOpacity(0.3),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.psychology,
                      size: 60,
                      color: Colors.white,
                    ),
                  )
                  .animate()
                  .scale(duration: 800.ms, curve: Curves.elasticOut)
                  .then()
                  .shimmer(duration: 2000.ms)
                  .animate(onPlay: (controller) => controller.repeat())
                  .rotate(duration: 4000.ms),

                  SizedBox(height: 40),

                  // Hoş geldin metni
                  Text(
                    'Taktik\'e\nHoş Geldin! 🎯',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  )
                  .animate(delay: 500.ms)
                  .fadeIn(duration: 800.ms)
                  .slideY(begin: 0.3, end: 0),

                  SizedBox(height: 20),

                  // Alt metin
                  Text(
                    'Sınav başarın için\nstratejik AI asistanın hazır',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.7),
                    ),
                  )
                  .animate(delay: 1000.ms)
                  .fadeIn(duration: 800.ms)
                  .slideY(begin: 0.3, end: 0),

                  SizedBox(height: 40),

                  // Özellik ikonları
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildFeatureIcon(
                        icon: Icons.quiz,
                        label: 'Sorular',
                        delay: 1500,
                      ),
                      _buildFeatureIcon(
                        icon: Icons.school,
                        label: 'Eğitim',
                        delay: 1700,
                      ),
                      _buildFeatureIcon(
                        icon: Icons.trending_up,
                        label: 'Takip',
                        delay: 1900,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Alt kısım - Devam butonu
          Expanded(
            flex: 1,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(
                  width: double.infinity,
                  margin: EdgeInsets.symmetric(horizontal: 32),
                  child: ElevatedButton(
                    onPressed: onContinue,
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      elevation: 8,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Hemen Başlayalım',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(width: 8),
                        Icon(Icons.arrow_forward),
                      ],
                    ),
                  ),
                )
                .animate(delay: 2200.ms)
                .fadeIn(duration: 800.ms)
                .slideY(begin: 0.5, end: 0)
                .then()
                .shimmer(duration: 2000.ms),

                SizedBox(height: 32),

                // Alt bilgi
                Text(
                  'Sadece 2 dakika sürer',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.5),
                  ),
                )
                .animate(delay: 2500.ms)
                .fadeIn(duration: 800.ms),

                SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureIcon({
    required IconData icon,
    required String label,
    required int delay,
  }) {
    return Column(
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Icon(
            icon,
            color: Colors.deepPurple,
            size: 24,
          ),
        )
        .animate(delay: Duration(milliseconds: delay))
        .scale(duration: 600.ms, curve: Curves.bounceOut)
        .then()
        .shimmer(duration: 1500.ms),

        SizedBox(height: 8),

        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.deepPurple,
          ),
        )
        .animate(delay: Duration(milliseconds: delay + 200))
        .fadeIn(duration: 400.ms),
      ],
    );
  }
}
