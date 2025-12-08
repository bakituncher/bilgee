import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';
import 'dart:ui';

import 'package:taktik/data/providers/premium_provider.dart';

// -----------------------------------------------------------------------------
// TAKTIK AI HUB - THE ULTIMATE SHOWCASE
// -----------------------------------------------------------------------------

class AiHubScreen extends ConsumerWidget {
  const AiHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPremium = ref.watch(premiumStatusProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Taktik Pro Gold Gradient
    final goldGradient = const LinearGradient(
      colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F0F13) : const Color(0xFFF5F7FA),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.auto_awesome_mosaic_rounded, color: theme.colorScheme.primary, size: 20),
            ),
            const SizedBox(width: 12),
            Text(
              'Taktik Tavşan',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: theme.colorScheme.onSurface,
                letterSpacing: -0.5,
                fontSize: 20,
              ),
            ),
          ],
        ),
        actions: [
          if (isPremium)
            Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                gradient: goldGradient,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(color: Colors.orange.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              child: const Row(
                children: [
                  Icon(Icons.verified, size: 16, color: Colors.white),
                  SizedBox(width: 4),
                  Text(
                    'TAKTIK PRO',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.white),
                  ),
                ],
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          // Arka Plan Dekoru (Premium Aura)
          const _AmbientBackground(),

          // Ana İçerik
          SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.only(top: 110, bottom: 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- SHOWCASE GRID (BENTO BOX) ---
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 4, bottom: 16),
                        child: Text(
                          'KOMUTA MERKEZİ',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5,
                            color: theme.colorScheme.onSurface.withOpacity(0.5),
                          ),
                        ),
                      ),

                      // 1. Büyük Kart: Stratejik Planlama (HERO)
                      _ShowcaseCardLarge(
                        title: 'Haftalık Stratejist',
                        // MERAK UYANDIRICI AÇIKLAMA:
                        subtitle: 'Sadece sana özel değil, *kazananlara* özel bir rota. Rakiplerin uyurken sen ne yapman gerektiğini bil.',
                        icon: Icons.map_rounded,
                        accentColor: const Color(0xFF6366F1), // Indigo
                        isPremium: isPremium,
                        lottieAsset: 'assets/lotties/data.json',
                        onTap: () => _handleNavigation(
                            context,
                            isPremium,
                            route: '/ai-hub/strategic-planning',
                            offerData: {
                              'title': 'Haftalık Planlama',
                              'subtitle': 'Zafer stratejini şimdi oluştur.',
                              'icon': Icons.insights_rounded,
                              'color': theme.colorScheme.primary,
                              'heroTag': 'strategic-core',
                              'marketingTitle': 'Kişisel Başarı Haritası',
                              'marketingSubtitle': 'Sınav takvimine göre dinamik olarak güncellenen, nokta atışı çalışma planı.',
                              'redirectRoute': '/ai-hub/strategic-planning',
                            }
                        ),
                      ),

                      const SizedBox(height: 16),

                      // 2. Orta Kartlar
                      Row(
                        children: [
                          // Cevher Atölyesi
                          Expanded(
                            child: _ShowcaseCardMedium(
                              title: 'Cevher\nAtölyesi',
                              // MERAK UYANDIRICI AÇIKLAMA:
                              subtitle: 'Zayıf halkanı, en güçlü silahına dönüştüren gizli laboratuvar.',
                              icon: Icons.diamond_outlined,
                              accentColor: const Color(0xFFEC4899), // Pink
                              isPremium: isPremium,
                              onTap: () => _handleNavigation(
                                  context,
                                  isPremium,
                                  route: '/ai-hub/weakness-workshop',
                                  offerData: {
                                    'title': 'Cevher Atölyesi',
                                    'subtitle': 'Zayıf noktalarını güce çevir.',
                                    'icon': Icons.construction_rounded,
                                    'color': theme.colorScheme.secondary,
                                    'heroTag': 'weakness-core',
                                    'marketingTitle': 'Zayıflıklar Güce Dönüşüyor',
                                    'marketingSubtitle': 'En çok zorlandığın konuları tespit edip seni o konuda ustalaştıran özel çalışma.',
                                    'redirectRoute': '/ai-hub/weakness-workshop',
                                  }
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          // Analiz & Strateji
                          Expanded(
                            child: _ShowcaseCardMedium(
                              title: 'Analiz &\nStrateji',
                              // MERAK UYANDIRICI AÇIKLAMA:
                              subtitle: 'Görünmeyeni gören göz. Netlerin neden artmıyor? Cevabı burada.',
                              icon: Icons.pie_chart_outline_rounded,
                              accentColor: const Color(0xFFF59E0B), // Amber
                              isPremium: isPremium,
                              onTap: () => _handleNavigation(
                                  context,
                                  isPremium,
                                  route: '/ai-hub/analysis-strategy',
                                  offerData: {
                                    'title': 'Analiz & Strateji',
                                    'subtitle': 'Derinlemesine performans analizi.',
                                    'icon': Icons.dashboard_customize_rounded,
                                    'color': Colors.amberAccent,
                                    'heroTag': 'analysis-strategy-core',
                                    'marketingTitle': 'Verilerle Konuşan Koç',
                                    'marketingSubtitle': 'Deneme analizlerinle hangi konuya odaklanman gerektiğini saniye saniye gör.',
                                    'redirectRoute': '/ai-hub/analysis-strategy',
                                  }
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // 3. Geniş Kart: Motivasyon
                      _ShowcaseCardWide(
                        title: 'Motivasyon & Güç',
                        // MERAK UYANDIRICI AÇIKLAMA:
                        subtitle: 'Düştüğünde kaldıran, yorulduğunda iten güç. Sınav maratonunun dopingi.',
                        icon: Icons.bolt_rounded,
                        accentColor: const Color(0xFF10B981), // Emerald
                        isPremium: isPremium,
                        onTap: () => _handleNavigation(
                            context,
                            isPremium,
                            route: '/ai-hub/motivation-chat',
                            offerData: {
                              'title': 'Motivasyon Sohbeti',
                              'subtitle': 'Zorlandığında yanında olan güç.',
                              'icon': Icons.forum_rounded,
                              'color': Colors.pinkAccent,
                              'heroTag': 'motivation-core',
                              'marketingTitle': 'Sınırsız Motivasyon Desteği',
                              'marketingSubtitle': 'Stresli anlarda seni sakinleştiren ve odaklayan yapay zeka koçun.',
                              'redirectRoute': '/ai-hub/motivation-chat',
                            }
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // --- DÖNÜŞÜM ALANI (HIGH CONVERSION ZONE) ---
                // Sadece Premium olmayanlar için görünür
                if (!isPremium) ...[
                  _HighConversionZone(theme: theme),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- YÖNLENDİRME MANTIĞI (Routing Logic) ---
  // Orijinal yapıyı bozmuyoruz: Kartlara tıklayınca ToolOfferScreen (/ai-hub/offer) açılıyor.
  void _handleNavigation(BuildContext context, bool isPremium, {required String route, required Map<String, dynamic> offerData}) {
    if (isPremium) {
      context.go(route);
    } else {
      // Premium değilse, o tool'a özel teklif ekranına git (Mevcut mantık)
      context.go('/ai-hub/offer', extra: offerData);
    }
  }
}

// -----------------------------------------------------------------------------
// HIGH CONVERSION ZONE (DÖNÜŞÜM ALANI)
// -----------------------------------------------------------------------------

class _HighConversionZone extends StatelessWidget {
  final ThemeData theme;
  const _HighConversionZone({required this.theme});

  @override
  Widget build(BuildContext context) {
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        // Dikkat çekici ama şık bir gradient
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
              : [const Color(0xFFFFFFFF), const Color(0xFFF1F5F9)],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.08),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
        border: Border.all(
          // Altın çerçeve detayı (Subliminal Premium mesajı)
          color: Colors.amber.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          // Başlık
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.workspace_premium_rounded, color: Colors.amber[700], size: 28),
              const SizedBox(width: 8),
              Text(
                'Neden Taktik Pro?',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: theme.colorScheme.onSurface,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Fayda Listesi (Kısa ve Vurucu)
          _buildBenefitRow(context, Icons.rocket_launch_rounded, 'Limitleri Kaldır', 'Yapay zeka analizlerine sınırsız erişim.'),
          _buildBenefitRow(context, Icons.visibility_rounded, 'Görünmeyeni Gör', 'Rakiplerinin fark etmediği detayları yakala.'),
          _buildBenefitRow(context, Icons.verified_user_rounded, 'Kişisel Zafer Planı', 'Sana özel hesaplanan başarı rotası.'),

          const SizedBox(height: 24),

          // CTA Butonu (Call to Action)
          // Bu buton direkt olarak ana satın alma ekranına (PremiumScreen) gidebilir
          // veya genel bir teklif sayfasına. Kullanıcı "premium_screen" istediği için
          // burayı direkt /premium rotasına yönlendiriyoruz.
          GestureDetector(
            onTap: () => context.go('/premium'), // DİREKT SATIN ALMA EKRANI
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: const LinearGradient(
                  colors: [Color(0xFF2E3192), Color(0xFF1BFFFF)], // Electric Blue Gradient
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF2E3192).withOpacity(0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'TAKTIK PRO\'YA GEÇ',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 1,
                    ),
                  ),
                  SizedBox(width: 8),
                  Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 20),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'İstediğin zaman iptal et. Gizli ücret yok.',
            style: TextStyle(
              fontSize: 11,
              color: theme.colorScheme.onSurface.withOpacity(0.5),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBenefitRow(BuildContext context, IconData icon, String title, String subtitle) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: theme.colorScheme.primary, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// SHOWCASE CARDS (VITRIN TASARIMI)
// -----------------------------------------------------------------------------

// Base Card: Ortak Stil ve Kilit Mantığı
class _BaseShowcaseCard extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;
  final Color accentColor;
  final bool isPremium;

  const _BaseShowcaseCard({
    required this.child,
    required this.onTap,
    required this.accentColor,
    required this.isPremium,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E24) : Colors.white,
          borderRadius: BorderRadius.circular(28),
          // Premium Değilse: Altın Çerçeve (Vitrin Etkisi)
          border: isPremium
              ? Border.all(color: accentColor.withOpacity(0.1), width: 1)
              : Border.all(color: Colors.amber.withOpacity(0.5), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: isPremium ? accentColor.withOpacity(0.08) : Colors.amber.withOpacity(0.1),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Stack(
            children: [
              // Arka plan dekoru (Hafif renk)
              Positioned(
                right: -40,
                top: -40,
                child: Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        accentColor.withOpacity(0.1),
                        Colors.transparent
                      ],
                    ),
                  ),
                ),
              ),

              // Ana İçerik
              child,

              // KİLİT MEKANİZMASI (Showcase: İçerik Net, Köşede Kilit)
              if (!isPremium)
                Positioned(
                  top: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.amber, // Altın Badge
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.amber.withOpacity(0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        )
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.lock_rounded, color: Colors.black, size: 12),
                        SizedBox(width: 4),
                        Text(
                          'PRO',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: Colors.black,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// Büyük Kart (Lottie Animasyonlu)
class _ShowcaseCardLarge extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
  final bool isPremium;
  final VoidCallback onTap;
  final String lottieAsset;

  const _ShowcaseCardLarge({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    required this.isPremium,
    required this.onTap,
    required this.lottieAsset,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 220,
      child: _BaseShowcaseCard(
        accentColor: accentColor,
        isPremium: isPremium,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: accentColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(icon, color: accentColor, size: 24),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          height: 1.4,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 2,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Opacity(
                      opacity: 0.9,
                      child: Lottie.asset(lottieAsset, fit: BoxFit.contain, height: 100),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Orta Boy Kartlar
class _ShowcaseCardMedium extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
  final bool isPremium;
  final VoidCallback onTap;

  const _ShowcaseCardMedium({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    required this.isPremium,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 190, // Açıklama sığsın diye biraz uzattık
      child: _BaseShowcaseCard(
        accentColor: accentColor,
        isPremium: isPremium,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: accentColor, size: 22),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Geniş Kart
class _ShowcaseCardWide extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
  final bool isPremium;
  final VoidCallback onTap;

  const _ShowcaseCardWide({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    required this.isPremium,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 110,
      child: _BaseShowcaseCard(
        accentColor: accentColor,
        isPremium: isPremium,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: accentColor, size: 26),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Arka Plan Efekti
class _AmbientBackground extends StatelessWidget {
  const _AmbientBackground();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Colors.transparent,
      child: Stack(
        children: [
          Positioned(
            top: -100,
            left: -50,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Theme.of(context).colorScheme.primary.withOpacity(isDark ? 0.08 : 0.04),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
                child: Container(color: Colors.transparent),
              ),
            ),
          ),
        ],
      ),
    );
  }
}