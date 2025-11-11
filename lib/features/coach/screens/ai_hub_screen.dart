import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:taktik/core/theme/app_theme.dart';
import 'package:taktik/data/providers/premium_provider.dart';
import 'dart:math';
import 'dart:ui';

// Öğretici için GlobalKey'ler
final GlobalKey strategicPlanningKey = GlobalKey();
final GlobalKey weaknessWorkshopKey = GlobalKey();
final GlobalKey motivationChatKey = GlobalKey();
final GlobalKey analysisStrategyKey = GlobalKey();

class AiHubScreen extends ConsumerStatefulWidget {
  const AiHubScreen({super.key});

  @override
  ConsumerState<AiHubScreen> createState() => _AiHubScreenState();
}

class _AiHubScreenState extends ConsumerState<AiHubScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  late final Animation<double> _glow;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: const Duration(seconds: 5))..forward();
    _glow = CurvedAnimation(parent: _pulse, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isPremium = ref.watch(premiumStatusProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final tools = [
      _AiTool(
        key: strategicPlanningKey,
        title: 'Haftalık Planlama',
        subtitle: 'Uzun vadeli zafer stratejini ve haftalık planını oluştur.',
        icon: Icons.insights_rounded,
        route: '/ai-hub/strategic-planning',
        color: theme.colorScheme.secondary,
        heroTag: 'strategic-core',
        chip: 'Odak',
        marketingTitle: 'Kişisel Başarı Yol Haritanız',
        marketingSubtitle: 'Yapay zeka, sınav hedeflerinize ve takviminize göre size özel, dinamik bir haftalık çalışma planı oluşturur. Ne zaman ne çalışacağınızı öğrenin.',
      ),
      _AiTool(
        key: weaknessWorkshopKey,
        title: 'Cevher Atölyesi',
        subtitle: 'En zayıf konunu, kişisel çalışma kartı ve özel test ile işle.',
        icon: Icons.construction_rounded,
        route: '/ai-hub/weakness-workshop',
        color: theme.colorScheme.secondary,
        heroTag: 'weakness-core',
        chip: 'Gelişim',
        marketingTitle: 'Zayıf Noktalarınızı Güce Dönüştürün',
        marketingSubtitle: 'En çok zorlandığınız konuları tespit edin ve AI destekli özel çalışma materyalleri ile zayıf yanlarınızı güçlü yanlara çevirin.',
      ),
      _AiTool(
        key: analysisStrategyKey,
        title: 'Analiz & Strateji',
        subtitle: 'Deneme değerlendirme ve strateji danışmanı tek panelden yönet.',
        icon: Icons.dashboard_customize_rounded,
        route: '/ai-hub/analysis-strategy',
        color: Colors.amberAccent,
        heroTag: 'analysis-strategy-core',
        chip: 'Suite',
        marketingTitle: 'Akıllı Deneme Analizi',
        marketingSubtitle: 'Deneme sınavlarınızı yapay zeka ile derinlemesine analiz edin. Hangi konulara odaklanmanız gerektiğini öğrenin, her zaman zirvede kalın.',
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
        marketingTitle: 'Sınav Sürecindeki En Yakın Dostunuz',
        marketingSubtitle: 'Stresli veya motivasyonsuz hissettiğinizde, yapay zeka koçunuzla sohbet edin. Size özel tavsiyeler ve destekle mental olarak her zaman daha iyi olacağınızı öğrenin.',
      ),
    ];

    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      extendBodyBehindAppBar: false,
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
                title: Text(
                  'TaktikAI Çekirdeği',
                  style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.w700),
                ),
                flexibleSpace: ClipRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: isDark
                              ? [
                                  theme.scaffoldBackgroundColor.withOpacity(0.9),
                                  theme.scaffoldBackgroundColor.withOpacity(0.7),
                                ]
                              : [
                                  theme.scaffoldBackgroundColor.withOpacity(0.9),
                                  theme.scaffoldBackgroundColor.withOpacity(0.75),
                                ],
                        ),
                        border: const Border(
                          bottom: BorderSide(
                            color: Colors.white10,
                            width: 0.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      _CoreVisual(glow: _glow),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Text(
                            'Yapay Zeka Araçları',
                            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          if (!isPremium) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    theme.colorScheme.primary.withOpacity(0.15),
                                    theme.colorScheme.secondary.withOpacity(0.15),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: theme.colorScheme.primary.withOpacity(0.3),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.workspace_premium_rounded,
                                    size: 16,
                                    color: theme.colorScheme.primary,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Premium Gerektirir',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: theme.colorScheme.primary,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    mainAxisExtent: 168,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final tool = tools[index];
                      return _AiToolTile(
                        tool: tool,
                        onTap: () {
                          if (isPremium) {
                            context.go(tool.route);
                          } else {
                            context.go(
                              '/ai-hub/offer',
                              extra: {
                                'title': tool.title,
                                'subtitle': tool.subtitle,
                                'icon': tool.icon,
                                'color': tool.color,
                                'heroTag': tool.heroTag,
                                'marketingTitle': tool.marketingTitle,
                                'marketingSubtitle': tool.marketingSubtitle,
                                'redirectRoute': tool.route,
                              },
                            );
                          }
                        },
                      );
                    },
                    childCount: tools.length,
                  ),
                ),
              ),

              // Sorumluluk Reddi - Alt kısımda şık yerleşim
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(20, 8, 20, bottomInset + 16),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: LinearGradient(
                        colors: [
                          theme.colorScheme.primary.withOpacity(0.06),
                          theme.colorScheme.secondary.withOpacity(0.04),
                        ],
                      ),
                      border: Border.all(
                        color: theme.colorScheme.primary.withOpacity(0.15),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.info_outline_rounded,
                            color: theme.colorScheme.primary,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Sorumluluk Reddi',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: theme.colorScheme.primary,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'TaktikAI, bir yapay zeka asistanıdır. Psikolojik danışmanlık hizmeti sunmaz.',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  height: 1.4,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
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
}

class _CoreVisual extends StatelessWidget {
  const _CoreVisual({required this.glow});
  final Animation<double> glow;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 140,
        height: 140,
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
                        Theme.of(context).colorScheme.primary.withOpacity(0.05 + g * 0.12),
                        Theme.of(context).scaffoldBackgroundColor.withOpacity(0),
                      ],
                      stops: const [0.5, 1],
                    ),
                  ),
                ),
                Container(
                  width: 114 + g * 4,
                  height: 114 + g * 4,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Theme.of(context).colorScheme.primary.withOpacity(.12 + g * .18),
                        blurRadius: 30 + g * 20,
                        spreadRadius: 5 + g * 5,
                      ),
                    ],
                    gradient: SweepGradient(
                      colors: [
                        Theme.of(context).colorScheme.primary.withOpacity(.4),
                        AppTheme.successBrandColor.withOpacity(.35),
                        Colors.pinkAccent.withOpacity(.3),
                        Theme.of(context).colorScheme.primary.withOpacity(.4),
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
                          Theme.of(context).cardColor.withOpacity(.9),
                          Theme.of(context).cardColor.withOpacity(.6),
                        ],
                      ),
                      border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(.2), width: 1.5),
                    ),
                    child: Icon(
                      Icons.auto_awesome,
                      size: 42 + g * 4,
                      color: Theme.of(context).colorScheme.primary.withOpacity(.92),
                    ),
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

class _AiTool {
  final GlobalKey key;
  final String title;
  final String subtitle;
  final IconData icon;
  final String route;
  final Color color;
  final String heroTag;
  final String chip;
  final String marketingTitle;
  final String marketingSubtitle;

  _AiTool({
    required this.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.route,
    required this.color,
    required this.heroTag,
    required this.chip,
    required this.marketingTitle,
    required this.marketingSubtitle,
  });
}

class _AnimatedBackground extends StatelessWidget {
  const _AnimatedBackground({required this.glow});
  final Animation<double> glow;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AnimatedBuilder(
      animation: glow,
      builder: (context, _) {
        final g = glow.value;
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [
                      Theme.of(context).scaffoldBackgroundColor,
                      Theme.of(context).scaffoldBackgroundColor.blend(Theme.of(context).colorScheme.primary.withOpacity(.15), .08 + g * .1),
                      Theme.of(context).scaffoldBackgroundColor.blend(Theme.of(context).colorScheme.secondary.withOpacity(.12), .05 + g * .08),
                    ]
                  : [
                      Theme.of(context).scaffoldBackgroundColor,
                      Theme.of(context).scaffoldBackgroundColor.blend(Theme.of(context).colorScheme.primary.withOpacity(.15), .03 + g * .05),
                      Theme.of(context).scaffoldBackgroundColor.blend(Theme.of(context).colorScheme.primary.withOpacity(.1), .02 + g * .04),
                    ],
            ),
          ),
          child: CustomPaint(
            painter: _ParticlePainter(progress: g, isDark: isDark),
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
  _ParticlePainter({required this.progress, required this.isDark});
  final double progress;
  final bool isDark;
  final int count = 22;

  @override
  void paint(Canvas canvas, Size size) {
    final rnd = Random(42);
    final baseOpacity = isDark ? 0.05 : 0.03;
    final variableOpacity = isDark ? 0.08 : 0.05;
    for (var i = 0; i < count; i++) {
      final dx = rnd.nextDouble() * size.width;
      final dy = rnd.nextDouble() * size.height;
      final radius = (rnd.nextDouble() * 2 + 1) * (1 + (progress * .3));
      final paint = Paint()
        ..color = AppTheme.secondaryBrandColor.withOpacity(baseOpacity + rnd.nextDouble() * variableOpacity)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
      canvas.drawCircle(Offset(dx, dy), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.isDark != isDark;
}

class _AiToolTile extends StatelessWidget {
  const _AiToolTile({required this.tool, required this.onTap});
  final _AiTool tool;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
                  BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                    child: Container(),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: radius,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: isDark
                            ? [
                                Theme.of(context).colorScheme.surfaceContainer.withOpacity(.85),
                                Theme.of(context).cardColor.withOpacity(.9),
                              ]
                            : [
                                Theme.of(context).cardColor.withOpacity(.98),
                                Theme.of(context).cardColor.withOpacity(.92),
                              ],
                      ),
                      border: Border.all(
                        color: isDark
                            ? tool.color.withOpacity(.4)
                            : Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(.5),
                        width: 1.5,
                      ),
                    ),
                  ),
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
                            _Badge(label: tool.chip, color: tool.color),
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
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
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
                            Icon(Icons.arrow_forward_rounded, size: 20, color: Theme.of(context).colorScheme.onSurface.withOpacity(.9)),
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

class _IconOrb extends StatelessWidget {
  const _IconOrb({required this.icon, required this.color});
  final IconData icon;
  final Color color;

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
  final String label;
  final Color color;

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
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
      ),
    );
  }
}

