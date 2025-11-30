import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:taktik/features/auth/application/auth_controller.dart';
import 'package:taktik/data/providers/firestore_providers.dart';
import 'dart:ui'; // For ImageFilter

class IntroScreen extends ConsumerStatefulWidget {
  const IntroScreen({super.key});

  @override
  ConsumerState<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends ConsumerState<IntroScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _isLoading = false;

  final List<_IntroContent> _contents = [
    _IntroContent(
      title: "Selam! Ben Taktik Tavşan",
      description: "Sınav maratonunda senin en büyük destekçin, seni zirveye taşıyacak yapay zeka koçunum. Hazır mısın?",
      imagePath: 'assets/images/bunnyy.png',
      isAssetImage: true,
      color: const Color(0xFF6366F1), // Indigo
    ),
    _IntroContent(
      title: "Akıllı Analiz Sistemi",
      description: "Sen test çözdükçe zayıf noktalarını tespit ederim. Kritik konuları belirler, eksiklerini kapatman için sana özel stratejiler üretirim.",
      iconData: Icons.insights_rounded,
      color: const Color(0xFF0EA5E9), // Sky Blue
    ),
    _IntroContent(
      title: "Sana Özel Plan",
      description: "Hedeflerine ve boş zamanlarına uygun haftalık çalışma programını saniyeler içinde hazırlarım. Planlama derdine son!",
      iconData: Icons.calendar_month_rounded,
      color: const Color(0xFFF59E0B), // Amber
    ),
    _IntroContent(
      title: "Rekabet ve Zafer",
      description: "Diğer adaylarla arenada yarış, liglerde yüksel ve başarılarını madalyalarla taçlandır. Motivasyonun hep zirvede kalsın.",
      iconData: Icons.emoji_events_rounded,
      color: const Color(0xFFEC4899), // Pink
    ),
  ];

  void _onPageChanged(int index) {
    setState(() {
      _currentPage = index;
    });
  }

  Future<void> _completeIntro() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      final user = ref.read(authControllerProvider).value;
      if (user != null) {
        await ref.read(firestoreServiceProvider).markTutorialAsCompleted(user.uid);
      }
      if (mounted) {
        context.go('/');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata oluştu: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _nextPage() {
    if (_currentPage < _contents.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 600),
        curve: Curves.fastOutSlowIn,
      );
    } else {
      _completeIntro();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final activeContent = _contents[_currentPage];

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          // 1. Dynamic Background (Gradients & Blobs)
          Positioned.fill(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeInOut,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    activeContent.color!.withOpacity(0.15),
                    theme.scaffoldBackgroundColor,
                    activeContent.color!.withOpacity(0.05),
                  ],
                ),
              ),
            ),
          ),

          // Decorative Blob 1 (Top Left)
          Positioned(
            top: -100,
            left: -100,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 800),
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: activeContent.color!.withOpacity(0.2),
                boxShadow: [
                  BoxShadow(
                    color: activeContent.color!.withOpacity(0.3),
                    blurRadius: 100,
                    spreadRadius: 20,
                  ),
                ],
              ),
            ),
          ),

          // Decorative Blob 2 (Bottom Right)
          Positioned(
            bottom: -50,
            right: -50,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 800),
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: activeContent.color!.withOpacity(0.15),
                boxShadow: [
                  BoxShadow(
                    color: activeContent.color!.withOpacity(0.2),
                    blurRadius: 80,
                    spreadRadius: 10,
                  ),
                ],
              ),
            ),
          ),

          // Blur Effect for smoother background blending
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
              child: Container(color: Colors.transparent),
            ),
          ),

          // 2. Main Content PageView
          SafeArea(
            child: Column(
              children: [
                // Header (Skip Button)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (_currentPage < _contents.length - 1)
                        TextButton(
                          onPressed: _completeIntro,
                          style: TextButton.styleFrom(
                            foregroundColor: colorScheme.onSurface.withOpacity(0.6),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            textStyle: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          child: const Text("Atla"),
                        ).animate().fadeIn(duration: 300.ms),
                    ],
                  ),
                ),

                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    onPageChanged: _onPageChanged,
                    itemCount: _contents.length,
                    itemBuilder: (context, index) {
                      return _IntroSlide(content: _contents[index]);
                    },
                  ),
                ),

                // 3. Bottom Controls (Indicators & Button)
                Padding(
                  padding: const EdgeInsets.fromLTRB(32, 0, 32, 48),
                  child: Column(
                    children: [
                      // Page Indicators
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          _contents.length,
                              (index) => AnimatedContainer(
                            duration: const Duration(milliseconds: 400),
                            curve: Curves.easeOutBack,
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            height: 8,
                            width: _currentPage == index ? 32 : 8,
                            decoration: BoxDecoration(
                              color: _currentPage == index
                                  ? activeContent.color
                                  : colorScheme.onSurface.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                              boxShadow: _currentPage == index
                                  ? [
                                BoxShadow(
                                  color: activeContent.color!.withOpacity(0.4),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                )
                              ]
                                  : null,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Large Action Button
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _nextPage,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: activeContent.color,
                            foregroundColor: Colors.white,
                            elevation: 8,
                            shadowColor: activeContent.color!.withOpacity(0.5),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                              : AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: child),
                            child: Row(
                              key: ValueKey(_currentPage == _contents.length - 1),
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  _currentPage == _contents.length - 1
                                      ? "Başlayalım"
                                      : "Devam Et",
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Icon(
                                  _currentPage == _contents.length - 1
                                      ? Icons.rocket_launch_rounded
                                      : Icons.arrow_forward_rounded,
                                  size: 24,
                                ),
                              ],
                            ),
                          ),
                        ).animate(target: _currentPage == _contents.length - 1 ? 1 : 0)
                            .shimmer(duration: 1200.ms, color: Colors.white30, delay: 500.ms),
                      ),
                    ],
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

class _IntroContent {
  final String title;
  final String description;
  final String? imagePath;
  final IconData? iconData;
  final bool isAssetImage;
  final Color? color;

  _IntroContent({
    required this.title,
    required this.description,
    this.imagePath,
    this.iconData,
    this.isAssetImage = false,
    this.color,
  });
}

class _IntroSlide extends StatelessWidget {
  final _IntroContent content;

  const _IntroSlide({required this.content});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(flex: 2),

          // Visual Container
          Expanded(
            flex: 5,
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withOpacity(0.05)
                    : Colors.white.withOpacity(0.6),
                borderRadius: BorderRadius.circular(40),
                border: Border.all(
                  color: Colors.white.withOpacity(isDark ? 0.1 : 0.5),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: (content.color ?? Colors.black).withOpacity(0.1),
                    blurRadius: 40,
                    offset: const Offset(0, 10),
                    spreadRadius: 0,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(40),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Center(
                    child: content.isAssetImage
                        ? Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Image.asset(
                        content.imagePath!,
                        fit: BoxFit.contain,
                      ).animate()
                          .scale(duration: 600.ms, curve: Curves.elasticOut)
                          .shimmer(delay: 1000.ms, duration: 1500.ms, color: Colors.white24),
                    )
                        : Icon(
                      content.iconData,
                      size: 100,
                      color: content.color,
                    ).animate()
                        .scale(duration: 500.ms, curve: Curves.easeOutBack)
                        .then()
                        .shake(duration: 500.ms, hz: 2),
                  ),
                ),
              ),
            ).animate()
                .slideY(begin: 0.1, end: 0, duration: 600.ms, curve: Curves.easeOutQuint)
                .fadeIn(duration: 600.ms),
          ),

          const SizedBox(height: 48),

          // Text Content
          Expanded(
            flex: 4,
            child: Column(
              children: [
                Text(
                  content.title,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: colorScheme.onSurface,
                    letterSpacing: -0.5,
                  ),
                ).animate()
                    .fadeIn(delay: 200.ms, duration: 500.ms)
                    .moveY(begin: 20, end: 0, curve: Curves.easeOut),

                const SizedBox(height: 16),

                Text(
                  content.description,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    height: 1.5,
                    fontSize: 16,
                  ),
                ).animate()
                    .fadeIn(delay: 400.ms, duration: 500.ms)
                    .moveY(begin: 20, end: 0, curve: Curves.easeOut),
              ],
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }
}
