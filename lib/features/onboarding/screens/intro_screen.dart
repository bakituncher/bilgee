import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:taktik/features/auth/application/auth_controller.dart';
import 'package:taktik/data/providers/firestore_providers.dart';
import 'dart:ui';

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
      description: "Sınav maratonunda senin en büyük destekçin, seni zirveye taşıyacak dijital koçunum. Hazır mısın?",
      imagePath: 'assets/images/bunnyy.webp',
      isAssetImage: true,
      color: const Color(0xFF6366F1),
    ),
    _IntroContent(
      title: "Akıllı Analiz Sistemi",
      description: "Sen deneme ve test verilerini ekledikçe zayıf noktalarını tespit ederim. Kritik konuları belirler, eksiklerini kapatman için sana özel stratejiler üretirim.",
      iconData: Icons.insights_rounded,
      color: const Color(0xFF0EA5E9),
    ),
    _IntroContent(
      title: "Soru Çözücü",
      description: "Takıldığın sorunun fotoğrafını çek, saniyeler içinde adım adım çözümünü ve mantığını anlatayım. Özel ders artık cebinde!",
      iconData: Icons.camera_enhance_rounded,
      color: const Color(0xFFF59E0B),
    ),
    _IntroContent(
      title: "Akıllı Not Defteri",
      description: "PDF veya görsel yükle, saniyeler içinde sana bilgi kartları, özetler veya test hazırlayayım. Çalışmanı verimli hale getireceğim!",
      iconData: Icons.bolt,
      color: const Color(0xFF0EA5E9),
    ),
    _IntroContent(
      title: "Zihin Haritası",
      description: "Karmaşık konuları görsel zihin haritalarına dönüştüreyim. Daha iyi anla, daha kolay hatırla!",
      iconData: Icons.account_tree_rounded,
      color: const Color(0xFF6366F1),
    ),
    _IntroContent(
      title: "Rekabet ve Zafer",
      description: "Diğer adaylarla arenada yarış, liglerde yüksel ve başarılarını madalyalarla taçlandır. Seni hep motive tutacağım!",
      iconData: Icons.emoji_events_rounded,
      color: const Color(0xFFEC4899),
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    if (mounted) {
      setState(() {
        _currentPage = index;
      });
    }
  }

  Future<void> _completeIntro() async {
    if (_isLoading) return;
    if (!mounted) return;

    setState(() => _isLoading = true);

    try {
      final user = ref.read(authControllerProvider).value;
      if (user != null) {
        await ref.read(firestoreServiceProvider).markTutorialAsCompleted(user.uid);
      }
      if (mounted) {
        // Router otomatik olarak bildirim izni ekranına yönlendirecek
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
    final size = MediaQuery.of(context).size;
    final activeContent = _contents[_currentPage];

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          // Animated Background
          Positioned.fill(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeInOut,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    activeContent.color.withOpacity(0.15),
                    theme.scaffoldBackgroundColor,
                    activeContent.color.withOpacity(0.05),
                  ],
                ),
              ),
            ),
          ),

          // Decorative Blob 1
          Positioned(
            top: -100,
            left: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    activeContent.color.withOpacity(0.2),
                    activeContent.color.withOpacity(0.05),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Decorative Blob 2
          Positioned(
            bottom: -50,
            right: -50,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    activeContent.color.withOpacity(0.15),
                    activeContent.color.withOpacity(0.05),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Blur Effect
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
              child: const SizedBox.expand(),
            ),
          ),

          // Main Content
          SafeArea(
            child: Column(
              children: [
                // Header with Skip Button
                SizedBox(
                  height: 56,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
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
                ),

                // PageView Content
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    onPageChanged: _onPageChanged,
                    itemCount: _contents.length,
                    physics: const BouncingScrollPhysics(),
                    itemBuilder: (context, index) {
                      return _IntroSlide(
                        content: _contents[index],
                        screenHeight: size.height,
                      );
                    },
                  ),
                ),

                // Bottom Controls
                Container(
                  padding: const EdgeInsets.fromLTRB(32, 16, 32, 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Page Indicators
                      SizedBox(
                        height: 8,
                        child: Row(
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
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Action Button
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _nextPage,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: activeContent.color,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            disabledBackgroundColor: activeContent.color.withOpacity(0.6),
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
                              : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _currentPage == 0
                                    ? "Hazırım!"
                                    : _currentPage == _contents.length - 1
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
  final Color color;

  _IntroContent({
    required this.title,
    required this.description,
    this.imagePath,
    this.iconData,
    this.isAssetImage = false,
    required this.color,
  });
}

class _IntroSlide extends StatelessWidget {
  final _IntroContent content;
  final double screenHeight;

  const _IntroSlide({
    required this.content,
    required this.screenHeight,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableHeight = constraints.maxHeight;
        final contentHeight = availableHeight * 0.80;
        final visualHeight = contentHeight * 0.45;
        final textHeight = contentHeight * 0.48;

        return Center(
          child: SizedBox(
            height: contentHeight,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Visual Container
                  SizedBox(
                    height: visualHeight,
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
                              )
                                  .animate()
                                  .scale(
                                duration: 600.ms,
                                curve: Curves.elasticOut,
                              )
                                  .shimmer(
                                delay: 1000.ms,
                                duration: 1500.ms,
                                color: Colors.white24,
                              ),
                            )
                                : Icon(
                              content.iconData,
                              size: 100,
                              color: content.color,
                            )
                                .animate()
                                .scale(
                              duration: 500.ms,
                              curve: Curves.easeOutBack,
                            )
                                .then()
                                .shake(duration: 500.ms, hz: 2),
                          ),
                        ),
                      ),
                    )
                        .animate()
                        .slideY(
                      begin: 0.1,
                      end: 0,
                      duration: 600.ms,
                      curve: Curves.easeOutQuint,
                    )
                        .fadeIn(duration: 600.ms),
                  ),

                  const SizedBox(height: 28),

                  // Text Content
                  SizedBox(
                    height: textHeight,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        Text(
                          content.title,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: colorScheme.onSurface,
                            letterSpacing: -0.5,
                            height: 1.2,
                          ),
                        )
                            .animate()
                            .fadeIn(delay: 200.ms, duration: 500.ms)
                            .moveY(begin: 20, end: 0, curve: Curves.easeOut),
                        const SizedBox(height: 16),
                        Flexible(
                          child: Text(
                            content.description,
                            textAlign: TextAlign.center,
                            maxLines: 5,
                            overflow: TextOverflow.visible,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              height: 1.45,
                              fontSize: 15.5,
                            ),
                          )
                              .animate()
                              .fadeIn(delay: 400.ms, duration: 500.ms)
                              .moveY(begin: 20, end: 0, curve: Curves.easeOut),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

