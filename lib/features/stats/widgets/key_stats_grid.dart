// lib/features/stats/widgets/key_stats_grid.dart
import 'package:flutter/material.dart';
import 'package:taktik/core/theme/app_theme.dart';
import 'package:taktik/features/stats/logic/stats_analysis.dart';

class KeyStatsGrid extends StatelessWidget {
  final StatsAnalysis analysis;
  const KeyStatsGrid({required this.analysis, super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final isNarrow = width < 360;
        final crossAxisCount = isNarrow ? 1 : 2;
        const crossAxisSpacing = 12.0;
        final cellWidth = (width - (crossAxisCount - 1) * crossAxisSpacing) / crossAxisCount;
        final desiredHeight = isNarrow ? 115.0 : 105.0;
        final aspect = cellWidth / desiredHeight;
        return GridView.builder(
          itemCount: 4,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 12,
            crossAxisSpacing: crossAxisSpacing,
            childAspectRatio: aspect,
          ),
          itemBuilder: (context, index) {
            switch (index) {
              case 0:
                return _StatCard(label: 'Savaşçı Skoru', value: analysis.warriorScore.toStringAsFixed(1), icon: Icons.shield_rounded, color: Theme.of(context).colorScheme.secondary, tooltip: "Genel net, doğruluk ve istikrarı birleştiren özel puanın.");
              case 1:
                return _StatCard(label: 'İsabet Oranı', value: '%${analysis.accuracy.toStringAsFixed(1)}', icon: Icons.gps_fixed_rounded, color: Colors.green, tooltip: "Cevapladığın soruların yüzde kaçı doğru?");
              case 2:
                return _StatCard(label: 'Tutarlılık Mührü', value: '%${analysis.consistency.toStringAsFixed(1)}', icon: Icons.sync_alt_rounded, color: Colors.blueAccent, tooltip: "Netlerin ne kadar istikrarlı? %100, tüm netlerin aynı demek.");
              default:
                return _StatCard(label: 'Yükseliş Hızı', value: analysis.trend.toStringAsFixed(2), icon: analysis.trend > 0.1 ? Icons.trending_up_rounded : (analysis.trend < -0.1 ? Icons.trending_down_rounded : Icons.trending_flat_rounded), color: analysis.trend > 0.1 ? Colors.teal : (analysis.trend < -0.1 ? Colors.redAccent : Colors.grey), tooltip: "Deneme başına net artış/azalış hızın.");
            }
          },
        );
      },
    );
  }
}

class _StatCard extends StatefulWidget {
  final String label, value, tooltip;
  final IconData icon;
  final Color color;
  const _StatCard({required this.label, required this.value, required this.icon, required this.color, required this.tooltip});

  @override
  State<_StatCard> createState() => _StatCardState();
}

class _StatCardState extends State<_StatCard> with SingleTickerProviderStateMixin {
  bool _isPressed = false;

  void _showInfoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: widget.color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(widget.icon, color: widget.color, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(widget.label, maxLines: 2, overflow: TextOverflow.ellipsis)),
          ],
        ),
        content: Text(widget.tooltip, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, height: 1.6, fontSize: 15)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            style: TextButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.secondary.withOpacity(0.2),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text("Anladım", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                widget.color.withOpacity(0.16),
                widget.color.withOpacity(0.06),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: widget.color.withOpacity(0.32),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: widget.color.withOpacity(0.18),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: Padding(
              padding: const EdgeInsets.all(14.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          widget.label,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.bold,
                            fontSize: 11.5,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                      InkWell(
                        onTap: () => _showInfoDialog(context),
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: widget.color.withOpacity(0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.info_outline, color: widget.color, size: 14),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: FittedBox(
                          alignment: Alignment.centerLeft,
                          fit: BoxFit.scaleDown,
                          child: Text(
                            widget.value,
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: widget.color.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(widget.icon, color: widget.color, size: 18),
                      ),
                    ],
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