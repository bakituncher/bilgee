// lib/features/stats/widgets/key_stats_grid.dart
import 'package:flutter/material.dart';
import 'package:bilge_ai/core/theme/app_theme.dart';
import 'package:bilge_ai/features/stats/logic/stats_analysis.dart';

class KeyStatsGrid extends StatelessWidget {
  final StatsAnalysis analysis;
  const KeyStatsGrid({required this.analysis, super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final isNarrow = width < 360; // çok küçük cihaz
        final crossAxisCount = isNarrow ? 1 : 2;
        const crossAxisSpacing = 12.0;
        // Hücre genişliği (GridView iç hesaplama mantığına paralel)
        final cellWidth = (width - (crossAxisCount - 1) * crossAxisSpacing) / crossAxisCount;
        // İçerik yüksekliğini yeterli olacak şekilde hedefle (etiket + boşluk + değer satırı)
        final desiredHeight = isNarrow ? 132.0 : 118.0; // önceki oranlara göre daha yüksek
        final aspect = cellWidth / desiredHeight; // childAspectRatio = width/height
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
                return _StatCard(label: 'Savaşçı Skoru', value: analysis.warriorScore.toStringAsFixed(1), icon: Icons.shield_rounded, color: AppTheme.secondaryColor, tooltip: "Genel net, doğruluk ve istikrarı birleştiren özel puanın.");
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

class _StatCard extends StatelessWidget {
  final String label, value, tooltip;
  final IconData icon;
  final Color color;
  const _StatCard({required this.label, required this.value, required this.icon, required this.color, required this.tooltip});

  void _showInfoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 10),
            Expanded(child: Text(label, maxLines: 2, overflow: TextOverflow.ellipsis)),
          ],
        ),
        content: Text(tooltip, style: const TextStyle(color: AppTheme.secondaryTextColor, height: 1.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("Anladım"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppTheme.secondaryTextColor, fontWeight: FontWeight.bold)),
                ),
                InkWell(
                  onTap: () => _showInfoDialog(context),
                  child: const Padding(
                    padding: EdgeInsets.all(2.0),
                    child: Icon(Icons.info_outline, color: AppTheme.secondaryTextColor, size: 18),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Spacer yerine sabit boşluk + Flexible satır, böylece dikey alan daralınca overflow olmaz
            Expanded(
              child: Align(
                alignment: Alignment.bottomLeft,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: FittedBox(
                        alignment: Alignment.centerLeft,
                        fit: BoxFit.scaleDown,
                        child: Text(
                          value,
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(icon, color: color, size: 24),
                  ],
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}