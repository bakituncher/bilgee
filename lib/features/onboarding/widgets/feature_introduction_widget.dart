// lib/features/onboarding/widgets/feature_introduction_widget.dart

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:taktik/features/onboarding/models/onboarding_step.dart';

class FeatureIntroductionWidget extends StatefulWidget {
  final OnboardingStep step;
  final VoidCallback onContinue;
  final VoidCallback? onSkip;

  const FeatureIntroductionWidget({
    super.key,
    required this.step,
    required this.onContinue,
    this.onSkip,
  });

  @override
  State<FeatureIntroductionWidget> createState() => _FeatureIntroductionWidgetState();
}

class _FeatureIntroductionWidgetState extends State<FeatureIntroductionWidget>
    with TickerProviderStateMixin {
  late PageController _pageController;
  int _currentFeatureIndex = 0;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _pulseController = AnimationController(
      duration: Duration(seconds: 2),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _nextFeature() {
    if (widget.step.features != null &&
        _currentFeatureIndex < widget.step.features!.length - 1) {
      setState(() {
        _currentFeatureIndex++;
      });
      _pageController.animateToPage(
        _currentFeatureIndex,
        duration: Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      widget.onContinue();
    }
  }

  void _previousFeature() {
    if (_currentFeatureIndex > 0) {
      setState(() {
        _currentFeatureIndex--;
      });
      _pageController.animateToPage(
        _currentFeatureIndex,
        duration: Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final features = widget.step.features ?? [];

    return Column(
      children: [
        // Başlık
        Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            children: [
              Text(
                widget.step.title,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
                textAlign: TextAlign.center,
              )
              .animate()
              .fadeIn(duration: 800.ms)
              .slideY(begin: -0.2, end: 0),

              SizedBox(height: 16),

              Text(
                widget.step.description,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.7),
                ),
                textAlign: TextAlign.center,
              )
              .animate(delay: 300.ms)
              .fadeIn(duration: 800.ms)
              .slideY(begin: 0.2, end: 0),
            ],
          ),
        ),

        // Özellik gösterimi
        if (features.isNotEmpty) ...[
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() {
                  _currentFeatureIndex = index;
                });
              },
              itemCount: features.length,
              itemBuilder: (context, index) {
                final feature = features[index];
                return _buildFeatureCard(feature, index);
              },
            ),
          ),

          // Sayfa göstergesi
          Container(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                features.length,
                (index) => Container(
                  width: 8,
                  height: 8,
                  margin: EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _currentFeatureIndex == index
                        ? theme.colorScheme.primary
                        : theme.colorScheme.primary.withOpacity(0.3),
                  ),
                )
                .animate()
                .scale(
                  duration: 200.ms,
                  begin: Offset(0.8, 0.8),
                  end: Offset(1.0, 1.0),
                ),
              ),
            ),
          ),
        ],

        // Alt butonlar
        Container(
          padding: EdgeInsets.all(24),
          child: Row(
            children: [
              if (_currentFeatureIndex > 0)
                OutlinedButton(
                  onPressed: _previousFeature,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.arrow_back, size: 18),
                      SizedBox(width: 8),
                      Text('Önceki'),
                    ],
                  ),
                ),

              if (_currentFeatureIndex > 0) SizedBox(width: 16),

              Expanded(
                child: ElevatedButton(
                  onPressed: _nextFeature,
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _currentFeatureIndex < features.length - 1
                            ? 'Sonraki Özellik'
                            : 'Devam Et',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(width: 8),
                      Icon(Icons.arrow_forward),
                    ],
                  ),
                ),
              ),

              if (widget.onSkip != null) ...[
                SizedBox(width: 16),
                TextButton(
                  onPressed: widget.onSkip,
                  child: Text('Atla'),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFeatureCard(OnboardingFeature feature, int index) {
    final theme = Theme.of(context);

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Card(
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Container(
          padding: EdgeInsets.all(32),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                theme.colorScheme.surface,
                theme.colorScheme.primaryContainer.withOpacity(0.1),
              ],
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Özellik ikonu
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: theme.colorScheme.primary.withOpacity(0.1),
                  border: Border.all(
                    color: theme.colorScheme.primary.withOpacity(0.3),
                    width: 2,
                  ),
                ),
                child: Icon(
                  feature.icon,
                  size: 50,
                  color: theme.colorScheme.primary,
                ),
              )
              .animate()
              .scale(duration: 800.ms, curve: Curves.elasticOut)
              .then()
              .shimmer(duration: 2000.ms),

              SizedBox(height: 32),

              // Özellik başlığı
              Text(
                feature.title,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
                textAlign: TextAlign.center,
              )
              .animate(delay: 300.ms)
              .fadeIn(duration: 800.ms)
              .slideY(begin: 0.2, end: 0),

              SizedBox(height: 16),

              // Özellik açıklaması
              Text(
                feature.description,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.7),
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              )
              .animate(delay: 600.ms)
              .fadeIn(duration: 800.ms)
              .slideY(begin: 0.2, end: 0),

              SizedBox(height: 32),

              // Demo butonu (eğer varsa)
              if (feature.demoAction != null)
                OutlinedButton.icon(
                  onPressed: () => _showDemo(feature.demoAction!),
                  icon: Icon(Icons.play_circle_outline),
                  label: Text('Demo İzle'),
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                )
                .animate(delay: 900.ms)
                .fadeIn(duration: 800.ms)
                .scale(begin: Offset(0.8, 0.8), end: Offset(1.0, 1.0)),
            ],
          ),
        ),
      ),
    )
    .animate()
    .fadeIn(duration: 800.ms)
    .slideX(begin: 0.3, end: 0);
  }

  void _showDemo(String demoAction) {
    // Demo gösterim işlemleri
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Demo'),
        content: Text('$demoAction demo gösterimi başlatılıyor...'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Tamam'),
          ),
        ],
      ),
    );
  }
}
