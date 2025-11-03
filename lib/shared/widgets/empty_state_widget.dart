// lib/shared/widgets/empty_state_widget.dart
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// A beautiful, professional empty state widget with modern design
class EmptyStateWidget extends StatelessWidget {
  final String title;
  final String message;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onActionPressed;
  final List<Color>? gradientColors;

  const EmptyStateWidget({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.inbox_rounded,
    this.actionLabel,
    this.onActionPressed,
    this.gradientColors,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final isDark = theme.brightness == Brightness.dark;

    final defaultGradient = [
      colorScheme.primary,
      colorScheme.secondary,
    ];

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Animated icon with gradient background
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: gradientColors ?? defaultGradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: (gradientColors?[0] ?? colorScheme.primary).withOpacity(0.3),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Icon(
                icon,
                size: 60,
                color: Colors.white,
              ),
            )
                .animate(onPlay: (controller) => controller.repeat(reverse: true))
                .fadeIn(duration: 600.ms)
                .scale(begin: const Offset(0.8, 0.8), duration: 600.ms)
                .then()
                .shimmer(delay: 800.ms, duration: 1500.ms)
                .then()
                .moveY(begin: 0, end: -10, duration: 2000.ms, curve: Curves.easeInOut),

            const SizedBox(height: 32),

            // Title
            Text(
              title,
              textAlign: TextAlign.center,
              style: textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: colorScheme.onSurface,
              ),
            )
                .animate()
                .fadeIn(delay: 300.ms, duration: 600.ms)
                .slideY(begin: 0.3, delay: 300.ms, duration: 600.ms),

            const SizedBox(height: 16),

            // Message
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurface.withOpacity(0.7),
                  height: 1.6,
                ),
              ),
            )
                .animate()
                .fadeIn(delay: 500.ms, duration: 600.ms)
                .slideY(begin: 0.3, delay: 500.ms, duration: 600.ms),

            // Action button
            if (actionLabel != null && onActionPressed != null) ...[
              const SizedBox(height: 32),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    colors: gradientColors ?? defaultGradient,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (gradientColors?[0] ?? colorScheme.primary).withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: onActionPressed,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        actionLabel!,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward_rounded, size: 20),
                    ],
                  ),
                ),
              )
                  .animate()
                  .fadeIn(delay: 700.ms, duration: 600.ms)
                  .slideY(begin: 0.3, delay: 700.ms, duration: 600.ms)
                  .then()
                  .shimmer(delay: 500.ms, duration: 1500.ms),
            ],
          ],
        ),
      ),
    );
  }
}

/// Specialized empty state for dashboard
class DashboardEmptyState extends StatelessWidget {
  final VoidCallback? onAddTest;

  const DashboardEmptyState({
    super.key,
    this.onAddTest,
  });

  @override
  Widget build(BuildContext context) {
    return EmptyStateWidget(
      title: 'Yolculuğa Başla! 🚀',
      message:
          'İlk deneme sonucunu ekleyerek başla!\n\nYapay zeka koçun, performansını analiz edecek ve sana özel stratejiler geliştirecek.',
      icon: Icons.rocket_launch_rounded,
      actionLabel: 'İlk Denememi Ekle',
      onActionPressed: onAddTest,
      gradientColors: const [
        Color(0xFF6366F1),
        Color(0xFF8B5CF6),
      ],
    );
  }
}

/// Specialized empty state for library/tests
class LibraryEmptyState extends StatelessWidget {
  final VoidCallback? onAddTest;

  const LibraryEmptyState({
    super.key,
    this.onAddTest,
  });

  @override
  Widget build(BuildContext context) {
    return EmptyStateWidget(
      title: 'Henüz Deneme Yok 📚',
      message:
          'Çözdüğün denemeleri buraya ekle ve gelişimini takip et!\n\nHer deneme, başarıya giden yolda bir adım.',
      icon: Icons.library_books_rounded,
      actionLabel: 'Deneme Ekle',
      onActionPressed: onAddTest,
      gradientColors: const [
        Color(0xFFEC4899),
        Color(0xFFF97316),
      ],
    );
  }
}

/// Specialized empty state for arena/competition
class ArenaEmptyState extends StatelessWidget {
  const ArenaEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return const EmptyStateWidget(
      title: 'Arena Yakında! 🏆',
      message:
          'Lider tablosu ve rekabet özellikleri çok yakında!\n\nDiğer kullanıcılarla yarışmaya hazır ol.',
      icon: Icons.emoji_events_rounded,
      gradientColors: [
        Color(0xFFF59E0B),
        Color(0xFFEF4444),
      ],
    );
  }
}

/// Specialized empty state for statistics
class StatsEmptyState extends StatelessWidget {
  final VoidCallback? onAddTest;

  const StatsEmptyState({
    super.key,
    this.onAddTest,
  });

  @override
  Widget build(BuildContext context) {
    return EmptyStateWidget(
      title: 'İstatistikler Bekleniyor 📊',
      message:
          'Henüz analiz edilecek veri yok!\n\nİlk denemeni ekle ve detaylı performans analizine ulaş.',
      icon: Icons.analytics_rounded,
      actionLabel: 'Deneme Ekle',
      onActionPressed: onAddTest,
      gradientColors: const [
        Color(0xFF10B981),
        Color(0xFF14B8A6),
      ],
    );
  }
}
