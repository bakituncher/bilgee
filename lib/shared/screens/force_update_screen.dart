// lib/shared/screens/force_update_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:taktik/core/services/version_check_service.dart';

/// Zorunlu güncelleme ekranı - Kullanıcı uygulamayı güncellemeden devam edemez
class ForceUpdateScreen extends StatelessWidget {
  final VersionCheckResult versionInfo;

  const ForceUpdateScreen({
    super.key,
    required this.versionInfo,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              colorScheme.primary.withValues(alpha: 0.05),
              colorScheme.secondary.withValues(alpha: 0.05),
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 24.0),
            child: Column(
              children: [
                // Üst kısımdaki boşluk
                const SizedBox(height: 20),

                // 1. ANİMASYON (ARKA PLAN DAİRESİ KALDIRILDI)
                // Ekran çok küçükse animasyonun küçülebilmesi için Flexible kullandık
                Flexible(
                  flex: 0, // Kendi boyutu kadar yer kaplasın ama sıkışırsa küçülsün
                  // Container ve decoration kaldırıldı, doğrudan Lottie kullanılıyor.
                  child: Lottie.asset(
                    'assets/lotties/Davsan.json',
                    width: 200, // Daire kalktığı için boyutu biraz büyüttüm, isteğe göre 180'e çekebilirsiniz.
                    height: 200,
                    fit: BoxFit.contain,
                  ),
                ),

                const SizedBox(height: 24),

                // 2. BAŞLIKLAR
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: ShaderMask(
                    shaderCallback: (bounds) => LinearGradient(
                      colors: [
                        colorScheme.primary,
                        colorScheme.secondary,
                      ],
                    ).createShader(bounds),
                    child: Column(
                      mainAxisSize: MainAxisSize.min, // Minimum yer kaplasın
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'İyi Haber!',
                            style: theme.textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: -0.3,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                          ),
                        ),
                        const SizedBox(height: 8),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'Uygulamanın yeni bir sürümü var.',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: -0.3,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // 3. MESAJ KUTUSU (EXPANDED - ESNEK ALAN)
                // Burası kilit nokta: Expanded kullanarak kalan tüm boşluğu buraya veriyoruz.
                // Böylece alttaki buton asla aşağı itilip kaybolmaz.
                Expanded(
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: colorScheme.surface,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: colorScheme.primary.withValues(alpha: 0.1),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    // Kutu içi kaydırma mekanizması
                    child: Scrollbar(
                      thumbVisibility: true, // Kullanıcı kaydırılabilir olduğunu görsün
                      radius: const Radius.circular(10),
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center, // Metin kısaysa ortala
                          children: [
                            Text(
                              versionInfo.updateMessage ??
                                  'Uygulamayı kullanmaya devam etmek için lütfen en son sürüme güncelleyin.',
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: colorScheme.onSurface.withValues(alpha: 0.8),
                                height: 1.5,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // 4. BUTON (SABİT ALT KISIM)
                Container(
                  width: double.infinity,
                  height: 60,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        colorScheme.primary,
                        colorScheme.secondary,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: colorScheme.primary.withValues(alpha: 0.4),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: ElevatedButton.icon(
                    onPressed: () => _openStore(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    icon: const Icon(Icons.system_update_alt, size: 26),
                    label: Text(
                      'Şimdi Güncelle',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openStore(BuildContext context) async {
    try {
      Uri? storeUrl;

      if (Platform.isAndroid) {
        // Google Play Store
        storeUrl = Uri.parse('https://play.google.com/store/apps/details?id=com.codenzi.taktik');
      } else if (Platform.isIOS) {
        // App Store
        storeUrl = Uri.parse('https://apps.apple.com/app/id6739040808');
      }

      if (storeUrl != null && await canLaunchUrl(storeUrl)) {
        await launchUrl(storeUrl, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Mağaza açılamadı. Lütfen manuel olarak güncelleyin.'),
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata: ${e.toString()}'),
          ),
        );
      }
    }
  }
}