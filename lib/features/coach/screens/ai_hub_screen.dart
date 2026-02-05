import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';

// Proje içi importlar
import 'package:taktik/data/providers/premium_provider.dart';
import 'package:taktik/data/providers/shared_prefs_provider.dart';
import 'package:taktik/features/coach/widgets/ai_hub_welcome_sheet.dart';
import 'package:taktik/features/onboarding/models/tutorial_step.dart';
import 'package:taktik/shared/widgets/pro_badge.dart';

// --- KEY TANIMLAMALARI (Spotlight için) ---
final GlobalKey _weeklyPlanKey = GlobalKey();
final GlobalKey _solverKey = GlobalKey();
final GlobalKey _studyRoomKey = GlobalKey();
final GlobalKey _coachKey = GlobalKey();
final GlobalKey _mindMapKey = GlobalKey();

class AiHubScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic>? extra;

  const AiHubScreen({super.key, this.extra});

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
      _checkAndStartPremiumTour();
    });
  }

  void _checkAndStartPremiumTour() {
    if (widget.extra != null && widget.extra!['startPremiumTour'] == true) {
      final premiumSteps = [
        TutorialStep(
          title: "Taktik Üssü Artık Seninle!",
          text: "Tebrikler! Artık tüm yapay zeka araçlarına sınırsız erişimin var. Şimdi sana bu güçlü araçları nasıl kullanacağını göstereyim.",
          buttonText: "Hadi Başlayalım",
        ),
        TutorialStep(
          highlightKey: _weeklyPlanKey,
          title: "Haftalık Çalışma Planın",
          text: "Her hafta sana özel, eksik konularına ve müsait zamanlarına göre hazırlanan akıllı bir ders programı. Artık neyi ne zaman çalışacağını düşünmek yok!",
          buttonText: "Anladım",
        ),
        TutorialStep(
          highlightKey: _solverKey,
          title: "Anında Soru Çözümü",
          text: "Takıldığın sorunun fotoğrafını çek, saniyeler içinde adım adım çözümünü ve mantığını öğren. Özel ders artık cebinde!",
          buttonText: "Harika",
        ),
        TutorialStep(
          highlightKey: _studyRoomKey,
          title: "Kişisel Etüt Odan",
          text: "Eksik olduğun konulara özel konu özetleri ve test soruları burada. Zayıf noktalarını güçlü yanlara çevir!",
          buttonText: "Devam",
        ),
        TutorialStep(
          highlightKey: _mindMapKey,
          title: "Zihin Haritaları",
          text: "Karmaşık konuları görsel haritalarla öğren. Bilgiyi organize et, hatırlamayı kolaylaştır!",
          buttonText: "Devam",
        ),
        TutorialStep(
          highlightKey: _coachKey,
          title: "Mentörün Taktik Tavşan",
          text: "Motivasyon, strateji, analiz ve destek... Sınav yolculuğunda her alanda yanında olacak koçun!",
          buttonText: "Keşfet",
        ),
      ];

      showDialog(
        context: context,
        useSafeArea: false,
        barrierDismissible: false,
        barrierColor: Colors.transparent,
        builder: (context) => _PremiumTourDialog(steps: premiumSteps),
      );
    }
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

  void _showInfoSheet(ThemeData theme) {
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
              const SizedBox(height: 16),
              Container(
                width: 48,
                height: 5,
                decoration: BoxDecoration(
                  color: theme.dividerColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
                  children: [
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
                      icon: Icons.account_tree_rounded,
                      color: const Color(0xFF6366F1),
                      title: "Zihin Haritası",
                      description: "Karmaşık konuları görsel zihin haritalarına dönüştür. Daha iyi anla, daha kolay hatırla.",
                    ),
                    _ProFeatureRow(
                      theme: theme,
                      icon: Icons.menu_book_rounded,
                      color: const Color(0xFF8B5CF6),
                      title: "Etüt Odası",
                      description: "Sadece senin eksik olduğun konulara özel konu özeti ve test soruları üretir.",
                    ),
                  ],
                ),
              ),
              if (!isPremium)
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 10, 24, 40),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () {
                        Navigator.pop(context);
                        context.push('/premium');
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: pinkColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        elevation: 8,
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
              const ProBadge(),
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
            KeyedSubtree(
              key: _coachKey,
              child: _HeroCoachCard(
                isPremium: isPremium,
                onTap: () => _handleNavigation(context, isPremium, route: '/ai-hub/motivation-chat', offerData: {
                  'title': 'Taktik Tavşan',
                  'subtitle': 'Sınav stresi ve motivasyon koçu.',
                  'iconName': 'psychology',
                  'color': Colors.indigoAccent,
                  'marketingTitle': 'Koçun Cebinde!',
                  'marketingSubtitle': 'Sınav sadece bilgi değil, mentalitedir. Taktik Tavşan seni mental olarak sınava hazırlar.',
                  'redirectRoute': '/ai-hub/motivation-chat',
                  'imageAsset': 'assets/images/bunnyy.png',
                }),
              ),
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

            // --- 2. BENTO GRID ---
            // Satır 1
            // IntrinsicHeight ile kartların boyunu eşitliyoruz
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: KeyedSubtree(
                      key: _weeklyPlanKey,
                      child: _BentoCard(
                        title: 'Haftalık\nPlan',
                        description: 'Senin verilerin ile\nsana özel program',
                        icon: Icons.calendar_month_rounded,
                        color: const Color(0xFF10B981),
                        isPremium: isPremium,
                        height: 180,
                        onTap: () => _handleNavigation(context, isPremium, route: '/ai-hub/strategic-planning', offerData: {
                          'title': 'Haftalık Stratejist',
                          'subtitle': 'Sana özel ders programı.',
                          'iconName': 'calendar_month',
                          'color': const Color(0xFF10B981),
                          'marketingTitle': 'Programın Hazır!',
                          'marketingSubtitle': 'Eksik konularına ve müsait zamanına göre sana en uygun haftalık ders çalışma programını saniyeler içinde oluştur.',
                          'redirectRoute': '/ai-hub/strategic-planning',
                        }),
                      ),
                    ),
                  ),
                  const SizedBox(width: gap),
                  Expanded(
                    child: KeyedSubtree(
                      key: _solverKey,
                      child: _BentoCard(
                        title: 'Soru\nÇözücü',
                        description: 'Sorunu çek, anında\nçözümünü öğren',
                        icon: Icons.camera_enhance_rounded,
                        color: const Color(0xFFF59E0B),
                        isPremium: true,
                        height: 180,
                        onTap: () => _handleNavigation(context, isPremium, route: '/ai-hub/question-solver', offerData: {
                          'title': 'Soru Çözücü',
                          'subtitle': 'Anında çözüm cebinde.',
                          'iconName': 'camera_enhance',
                          'color': Colors.orangeAccent,
                          'marketingTitle': 'Soruda Takılma!',
                          'marketingSubtitle': 'Yapamadığın sorunun fotoğrafını çek, Taktik Tavşan adım adım çözümünü anlatsın.',
                          'redirectRoute': '/ai-hub/question-solver',
                        }),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: gap),

            // Satır 2 - Etüt Odası ve Zihin Haritası
            // IntrinsicHeight ile kartların boyunu eşitliyoruz
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: KeyedSubtree(
                      key: _studyRoomKey,
                      child: _BentoCard(
                        title: 'Etüt\nOdası',
                        description: 'Eksik konularına\nözel içerik üret',
                        icon: Icons.menu_book_rounded,
                        color: const Color(0xFF8B5CF6),
                        isPremium: isPremium,
                        height: 180,
                        onTap: () => _handleNavigation(context, isPremium, route: '/ai-hub/weakness-workshop', offerData: {
                          'title': 'Etüt Odası',
                          'subtitle': 'Kişiye özel çalışma materyalleri.',
                          'iconName': 'menu_book',
                          'color': const Color(0xFF8B5CF6),
                          'marketingTitle': 'Eksiklerini Kapat!',
                          'marketingSubtitle': 'Yapay zeka sadece eksik olduğun konulara özel konu özeti ve test soruları üretsin.',
                          'redirectRoute': '/ai-hub/weakness-workshop',
                        }),
                      ),
                    ),
                  ),
                  const SizedBox(width: gap),
                  Expanded(
                    // EKLENDİ: Zihin Haritası için KeyedSubtree eklendi
                    child: KeyedSubtree(
                      key: _mindMapKey,
                      child: _BentoCard(
                        title: 'Zihin\nHaritası',
                        description: 'Konuları görsel\nharitalarla öğren',
                        icon: Icons.account_tree_rounded,
                        color: const Color(0xFF6366F1),
                        isPremium: true,
                        height: 180,
                        onTap: () => _handleNavigation(context, isPremium, route: '/ai-hub/mind-map', offerData: {
                          'title': 'Zihin Haritası',
                          'subtitle': 'Konuları görselleştir ve daha iyi anla.',
                          'iconName': 'account_tree',
                          'color': const Color(0xFF6366F1),
                          'marketingTitle': 'Düşüncelerini Haritala!',
                          'marketingSubtitle': 'Karmaşık konuları görsel zihin haritalarına dönüştür. Daha iyi anla, daha kolay hatırla.',
                          'redirectRoute': '/ai-hub/mind-map',
                        }),
                      ),
                    ),
                  ),
                ],
              ),
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
    if (route == '/ai-hub/question-solver' || route == '/ai-hub/mind-map') {
      context.go(route);
      return;
    }

    if (isPremium) {
      context.go(route);
    } else {
      context.go('/ai-hub/offer', extra: offerData);
    }
  }
}

// -----------------------------------------------------------------------------
// PREMIUM TOUR DIALOG
// -----------------------------------------------------------------------------
class _PremiumTourDialog extends StatefulWidget {
  final List<TutorialStep> steps;
  const _PremiumTourDialog({required this.steps});

  @override
  State<_PremiumTourDialog> createState() => _PremiumTourDialogState();
}

class _PremiumTourDialogState extends State<_PremiumTourDialog> {
  int _currentIndex = 0;

  void _next() {
    if (_currentIndex < widget.steps.length - 1) {
      setState(() {
        _currentIndex++;
      });
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final step = widget.steps[_currentIndex];
    final key = step.highlightKey;

    Rect? highlightRect;
    if (key != null && key.currentContext != null) {
      final renderBox = key.currentContext!.findRenderObject() as RenderBox;
      final offset = renderBox.localToGlobal(Offset.zero);
      highlightRect = Rect.fromLTWH(offset.dx, offset.dy, renderBox.size.width, renderBox.size.height);
    }

    final size = MediaQuery.of(context).size;
    final topPadding = MediaQuery.of(context).padding.top;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    bool placeBelow = true;
    double? topPos;
    double? bottomPos;

    const double spacing = 24.0;

    if (highlightRect != null) {
      final spaceAbove = highlightRect.top - topPadding;
      final spaceBelow = size.height - highlightRect.bottom - bottomPadding;

      if (spaceBelow >= spaceAbove || spaceAbove < 200) {
        placeBelow = true;
        topPos = highlightRect.bottom + spacing;
        bottomPos = null;
      } else {
        placeBelow = false;
        bottomPos = (size.height - highlightRect.top) + spacing;
        topPos = null;
      }
    } else {
      topPos = size.height * 0.35;
    }

    return Stack(
      children: [
        GestureDetector(
          onTap: _next,
          child: CustomPaint(
            size: size,
            painter: _SpotlightPainter(
              highlightRect: highlightRect,
              overlayColor: Colors.black.withOpacity(0.85),
              glowColor: const Color(0xFFFFD700),
            ),
          ),
        ),

        Positioned(
          left: 24,
          right: 24,
          top: topPos,
          bottom: bottomPos,
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E2C).withOpacity(0.98),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.5), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.5),
                    blurRadius: 30,
                    spreadRadius: 5,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFD700).withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.auto_awesome, color: Color(0xFFFFD700), size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          step.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.3,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    step.text,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 15,
                      height: 1.5,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.icon(
                      onPressed: _next,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFFFD700),
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                      label: Text(
                        step.buttonText.toUpperCase(),
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 1),
                      ),
                    ),
                  ),
                ],
              ),
            )
                .animate(key: ValueKey(_currentIndex))
                .fadeIn(duration: 300.ms)
                .slide(
                begin: placeBelow ? const Offset(0, 0.1) : const Offset(0, -0.1),
                end: Offset.zero,
                duration: 400.ms,
                curve: Curves.easeOutBack
            ),
          ),
        ),

        Positioned(
          top: MediaQuery.of(context).padding.top + 10,
          right: 16,
          child: SafeArea(
            child: TextButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                foregroundColor: Colors.white.withOpacity(0.8),
                backgroundColor: Colors.black.withOpacity(0.3),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              icon: const Icon(Icons.close_rounded, size: 18),
              label: const Text(
                "Turu Kapat",
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// HELPER WIDGETS
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
      child: SizedBox(
        height: height,
        child: Container(
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
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            description,
                            style: TextStyle(
                              fontSize: 12.5,
                              height: 1.3,
                              color: theme.colorScheme.onSurface.withOpacity(0.65),
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
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
      ),
    );
  }
}

class _HeroCoachCard extends StatelessWidget {
  final bool isPremium;
  final VoidCallback onTap;

  const _HeroCoachCard({
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
        'Yapay zeka öngörüleri referans amaçlıdır.',
        style: TextStyle(
          fontSize: 11,
          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
        ),
      ),
    );
  }
}

class _SpotlightPainter extends CustomPainter {
  final Rect? highlightRect;
  final Color overlayColor;
  final Color glowColor;

  _SpotlightPainter({
    required this.highlightRect,
    required this.overlayColor,
    required this.glowColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final backgroundPath = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));

    if (highlightRect == null) {
      canvas.drawPath(backgroundPath, Paint()..color = overlayColor);
      return;
    }

    final cutoutRect = highlightRect!.inflate(8);
    final cutoutPath = Path()..addRRect(RRect.fromRectAndRadius(cutoutRect, const Radius.circular(24)));

    final overlayPath = Path.combine(
      PathOperation.difference,
      backgroundPath,
      cutoutPath,
    );

    canvas.drawPath(overlayPath, Paint()..color = overlayColor);

    final glowPaint = Paint()
      ..color = glowColor.withOpacity(0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20);

    canvas.drawPath(cutoutPath, glowPaint);

    final borderPaint = Paint()
      ..color = glowColor.withOpacity(0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawPath(cutoutPath, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _SpotlightPainter oldDelegate) {
    return oldDelegate.highlightRect != highlightRect;
  }
}