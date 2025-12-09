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
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        title: Text(
          'Taktik Üssü',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: theme.colorScheme.onSurface,
            letterSpacing: -0.5,
            fontSize: 24,
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
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- 1. HERO KART: TAKTİK TAVŞAN ---
            _HeroCoachCard(
              isPremium: isPremium,
              onTap: () => _handleNavigation(
                  context,
                  isPremium,
                  route: '/ai-hub/motivation-chat',
                  offerData: {
                    'title': 'Taktik Tavşan',
                    'subtitle': 'Sadece ders değil, kriz anlarını yönet.',
                    'icon': Icons.psychology_rounded,
                    'color': Colors.indigoAccent,
                    'marketingTitle': 'Koçun Cebinde!',
                    'marketingSubtitle': 'Netlerin neden artmıyor? Stresle nasıl başa çıkarsın? Taktik Tavşan seni analiz edip nokta atışı yönlendirme yapsın.',
                    'redirectRoute': '/ai-hub/motivation-chat',
                    'imageAsset': 'assets/images/bunnyy.png',
                  }
              ),
            ),

            const SizedBox(height: 24),

            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 12),
              child: Text(
                'PERFORMANS ARAÇLARI',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                  color: theme.colorScheme.onSurface.withOpacity(0.4),
                ),
              ),
            ),

            // --- 2. GRID KARTLAR ---
            Row(
              children: [
                Expanded(
                  child: _FeatureCard(
                    title: 'Haftalık Strateji',
                    subtitle: 'Planı Taktik Tavşan yapsın, sen hedefe kilitlen! Kişisel haftalık programın hazır.',
                    icon: Icons.map_rounded,
                    color: const Color(0xFF10B981),
                    isPremium: isPremium,
                    onTap: () => _handleNavigation(context, isPremium, route: '/ai-hub/strategic-planning', offerData: {
                      'title': 'Haftalık Stratejist',
                      'subtitle': 'Hedefine giden en kısa yol.',
                      'icon': Icons.map_rounded,
                      'color': const Color(0xFF10B981),
                      'marketingTitle': 'Rotanı Çiz!',
                      'marketingSubtitle': 'Rastgele çalışarak vakit kaybetme. Taktik Tavşan senin için en verimli haftalık planı saniyeler içinde oluştursun.',
                      'redirectRoute': '/ai-hub/strategic-planning',
                    }),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _FeatureCard(
                    title: 'Analiz & Strateji',
                    subtitle: 'Taktik Tavşan senin için deneme analizleri yapsın, stratejini belirlesin.',
                    icon: Icons.radar_rounded,
                    color: const Color(0xFFF43F5E),
                    isPremium: isPremium,
                    onTap: () => _handleNavigation(context, isPremium, route: '/ai-hub/analysis-strategy', offerData: {
                      'title': 'Analiz & Strateji',
                      'subtitle': 'Verilerle konuşan koç.',
                      'icon': Icons.radar_rounded,
                      'color': const Color(0xFFF43F5E),
                      'marketingTitle': 'Tuzağı Fark Et!',
                      'marketingSubtitle': 'Denemelerde neden takılıyorsun? Detaylı analiz sistemi, seni aşağı çeken konuları nokta atışı tespit etsin.',
                      'redirectRoute': '/ai-hub/analysis-strategy',
                    }),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Cevher Atölyesi
            _WideFeatureCard(
              title: 'Cevher Atölyesi',
              subtitle: 'Taktik Tavşan zayıf olduğun konuları tespit edip sana özel çalışma seti sunsun.',
              icon: Icons.diamond_rounded,
              color: const Color(0xFF8B5CF6),
              isPremium: isPremium,
              onTap: () => _handleNavigation(context, isPremium, route: '/ai-hub/weakness-workshop', offerData: {
                'title': 'Cevher Atölyesi',
                'subtitle': 'Zayıflıkları güce çevir.',
                'icon': Icons.diamond_rounded,
                'color': const Color(0xFF8B5CF6),
                'marketingTitle': 'Ustalaşmadan Çıkma!',
                'marketingSubtitle': 'Sadece eksik olduğun konuya odaklan. Taktik Tavşan sana özel sorularla o konuyu halletmeden seni bırakmasın.',
                'redirectRoute': '/ai-hub/weakness-workshop',
              }),
            ),

            const SizedBox(height: 30),

            // --- 3. ALAN YÖNETİMİ ---
            if (!isPremium)
              const _PremiumSalesCard()
            else
              const _AiDisclaimerFooter(),
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
// HERO KART
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
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 160),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6366F1).withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              right: -40,
              bottom: -40,
              child: Opacity(
                opacity: 0.05,
                child: Image.asset(
                  'assets/images/bunnyy.png',
                  height: 240,
                  fit: BoxFit.contain,
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6366F1).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text(
                            'MENTORUN',
                            style: TextStyle(
                              color: Color(0xFF6366F1),
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Taktik Tavşan',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            height: 1.0,
                            color: theme.colorScheme.onSurface,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Flexible(
                          child: Text(
                            'Sınav maratonunda seni yalnız bırakmayan, her adımda sana rehberlik eden yol arkadaşın.',
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.onSurface.withOpacity(0.7),
                              height: 1.3,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 12.0),
                      child: Image.asset(
                        'assets/images/bunnyy.png',
                        height: 110,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            if (!isPremium)
              Positioned(
                top: 20,
                right: 20,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.amber,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: Colors.amber.withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 4)),
                    ],
                  ),
                  child: const Icon(Icons.lock, size: 16, color: Colors.black),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// FEATURE CARDS (GÜNCELLENDİ: SPACER KALDIRILDI)
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
        height: 200,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF000000).withOpacity(0.04),
              blurRadius: 10,
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
                  child: Icon(icon, color: color, size: 24),
                ),
                if (!isPremium)
                  Icon(Icons.lock_rounded, size: 18, color: theme.colorScheme.onSurface.withOpacity(0.2)),
              ],
            ),

            const SizedBox(height: 14),

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
            Expanded(
              child: Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11.5,
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                  height: 1.3,
                ),
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
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
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF000000).withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                      height: 1.3,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (!isPremium)
              Icon(Icons.lock_rounded, size: 18, color: theme.colorScheme.onSurface.withOpacity(0.2)),
          ],
        ),
      ),
    );
  }
}

class _PremiumSalesCard extends StatelessWidget {
  const _PremiumSalesCard();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E1B4B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: Colors.amber.withOpacity(0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E1B4B).withOpacity(0.5),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            top: -20,
            child: Icon(
              Icons.workspace_premium,
              size: 150,
              color: Colors.white.withOpacity(0.03),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.stars_rounded, color: Colors.amber, size: 32),
                    const SizedBox(width: 8),
                    Text(
                      'Taktik Pro Ayrıcalığı',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                        shadows: [Shadow(color: Colors.amber.withOpacity(0.5), blurRadius: 10)],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Rakiplerin uyurken sen fark at. Taktik Pro üyeleri tüm analizlere ve sınırsız koçluk desteğine anında erişir.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                GestureDetector(
                  onTap: () => context.push('/premium'),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFFD700), Color(0xFFFFA000)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.amber.withOpacity(0.4),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'AVANTAJI KAP',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                        SizedBox(width: 8),
                        Icon(Icons.arrow_forward_rounded, color: Colors.black, size: 20),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'İstediğin zaman iptal et. Gizli ücret yok.',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.4),
                    fontSize: 11,
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

class _AiDisclaimerFooter extends StatelessWidget {
  const _AiDisclaimerFooter();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(top: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.onSurface.withOpacity(0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.onSurface.withOpacity(0.05),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
              Icons.info_outline_rounded,
              size: 20,
              color: theme.colorScheme.onSurface.withOpacity(0.4)
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Yapay Zeka Sorumluluk Reddi',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Taktik Tavşan, üretken yapay zeka teknolojisi kullanır. Sunulan analizler ve tavsiyeler rehberlik amaçlıdır, kesinlik içermeyebilir. Önemli kararlar için bir uzmana danışmanızı öneririz.',
                  style: TextStyle(
                    fontSize: 10,
                    color: theme.colorScheme.onSurface.withOpacity(0.4),
                    height: 1.4,
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