// lib/features/onboarding/widgets/completion_widget.dart

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:confetti/confetti.dart';

class CompletionWidget extends StatefulWidget {
  final VoidCallback onContinue;
  final String userName;

  const CompletionWidget({
    super.key,
    required this.onContinue,
    required this.userName,
  });

  @override
  State<CompletionWidget> createState() => _CompletionWidgetState();
}

class _CompletionWidgetState extends State<CompletionWidget>
    with TickerProviderStateMixin {
  late ConfettiController _confettiController;
  late AnimationController _pulseController;
  late AnimationController _rotationController;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: Duration(seconds: 3));
    _pulseController = AnimationController(
      duration: Duration(seconds: 2),
      vsync: this,
    )..repeat();
    _rotationController = AnimationController(
      duration: Duration(seconds: 10),
      vsync: this,
    )..repeat();

    // Konfeti animasyonunu başlat
    Future.delayed(Duration(milliseconds: 500), () {
      _confettiController.play();
    });
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _pulseController.dispose();
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      body: Stack(
        children: [
          // Arka plan gradient
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  theme.colorScheme.primary.withOpacity(0.1),
                  theme.colorScheme.secondary.withOpacity(0.1),
                  theme.colorScheme.tertiary.withOpacity(0.1),
                ],
              ),
            ),
          ),

          // Ana içerik
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  flex: 3,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Başarı ikonu animasyonu
                        AnimatedBuilder(
                          animation: _rotationController,
                          builder: (context, child) {
                            return Transform.rotate(
                              angle: _rotationController.value * 2 * 3.14159,
                              child: Container(
                                width: 150,
                                height: 150,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.green,
                                      Colors.lightGreen,
                                      Colors.greenAccent,
                                    ],
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.green.withOpacity(0.3),
                                      blurRadius: 30,
                                      spreadRadius: 5,
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  Icons.check,
                                  size: 80,
                                  color: Colors.white,
                                ),
                              ),
                            );
                          },
                        )
                        .animate()
                        .scale(
                          duration: 1200.ms,
                          curve: Curves.elasticOut,
                        )
                        .then()
                        .shimmer(duration: 2000.ms),

                        SizedBox(height: 40),

                        // Tebrik mesajı
                        Text(
                          'Tebrikler ${widget.userName}! 🎉',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        )
                        .animate(delay: 800.ms)
                        .fadeIn(duration: 800.ms)
                        .slideY(begin: 0.3, end: 0),

                        SizedBox(height: 16),

                        Text(
                          'Artık Bilge AI ile başarıya giden\nyolculuğuna başlayabilirsin!',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(0.8),
                            height: 1.5,
                          ),
                        )
                        .animate(delay: 1200.ms)
                        .fadeIn(duration: 800.ms)
                        .slideY(begin: 0.3, end: 0),

                        SizedBox(height: 40),

                        // Özellik kartları
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildFeatureCard(
                              icon: Icons.psychology,
                              title: 'AI Asistan',
                              color: Colors.purple,
                              delay: 1600,
                            ),
                            _buildFeatureCard(
                              icon: Icons.quiz,
                              title: 'Soru Bankası',
                              color: Colors.blue,
                              delay: 1800,
                            ),
                            _buildFeatureCard(
                              icon: Icons.trending_up,
                              title: 'İlerleme Takibi',
                              color: Colors.green,
                              delay: 2000,
                            ),
                          ],
                        ),

                        SizedBox(height: 40),

                        // Motivasyon metni
                        Container(
                          margin: EdgeInsets.symmetric(horizontal: 40),
                          padding: EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.amber.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.amber.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.lightbulb,
                                color: Colors.amber,
                                size: 24,
                              ),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Unutma: Başarı, küçük adımların toplamıdır. Sen de başaracaksın!',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.amber.shade800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                        .animate(delay: 2200.ms)
                        .fadeIn(duration: 800.ms)
                        .slideY(begin: 0.3, end: 0),
                      ],
                    ),
                  ),
                ),

                // Alt kısım - Başla butonu
                Expanded(
                  flex: 1,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Container(
                        width: double.infinity,
                        margin: EdgeInsets.symmetric(horizontal: 32),
                        child: ElevatedButton(
                          onPressed: widget.onContinue,
                          style: ElevatedButton.styleFrom(
                            padding: EdgeInsets.symmetric(vertical: 20),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                            elevation: 8,
                            backgroundColor: theme.colorScheme.primary,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Hadi Başlayalım!',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(width: 12),
                              Icon(
                                Icons.rocket_launch,
                                color: Colors.white,
                                size: 24,
                              ),
                            ],
                          ),
                        ),
                      )
                      .animate(delay: 2500.ms)
                      .fadeIn(duration: 800.ms)
                      .slideY(begin: 0.5, end: 0)
                      .then()
                      .shimmer(duration: 2000.ms, color: Colors.white.withOpacity(0.5)),

                      SizedBox(height: 20),

                      Text(
                        'Seni bekleyen harika özellikler var! 🚀',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                        ),
                      )
                      .animate(delay: 2800.ms)
                      .fadeIn(duration: 800.ms),

                      SizedBox(height: 40),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Konfeti
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirection: 3.14159 / 2, // Aşağı doğru
              emissionFrequency: 0.05,
              numberOfParticles: 20,
              gravity: 0.1,
              shouldLoop: false,
              colors: [
                Colors.red,
                Colors.blue,
                Colors.green,
                Colors.yellow,
                Colors.purple,
                Colors.orange,
              ],
            ),
          ),

          // Sol konfeti
          Align(
            alignment: Alignment.topLeft,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirection: 0,
              emissionFrequency: 0.03,
              numberOfParticles: 10,
              gravity: 0.1,
              shouldLoop: false,
            ),
          ),

          // Sağ konfeti
          Align(
            alignment: Alignment.topRight,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirection: 3.14159,
              emissionFrequency: 0.03,
              numberOfParticles: 10,
              gravity: 0.1,
              shouldLoop: false,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureCard({
    required IconData icon,
    required String title,
    required Color color,
    required int delay,
  }) {
    return Column(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withOpacity(0.2),
            border: Border.all(
              color: color.withOpacity(0.5),
              width: 2,
            ),
          ),
          child: Icon(
            icon,
            color: color,
            size: 28,
          ),
        )
        .animate(delay: Duration(milliseconds: delay))
        .scale(duration: 800.ms, curve: Curves.elasticOut)
        .then()
        .shimmer(duration: 2000.ms),

        SizedBox(height: 8),

        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: color,
          ),
          textAlign: TextAlign.center,
        )
        .animate(delay: Duration(milliseconds: delay + 200))
        .fadeIn(duration: 600.ms),
      ],
    );
  }
}
