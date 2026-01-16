import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:taktik/data/providers/premium_provider.dart';
import 'package:taktik/data/providers/shared_prefs_provider.dart';
import 'package:taktik/features/coach/widgets/ai_hub_welcome_sheet.dart';

class AiHubScreen extends ConsumerStatefulWidget {
  const AiHubScreen({super.key});

  @override
  ConsumerState<AiHubScreen> createState() => _AiHubScreenState();
}

class _AiHubScreenState extends ConsumerState<AiHubScreen> {
  static const String _prefsKeyHasSeenOffer = 'has_seen_ai_hub_offer';
  bool _welcomeSheetTriggeredThisSession = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndShowWelcomeOffer();
    });
  }

  Future<void> _checkAndShowWelcomeOffer() async {
    if (_welcomeSheetTriggeredThisSession) return;
    final isPremium = ref.read(premiumStatusProvider);
    if (isPremium) return;

    final prefs = await ref.read(sharedPreferencesProvider.future);
    final hasSeenOffer = prefs.getBool(_prefsKeyHasSeenOffer) ?? false;

    if (!hasSeenOffer) {
      _welcomeSheetTriggeredThisSession = true;
      if (!mounted) return;
      await prefs.setBool(_prefsKeyHasSeenOffer, true);
      if (!mounted) return;

      showModalBottomSheet<void>(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (context) => const AiHubWelcomeSheet(),
      );
    }
  }

  // --- BİLGİ VE SATIŞ EKRANI (NET VE İKNA EDİCİ) ---
  void _showInfoSheet(ThemeData theme) {
    // Şık ve uyumlu bir pembe tonu tanımlıyoruz
    const pinkColor = Color(0xFFE11D48);
    final isPremium = ref.read(premiumStatusProvider);

    showModalBottomSheet(
      context: context,
      backgroundColor: theme.scaffoldBackgroundColor,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.92,
        minChildSize: 0.6,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return Column(
            children: [
              // Tutamaç
              const SizedBox(height: 16),
              Container(
                width: 48,
                height: 5,
                decoration: BoxDecoration(
                  color: theme.dividerColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),

              // İÇERİK
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
                  children: [
                    // Başlık
                    Text(
                      "Bu Özellikler Ne İşe Yarar?",
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                        color: theme.colorScheme.onSurface,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "Yapay zeka araçları seni sınava nasıl hazırlayacak?",
                      style: TextStyle(
                        fontSize: 16,
                        height: 1.4,
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    const SizedBox(height: 40),

                    // ÖZELLİKLER (SOMUT FAYDA ODAKLI)
                    _ProFeatureRow(
                      theme: theme,
                      icon: Icons.calendar_month_rounded,
                      color: const Color(0xFF10B981),
                      title: "Kişiye Özel Ders Programı",
                      description: "Eksik olduğun konulara ve boş günlerine göre sana özel, haftalık ders çalışma programı hazırlar.",
                    ),

                    _ProFeatureRow(
                      theme: theme,
                      icon: Icons.camera_alt_rounded,
                      color: const Color(0xFFF59E0B),
                      title: "Fotoğraflı Soru Çözümü",
                      description: "Çözemediğin sorunun fotoğrafını çek, yapay zeka adım adım nasıl çözüleceğini anlatsın.",
                    ),

                    _ProFeatureRow(
                      theme: theme,
                      icon: Icons.radar_rounded,
                      color: const Color(0xFFF43F5E),
                      title: "Net Arttırma Analizi",
                      description: "Deneme sonuçlarını inceler ve netlerinin neden artmadığını tespit edip çözüm önerir.",
                    ),

                    _ProFeatureRow(
                      theme: theme,
                      icon: Icons.auto_fix_high_rounded,
                      color: const Color(0xFF8B5CF6),
                      title: "Eksik Konu Materyalleri",
                      description: "Sadece senin eksik olduğun konulara özel konu özeti ve test soruları üretir.",
                    ),
                  ],
                ),
              ),

              // SABİT BUTON (Action - PEMBE VE PREMİUM YÖNLENDİRMELİ)
              if (!isPremium)
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 10, 24, 40),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () {
                        Navigator.pop(context); // Sheet'i kapat
                        context.push('/premium'); // Premium ekranına git
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: pinkColor, // İstenilen pembe renk
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        elevation: 8, // Biraz gölge ile şıklık
                        shadowColor: pinkColor.withOpacity(0.4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: const Text(
                        "Hemen Denemeye Başla",
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5
                        ),
                      ),
                    ),
                  ),
                )
              else
                const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isPremium = ref.watch(premiumStatusProvider);
    final theme = Theme.of(context);

    const double gap = 14.0;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        centerTitle: true,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Taktik Üssü',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: theme.colorScheme.onSurface,
                letterSpacing: -0.5,
                fontSize: 20,
              ),
            ),
            if (isPremium) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.amber.withOpacity(0.5), width: 1),
                ),
                child: const Text(
                  'PRO',
                  style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.amber),
                ),
              ),
            ]
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              onPressed: () => _showInfoSheet(theme),
              icon: Icon(
                Icons.question_mark_rounded,
                size: 20,
                color: theme.colorScheme.onSurface,
              ),
              tooltip: 'Nedir?',
              constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
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

            // --- 1. HERO COACH (Tavşan) ---
            _HeroCoachCard(
              isPremium: isPremium,
              onTap: () => _handleNavigation(context, isPremium, route: '/ai-hub/motivation-chat', offerData: {
                'title': 'Taktik Tavşan',
                'subtitle': 'Sınav stresi ve motivasyon koçu.',
                'icon': Icons.psychology_rounded,
                'color': Colors.indigoAccent,
                'marketingTitle': 'Koçun Cebinde!',
                'marketingSubtitle': 'Sınav sadece bilgi değil, psikolojidir. Taktik Tavşan seni mental olarak sınava hazırlar.',
                'redirectRoute': '/ai-hub/motivation-chat',
                'imageAsset': 'assets/images/bunnyy.png',
              }),
            ),

            const SizedBox(height: 24),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              child: Text(
                'PERFORMANS ARAÇLARI',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                  color: theme.colorScheme.onSurface.withOpacity(0.4),
                ),
              ),
            ),

            // --- 2. BENTO GRID (NET VE SATIŞ ODAKLI METİNLER) ---

            // Satır 1
            Row(
              children: [
                Expanded(
                  child: _BentoCard(
                    title: 'Haftalık\nPlan',
                    // ÇOK NET: Ne işe yarar? Program oluşturur.
                    description: 'Senin verilerin ile \nsana özel',
                    icon: Icons.calendar_month_rounded,
                    color: const Color(0xFF10B981),
                    isPremium: isPremium,
                    height: 180, // Rahat sığsın diye
                    onTap: () => _handleNavigation(context, isPremium, route: '/ai-hub/strategic-planning', offerData: {
                      'title': 'Haftalık Stratejist',
                      'subtitle': 'Sana özel ders programı.',
                      'icon': Icons.calendar_month_rounded,
                      'color': const Color(0xFF10B981),
                      'marketingTitle': 'Programın Hazır!',
                      'marketingSubtitle': 'Eksik konularına ve müsait zamanına göre sana en uygun haftalık ders çalışma programını saniyeler içinde oluştur.',
                      'redirectRoute': '/ai-hub/strategic-planning',
                    }),
                  ),
                ),
                const SizedBox(width: gap),
                Expanded(
                  child: _BentoCard(
                    title: 'Soru\nÇözücü',
                    // ÇOK NET: Ne işe yarar? Çözümü gösterir.
                    description: 'Sorunu çek, anında\nçözümünü al.',
                    icon: Icons.camera_enhance_rounded,
                    color: const Color(0xFFF59E0B),
                    isPremium: isPremium,
                    height: 180,
                    onTap: () => _handleNavigation(context, isPremium, route: '/ai-hub/question-solver', offerData: {
                      'title': 'Soru Çözücü',
                      'subtitle': 'Anında çözüm cebinde.',
                      'icon': Icons.camera_enhance_rounded,
                      'color': Colors.orangeAccent,
                      'marketingTitle': 'Soruda Takılma!',
                      'marketingSubtitle': 'Yapamadığın sorunun fotoğrafını çek, Taktik Tavşan adım adım çözümünü anlatsın.',
                      'redirectRoute': '/ai-hub/question-solver',
                    }),
                  ),
                ),
              ],
            ),

            const SizedBox(height: gap),

            // Satır 2
            Row(
              children: [
                Expanded(
                  child: _BentoCard(
                    title: 'Analiz &\nStrateji',
                    // ÇOK NET: Ne işe yarar? Sebebi bulur.
                    description: 'Nasıl daha çok net\nyapacağını söyler.',
                    icon: Icons.radar_rounded,
                    color: const Color(0xFFF43F5E),
                    isPremium: isPremium,
                    height: 160,
                    onTap: () => _handleNavigation(context, isPremium, route: '/ai-hub/analysis-strategy', offerData: {
                      'title': 'Analiz & Strateji',
                      'subtitle': 'Verilerle konuşan koç.',
                      'icon': Icons.radar_rounded,
                      'color': const Color(0xFFF43F5E),
                      'marketingTitle': 'Tuzağı Fark Et!',
                      'marketingSubtitle': 'Denemelerde sürekli aynı yanlışları mı yapıyorsun? Seni aşağı çeken konuları nokta atışı tespit et.',
                      'redirectRoute': '/ai-hub/analysis-strategy',
                    }),
                  ),
                ),
                const SizedBox(width: gap),
                Expanded(
                  child: _BentoCard(
                    title: 'Cevher\nAtölyesi',
                    // ÇOK NET: Ne işe yarar? Materyal verir.
                    description: 'Eksik konularına özel\nçalışma setleri.',
                    icon: Icons.auto_fix_high_rounded,
                    color: const Color(0xFF8B5CF6),
                    isPremium: isPremium,
                    height: 160,
                    onTap: () => _handleNavigation(context, isPremium, route: '/ai-hub/weakness-workshop', offerData: {
                      'title': 'Cevher Atölyesi',
                      'subtitle': 'Kişiye özel çalışma materyalleri.',
                      'icon': Icons.diamond_rounded,
                      'color': const Color(0xFF8B5CF6),
                      'marketingTitle': 'Eksiklerini Kapat!',
                      'marketingSubtitle': 'Yapay zeka sadece eksik olduğun konulara özel konu özeti ve test soruları üretsin.',
                      'redirectRoute': '/ai-hub/weakness-workshop',
                    }),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 32),

            if (!isPremium)
              const _StylishPremiumBanner()
            else
              const _MinimalDisclaimer(),
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
// BİLGİ EKRANI SATIRI (Şık ve Okunaklı)
// -----------------------------------------------------------------------------
class _ProFeatureRow extends StatelessWidget {
  final ThemeData theme;
  final IconData icon;
  final Color color;
  final String title;
  final String description;

  const _ProFeatureRow({
    required this.theme,
    required this.icon,
    required this.color,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // İkon Kutusu
          Container(
            height: 52,
            width: 52,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(width: 18),
          // Yazılar
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                    color: theme.colorScheme.onSurface,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.4,
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                    fontWeight: FontWeight.w400,
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
// BENTO KART (SATIŞ ODAKLI)
// -----------------------------------------------------------------------------
class _BentoCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final bool isPremium;
  final double height;
  final VoidCallback onTap;

  const _BentoCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.isPremium,
    required this.height,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        constraints: BoxConstraints(minHeight: height),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: theme.brightness == Brightness.light
                ? const Color(0xFFE5E7EB)
                : Colors.white.withOpacity(0.05),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F172A).withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: color.withOpacity(0.1),
              blurRadius: 0,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            children: [
              // Hafif Renkli Arkaplan
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                      colors: [
                        color.withOpacity(0.05),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // İkon ve Kilit
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(icon, color: color, size: 24),
                        ),
                        if (!isPremium)
                          Icon(Icons.lock_rounded, size: 18, color: theme.colorScheme.onSurface.withOpacity(0.2)),
                      ],
                    ),

                    // Başlık + Açıklama (alt blok)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            height: 1.1,
                            color: theme.colorScheme.onSurface,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Açıklama (Teşvik Edici)
                        Text(
                          description,
                          style: TextStyle(
                            fontSize: 12.5,
                            height: 1.3,
                            color: theme.colorScheme.onSurface.withOpacity(0.65),
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.fade,
                        ),
                      ],
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

// -----------------------------------------------------------------------------
// HERO KART (TEMİZ VE ŞIK)
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
        height: 130,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1B4B) : const Color(0xFFEEF2FF),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: Colors.indigoAccent.withOpacity(0.2),
            width: 1.5,
          ),
        ),
        child: Stack(
          children: [
            // Arka plan temizlendi (kafa yok)

            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 0, 16),
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.indigo,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'MENTORUN',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Taktik Tavşan',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: isDark ? Colors.white : const Color(0xFF312E81),
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Sınav stresini yöneten\nyapay zeka koçun.',
                          style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.white70 : const Color(0xFF4338CA),
                              fontWeight: FontWeight.w500,
                              height: 1.2
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Tavşan Resmi
                  Expanded(
                    flex: 1,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 8.0, right: 12),
                      child: Image.asset(
                        'assets/images/bunnyy.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// PREMIUM BANNER
// -----------------------------------------------------------------------------
class _StylishPremiumBanner extends StatelessWidget {
  const _StylishPremiumBanner();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/premium'),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF0F172A), Color(0xFF334155)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: const BoxDecoration(
                color: Color(0xFFFFD700),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.star_rounded, color: Colors.black, size: 24),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Taktik Pro\'ya Yükselt',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Tüm araçların kilidini aç, rakiplerini geride bırak.',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white30, size: 16),
          ],
        ),
      ),
    );
  }
}

class _MinimalDisclaimer extends StatelessWidget {
  const _MinimalDisclaimer();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'Yapay zeka önerileri rehberlik amaçlıdır.',
        style: TextStyle(
          fontSize: 11,
          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
        ),
      ),
    );
  }
}

