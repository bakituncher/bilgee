// lib/features/stats/widgets/swipeable_performance_card.dart
import 'package:flutter/material.dart';
import 'package:taktik/core/theme/app_theme.dart';
import 'package:taktik/features/stats/models/chart_data.dart';
import 'package:taktik/features/stats/widgets/mini_performance_chart.dart' show MiniPerformanceChart;

/// Kaydırılabilir şık performans kartı - Performansa göre dinamik renkler
class SwipeablePerformanceCard extends StatelessWidget {
  final ChartData data;
  final bool isDark;

  const SwipeablePerformanceCard({
    super.key,
    required this.data,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final trend = data.performanceTrend;
    final avgNet = data.averageNet;

    // Trend durumuna göre renk belirle (yüzdelik değişime göre)
    Color trendColor;
    Color gradientStart;
    Color gradientEnd;
    IconData trendIcon;
    String trendText;

    if (trend > 8) {
      trendColor = const Color(0xFF10B981); // Yeşil - Harika yükseliş
      gradientStart = const Color(0xFF10B981);
      gradientEnd = const Color(0xFF059669);
      trendIcon = Icons.trending_up_rounded;
      trendText = 'Harika Yükseliş!';
    } else if (trend > 3) {
      trendColor = const Color(0xFF3B82F6); // Mavi - İyi yükseliş
      gradientStart = const Color(0xFF3B82F6);
      gradientEnd = const Color(0xFF2563EB);
      trendIcon = Icons.trending_up_rounded;
      trendText = 'İyi Gidiyor';
    } else if (trend >= -3) {
      trendColor = AppTheme.goldBrandColor; // Sarı - Stabil
      gradientStart = AppTheme.goldBrandColor;
      gradientEnd = const Color(0xFFD97706);
      trendIcon = Icons.trending_flat_rounded;
      trendText = 'Stabil';
    } else if (trend >= -8) {
      trendColor = const Color(0xFFF59E0B); // Turuncu - Hafif düşüş
      gradientStart = const Color(0xFFF59E0B);
      gradientEnd = const Color(0xFFD97706);
      trendIcon = Icons.trending_down_rounded;
      trendText = 'Biraz Dikkat';
    } else {
      trendColor = const Color(0xFFEF4444); // Kırmızı - Düşüş
      gradientStart = const Color(0xFFEF4444);
      gradientEnd = const Color(0xFFDC2626);
      trendIcon = Icons.trending_down_rounded;
      trendText = 'Odaklan';
    }

    return Container(
      width: MediaQuery.of(context).size.width * 0.80,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            gradientStart.withOpacity(0.15),
            gradientEnd.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: trendColor.withOpacity(0.12),
            blurRadius: 12,
            offset: const Offset(0, 4),
            spreadRadius: -2,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            // Arka plan deseni - daha küçük
            Positioned(
              right: -20,
              top: -20,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: trendColor.withOpacity(0.04),
                ),
              ),
            ),
            Positioned(
              left: -15,
              bottom: -15,
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: trendColor.withOpacity(0.04),
                ),
              ),
            ),

            // İçerik
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: (isDark ? const Color(0xFF1E293B) : Colors.white).withOpacity(0.95),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Başlık ve durum
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [gradientStart, gradientEnd],
                          ),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: trendColor.withOpacity(0.25),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Icon(data.icon, color: Colors.white, size: 16),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              data.title,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                                letterSpacing: -0.5,
                              ),
                            ),
                            Text(
                              data.subtitle,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? Colors.white.withOpacity(0.5)
                                    : Colors.black.withOpacity(0.45),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: trendColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: trendColor.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(trendIcon, color: trendColor, size: 12),
                            const SizedBox(width: 3),
                            Text(
                              trendText,
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: trendColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Ortalama net bilgisi
                  Row(
                    children: [
                      Text(
                        'Ort. Net: ',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? Colors.white.withOpacity(0.6)
                              : Colors.black.withOpacity(0.5),
                        ),
                      ),
                      Text(
                        avgNet.toStringAsFixed(1),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: trendColor,
                          height: 1,
                        ),
                      ),
                      const Spacer(),
                      if (trend.abs() > 0.5)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: trendColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            '${trend > 0 ? '+' : ''}${trend.toStringAsFixed(1)}',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: trendColor,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Mini grafik
                  Expanded(
                    child: MiniPerformanceChart(
                      tests: data.tests,
                      color: trendColor,
                      isDark: isDark,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

