// lib/features/blog/screens/blog_screen.dart
import 'package:bilge_ai/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

class BlogScreen extends StatelessWidget {
  const BlogScreen({super.key});

  Future<void> _handleBack(BuildContext context) async {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = [
      ('Derin Odak: Pomodoro’yu Üst Seviye Kullanma', Icons.timer_rounded),
      ('Deneme Analizi: 5 Adımda Zayıflık Haritası', Icons.analytics_rounded),
      ('Motivasyon Döngüsü: Seriyi Nasıl Korursun?', Icons.local_fire_department_rounded),
      ('Uyku ve Başarı: Nörobilimden İpuçları', Icons.nightlight_round),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bilgelik Yazıları'),
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Geri',
          onPressed: () => _handleBack(context),
        ),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, i) {
          final (title, icon) = items[i];
          return Card(
            elevation: 6,
            shadowColor: AppTheme.lightSurfaceColor.withOpacity(.4),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            child: InkWell(
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Yakında: Makale içeriği hazırlanıyor.')),
                );
              },
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: AppTheme.secondaryColor.withOpacity(.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.all(10),
                      child: Icon(icon, color: AppTheme.secondaryColor),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 4),
                          Text('Yakında • Okuma süresi ~4 dk', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppTheme.secondaryTextColor)),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded, color: AppTheme.secondaryTextColor),
                  ],
                ),
              ),
            ),
          ).animate().fadeIn(duration: 250.ms).slideY(begin: .05, curve: Curves.easeOut);
        },
      ),
    );
  }
}
