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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Üst İkon - Kompakt
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFFF0F7FF),
                    Color(0xFFE3F2FD),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Color(0xFF1565C0),
                  width: 1.5,
                ),
              ),
              child: Icon(
                _icon,
                size: 32,
                color: Color(0xFF1565C0),
              ),
            ),
            const SizedBox(height: 12),

            // Başlık - Kompakt
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                _title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                  letterSpacing: -0.3,
                ),
              ),
            ),
            const SizedBox(height: 6),

            // Açıklama - Kompakt
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  _description,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.2,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Pro Vurgu Kutusu - Kompakt
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFFF0F7FF),
                    Color(0xFFE3F2FD),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Color(0xFF1565C0),
                  width: 1.5,
                ),
              ),
              child: Column(
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const ProBadge(
                          fontSize: 8,
                          horizontalPadding: 6,
                          verticalPadding: 2,
                          borderRadius: 5,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'ile Sınırsız',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: Color(0xFF0D47A1),
                            letterSpacing: 0.1,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 3),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        _proDescription,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          color: theme.colorScheme.onSurfaceVariant,
                          height: 1.2,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Ücretsiz vs Pro Karşılaştırma - Scrollable
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.32,
              ),
              child: SingleChildScrollView(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      // Header
                      Container(
                        decoration: BoxDecoration(
                          color: Color(0xFFF5F5F5),
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: Text(
                                "Özellikler",
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF666666),
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                "Ücretsiz",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF666666),
                                ),
                              ),
                            ),
                            Expanded(
                              child: Center(
                                child: ProBadge(
                                  fontSize: 8,
                                  horizontalPadding: 5,
                                  verticalPadding: 2,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Comparison Rows - Feature'a göre farklı
                      if (widget.feature == LimitFeature.questionSolver) ...[
                        _buildComparisonRow(
                          theme: theme,
                          feature: "Soru Çözücü",
                          free: "3 soru/gün",
                          pro: "Sınırsız",
                        ),
                        _buildComparisonRow(
                          theme: theme,
                          feature: "Not Defteri",
                          free: "3 hak/gün",
                          pro: "Sınırsız",
                        ),
                        _buildComparisonRow(
                          theme: theme,
                          feature: "Haftalık Plan",
                          free: false,
                          pro: true,
                        ),
                        _buildComparisonRow(
                          theme: theme,
                          feature: "Zihin Haritaları",
                          free: false,
                          pro: true,
                        ),
                        _buildComparisonRow(
                          theme: theme,
                          feature: "Etüt Odası",
                          free: false,
                          pro: true,
                        ),
                        _buildComparisonRow(
                          theme: theme,
                          feature: "Koçun Taktik Tavşan",
                          free: false,
                          pro: true,
                        ),
                        _buildComparisonRow(
                          theme: theme,
                          feature: "Reklamlar",
                          free: "Var",
                          pro: "Yok",
                          isLast: true,
                        ),
                      ] else ...[
                        _buildComparisonRow(
                          theme: theme,
                          feature: "Not Defteri",
                          free: "3 hak/gün",
                          pro: "Sınırsız",
                        ),
                        _buildComparisonRow(
                          theme: theme,
                          feature: "Soru Çözücü",
                          free: "3 soru/gün",
                          pro: "Sınırsız",
                        ),
                        _buildComparisonRow(
                          theme: theme,
                          feature: "Haftalık Plan",
                          free: false,
                          pro: true,
                        ),
                        _buildComparisonRow(
                          theme: theme,
                          feature: "Zihin Haritaları",
                          free: false,
                          pro: true,
                        ),
                        _buildComparisonRow(
                          theme: theme,
                          feature: "Etüt Odası",
                          free: false,
                          pro: true,
                        ),
                        _buildComparisonRow(
                          theme: theme,
                          feature: "Koçun Taktik Tavşan",
                          free: false,
                          pro: true,
                        ),
                        _buildComparisonRow(
                          theme: theme,
                          feature: "Reklamlar",
                          free: "Var",
                          pro: "Yok",
                          isLast: true,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Butonlar - Simetrik ve Sabit
            Column(
              children: [
                // Premium Butonu
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
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
                      borderRadius: BorderRadius.circular(12),
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
                              borderRadius: BorderRadius.circular(12),
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
                const SizedBox(height: 8),
                // İptal Butonu
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
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

  Widget _buildComparisonRow({
    required ThemeData theme,
    required String feature,
    required dynamic free,
    required dynamic pro,
    bool isLast = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 10),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // Feature name
          Expanded(
            flex: 2,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                feature,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
          ),
          // Free
          Expanded(
            child: _buildCell(free, theme, isPro: false),
          ),
          // Pro
          Expanded(
            child: _buildCell(pro, theme, isPro: true),
          ),
        ],
      ),
    );
  }

  Widget _buildCell(dynamic value, ThemeData theme, {required bool isPro}) {
    if (value is bool) {
      if (value) {
        // Checkmark for true
        return Icon(
          Icons.check_circle_rounded,
          color: isPro ? Color(0xFF1565C0) : Color(0xFF4CAF50),
          size: 16,
        );
      } else {
        // X for false
        return Icon(
          Icons.remove_circle_outline_rounded,
          color: Colors.grey.withValues(alpha: 0.4),
          size: 16,
        );
      }
    } else if (value is String) {
      // Text value
      return FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          value,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isPro ? FontWeight.w700 : FontWeight.normal,
            color: isPro ? Color(0xFF1565C0) : theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }
}




