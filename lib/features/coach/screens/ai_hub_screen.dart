import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:taktik/data/providers/premium_provider.dart';

class AiHubScreen extends ConsumerWidget {
  const AiHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPremium = ref.watch(premiumStatusProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F0F13) : const Color(0xFFF0F2F5),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF0F0F13) : const Color(0xFFF0F2F5),
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Taktik Üssü',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: theme.colorScheme.onSurface,
            letterSpacing: -0.5,
            fontSize: 22,
          ),
        ),
        actions: [
          if (isPremium)
            Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.withOpacity(0.5)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.verified, size: 14, color: Colors.amber),
                  SizedBox(width: 4),
                  Text('PRO', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.amber)),
                ],
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- 1. HERO KART: TAKTİK TAVŞAN (Görsel Güncellendi) ---
            _HeroCoachCard(
              isPremium: isPremium,
              onTap: () => _handleNavigation(
                  context,
                  isPremium,
                  route: '/ai-hub/motivation-chat',
                  offerData: {
                    'title': 'Taktik Tavşan',
                    'subtitle': 'Sadece ders değil, kriz anlarını yönet.',
                    'icon': Icons.psychology_rounded, // Burada ikon kalabilir, görsel asset yollanmaz
                    'color': Colors.indigoAccent,
                    'marketingTitle': 'Koçun Cebinde!',
                    'marketingSubtitle': 'Netlerin neden artmıyor? Stresle nasıl başa çıkarsın? Taktik Tavşan seni analiz edip nokta atışı yönlendirme yapsın.',
                    'redirectRoute': '/ai-hub/motivation-chat',
                  }
              ),
            ),

            const SizedBox(height: 20),

            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 12),
              child: Text(
                'PERFORMANS ARAÇLARI',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1,
                  color: theme.colorScheme.onSurface.withOpacity(0.4),
                ),
              ),
            ),

            // --- 2. GRID KARTLAR ---
            Row(
              children: [
                Expanded(
                  child: _FeatureCard(
                    title: 'Haftalık\nStratejist',
                    subtitle: 'Senin hızına göre dinamik değişen rota.',
                    icon: Icons.map_rounded,
                    color: const Color(0xFF10B981), // Emerald Green
                    isPremium: isPremium,
                    onTap: () => _handleNavigation(
                        context,
                        isPremium,
                        route: '/ai-hub/strategic-planning',
                        offerData: {
                          'title': 'Haftalık Stratejist',
                          'subtitle': 'Hedefine giden en kısa yol.',
                          'icon': Icons.map_rounded,
                          'color': const Color(0xFF10B981),
                          'marketingTitle': 'Rotanı Çiz!',
                          'marketingSubtitle': 'Rastgele çalışarak vakit kaybetme. Taktik Tavşan senin için en verimli haftalık planı saniyeler içinde oluştursun.',
                          'redirectRoute': '/ai-hub/strategic-planning',
                        }
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _FeatureCard(
                    title: 'Analiz &\nStrateji',
                    subtitle: 'Gözünden kaçan "tuzağı" bulur.',
                    icon: Icons.radar_rounded,
                    color: const Color(0xFFF43F5E), // Rose Red
                    isPremium: isPremium,
                    onTap: () => _handleNavigation(
                        context,
                        isPremium,
                        route: '/ai-hub/analysis-strategy',
                        offerData: {
                          'title': 'Analiz & Strateji',
                          'subtitle': 'Verilerle konuşan koç.',
                          'icon': Icons.radar_rounded,
                          'color': const Color(0xFFF43F5E),
                          'marketingTitle': 'Tuzağı Fark Et!',
                          'marketingSubtitle': 'Denemelerde neden takılıyorsun? Detaylı analiz sistemi, seni aşağı çeken konuları nokta atışı tespit etsin.',
                          'redirectRoute': '/ai-hub/analysis-strategy',
                        }
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Cevher Atölyesi (Yatay)
            _WideFeatureCard(
              title: 'Cevher Atölyesi',
              subtitle: 'Zayıf olduğun konuyu seç, Taktik Tavşan seni o konuda ustalaştırana kadar test etsin.',
              icon: Icons.diamond_rounded,
              color: const Color(0xFF8B5CF6), // Violet
              isPremium: isPremium,
              onTap: () => _handleNavigation(
                  context,
                  isPremium,
                  route: '/ai-hub/weakness-workshop',
                  offerData: {
                    'title': 'Cevher Atölyesi',
                    'subtitle': 'Zayıflıkları güce çevir.',
                    'icon': Icons.diamond_rounded,
                    'color': const Color(0xFF8B5CF6),
                    'marketingTitle': 'Ustalaşmadan Çıkma!',
                    'marketingSubtitle': 'Sadece eksik olduğun konuya odaklan. Taktik Tavşan sana özel sorularla o konuyu halletmeden seni bırakmasın.',
                    'redirectRoute': '/ai-hub/weakness-workshop',
                  }
              ),
            ),

            const SizedBox(height: 30),

            // --- 3. PREMIUM TEŞVİK (Tavşansız, Pro Odaklı) ---
            if (!isPremium) const _PremiumTeaserBox(),
          ],
        ),
      ),
    );
  }

  void _handleNavigation(BuildContext context, bool isPremium, {required String route, required Map<String, dynamic> offerData}) {
    if (isPremium) {
      context.go(route);
    } else {
      context.go('/ai-hub/offer', extra: offerData);
    }
  }
}

// -----------------------------------------------------------------------------
// 1. HERO COACH CARD (BUNNY PNG KULLANILDI)
// -----------------------------------------------------------------------------
class _HeroCoachCard extends StatelessWidget {
  final bool isPremium;
  final VoidCallback onTap;

  const _HeroCoachCard({required this.isPremium, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 160,
        width: double.infinity,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF18181B) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: isDark ? Colors.white10 : Colors.grey.shade200,
          ),
        ),
        child: Stack(
          children: [
            // Arka plan dekoru - Bunny PNG (Silik)
            Positioned(
              right: -30,
              bottom: -20,
              child: Opacity(
                opacity: 0.08, // Çok hafif arkada dursun
                child: Image.asset(
                  'assets/images/bunnyy.png',
                  height: 180,
                  fit: BoxFit.contain,
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  // Sol taraf: Metinler
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6366F1).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'MENTORUN',
                            style: TextStyle(
                              color: Color(0xFF6366F1),
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Taktik Tavşan',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            height: 1.1,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Netlerin neden durdu? Seni analiz edip nokta atışı taktik veren akıl hocan.',
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurface.withOpacity(0.7),
                            height: 1.4,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),

                  // Sağ taraf: Bunny PNG (Net Görünüm)
                  Expanded(
                    flex: 2,
                    child: Center(
                      child: Image.asset(
                        'assets/images/bunnyy.png',
                        height: 90, // Yüksekliği ayarlayabilirsin
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Kilit İkonu
            if (!isPremium)
              Positioned(
                top: 16,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: Colors.amber,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.lock, size: 14, color: Colors.black),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// 2. FEATURE CARDS
// -----------------------------------------------------------------------------
class _FeatureCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final bool isPremium;
  final VoidCallback onTap;

  const _FeatureCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.isPremium,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 150,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF18181B) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                if (!isPremium)
                  Icon(Icons.lock_rounded, size: 16, color: theme.colorScheme.onSurface.withOpacity(0.3)),
              ],
            ),
            const Spacer(),
            Text(
              title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: theme.colorScheme.onSurface,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 11,
                color: theme.colorScheme.onSurface.withOpacity(0.6),
                height: 1.2,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _WideFeatureCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final bool isPremium;
  final VoidCallback onTap;

  const _WideFeatureCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.isPremium,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF18181B) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                      height: 1.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (!isPremium)
              Icon(Icons.lock_rounded, size: 16, color: theme.colorScheme.onSurface.withOpacity(0.3)),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// 3. PREMIUM TEASER (TAKTİK PRO KONSEPTİ)
// -----------------------------------------------------------------------------
class _PremiumTeaserBox extends StatelessWidget {
  const _PremiumTeaserBox();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A1A2E), Color(0xFF16213E)], // Dark Blue Gradient
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1A1A2E).withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // Tavşan Yok -> Pro/Elmas İkonu Var
          const Icon(Icons.workspace_premium_rounded, color: Colors.amber, size: 36),
          const SizedBox(height: 12),
          const Text(
            'Taktik Pro Ayrıcalığı',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Rakiplerin uyurken sen fark at. Taktik Pro üyeleri tüm analizlere ve sınırsız koçluk desteğine sahiptir.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => context.go('/premium'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('AVANTAJI KAP', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
            ),
          ),
        ],
      ),
    );
  }
}