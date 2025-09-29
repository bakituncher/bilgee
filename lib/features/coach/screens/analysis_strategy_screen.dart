// lib/features/coach/screens/analysis_strategy_screen.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:taktik/core/theme/app_theme.dart';

class AnalysisStrategyScreen extends StatelessWidget {
  const AnalysisStrategyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final items = [
      _PanelItem(
        title: 'Deneme Değerlendirme',
        subtitle: 'Son denemeyi analiz et, güçlü/zayıf yönlerini gör ve toparlanma adımlarını al.',
        icon: Icons.flag_circle_rounded,
        color: Colors.amberAccent,
        onTap: () => context.go('/ai-hub/motivation-chat', extra: 'trial_review'),
      ),
      _PanelItem(
        title: 'Strateji Danışma',
        subtitle: 'Haftalık odak, ritim ve takip metrikleri için koçla hızlı görüşme.',
        icon: Icons.track_changes_rounded,
        color: Colors.lightBlueAccent,
        onTap: () => context.go('/ai-hub/motivation-chat', extra: 'strategy_consult'),
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analiz & Strateji'),
        backgroundColor: AppTheme.primaryColor,
        elevation: 0,
      ),
      backgroundColor: AppTheme.primaryColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 720;
              final crossAxisCount = isWide ? 2 : 1;
              final itemHeight = 150.0;
              return GridView.builder(
                physics: const BouncingScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  mainAxisExtent: itemHeight,
                ),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final it = items[index];
                  return _GlassTile(item: it);
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

class _PanelItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _PanelItem({required this.title, required this.subtitle, required this.icon, required this.color, required this.onTap});
}

class _GlassTile extends StatelessWidget {
  const _GlassTile({required this.item});
  final _PanelItem item;
  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(20);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: radius,
        onTap: item.onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: radius,
            boxShadow: [
              BoxShadow(color: item.color.withOpacity(.18), blurRadius: 18, spreadRadius: -2, offset: const Offset(0, 10)),
            ],
          ),
          child: ClipRRect(
            borderRadius: radius,
            child: Stack(
              children: [
                BackdropFilter(filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14), child: Container()),
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
                Positioned(
                  right: -22,
                  top: -22,
                  child: Container(
                    width: 92,
                    height: 92,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(colors: [item.color.withOpacity(.28), Colors.transparent]),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _IconOrb(icon: item.icon, color: item.color),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              gradient: LinearGradient(colors: [item.color.withOpacity(.7), item.color.withOpacity(.4)]),
                            ),
                            child: const Text('Hızlı', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(item.title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 6),
                      Text(
                        item.subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.secondaryTextColor),
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          Icon(Icons.flash_on_rounded, size: 16, color: item.color.withOpacity(.9)),
                          const SizedBox(width: 6),
                          Text('Başlat', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: item.color.withOpacity(.9), fontWeight: FontWeight.w700)),
                          const Spacer(),
                          Icon(Icons.arrow_forward_rounded, size: 20, color: Colors.white.withOpacity(.9)),
                        ],
                      )
                    ],
                  ),
                )
              ],
            ),
          ),
        ),
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

