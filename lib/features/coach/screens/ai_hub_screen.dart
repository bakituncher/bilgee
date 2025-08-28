// lib/features/coach/screens/ai_hub_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:bilge_ai/core/theme/app_theme.dart'; // AppTheme import geri eklendi
import 'dart:math';
import 'dart:ui';
import 'dart:async';

// Öğretici için GlobalKey'ler
final GlobalKey strategicPlanningKey = GlobalKey();
final GlobalKey weaknessWorkshopKey = GlobalKey();
final GlobalKey motivationChatKey = GlobalKey();

class AiHubScreen extends StatefulWidget {
  const AiHubScreen({super.key});

  @override
  State<AiHubScreen> createState() => _AiHubScreenState();
}

class _AiHubScreenState extends State<AiHubScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  late final Animation<double> _glow;
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: const Duration(seconds: 5))..repeat(reverse: true);
    _glow = CurvedAnimation(parent: _pulse, curve: Curves.easeInOut);
    _searchCtrl.addListener(() {
      setState(() => _query = _searchCtrl.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _pulse.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tools = [
      _AiTool(
        key: strategicPlanningKey,
        title: 'Stratejik Planlama',
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
    ].where((t) => _query.isEmpty || t.title.toLowerCase().contains(_query) || t.subtitle.toLowerCase().contains(_query)).toList();

    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Scaffold(
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
                title: const Text('BilgeAI Çekirdeği'),
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
                      const SizedBox(height: 20),
                      _SearchBar(controller: _searchCtrl),
                      const SizedBox(height: 10),
                      _QuickActions(onSelect: (route) => context.go(route)),
                      const SizedBox(height: 20),
                      Text('Yapay Zeka Araçları', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 10),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, bottomInset + 32), // alt boşluk optimize
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final tool = tools[index];
                      return _AiToolCard(tool: tool, onTap: () => context.go(tool.route));
                    },
                    childCount: tools.length,
                  ),
                ),
              ),
              // ekstra boşluk küçültüldü
              SliverToBoxAdapter(child: SizedBox(height: bottomInset + 8)),
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
        width: 220,
        height: 220,
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
                  width: 180 + g * 6,
                  height: 180 + g * 6,
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
                    margin: const EdgeInsets.all(18),
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
                    child: Icon(Icons.auto_awesome, size: 64 + g * 6, color: Colors.white.withOpacity(.92)),
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

class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.controller});
  final TextEditingController controller;
  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        hintText: 'Araç ara... (örn: motivasyon)',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: controller.text.isNotEmpty
            ? IconButton(icon: const Icon(Icons.close), onPressed: () => controller.clear())
            : null,
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.onSelect});
  final void Function(String route) onSelect;
  @override
  Widget build(BuildContext context) {
    final actions = [
      ('Hafta Planı', Icons.calendar_month_rounded, '/ai-hub/strategic-planning'),
      ('Zayıflık', Icons.bug_report_rounded, '/ai-hub/weakness-workshop'),
      ('Motivasyon', Icons.psychology_rounded, '/ai-hub/motivation-chat'),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: actions.map((a) => Padding(
          padding: const EdgeInsets.only(right: 12),
          child: _GlassChip(
            label: a.$1,
            icon: a.$2,
            onTap: () => onSelect(a.$3),
          ),
        )).toList(),
      ),
    );
  }
}

class _GlassChip extends StatelessWidget {
  const _GlassChip({required this.label, required this.icon, required this.onTap});
  final String label; final IconData icon; final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(40),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(40),
          border: Border.all(color: Colors.white.withOpacity(.08)),
          gradient: LinearGradient(
            colors: [Colors.white.withOpacity(.08), Colors.white.withOpacity(.02)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(.3), blurRadius: 12, offset: const Offset(0, 6)),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [Icon(icon, size: 18, color: AppTheme.secondaryColor), const SizedBox(width: 6), Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),],
        ),
      ),
    );
  }
}

class _AiToolCard extends StatelessWidget {
  const _AiToolCard({required this.tool, required this.onTap});
  final _AiTool tool; final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: tool.heroTag,
      flightShuttleBuilder: (context, animation, direction, from, to) => FadeTransition(opacity: animation, child: to.widget),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: _FrostedCard(
          key: tool.key,
          onTap: onTap,
          leading: Icon(tool.icon, size: 38, color: tool.color),
          title: tool.title,
          subtitle: tool.subtitle,
          chip: tool.chip,
          color: tool.color,
        ),
      ),
    );
  }
}

class _FrostedCard extends StatelessWidget {
  const _FrostedCard({super.key, required this.leading, required this.title, required this.subtitle, required this.onTap, required this.chip, required this.color});
  final Widget leading; final String title; final String subtitle; final VoidCallback onTap; final String chip; final Color color;
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            colors: [
              Colors.white.withOpacity(.06),
              Colors.white.withOpacity(.02),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: Colors.white.withOpacity(.09)),
          boxShadow: [
            BoxShadow(color: color.withOpacity(.25), blurRadius: 22, spreadRadius: -4, offset: const Offset(0, 8)),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [color.withOpacity(.25), Colors.transparent]),
                ),
                padding: const EdgeInsets.all(4),
                child: leading,
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold))),
                        _Badge(label: chip, color: color),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(subtitle, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.secondaryTextColor)),
                    const SizedBox(height: 12),
                    Row(children: [
                      Icon(Icons.flash_on_rounded, size: 16, color: color.withOpacity(.8)),
                      const SizedBox(width: 4),
                      Text('AI hızlandırıcı aktif', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color.withOpacity(.8), fontWeight: FontWeight.w600)),
                      const Spacer(),
                      const Icon(Icons.arrow_forward_ios_rounded, size: 18, color: AppTheme.secondaryTextColor),
                    ])
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

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color});
  final String label; final Color color;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(colors: [color.withOpacity(.7), color.withOpacity(.4)]),
      ),
      child: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
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
