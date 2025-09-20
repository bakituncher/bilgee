// lib/features/premium/screens/premium_screen.dart
import 'package:taktik/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

class PremiumView extends StatelessWidget {
  const PremiumView({super.key});

  Future<void> _handleBack(BuildContext context) async {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final perks = const [
      (Icons.bolt_rounded, 'Hızlı Öneriler', 'Anında kişiselleştirilmiş çalışma önerileri'),
      (Icons.auto_awesome_rounded, 'Akıllı Planlama', 'Yoğunluğa göre dinamik program revizyonu'),
      (Icons.insights_rounded, 'Derin Analizler', 'Zayıflık tespiti ve mikro hedefler'),
      (Icons.workspace_premium_rounded, 'Öncelikli Erişim', 'Yeni özelliklere erken erişim'),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Premium'),
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Geri',
          onPressed: () => _handleBack(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [AppTheme.secondaryColor, Colors.amber]),
                borderRadius: BorderRadius.circular(20),
              ),
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  const Icon(Icons.workspace_premium_rounded, size: 40, color: AppTheme.primaryColor),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('TaktikAI Premium', style: Theme.of(context).textTheme.titleLarge?.copyWith(color: AppTheme.primaryColor, fontWeight: FontWeight.w800)),
                        Text('Odakta kal, daha hızlı ilerle', style: Theme.of(context).textTheme.labelLarge?.copyWith(color: AppTheme.primaryColor.withValues(alpha: .9))),
                      ],
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 250.ms).slideY(begin: .06),
            const SizedBox(height: 16),
            ListView.separated(
              itemCount: perks.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemBuilder: (context, i) {
                final (icon, title, desc) = perks[i];
                return Card(
                  elevation: 6,
                  shadowColor: AppTheme.lightSurfaceColor.withValues(alpha: .4),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  child: ListTile(
                    leading: Icon(icon, color: AppTheme.secondaryColor),
                    title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text(desc, style: TextStyle(color: AppTheme.secondaryTextColor)),
                  ),
                );
              },
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Satın alma akışı yakında.')));
                },
                icon: const Icon(Icons.lock_open_rounded),
                label: const Text('Premium’a Geç'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
