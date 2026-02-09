import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:taktik/core/navigation/app_routes.dart';
import 'package:taktik/shared/widgets/pro_badge.dart';

enum LimitFeature {
  questionSolver,
  contentGenerator,
}

/// Günlük limit dolduğunda gösterilen dialog
class DailyLimitDialog extends StatefulWidget {
  final LimitFeature feature;

  const DailyLimitDialog({
    super.key,
    this.feature = LimitFeature.questionSolver,
  });

  @override
  State<DailyLimitDialog> createState() => _DailyLimitDialogState();
}

class _DailyLimitDialogState extends State<DailyLimitDialog> with SingleTickerProviderStateMixin {
  late AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  String get _title {
    switch (widget.feature) {
      case LimitFeature.questionSolver:
        return 'Günlük Limit Doldu';
      case LimitFeature.contentGenerator:
        return 'Günlük Limit Doldu';
    }
  }

  String get _description {
    switch (widget.feature) {
      case LimitFeature.questionSolver:
        return 'Günlük 3 soru çözüm hakkınızı kullandınız.';
      case LimitFeature.contentGenerator:
        return 'Günlük 3 içerik üretim hakkınızı kullandınız.';
    }
  }

  String get _proDescription {
    switch (widget.feature) {
      case LimitFeature.questionSolver:
        return 'Tüm sorularını çözdür, sınırı unut!';
      case LimitFeature.contentGenerator:
        return 'Sınırsız içerik üret, öğrenmeye devam et!';
    }
  }

  IconData get _icon {
    switch (widget.feature) {
      case LimitFeature.questionSolver:
        return Icons.camera_alt_rounded;
      case LimitFeature.contentGenerator:
        return Icons.bolt_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Üst İkon - Simetrik ve Merkezi
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFFF0F7FF), // Çok açık mavi
                    Color(0xFFE3F2FD), // Açık mavi
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Color(0xFF1565C0),
                  width: 2,
                ),
              ),
              child: Icon(
                _icon,
                size: 48,
                color: Color(0xFF1565C0), // Koyu mavi
              ),
            ),
            const SizedBox(height: 24),

            // Başlık - Merkezi ve Kalın
            Text(
              _title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 12),

            // Açıklama - Merkezi
            Text(
              _description,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),

            // Pro Vurgu Kutusu - Simetrik
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFFF0F7FF), // Çok açık mavi
                    Color(0xFFE3F2FD), // Açık mavi
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Color(0xFF1565C0), // Koyu mavi - Tutarlı ton
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Color(0xFF1565C0).withValues(alpha: 0.15),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const ProBadge(
                        fontSize: 10,
                        horizontalPadding: 8,
                        verticalPadding: 4,
                        borderRadius: 8,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'ile Sınırsız',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                          color: Color(0xFF0D47A1), // Çok koyu mavi
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _proDescription,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Butonlar - Simetrik
            Column(
              children: [
                // Premium Butonu
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFF1565C0),
                          Color(0xFF0D47A1),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Color(0xFF1565C0).withValues(alpha: 0.4),
                          blurRadius: 12,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Stack(
                        children: [
                          // Shimmer Efekti
                          AnimatedBuilder(
                            animation: _shimmerController,
                            builder: (context, child) {
                              const double startPoint = 0.7;
                              final double value = _shimmerController.value;

                              if (value < startPoint) {
                                return const SizedBox();
                              }

                              final double normalizedValue = (value - startPoint) / (1.0 - startPoint);

                              return Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.transparent,
                                      Colors.white.withValues(alpha: 0.3),
                                      Colors.transparent,
                                    ],
                                    stops: const [0.0, 0.5, 1.0],
                                    begin: Alignment(-2.5 + (normalizedValue * 5), -0.5),
                                    end: Alignment(-1.5 + (normalizedValue * 5), 0.5),
                                  ),
                                ),
                              );
                            },
                          ),
                          // Tıklanabilir Alan
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () {
                                Navigator.pop(context);
                                context.push(AppRoutes.premium);
                              },
                              borderRadius: BorderRadius.circular(14),
                              child: Center(
                                child: Text(
                                  'Pro\'ya Geç',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // İptal Butonu
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      'Daha Sonra',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
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

