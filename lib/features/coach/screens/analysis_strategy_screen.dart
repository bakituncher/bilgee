// lib/features/coach/screens/analysis_strategy_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';

class AnalysisStrategyScreen extends StatelessWidget {
  const AnalysisStrategyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Analiz & Strateji'),
        backgroundColor: colorScheme.surface,
        elevation: 0,
      ),
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const CircleAvatar(
                backgroundColor: Colors.transparent,
                radius: 42,
                backgroundImage: AssetImage('assets/images/bunnyy.png'),
              ).animate().fadeIn(duration: 220.ms).scale(),
              const SizedBox(height: 20),
              Text(
                'Analiz & Strateji Süiti',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ).animate().fadeIn(delay: 120.ms),
              const SizedBox(height: 8),
              Text(
                'Deneme değerlendirme ve strateji danışmayı tek yerden başlat. Görüşme, kişisel verilerinle özelleştirilir.',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  height: 1.3,
                ),
                textAlign: TextAlign.center,
              ).animate().fadeIn(delay: 180.ms),
              const SizedBox(height: 24),

              _SuiteButton(
                icon: Icons.flag_circle_rounded,
                title: 'Deneme Değerlendirme',
                subtitle: 'Son denemenin güçlü/zayıf yanlarını gör, toparlanma adımları al.',
                onTap: () => context.go('/ai-hub/motivation-chat', extra: 'trial_review'),
                gradient: const LinearGradient(colors: [Color(0xFFFFE082), Color(0xFFFFF3E0)]),
              ).animate().fadeIn(delay: 240.ms).slideY(begin: 0.25, curve: Curves.easeOutCubic),

              _SuiteButton(
                icon: Icons.track_changes_rounded,
                title: 'Strateji Danışma',
                subtitle: 'Haftalık odak, ritim ve takip metrikleri için hızlı koç görüşmesi.',
                onTap: () => context.go('/ai-hub/motivation-chat', extra: 'strategy_consult'),
                gradient: const LinearGradient(colors: [Color(0xFF80D8FF), Color(0xFFE1F5FE)]),
              ).animate().fadeIn(delay: 320.ms).slideY(begin: 0.25, curve: Curves.easeOutCubic),

              const SizedBox(height: 8),
              Divider(
                color: colorScheme.onSurfaceVariant.withOpacity(0.2),
                height: 36,
              ),
              const SizedBox(height: 4),

              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'İpucu',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ).animate().fadeIn(delay: 380.ms),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Danışma ekranında yazışmalar, durumuna göre kişiselleşir. Deneme ekleyerek analiz doğruluğunu artır.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ).animate().fadeIn(delay: 420.ms),
            ],
          ),
        ),
      ),
    );
  }
}

class _SuiteButton extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Gradient gradient;
  const _SuiteButton({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [const Color(0x18222C2C), const Color(0x10222C2C)]
                : [
                    colorScheme.surfaceContainerHighest.withOpacity(0.4),
                    colorScheme.surfaceContainerHighest.withOpacity(0.2),
                  ],
          ),
          border: Border.all(
            color: isDark
                ? Colors.white.withOpacity(0.08)
                : colorScheme.outline.withOpacity(0.3),
          ),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withOpacity(0.25)
                  : Colors.black.withOpacity(0.08),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: gradient,
              ),
              child: Icon(icon, size: 30, color: isDark ? theme.primaryColor : Colors.black87),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: colorScheme.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      height: 1.25,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 18,
              color: colorScheme.onSurfaceVariant.withOpacity(0.8),
            ),
          ],
        ),
      ),
    );
  }
}
