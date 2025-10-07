// lib/features/coach/screens/ai_hub_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:taktik/core/theme/app_theme.dart'; // AppTheme import geri eklendi
import 'dart:math';
import 'dart:ui';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:taktik/data/providers/firestore_providers.dart';
import 'package:taktik/shared/widgets/premium_gate.dart';

// Öğretici için GlobalKey'ler
final GlobalKey strategicPlanningKey = GlobalKey();
final GlobalKey weaknessWorkshopKey = GlobalKey();
final GlobalKey motivationChatKey = GlobalKey();
final GlobalKey analysisStrategyKey = GlobalKey(); // YENİ: Analiz & Strateji (birleşik)

class AiHubScreen extends ConsumerStatefulWidget {
  const AiHubScreen({super.key});

  @override
  ConsumerState<AiHubScreen> createState() => _AiHubScreenState();
}

class _AiHubScreenState extends ConsumerState<AiHubScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  late final Animation<double> _glow;
  bool _isGenerating = false;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: const Duration(seconds: 5))..repeat(reverse: true);
    _glow = CurvedAnimation(parent: _pulse, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  Future<void> _handleAiToolTap(_AiTool tool) async {
    if (_isGenerating) return;

    final user = ref.read(userProfileProvider).value;
    final isPremium = user?.isPremium ?? false;

    if (!isPremium) {
      context.push('/premium');
      return;
    }

    setState(() => _isGenerating = true);

    final functions = ref.read(functionsProvider);
    final callable = functions.httpsCallable('premium-generateGemini');

    try {
      await callable.call();
      if (mounted) context.go(tool.route);
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      String message = e.message ?? 'Bilinmeyen bir sunucu hatası oluştu.';
      if (e.code == 'resource-exhausted') {
        message = 'Bu işlemi yapmak için yeterli yıldızınız yok.';
      } else if (e.code == 'failed-precondition') {
        message = 'Bu özellik yalnızca Premium üyelere açıktır.';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Beklenmedik bir hata oluştu.'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final userProfile = ref.watch(userProfileProvider);
    final stars = userProfile.value?.stars ?? 0;
    final isPremium = userProfile.value?.isPremium ?? false;

    final tools = [
      _AiTool(
        key: strategicPlanningKey,
        title: 'Haftalık Planlama',
        subtitle: 'Uzun vadeli zafer stratejini ve haftalık planını oluştur.',
        icon: Icons.insights_rounded,
        route: '/ai-hub/strategic-planning',
        color: AppTheme.secondaryColor,
        heroTag: 'strategic-core',
        chip: 'Odak',
      ),
      _AiTool(
        key: weaknessWorkshopKey,
        title: 'Cevher Atölyesi',
        subtitle: 'En zayıf konunu, kişisel çalışma kartı ve özel test ile işle.',
        icon: Icons.construction_rounded,
        route: '/ai-hub/weakness-workshop',
        color: AppTheme.successColor,
        heroTag: 'weakness-core',
        chip: 'Gelişim',
      ),
      // Birleşik: Analiz & Strateji
      _AiTool(
        key: analysisStrategyKey,
        title: 'Analiz & Strateji',
        subtitle: 'Deneme değerlendirme ve strateji danışmayı tek panelden yönet.',
        icon: Icons.dashboard_customize_rounded,
        route: '/ai-hub/analysis-strategy',
        color: Colors.amberAccent,
        heroTag: 'analysis-strategy-core',
        chip: 'Suite',
      ),
      _AiTool(
        key: motivationChatKey,
        title: 'Motivasyon Sohbeti',
        subtitle: 'Zorlandığında konuşabileceğin bir dost.',
        icon: Icons.forum_rounded,
        route: '/ai-hub/motivation-chat',
        color: Colors.pinkAccent,
        heroTag: 'motivation-core',
        chip: 'Destek',
      ),
    ];

    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Stack(
      children: [
        Scaffold(
          extendBodyBehindAppBar: false, // çakışmayı önle
          appBar: null,
          body: Stack(
            children: [
              _AnimatedBackground(glow: _glow),
              CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  SliverAppBar(
                    pinned: true,
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    toolbarHeight: kToolbarHeight,
                    title: const Text('TaktikAI Çekirdeği'),
                    actions: [
                      Padding(
                        padding: const EdgeInsets.only(right: 16.0),
                        child: Row(
                          children: [
                            const Icon(Icons.star_rounded, color: Colors.amber, size: 24),
                            const SizedBox(width: 8),
                            Text(
                              stars.toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    flexibleSpace: ClipRect(
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                        child: Container(
                          color: Colors.black.withOpacity(0.25),
                        ),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8), // azaltıldı
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _CoreVisual(glow: _glow),
                          const SizedBox(height: 24), // 40 -> 24: daha kompakt üst alan
                          Text(
                            'Yapay Zeka Araçları',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 12),
                        ],
                      ),
                    ),
                  ),
                  // Liste yerine 2 sütunlu, kompakt grid
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(16, 0, 16, bottomInset + 24),
                    sliver: SliverGrid(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        mainAxisExtent: 168, // daha az dikey kaydırma
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final tool = tools[index];
                          return _AiToolTile(
                            tool: tool,
                            onTap: () => _handleAiToolTap(tool),
                              isPremium: isPremium,
                          );
                        },
                        childCount: tools.length,
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(child: SizedBox(height: bottomInset + 8)),
                ],
              ),
            ],
          ),
        ),
        if (_isGenerating)
          Container(
            color: Colors.black.withOpacity(0.5),
            child: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                  SizedBox(height: 20),
                  Text(
                    'AI aracı hazırlanıyor...',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _CoreVisual extends StatelessWidget {
  const _CoreVisual({required this.glow});
  final Animation<double> glow;
  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 200, // 220 -> 200: daha az yer kaplasın
        height: 200,
        child: AnimatedBuilder(
          animation: glow,
          builder: (context, _) {
            final g = glow.value;
            return Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppTheme.secondaryColor.withOpacity(0.05 + g * 0.12),
                        AppTheme.primaryColor.withOpacity(0),
                      ],
                      stops: const [0.5, 1],
                    ),
                  ),
                ),
                Container(
                  width: 164 + g * 6,
                  height: 164 + g * 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.secondaryColor.withOpacity(.15 + g * .25),
                        blurRadius: 50 + g * 30,
                        spreadRadius: 8 + g * 8,
                      ),
                    ],
                    gradient: SweepGradient(
                      colors: [
                        AppTheme.secondaryColor.withOpacity(.4),
                        AppTheme.successColor.withOpacity(.35),
                        Colors.pinkAccent.withOpacity(.3),
                        AppTheme.secondaryColor.withOpacity(.4),
                      ],
                      stops: const [0, .33, .66, 1],
                      transform: GradientRotation(g * pi * 2),
                    ),
                  ),
                  child: Container(
                    margin: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          AppTheme.primaryColor.withOpacity(.9),
                          AppTheme.primaryColor.withOpacity(.6),
                        ],
                      ),
                      border: Border.all(color: AppTheme.secondaryColor.withOpacity(.2), width: 1.5),
                    ),
                    child: Icon(Icons.auto_awesome, size: 60 + g * 6, color: Colors.white.withOpacity(.92)),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// class _AiToolCard extends StatelessWidget {
//   const _AiToolCard({required this.tool, required this.onTap});
//   final _AiTool tool; final VoidCallback onTap;
//   @override
//   Widget build(BuildContext context) {
//     return Hero(
//       tag: tool.heroTag,
//       flightShuttleBuilder: (context, animation, direction, from, to) => FadeTransition(opacity: animation, child: to.widget),
//       child: Padding(
//         padding: const EdgeInsets.only(bottom: 16),
//         child: _FrostedCard(
//           key: tool.key,
//           onTap: onTap,
//           leading: Icon(tool.icon, size: 38, color: tool.color),
//           title: tool.title,
//           subtitle: tool.subtitle,
//           chip: tool.chip,
//           color: tool.color,
//         ),
//       ),
//     );
//   }
// }

class _AiTool {
  final GlobalKey key;
  final String title;
  final String subtitle;
  final IconData icon;
  final String route;
  final Color color;
  final String heroTag;
  final String chip;
  _AiTool({required this.key, required this.title, required this.subtitle, required this.icon, required this.route, required this.color, required this.heroTag, required this.chip});
}

class _AnimatedBackground extends StatelessWidget {
  const _AnimatedBackground({required this.glow});
  final Animation<double> glow;
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: glow,
      builder: (context, _) {
        final g = glow.value;
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppTheme.primaryColor,
                AppTheme.primaryColor.blend(Colors.black, .2 + g * .1),
                AppTheme.primaryColor.blend(AppTheme.secondaryColor.withOpacity(.2), .05 + g * .08),
              ],
            ),
          ),
          child: CustomPaint(
            painter: _ParticlePainter(progress: g),
          ),
        );
      },
    );
  }
}

extension on Color {
  Color blend(Color other, double t) => Color.lerp(this, other, t)!;
}

class _ParticlePainter extends CustomPainter {
  _ParticlePainter({required this.progress});
  final double progress;
  final int count = 22;
  @override
  void paint(Canvas canvas, Size size) {
    final rnd = Random(42); // deterministik
    for (var i = 0; i < count; i++) {
      final dx = rnd.nextDouble() * size.width;
      final dy = rnd.nextDouble() * size.height;
      final radius = (rnd.nextDouble() * 2 + 1) * (1 + (progress * .3));
      final paint = Paint()
        ..color = AppTheme.secondaryColor.withOpacity(.05 + rnd.nextDouble() * .08)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
      canvas.drawCircle(Offset(dx, dy), radius, paint);
    }
  }
  @override
  bool shouldRepaint(covariant _ParticlePainter oldDelegate) => oldDelegate.progress != progress;
}

// Yeni: Grid için kompakt, premium görünümlü frosted tile
class _AiToolTile extends StatelessWidget {
  const _AiToolTile({required this.tool, required this.onTap, required this.isPremium});
  final _AiTool tool;
  final VoidCallback onTap;
  final bool isPremium;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(20);

    return Hero(
      tag: tool.heroTag,
      flightShuttleBuilder: (context, animation, direction, from, to) => FadeTransition(opacity: animation, child: to.widget),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: tool.key,
          borderRadius: radius,
          onTap: onTap,
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: radius,
              boxShadow: [
                BoxShadow(color: tool.color.withOpacity(.18), blurRadius: 18, spreadRadius: -2, offset: const Offset(0, 10)),
              ],
            ),
            child: ClipRRect(
              borderRadius: radius,
              child: Stack(
                children: [
                  // Cam efekti
                  BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                    child: Container(),
                  ),
                  // Yarı saydam cam panel + gradient kenar vurgusu
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: radius,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white.withOpacity(.08),
                          Colors.white.withOpacity(.03),
                        ],
                      ),
                      border: Border.all(color: Colors.white.withOpacity(.12)),
                    ),
                  ),
                  // Dekoratif ışık lekesi
                  Positioned(
                    right: -24,
                    top: -24,
                    child: Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(colors: [tool.color.withOpacity(.28), Colors.transparent]),
                      ),
                    ),
                  ),
                  // İçerik
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _IconOrb(icon: tool.icon, color: tool.color),
                            const Spacer(),
                            if (isPremium)
                              _Badge(label: tool.chip, color: tool.color)
                            else
                              const _PremiumBadge(),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          tool.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          tool.subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.secondaryTextColor),
                        ),
                        const Spacer(),
                        Row(
                          children: [
                            Icon(Icons.flash_on_rounded, size: 16, color: tool.color.withOpacity(.9)),
                            const SizedBox(width: 6),
                            Text(
                              'Hızlı başla',
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: tool.color.withOpacity(.9),
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                            const Spacer(),
                            Icon(Icons.arrow_forward_rounded, size: 20, color: Colors.white.withOpacity(.9)),
                          ],
                        )
                      ],
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

class _PremiumBadge extends StatelessWidget {
  const _PremiumBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        gradient: LinearGradient(
          colors: [Colors.amber.withOpacity(.3), Colors.amber.withOpacity(.15)],
        ),
        border: Border.all(color: Colors.amber.withOpacity(.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.workspace_premium_rounded, color: Colors.amber, size: 14),
          const SizedBox(width: 4),
          Text(
            'Premium',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: Colors.amber,
                  letterSpacing: .2,
                ),
          ),
        ],
      ),
    );
  }
}

class _IconOrb extends StatelessWidget {
  const _IconOrb({required this.icon, required this.color});
  final IconData icon; final Color color;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color.withOpacity(.35), Colors.transparent]),
        border: Border.all(color: color.withOpacity(.35)),
      ),
      child: Icon(icon, size: 22, color: color),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color});
  final String label; final Color color;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        gradient: LinearGradient(colors: [color.withOpacity(.25), color.withOpacity(.12)]),
        border: Border.all(color: color.withOpacity(.35)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: .2,
            ),
      ),
    );
  }
}
