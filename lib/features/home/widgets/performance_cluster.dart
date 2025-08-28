// lib/features/home/widgets/performance_cluster.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:bilge_ai/data/models/test_model.dart';
import 'package:bilge_ai/data/models/user_model.dart';
import 'package:bilge_ai/core/theme/app_theme.dart';
import 'package:go_router/go_router.dart';

class PerformanceCluster extends StatefulWidget {
  final List<TestModel> tests;
  final UserModel user;
  const PerformanceCluster({super.key, required this.tests, required this.user});
  @override
  State<PerformanceCluster> createState() => _PerformanceClusterState();
}

class _PerformanceClusterState extends State<PerformanceCluster> with SingleTickerProviderStateMixin {
  late AnimationController _sparkController;
  double? _prevAvg;

  @override
  void initState() {
    super.initState();
    _sparkController = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _sparkController.forward();
  }

  @override
  void didUpdateWidget(covariant PerformanceCluster oldWidget) {
    super.didUpdateWidget(oldWidget);
    final avg = _avgNet();
    if (_prevAvg != null && (avg - _prevAvg!).abs() > 0.05) {
      // yeniden parlatma için reverse-forward tetikleyebiliriz
      if (mounted) {
        _highlightKey.currentState?.flash();
      }
    }
    _prevAvg = avg;
    if (oldWidget.tests != widget.tests) {
      _sparkController.forward(from: 0); // yeni spark animasyonu
    }
  }

  @override
  void dispose() {
    _sparkController.dispose();
    super.dispose();
  }

  double _avgNet() => widget.tests.isNotEmpty ? (widget.user.totalNetSum / widget.tests.length) : 0.0;
  double _bestNet() => widget.tests.isEmpty ? 0.0 : widget.tests.map((t) => t.totalNet).reduce(max);
  int _streak() => widget.user.streak;
  int _trend() {
    final tests = widget.tests;
    if (tests.length < 3) return 0;
    final sorted = [...tests]..sort((a,b)=> a.date.compareTo(b.date));
    final last3 = sorted.skip(sorted.length-3).toList();
    final diff = last3.last.totalNet - last3.first.totalNet;
    if (diff > 0.1) return 1; if (diff < -0.1) return -1; return 0;
  }
  List<double> _lastValues(int n){
    final tests = widget.tests; if (tests.isEmpty) return [];
    final sorted = [...tests]..sort((a,b)=> a.date.compareTo(b.date));
    return sorted.skip(sorted.length - (sorted.length < n ? sorted.length : n)).map((e)=> e.totalNet).toList();
  }

  final GlobalKey<_AvgHighlightState> _highlightKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final avgNet = _avgNet();
    final bestNet = _bestNet();
    final streak = _streak();
    final trend = _trend();
    final lastValues = _lastValues(5);
    final compact = MediaQuery.of(context).size.height < 650;

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: AppTheme.lightSurfaceColor.withValues(alpha: .4)),
      ),
      child: InkWell(
        onTap: () => context.push('/home/stats'),
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, compact?12:18, 20, compact?12:18),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('Performans', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(width: 8),
                        if (bestNet>0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.secondaryColor.withValues(alpha: .15),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppTheme.secondaryColor.withValues(alpha: .5)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.emoji_events_rounded, size: 14, color: AppTheme.secondaryColor),
                                const SizedBox(width: 4),
                                Text(bestNet.toStringAsFixed(1), style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppTheme.secondaryColor, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                      ],
                    ),
                    SizedBox(height: compact?8:12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _AvgHighlight(key: _highlightKey, value: avgNet),
                        const SizedBox(width: 6),
                        Text('Ort. Net', style: Theme.of(context).textTheme.labelLarge?.copyWith(color: AppTheme.secondaryTextColor)),
                      ],
                    ),
                    SizedBox(height: compact?10:14),
                    SizedBox(
                      height: compact?40:48,
                      child: _AnimatedSparkline(values: lastValues, accent: AppTheme.secondaryColor, controller: _sparkController),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      lastValues.isEmpty ? 'Henüz deneme yok' : 'Son ${lastValues.length} deneme trendi',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppTheme.secondaryTextColor),
                    )
                  ],
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                flex: 2,
                child: Column(
                  children: [
                    _MiniStat(
                      icon: Icons.local_fire_department_rounded,
                      label: 'Seri',
                      value: streak.toString(),
                      color: Colors.orangeAccent,
                      onTap: () => context.push('/profile'),
                      compact: compact,
                    ),
                    SizedBox(height: compact?10:14),
                    _MiniStat(
                      icon: trend == 1
                          ? Icons.trending_up_rounded
                          : trend == -1
                              ? Icons.trending_down_rounded
                              : Icons.trending_flat_rounded,
                      label: 'Trend',
                      value: trend == 1
                          ? 'Yukarı'
                          : trend == -1
                              ? 'Aşağı'
                              : 'Düz',
                      color: trend == 1
                          ? Colors.greenAccent
                          : trend == -1
                              ? AppTheme.accentColor
                              : AppTheme.secondaryTextColor,
                      onTap: () => context.push('/home/stats'),
                      compact: compact,
                    ),
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}

class _AnimatedSparkline extends StatelessWidget {
  final List<double> values; final Color accent; final AnimationController controller;
  const _AnimatedSparkline({required this.values, required this.accent, required this.controller});
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, __) => CustomPaint(
        painter: _SparklinePainter(values: values, accent: accent, t: controller.value),
        size: Size.infinite,
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final List<double> values; final Color accent; final double t;
  _SparklinePainter({required this.values, required this.accent, required this.t});
  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    if (values.length == 1) {
      // Tek veri noktası: merkezde veya değer normalize edilerek göster, bölme hatasını önle
      final v = values.first;
      final y = size.height * 0.5; // tek nokta için ortalama konum; istenirse değerle ölçeklenebilir
      final x = size.width * (0.15 + 0.7 * t); // animasyonla içeri kayma
      final pointPaint = Paint()..color = accent..style = PaintingStyle.fill;
      // Arkaplan glow
      final glowPaint = Paint()..color = accent.withValues(alpha: 0.25)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
      canvas.drawCircle(Offset(x, y), 10 * t, glowPaint);
      canvas.drawCircle(Offset(x, y), 4 + 2 * t, pointPaint);
      final textPainter = TextPainter(
        text: TextSpan(text: v.toStringAsFixed(1), style: const TextStyle(fontSize: 11, color: Colors.white70)),
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(canvas, Offset(x + 6, y - 6));
      return;
    }
    final minV = values.reduce(min);
    final maxV = values.reduce(max);
    final uniform = (maxV - minV).abs() < 0.0001;
    final range = uniform ? 1.0 : (maxV - minV);
    final points = <Offset>[];
    for (int i=0;i<values.length;i++) {
      final denom = (values.length - 1).toDouble();
      final x = (i/denom) * size.width;
      double norm = uniform ? 0.5 : (values[i]-minV)/range;
      final y = size.height - norm * size.height;
      points.add(Offset(x,y));
    }
    final path = Path();
    for (int i=0;i<points.length;i++) {
      if (i==0) {
        path.moveTo(points[i].dx, points[i].dy);
      } else {
        path.lineTo(points[i].dx, points[i].dy);
      }
    }
    final metrics = path.computeMetrics().toList();
    final drawPath = Path();
    for (final m in metrics) {
      final len = m.length * t;
      drawPath.addPath(m.extractPath(0, len), Offset.zero);
    }
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..color = accent;
    canvas.drawPath(drawPath, stroke);
    if (t > 0.99) {
      final fillPath = Path.from(path)
        ..lineTo(size.width, size.height)
        ..lineTo(0, size.height)
        ..close();
      final fillPaint = Paint()
        ..shader = LinearGradient(
          colors: [accent.withValues(alpha: .35), accent.withValues(alpha: 0.0)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
      canvas.drawPath(fillPath, fillPaint);
      final pointPaint = Paint()..color = accent..style = PaintingStyle.fill;
      for (final p in points) { canvas.drawCircle(p, 3.2, pointPaint); }
    }
  }
  @override
  bool shouldRepaint(covariant _SparklinePainter old) => old.values != values || old.accent != accent || old.t != t;
}

class _MiniStat extends StatelessWidget {
  final IconData icon; final String label; final String value; final Color color; final VoidCallback onTap; final bool compact;
  const _MiniStat({required this.icon, required this.label, required this.value, required this.color, required this.onTap, required this.compact});
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: AppTheme.cardColor,
          border: Border.all(color: AppTheme.lightSurfaceColor.withValues(alpha: .45)),
        ),
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: compact?8:10),
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: color, size: compact?20:22),
                SizedBox(height: compact?4:6),
                Text(value, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600, fontSize: compact?16:null)),
                Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppTheme.secondaryTextColor)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AvgHighlight extends StatefulWidget {
  final double value; const _AvgHighlight({super.key, required this.value});
  @override
  State<_AvgHighlight> createState() => _AvgHighlightState();
}
class _AvgHighlightState extends State<_AvgHighlight> with SingleTickerProviderStateMixin {
  late AnimationController _c;
  late Animation<Color?> _color;
  double? _old;
  void flash(){
    _c.forward(from:0);
  }
  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _color = ColorTween(begin: AppTheme.textColor, end: AppTheme.secondaryColor).animate(CurvedAnimation(parent: _c, curve: Curves.easeOut));
  }
  @override
  void didUpdateWidget(covariant _AvgHighlight oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_old != null && (widget.value - _old!).abs() > 0.05) {
      flash();
    }
    _old = widget.value;
  }
  @override
  void dispose(){ _c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _color,
      builder: (_, __) => Text(widget.value.toStringAsFixed(1),
          style: Theme.of(context).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w700, height: 0.95, color: _color.value)),
    );
  }
}
