import 'dart:ui';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:taktik/core/services/revenuecat_service.dart';
import 'package:taktik/core/theme/app_theme.dart';
import 'package:taktik/data/providers/premium_provider.dart';

class PremiumScreen extends ConsumerStatefulWidget {
  const PremiumScreen({super.key});

  @override
  ConsumerState<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends ConsumerState<PremiumScreen> with TickerProviderStateMixin {
  late final AnimationController _headerSlideController;
  late final AnimationController _fadeController;
  late final AnimationController _cardPopController;
  late final AnimationController _backgroundPulseController;

  late final Animation<double> _gradientShift;

  @override
  void initState() {
    super.initState();
    _headerSlideController = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _fadeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _cardPopController = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _backgroundPulseController = AnimationController(vsync: this, duration: const Duration(seconds: 16))
      ..repeat(reverse: true);

    _gradientShift = CurvedAnimation(parent: _backgroundPulseController, curve: Curves.easeInOut);

    Future.delayed(const Duration(milliseconds: 120), () {
      _headerSlideController.forward();
      _fadeController.forward();
      _cardPopController.forward();
    });
  }

  @override
  void dispose() {
    _headerSlideController.dispose();
    _fadeController.dispose();
    _cardPopController.dispose();
    _backgroundPulseController.dispose();
    super.dispose();
  }

  Future<void> _handleBack() async {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final offeringsAsync = ref.watch(offeringsProvider);
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: AppTheme.primaryColor,
      body: Stack(
        children: [
          _AnimatedPremiumBackground(animation: _gradientShift),
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(color: Colors.black.withOpacity(0.25)),
          ),
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverAppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                pinned: true,
                automaticallyImplyLeading: false,
                leading: IconButton(
                  icon: const Icon(Icons.close_rounded, size: 28, color: Colors.white),
                  tooltip: 'Kapat',
                  onPressed: _handleBack,
                ),
                title: FadeTransition(
                  opacity: CurvedAnimation(parent: _fadeController, curve: const Interval(0.2, 1)),
                  child: const Text(
                    'TaktikAI Premium',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () async {
                      await ref.read(premiumStatusProvider.notifier).restorePurchases();
                      if (!mounted) return;
                      final isPremium = ref.read(premiumStatusProvider);
                      final message = isPremium
                          ? 'Satın alımlar geri yüklendi. Premium aktif.'
                          : 'Aktif satın alım bulunamadı.';
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(message),
                          backgroundColor: isPremium ? AppTheme.successColor : AppTheme.accentColor,
                        ),
                      );
                      if (isPremium) _handleBack();
                    },
                    child: Text(
                      'Geri Yükle',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Colors.white70,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                ],
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                  child: _HeroSection(
                    slideController: _headerSlideController,
                    fadeController: _fadeController,
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: _ExamFocusCarousel(
                    slideController: _headerSlideController,
                    fadeController: _fadeController,
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: _PremiumAdvantageList(
                    slideController: _headerSlideController,
                    fadeController: _fadeController,
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 32, 24, 0),
                  child: FadeTransition(
                    opacity: CurvedAnimation(parent: _fadeController, curve: const Interval(0.5, 1)),
                    child: const _SupportHighlights(),
                  ),
                ),
              ),
              SliverFillRemaining(
                hasScrollBody: false,
                child: offeringsAsync.when(
                  data: (offerings) => FadeTransition(
                    opacity: _fadeController,
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(20, 48, 20, bottomInset > 0 ? bottomInset + 20 : 32),
                      child: Column(
                        children: [
                          const Spacer(),
                          _PurchaseOptionsSection(
                            cardController: _cardPopController,
                            offerings: offerings,
                            onPurchase: (package) => _purchasePackage(context, ref, package),
                          ),
                          const SizedBox(height: 32),
                          const _TrustBadges(),
                        ],
                      ),
                    ),
                  ),
                  loading: () => const Center(
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.secondaryColor),
                  ),
                  error: (error, stack) => Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Text(
                        'Satın alma seçenekleri yüklenirken bir hata oluştu: $error',
                        style: const TextStyle(color: Colors.white70),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _purchasePackage(BuildContext context, WidgetRef ref, Package package) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator(color: AppTheme.secondaryColor)),
    );

    try {
      final outcome = await RevenueCatService.makePurchase(package);
      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop();

      if (outcome.cancelled) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Satın alma iptal edildi.'),
            backgroundColor: AppTheme.accentColor,
          ),
        );
        return;
      }

      if (outcome.success && outcome.info != null) {
        ref.read(premiumStatusProvider.notifier).updateFromCustomerInfo(outcome.info!);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Premium dünyasına hoş geldin!'),
            backgroundColor: AppTheme.successColor,
          ),
        );
        _handleBack();
        return;
      }

      final message = outcome.error ?? 'Bilinmeyen bir hata oluştu.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Satın alma başarısız: $message'),
          backgroundColor: AppTheme.accentColor,
        ),
      );
    } catch (error) {
      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Satın alma sırasında bir hata oluştu: $error'),
          backgroundColor: AppTheme.accentColor,
        ),
      );
    }
  }
}

class _AnimatedPremiumBackground extends StatelessWidget {
  const _AnimatedPremiumBackground({required this.animation});

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.lerp(const Color(0xFF101727), const Color(0xFF1F2B45), animation.value)!,
                Color.lerp(const Color(0xFF0A0E18), const Color(0xFF121829), 1 - animation.value)!,
              ],
            ),
          ),
        );
      },
    );
  }
}

class _HeroSection extends StatelessWidget {
  const _HeroSection({required this.slideController, required this.fadeController});

  final AnimationController slideController;
  final AnimationController fadeController;

  @override
  Widget build(BuildContext context) {
    final slideAnimation = Tween<Offset>(begin: const Offset(0, 0.25), end: Offset.zero).animate(
      CurvedAnimation(parent: slideController, curve: Curves.easeOutCubic),
    );

    return SlideTransition(
      position: slideAnimation,
      child: FadeTransition(
        opacity: fadeController,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF243350), Color(0xFF1B2440)],
            ),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.35),
                blurRadius: 40,
                offset: const Offset(0, 24),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: Colors.white.withOpacity(0.1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 16),
                    SizedBox(width: 8),
                    Text(
                      'Yeni Nesil Paywall',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, letterSpacing: 0.4),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Başarı planını Premium ile güçlendir',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Deneme ve konu netlerini gir, yapay zekâ haftalık planını ve stratejini hazırlasın. YKS, LGS veya KPSS hedefin ne olursa olsun; psikolojik destek, taktik koçluk ve motivasyon tek ekranda.',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.75),
                  height: 1.4,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 28),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: const [
                  _HeroMetric(icon: Icons.timeline_rounded, title: '40K+ plan', subtitle: 'Haftalık rota hazırlandı'),
                  _HeroMetric(icon: Icons.psychology_rounded, title: 'Uzman koçlar', subtitle: 'Psikolojik & stratejik destek'),
                  _HeroMetric(icon: Icons.favorite_rounded, title: '%94 memnuniyet', subtitle: 'Sınav maratonunda yanındayız'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroMetric extends StatelessWidget {
  const _HeroMetric({required this.icon, required this.title, required this.subtitle});

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.white.withOpacity(0.08),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              Text(
                subtitle,
                style: TextStyle(color: Colors.white.withOpacity(0.65), fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ExamFocusCarousel extends StatelessWidget {
  const _ExamFocusCarousel({required this.slideController, required this.fadeController});

  final AnimationController slideController;
  final AnimationController fadeController;

  @override
  Widget build(BuildContext context) {
    final exams = [
      (
        'YKS Turbo Modu',
        'Netlerini gir, TaktikAI eksiklerini tarayıp sana özel ders/soru dağılımı önerir. Deneme ritmini koru.',
        Icons.auto_graph_outlined,
      ),
      (
        'LGS Oyun Planı',
        'Sınav stresi ve motivasyon için mikro molalar, hedef net hatırlatıcıları ve günlük görev setleri.',
        Icons.rocket_launch_outlined,
      ),
      (
        'KPSS Pro Stratejisi',
        'Branşlara göre konu önceliklendirmesi, yoğun çalışma günlerine psikolojik dayanıklılık önerileri.',
        Icons.military_tech_rounded,
      ),
    ];

    return SizedBox(
      height: 190,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(parent: slideController, curve: const Interval(0.15, 1, curve: Curves.easeOutCubic)),
        ),
        child: FadeTransition(
          opacity: CurvedAnimation(parent: fadeController, curve: const Interval(0.15, 1)),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            physics: const BouncingScrollPhysics(),
            itemBuilder: (context, index) {
              final exam = exams[index];
              return _ExamCard(title: exam.$1, description: exam.$2, icon: exam.$3);
            },
            separatorBuilder: (_, __) => const SizedBox(width: 16),
            itemCount: exams.length,
          ),
        ),
      ),
    );
  }
}

class _ExamCard extends StatelessWidget {
  const _ExamCard({required this.title, required this.description, required this.icon});

  final String title;
  final String description;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [Color(0xFF2C3A5D), Color(0xFF1B223B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.28),
            blurRadius: 30,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(height: 18),
          Text(
            title,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Text(
              description,
              style: const TextStyle(color: Colors.white70, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _PremiumAdvantageList extends StatelessWidget {
  const _PremiumAdvantageList({required this.slideController, required this.fadeController});

  final AnimationController slideController;
  final AnimationController fadeController;

  @override
  Widget build(BuildContext context) {
    final items = [
      (
        Icons.smart_toy_outlined,
        'Haftalık Yapay Zekâ Programı',
        'Net verilerini analiz edip seviyene göre çalışma saatleri, mola dengesi ve soru adetleri önerir.',
      ),
      (
        Icons.pie_chart_rounded,
        'Derin Analiz & Net Takibi',
        'Deneme trendlerini canlı izleyip, zayıf konularına anında müdahale et.',
      ),
      (
        Icons.psychology_rounded,
        'Psikolojik Dayanıklılık Modülü',
        'Uzman destekleriyle odaklanma, nefes egzersizleri ve motivasyon mesajları al.',
      ),
      (
        Icons.schedule_rounded,
        'Taktik Hatırlatıcılar',
        'Her güne özel görev listesi, pomodoro blokları ve sınav takvimi senkronizasyonu.',
      ),
    ];

    return Column(
      children: [
        for (var i = 0; i < items.length; i++)
          _AdvantageTile(
            slideController: slideController,
            fadeController: fadeController,
            icon: items[i].$1,
            title: items[i].$2,
            subtitle: items[i].$3,
            delay: Duration(milliseconds: 180 * i),
          ),
      ],
    );
  }
}

class _AdvantageTile extends StatefulWidget {
  const _AdvantageTile({
    required this.slideController,
    required this.fadeController,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.delay,
  });

  final AnimationController slideController;
  final AnimationController fadeController;
  final IconData icon;
  final String title;
  final String subtitle;
  final Duration delay;

  @override
  State<_AdvantageTile> createState() => _AdvantageTileState();
}

class _AdvantageTileState extends State<_AdvantageTile> {
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    final base = widget.delay.inMilliseconds / 1000;
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.4), end: Offset.zero).animate(
      CurvedAnimation(parent: widget.slideController, curve: Interval(base, 1, curve: Curves.easeOutCubic)),
    );
    _fadeAnimation = CurvedAnimation(parent: widget.fadeController, curve: Interval(base, 1, curve: Curves.easeOut));
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 10),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: const LinearGradient(
              colors: [Color(0xFF1E2A45), Color(0xFF1A243A)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.25),
                blurRadius: 30,
                offset: const Offset(0, 18),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.1),
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                ),
                child: Icon(widget.icon, color: Colors.white, size: 26),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 17),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      widget.subtitle,
                      style: TextStyle(color: Colors.white.withOpacity(0.7), height: 1.4),
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

class _SupportHighlights extends StatelessWidget {
  const _SupportHighlights();

  @override
  Widget build(BuildContext context) {
    final items = [
      (
        Icons.headset_mic_rounded,
        'Koçluk Kanalı',
        'Mentorler ve yapay zekâ birlikte çalışır; hedef güncellemelerin WhatsApp/Telegram ritmine uyum sağlar.',
      ),
      (
        Icons.nightlight_round,
        'Odak & Dinlenme',
        'Nefes egzersizleri, meditasyon sesleri ve uyku planları ile zihnini dengede tut.',
      ),
      (
        Icons.workspace_premium_rounded,
        'Şampiyon Kulübü',
        'Deneme ligleri, haftalık leaderboard ve başarı hikâyelerinden ilham al.',
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Premium ile gelen ek güçler',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 20),
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 16,
          runSpacing: 16,
          children: items
              .map(
                (item) => _SupportCard(icon: item.$1, title: item.$2, description: item.$3),
              )
              .toList(),
        ),
      ],
    );
  }
}

class _SupportCard extends StatelessWidget {
  const _SupportCard({required this.icon, required this.title, required this.description});

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white.withOpacity(0.06),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.1),
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 6),
          Text(
            description,
            style: const TextStyle(color: Colors.white70, height: 1.4, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _PurchaseOptionsSection extends StatelessWidget {
  const _PurchaseOptionsSection({
    required this.cardController,
    required this.offerings,
    required this.onPurchase,
  });

  final AnimationController cardController;
  final Offerings? offerings;
  final ValueChanged<Package> onPurchase;

  @override
  Widget build(BuildContext context) {
    Package? monthly;
    Package? yearly;
    double? savePercent;

    if (offerings != null) {
      final current = offerings!.current ??
          offerings!.all.values.firstWhereOrNull((element) => element.availablePackages.isNotEmpty);
      if (current != null) {
        monthly = current.monthly ??
            current.getPackage('aylik-normal') ??
            current.availablePackages.firstWhereOrNull((p) => p.packageType == PackageType.monthly);
        yearly = current.annual ??
            current.getPackage('yillik-normal') ??
            current.availablePackages.firstWhereOrNull((p) => p.packageType == PackageType.annual);

        if (monthly == null || yearly == null) {
          final sorted = List<Package>.from(current.availablePackages)
            ..sort((a, b) => a.storeProduct.price.compareTo(b.storeProduct.price));
          if (sorted.isNotEmpty) monthly ??= sorted.first;
          if (sorted.length > 1) yearly ??= sorted.last;
        }

        if (monthly != null && yearly != null) {
          final mPrice = monthly!.storeProduct.price;
          final yPrice = yearly!.storeProduct.price;
          if (mPrice > 0 && yPrice > 0) {
            savePercent = (1 - (yPrice / (mPrice * 12))) * 100;
          }
        }
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Premium’a geç ve sınav maratonunu yeniden yaz',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 20),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Text(
          'Planın aktif olur olmaz tüm koçluk özelliklerine, strateji laboratuvarına ve sınırsız yapay zekâ desteğine erişirsin.',
          style: TextStyle(color: Colors.white.withOpacity(0.7), height: 1.4),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 28),
        if (yearly != null)
          _PurchaseOptionCard(
            animationController: cardController,
            package: yearly!,
            title: 'Yıllık Premium',
            subtitle: '${yearly!.storeProduct.priceString} / yıl',
            tag: savePercent != null ? '%${savePercent!.toStringAsFixed(0)} avantaj' : 'En popüler',
            highlights: const [
              'Strateji laboratuvarına sınırsız erişim',
              'Koçluk yayınlarına öncelikli giriş',
              'Planını dilediğin an durdur / devam et',
            ],
            highlight: true,
            delay: const Duration(milliseconds: 0),
            onTap: () => onPurchase(yearly!),
          ),
        if (yearly != null) const SizedBox(height: 18),
        if (monthly != null)
          _PurchaseOptionCard(
            animationController: cardController,
            package: monthly!,
            title: 'Aylık Premium',
            subtitle: '${monthly!.storeProduct.priceString} / ay',
            highlights: const [
              'Haftalık yapay zekâ programı',
              'Psikolojik destek içerikleri',
              'Tüm planlayıcılara tam erişim',
            ],
            delay: const Duration(milliseconds: 120),
            onTap: () => onPurchase(monthly!),
          ),
      ],
    );
  }
}

class _PurchaseOptionCard extends StatefulWidget {
  const _PurchaseOptionCard({
    required this.animationController,
    required this.package,
    required this.title,
    required this.subtitle,
    required this.highlights,
    this.tag,
    this.highlight = false,
    required this.onTap,
    required this.delay,
  });

  final AnimationController animationController;
  final Package package;
  final String title;
  final String subtitle;
  final List<String> highlights;
  final String? tag;
  final bool highlight;
  final VoidCallback onTap;
  final Duration delay;

  @override
  State<_PurchaseOptionCard> createState() => _PurchaseOptionCardState();
}

class _PurchaseOptionCardState extends State<_PurchaseOptionCard> with SingleTickerProviderStateMixin {
  late final AnimationController _tapController;
  late final Animation<double> _scaleAnimation;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _tapController = AnimationController(vsync: this, duration: const Duration(milliseconds: 160));
    _scaleAnimation = Tween(begin: 1.0, end: 0.97).animate(CurvedAnimation(parent: _tapController, curve: Curves.easeOut));
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.4), end: Offset.zero).animate(
      CurvedAnimation(
        parent: widget.animationController,
        curve: Interval(
          widget.delay.inMilliseconds / widget.animationController.duration!.inMilliseconds,
          1,
          curve: Curves.easeOutCubic,
        ),
      ),
    );
    _fadeAnimation = CurvedAnimation(
      parent: widget.animationController,
      curve: Interval(
        widget.delay.inMilliseconds / widget.animationController.duration!.inMilliseconds,
        1,
        curve: Curves.easeOut,
      ),
    );
  }

  @override
  void dispose() {
    _tapController.dispose();
    super.dispose();
  }

  void _handleTapDown(_) => _tapController.forward();
  void _handleTapUp(_) => _tapController.reverse();
  void _handleTapCancel() => _tapController.reverse();

  void _handleTap() {
    _tapController.forward().then((_) {
      _tapController.reverse();
      widget.onTap();
    });
  }

  @override
  Widget build(BuildContext context) {
    final borderColor = widget.highlight ? AppTheme.secondaryColor : Colors.white.withOpacity(0.12);
    final background = widget.highlight
        ? const LinearGradient(colors: [Color(0xFF2D3B5F), Color(0xFF243351)], begin: Alignment.topLeft, end: Alignment.bottomRight)
        : const LinearGradient(colors: [Color(0xFF1B2439), Color(0xFF161D2E)], begin: Alignment.topLeft, end: Alignment.bottomRight);

    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: GestureDetector(
            onTapDown: _handleTapDown,
            onTapUp: _handleTapUp,
            onTapCancel: _handleTapCancel,
            onTap: _handleTap,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(26),
                gradient: background,
                border: Border.all(color: borderColor, width: widget.highlight ? 2.4 : 1.6),
                boxShadow: [
                  BoxShadow(
                    color: widget.highlight
                        ? AppTheme.secondaryColor.withOpacity(0.4)
                        : Colors.black.withOpacity(0.3),
                    blurRadius: widget.highlight ? 32 : 18,
                    offset: const Offset(0, 18),
                  ),
                ],
              ),
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.tag != null)
                    Align(
                      alignment: Alignment.topLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: const LinearGradient(
                            colors: [AppTheme.secondaryColor, Colors.amber],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: Text(
                          widget.tag!.toUpperCase(),
                          style: const TextStyle(
                            color: AppTheme.primaryColor,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  if (widget.tag != null) const SizedBox(height: 18),
                  Text(
                    widget.title,
                    style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.subtitle,
                    style: const TextStyle(color: Colors.white70, fontSize: 15),
                  ),
                  const SizedBox(height: 16),
                  ...widget.highlights.map(
                    (highlight) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_rounded, color: AppTheme.secondaryColor, size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              highlight,
                              style: const TextStyle(color: Colors.white70, height: 1.4),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      color: Colors.white,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'Premium’a Katıl',
                      style: TextStyle(
                        color: widget.highlight ? AppTheme.primaryColor : AppTheme.primaryColor,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TrustBadges extends StatelessWidget {
  const _TrustBadges();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            _TrustBadge(icon: Icons.lock_rounded, text: 'Güvenli ödeme altyapısı'),
            SizedBox(width: 24),
            _TrustBadge(icon: Icons.refresh_rounded, text: 'Dilediğin an iptal et'),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'Türkiye’de binlerce öğrenci TaktikAI ile sınav maratonunu yönetiyor.',
          style: TextStyle(color: Colors.white.withOpacity(0.6)),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _TrustBadge extends StatelessWidget {
  const _TrustBadge({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white70, size: 18),
        const SizedBox(width: 8),
        Text(text, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
