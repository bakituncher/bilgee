// lib/features/home/screens/test_detail_screen.dart
import 'package:taktik/data/models/test_model.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:taktik/shared/widgets/custom_back_button.dart';
class TestDetailScreen extends StatelessWidget {
  final TestModel test;
  const TestDetailScreen({super.key, required this.test});
  static const Color _colDeepBlue = Color(0xFF2E3192);
  static const Color _colCyan = Color(0xFF1BFFFF);
  MapEntry<String, double> _findWeakestSubject() {
    double minNet = double.maxFinite;
    String weakestSubject = '';
    test.scores.forEach((subject, scores) {
      final net = scores['dogru']! - (scores['yanlis']! * test.penaltyCoefficient);
      if (net < minNet) {
        minNet = net;
        weakestSubject = subject;
      }
    });
    return MapEntry(weakestSubject, minNet);
  }
  MapEntry<String, double> _findStrongestSubject() {
    double maxNet = double.negativeInfinity;
    String strongestSubject = '';
    test.scores.forEach((subject, scores) {
      final net = scores['dogru']! - (scores['yanlis']! * test.penaltyCoefficient);
      if (net > maxNet) {
        maxNet = net;
        strongestSubject = subject;
      }
    });
    return MapEntry(strongestSubject, maxNet);
  }
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final pieChartSections = _createPieChartSections(context);
    final weakestSubjectEntry = _findWeakestSubject();
    final strongestSubjectEntry = _findStrongestSubject();
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        leading: const CustomBackButton(),
        title: Text("Detaylı Analiz", style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800, fontSize: 17, letterSpacing: 0.5)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: ClipRect(
          child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10), child: Container(color: Colors.transparent)),
        ),
      ),
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0, -0.8),
                radius: 1.6,
                colors: isDark ? [_colDeepBlue.withOpacity(0.12), theme.scaffoldBackgroundColor] : [_colCyan.withOpacity(0.08), theme.scaffoldBackgroundColor],
                stops: const [0.0, 1.0],
              ),
            ),
          ),
          SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 70, 20, MediaQuery.of(context).padding.bottom + 24),
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _TestHeaderCard(test: test, isDark: isDark),
                const SizedBox(height: 16),
                _StatsCard(test: test, isDark: isDark),
                const SizedBox(height: 16),
                _InsightCard(weakestSubject: weakestSubjectEntry, strongestSubject: strongestSubjectEntry, isDark: isDark),
                const SizedBox(height: 20),
                if (pieChartSections.isNotEmpty) _ChartCard(pieChartSections: pieChartSections, test: test, isDark: isDark),
                const SizedBox(height: 20),
                _SubjectDetailsList(test: test, isDark: isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }
  static const List<Color> _chartColors = [Color(0xFF2E3192), Color(0xFF00C853), Color(0xFFFF9800), Color(0xFF9C27B0), Color(0xFFFF5252), Color(0xFF00BCD4), Color(0xFFE91E63), Color(0xFFFFB300), Color(0xFF3F51B5), Color(0xFF795548)];
  List<PieChartSectionData> _createPieChartSections(BuildContext context) {
    int colorIndex = 0;
    return test.scores.entries.map((entry) {
      final subjectNet = entry.value['dogru']! - (entry.value['yanlis']! * test.penaltyCoefficient);
      if (subjectNet <= 0) return null;
      final section = PieChartSectionData(value: subjectNet, title: '', radius: 65, color: _chartColors[colorIndex % _chartColors.length]);
      colorIndex++;
      return section;
    }).where((section) => section != null).cast<PieChartSectionData>().toList();
  }
}
class _TestHeaderCard extends StatelessWidget {
  final TestModel test;
  final bool isDark;
  const _TestHeaderCard({required this.test, required this.isDark});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2230) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.06), blurRadius: 16, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: const Color(0xFF2E3192).withOpacity(isDark ? 0.2 : 0.08), borderRadius: BorderRadius.circular(8)),
                child: Text(test.sectionName.toUpperCase(), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: isDark ? const Color(0xFF8B8FFF) : const Color(0xFF2E3192), letterSpacing: 0.5)),
              ),
              const Spacer(),
              Icon(Icons.calendar_today_rounded, size: 14, color: isDark ? Colors.white54 : Colors.black45),
              const SizedBox(width: 6),
              Text('${test.date.day}/${test.date.month}/${test.date.year}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : Colors.black54)),
            ],
          ),
          const SizedBox(height: 12),
          Text(test.testName, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700, fontSize: 20, height: 1.3)),
        ],
      ),
    );
  }
}
class _StatsCard extends StatelessWidget {
  final TestModel test;
  final bool isDark;
  const _StatsCard({required this.test, required this.isDark});
  Widget _divider() => Container(width: 1, height: 40, margin: const EdgeInsets.symmetric(horizontal: 4), color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06));
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2230) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.06), blurRadius: 16, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          Expanded(child: _StatItem(label: "Toplam Net", value: test.totalNet.toStringAsFixed(1), color: const Color(0xFF2E3192), isDark: isDark, isHighlighted: true)),
          _divider(),
          Expanded(child: _StatItem(label: "Doğru", value: test.totalCorrect.toString(), color: const Color(0xFF00C853), isDark: isDark)),
          _divider(),
          Expanded(child: _StatItem(label: "Yanlış", value: test.totalWrong.toString(), color: const Color(0xFFFF5252), isDark: isDark)),
          _divider(),
          Expanded(child: _StatItem(label: "Boş", value: test.totalBlank.toString(), color: isDark ? Colors.white54 : Colors.grey, isDark: isDark)),
        ],
      ),
    );
  }
}
class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool isDark;
  final bool isHighlighted;
  const _StatItem({required this.label, required this.value, required this.color, required this.isDark, this.isHighlighted = false});
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value, style: TextStyle(fontSize: isHighlighted ? 22 : 20, fontWeight: FontWeight.w800, color: color)),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: isDark ? Colors.white54 : Colors.black54)),
      ],
    );
  }
}
class _InsightCard extends StatelessWidget {
  final MapEntry<String, double> weakestSubject;
  final MapEntry<String, double> strongestSubject;
  final bool isDark;
  const _InsightCard({required this.weakestSubject, required this.strongestSubject, required this.isDark});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark ? [const Color(0xFF2E3192).withOpacity(0.15), const Color(0xFF1BFFFF).withOpacity(0.08)] : [const Color(0xFF2E3192).withOpacity(0.06), const Color(0xFF1BFFFF).withOpacity(0.04)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF2E3192).withOpacity(isDark ? 0.2 : 0.1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: const Color(0xFF2E3192).withOpacity(isDark ? 0.2 : 0.1), borderRadius: BorderRadius.circular(12)),
            child: const Text('??', style: TextStyle(fontSize: 20)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Analiz ve Tavsiye', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: isDark ? Colors.white : Colors.black87)),
                const SizedBox(height: 8),
                RichText(
                  text: TextSpan(
                    style: TextStyle(fontSize: 13, height: 1.5, color: isDark ? Colors.white70 : Colors.black54),
                    children: [
                      const TextSpan(text: 'En güçlü alanın '),
                      TextSpan(text: strongestSubject.key, style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF00C853))),
                      const TextSpan(text: ', devam et! En cok gelişim fırsatı ise '),
                      TextSpan(text: weakestSubject.key, style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFFFF9800))),
                      const TextSpan(text: ' dersinde. Bu derse odaklanarak netlerini hızla artırabilirsin!'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
class _ChartCard extends StatelessWidget {
  final List<PieChartSectionData> pieChartSections;
  final TestModel test;
  final bool isDark;
  const _ChartCard({required this.pieChartSections, required this.test, required this.isDark});
  static const List<Color> _chartColors = [Color(0xFF2E3192), Color(0xFF00C853), Color(0xFFFF9800), Color(0xFF9C27B0), Color(0xFFFF5252), Color(0xFF00BCD4), Color(0xFFE91E63), Color(0xFFFFB300), Color(0xFF3F51B5), Color(0xFF795548)];
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2230) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.06), blurRadius: 16, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Net Dağılımı', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: isDark ? Colors.white : Colors.black87)),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: Row(
              children: [
                Expanded(flex: 3, child: PieChart(PieChartData(sections: pieChartSections, centerSpaceRadius: 40, sectionsSpace: 2))),
                const SizedBox(width: 16),
                Expanded(flex: 2, child: _buildLegend()),
              ],
            ),
          ),
        ],
      ),
    );
  }
  Widget _buildLegend() {
    final entries = test.scores.entries.toList();
    final legendItems = <Widget>[];
    int colorIndex = 0;
    for (var entry in entries) {
      final subjectNet = entry.value['dogru']! - (entry.value['yanlis']! * test.penaltyCoefficient);
      if (subjectNet <= 0) continue;
      legendItems.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Container(width: 12, height: 12, decoration: BoxDecoration(color: _chartColors[colorIndex % _chartColors.length], borderRadius: BorderRadius.circular(3))),
              const SizedBox(width: 8),
              Expanded(child: Text(entry.key, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : Colors.black54), maxLines: 1, overflow: TextOverflow.ellipsis)),
              Text(subjectNet.toStringAsFixed(1), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: isDark ? Colors.white : Colors.black87)),
            ],
          ),
        ),
      );
      colorIndex++;
    }
    return SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: legendItems));
  }
}
class _SubjectDetailsList extends StatelessWidget {
  final TestModel test;
  final bool isDark;
  const _SubjectDetailsList({required this.test, required this.isDark});
  @override
  Widget build(BuildContext context) {
    final entries = test.scores.entries.toList()..sort((a, b) {
      final netA = a.value['dogru']! - (a.value['yanlis']! * test.penaltyCoefficient);
      final netB = b.value['dogru']! - (b.value['yanlis']! * test.penaltyCoefficient);
      return netB.compareTo(netA);
    });
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text("Ders Bazlı Sonuclar", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: isDark ? Colors.white : Colors.black87)),
        ),
        Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E2230) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.06), blurRadius: 16, offset: const Offset(0, 4))],
          ),
          child: Column(
            children: entries.asMap().entries.map((entry) {
              final index = entry.key;
              final e = entry.value;
              final scores = e.value;
              final net = scores['dogru']! - (scores['yanlis']! * test.penaltyCoefficient);
              final d = scores['dogru'] ?? 0;
              final y = scores['yanlis'] ?? 0;
              final b = scores['bos'] ?? 0;
              final isLast = index == entries.length - 1;
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(border: !isLast ? Border(bottom: BorderSide(color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04))) : null),
                child: Row(
                  children: [
                    Expanded(flex: 4, child: Text(e.key, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: isDark ? Colors.white : Colors.black87), maxLines: 1, overflow: TextOverflow.ellipsis)),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _MiniChip(value: d, color: const Color(0xFF00C853), isDark: isDark),
                        const SizedBox(width: 6),
                        _MiniChip(value: y, color: const Color(0xFFFF5252), isDark: isDark),
                        const SizedBox(width: 6),
                        _MiniChip(value: b, color: isDark ? Colors.white38 : Colors.grey.shade400, isDark: isDark),
                      ],
                    ),
                    const SizedBox(width: 12),
                    Container(
                      width: 50,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(color: isDark ? const Color(0xFF2E3192).withOpacity(0.2) : const Color(0xFF2E3192).withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
                      child: Text(net.toStringAsFixed(1), textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: isDark ? const Color(0xFF8B8FFF) : const Color(0xFF2E3192))),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
class _MiniChip extends StatelessWidget {
  final int value;
  final Color color;
  final bool isDark;
  const _MiniChip({required this.value, required this.color, required this.isDark});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(color: color.withOpacity(isDark ? 0.2 : 0.1), borderRadius: BorderRadius.circular(6)),
      child: Center(child: Text('$value', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color))),
    );
  }
}
