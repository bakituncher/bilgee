// lib/features/coach/screens/analysis_strategy_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:taktik/core/theme/app_theme.dart';
import 'package:flutter_animate/flutter_animate.dart';

class AnalysisStrategyScreen extends StatelessWidget {
  const AnalysisStrategyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Analiz & Strateji'),
        backgroundColor: AppTheme.primaryColor,
        elevation: 0,
      ),
      backgroundColor: AppTheme.primaryColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const CircleAvatar(
                backgroundColor: AppTheme.secondaryColor,
                radius: 42,
                child: Icon(Icons.auto_awesome, size: 42, color: AppTheme.primaryColor),
              ).animate().fadeIn(duration: 220.ms).scale(),
              const SizedBox(height: 20),
              Text(
                'Analiz & Strateji Süiti',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
                textAlign: TextAlign.center,
              ).animate().fadeIn(delay: 120.ms),
              const SizedBox(height: 8),
              Text(
                'Deneme değerlendirme ve strateji danışmayı tek yerden başlat. Görüşme, kişisel verilerinle özelleştirilir.',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppTheme.secondaryTextColor, height: 1.3),
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
              Divider(color: Colors.white.withOpacity(0.06), height: 36),
              const SizedBox(height: 4),

              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'İpucu',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(color: AppTheme.secondaryTextColor),
                ),
              ).animate().fadeIn(delay: 380.ms),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Danışma ekranında yazışmalar, durumuna göre kişiselleşir. Deneme ekleyerek analiz doğruluğunu artır.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.secondaryTextColor),
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0x18222C2C), Color(0x10222C2C)],
          ),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.25), blurRadius: 14, offset: const Offset(0, 4)),
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
              child: Icon(icon, size: 30, color: AppTheme.primaryColor),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodyMedium?.copyWith(color: AppTheme.secondaryTextColor, height: 1.25),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Icon(Icons.arrow_forward_ios_rounded, size: 18, color: AppTheme.secondaryTextColor.withOpacity(0.8)),
          ],
        ),
      ),
    );
  }
}
