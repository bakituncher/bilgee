// lib/features/stats/screens/general_overview_screen.dart
import 'package:taktik/data/models/test_model.dart';
import 'package:taktik/data/providers/firestore_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:taktik/shared/widgets/logo_loader.dart';

class GeneralOverviewScreen extends ConsumerWidget {
  const GeneralOverviewScreen({super.key});

  Future<void> _handleBack(BuildContext context) async {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(userProfileProvider);
    final testsAsync = ref.watch(testsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Genel Bakış'),
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Geri',
          onPressed: () => _handleBack(context),
        ),
      ),
      body: userAsync.when(
        data: (user) {
          final tests = testsAsync.valueOrNull ?? <TestModel>[];
          final testCount = user?.testCount ?? tests.length;
          final totalNet = user?.totalNetSum ?? tests.fold<double>(0, (sum, t) => sum + t.totalNet);
          final avgNet = testCount > 0 ? (totalNet / testCount) : 0.0;
          DateTime? lastDate;
          double? lastNet;
          if (tests.isNotEmpty) {
            final sorted = [...tests]..sort((a,b)=> b.date.compareTo(a.date));
            lastDate = sorted.first.date;
            lastNet = sorted.first.totalNet;
          }
          final lastWhen = lastDate == null ? '—' : _humanize(lastDate);

          // Haftanın başlangıcı ve görev verisi
          final now = DateTime.now();
          final weekStart = DateTime(now.year, now.month, now.day).subtract(Duration(days: (now.weekday - 1)));
          final weekTasksAsync = ref.watch(completedTasksForWeekProvider(weekStart));

          // Özet kutuları
          final tiles = [
            _tile(context, icon: Icons.assignment_rounded, title: 'Toplam Deneme', value: '$testCount'),
            _tile(context, icon: Icons.show_chart_rounded, title: 'Ortalama Net', value: avgNet.toStringAsFixed(1)),
            _tile(context, icon: Icons.local_fire_department_rounded, title: 'Seri', value: '${user?.streak ?? 0} gün'),
            _tile(context, icon: Icons.history_edu_rounded, title: 'Son Deneme', value: lastNet != null ? '${lastNet.toStringAsFixed(1)} net • $lastWhen' : lastWhen),
          ];

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: tiles.map((w) => SizedBox(
                  width: MediaQuery.of(context).size.width > 520 ? (MediaQuery.of(context).size.width - 32 - 12)/2 : double.infinity,
                  child: w.animate().fadeIn(duration: 200.ms).slideY(begin: .05, curve: Curves.easeOut),
                )).toList(),
              ),
              const SizedBox(height: 16),
              if (tests.isNotEmpty)
                _RecentNetSparkline(tests: tests.take(8).toList().reversed.toList())
                    .animate().fadeIn(duration: 250.ms).slideY(begin: .05),
              const SizedBox(height: 16),
              weekTasksAsync.when(
                data: (map) => _WeeklyTasksCard(weekStart: weekStart, data: map)
                    .animate().fadeIn(duration: 250.ms).slideY(begin: .05),
                loading: () => const LogoLoader(),
                error: (e, s) => const SizedBox.shrink(),
              ),
              const SizedBox(height: 16),
              if (user != null)
                _VisitsThisMonthTile(userId: user.id)
                    .animate().fadeIn(duration: 250.ms).slideY(begin: .05),
            ],
          );
        },
        loading: () => const LogoLoader(),
        error: (e, s) => Center(child: Text('Hata: $e')),
      ),
    );
  }

  Widget _tile(BuildContext context, {required IconData icon, required String title, required String value}) {
    return Card(
      elevation: 6,
      shadowColor: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ListTile(
        leading: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.all(10),
          child: Icon(icon, color: Theme.of(context).colorScheme.primary),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        trailing: Text(value, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
      ),
    );
  }

  String _humanize(DateTime d) {
    final diff = DateTime.now().difference(d);
    if (diff.inDays > 0) return '${diff.inDays}g önce';
    if (diff.inHours > 0) return '${diff.inHours}s önce';
    final m = diff.inMinutes;
    return m <= 1 ? 'az önce' : '${m}dk önce';
  }
}

class _RecentNetSparkline extends StatelessWidget {
  final List<TestModel> tests; // kronolojik (eski->yeni)
  const _RecentNetSparkline({required this.tests});

  @override
  Widget build(BuildContext context) {
    final nets = tests.map((t) => t.totalNet).toList();
    if (nets.isEmpty) return const SizedBox.shrink();
    final minY = nets.reduce((a,b)=> a < b ? a : b);
    final maxY = nets.reduce((a,b)=> a > b ? a : b);
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children:[
              Icon(Icons.trending_up_rounded, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              Text('Son Deneme Net Trendi', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            ]),
            const SizedBox(height: 12),
            SizedBox(
              height: 140,
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(show: false),
                  titlesData: const FlTitlesData(show: false),
                  borderData: FlBorderData(show: false),
                  minY: minY - 1,
                  maxY: maxY + 1,
                  lineBarsData: [
                    LineChartBarData(
                      spots: [for (int i=0;i<nets.length;i++) FlSpot(i.toDouble(), nets[i])],
                      isCurved: true,
                      color: Theme.of(context).colorScheme.primary,
                      barWidth: 3,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(show: true, color: Theme.of(context).colorScheme.primary.withOpacity(0.12)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WeeklyTasksCard extends StatelessWidget {
  final DateTime weekStart; // Pazartesi
  final Map<String, List<String>> data; // dateKey -> tasks
  const _WeeklyTasksCard({required this.weekStart, required this.data});

  @override
  Widget build(BuildContext context) {
    final days = List<DateTime>.generate(7, (i) => weekStart.add(Duration(days: i)));
    final counts = days.map((d){
      final key = '${d.year.toString().padLeft(4,'0')}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';
      return (data[key]?.length ?? 0).toDouble();
    }).toList();
    final maxY = (counts.isEmpty ? 1 : counts.reduce((a,b)=> a>b?a:b)).clamp(1, 10);

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children:[
              Icon(Icons.task_alt_rounded, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              Text('Bu Hafta Görev Aktivitesi', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            ]),
            const SizedBox(height: 12),
            SizedBox(
              height: 140,
              child: BarChart(
                BarChartData(
                  gridData: const FlGridData(show: false),
                  titlesData: FlTitlesData(
                    leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: (value, meta){
                      final i = value.toInt();
                      if (i < 0 || i >= days.length) return const SizedBox.shrink();
                      const labels = ['Pzt','Sal','Çar','Per','Cum','Cmt','Paz'];
                      return Padding(padding: const EdgeInsets.only(top: 6), child: Text(labels[i], style: Theme.of(context).textTheme.labelSmall));
                    })),
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: [
                    for (int i=0;i<counts.length;i++)
                      BarChartGroupData(x: i, barRods: [
                        BarChartRodData(toY: counts[i], width: 14, borderRadius: BorderRadius.circular(6), color: Theme.of(context).colorScheme.primary)
                      ])
                  ],
                  maxY: maxY.toDouble(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VisitsThisMonthTile extends ConsumerWidget {
  final String userId;
  const _VisitsThisMonthTile({required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder(
      future: ref.read(firestoreServiceProvider).getVisitsForMonth(userId, DateTime.now()),
      builder: (context, snap){
        if (snap.connectionState != ConnectionState.done) {
          return const SizedBox(height: 72, child: LogoLoader());
        }
        if (snap.hasError) {
          return const SizedBox.shrink();
        }
        final visits = (snap.data ?? const <Timestamp>[]) as List;
        return Card(
          elevation: 6,
          shadowColor: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          child: ListTile(
            leading: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(10),
              child: Icon(Icons.calendar_month_rounded, color: Theme.of(context).colorScheme.primary),
            ),
            title: const Text('Bu Ay Ziyaret'),
            trailing: Text('${visits.length}', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          ),
        );
      },
    );
  }
}
