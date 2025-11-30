import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:taktik/features/auth/application/auth_controller.dart';
import 'package:taktik/data/providers/firestore_providers.dart';

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
      description: "Sınav maratonunda sana rehberlik edecek, seni zirveye taşıyacak yapay zeka koçunum. Tanıştığımıza memnun oldum!",
      imagePath: 'assets/images/bunnyy.png',
      isAssetImage: true,
    ),
    _IntroContent(
      title: "Akıllı Analiz Sistemi",
      description: "Sen test çözdükçe zayıf noktalarını tespit ederim. Senin için en kritik konuları belirler ve eksiklerini kapatman için özel stratejiler üretirim.",
      iconData: Icons.insights_rounded,
      color: Colors.cyan,
    ),
    _IntroContent(
      title: "Sana Özel Plan",
      description: "Hedeflerine ve boş zamanlarına uygun haftalık çalışma programını hazırlarım. 'Bugün ne çalışsam?' derdine son!",
      iconData: Icons.calendar_month_rounded,
      color: Colors.orange,
    ),
    _IntroContent(
      title: "Rekabet ve Ödül",
      description: "Diğer adaylarla arenada yarış, liglerde yüksel ve başarılarını madalyalarla taçlandır. Oyunlaştırma ile motivasyonun hep zirvede kalsın.",
      iconData: Icons.emoji_events_rounded,
      color: Colors.amber,
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
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _completeIntro();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Stack(
          children: [
            // Skip Button
            if (_currentPage < _contents.length - 1)
              Positioned(
                top: 16,
                right: 16,
                child: TextButton(
                  onPressed: _completeIntro,
                  child: Text(
                    "Atla",
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),

            // Content
            Column(
              children: [
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

                // Bottom Controls
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Indicators
                      Row(
                        children: List.generate(
                          _contents.length,
                          (index) => AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            margin: const EdgeInsets.only(right: 8),
                            height: 8,
                            width: _currentPage == index ? 24 : 8,
                            decoration: BoxDecoration(
                              color: _currentPage == index
                                  ? colorScheme.primary
                                  : colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ),

                      // Next/Start Button
                      ElevatedButton(
                        onPressed: _nextPage,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colorScheme.primary,
                          foregroundColor: colorScheme.onPrimary,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 16,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        child: _isLoading
                            ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: colorScheme.onPrimary,
                                ),
                              )
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _currentPage == _contents.length - 1
                                        ? "Başlayalım"
                                        : "İlerle",
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Icon(
                                    _currentPage == _contents.length - 1
                                        ? Icons.rocket_launch_rounded
                                        : Icons.arrow_forward_rounded,
                                    size: 20,
                                  ),
                                ],
                              ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
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

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(),
          // Image / Icon
          Expanded(
            flex: 3,
            child: Container(
              alignment: Alignment.center,
              child: content.isAssetImage
                  ? Image.asset(
                      content.imagePath!,
                      fit: BoxFit.contain,
                    ).animate()
                      .scale(duration: 600.ms, curve: Curves.easeOutBack)
                      .fadeIn(duration: 400.ms)
                  : Container(
                      padding: const EdgeInsets.all(48),
                      decoration: BoxDecoration(
                        color: (content.color ?? colorScheme.primary).withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        content.iconData,
                        size: 80,
                        color: content.color ?? colorScheme.primary,
                      ),
                    ).animate()
                      .scale(duration: 500.ms, curve: Curves.easeOutBack)
                      .shimmer(delay: 1000.ms, duration: 1000.ms, color: Colors.white24),
            ),
          ),
          const SizedBox(height: 32),
          // Text Content
          Expanded(
            flex: 2,
            child: Column(
              children: [
                Text(
                  content.title,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ).animate()
                  .fadeIn(delay: 200.ms, duration: 400.ms)
                  .slideY(begin: 0.2, end: 0),
                const SizedBox(height: 16),
                Text(
                  content.description,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    height: 1.5,
                  ),
                ).animate()
                  .fadeIn(delay: 400.ms, duration: 400.ms)
                  .slideY(begin: 0.2, end: 0),
              ],
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }
}
