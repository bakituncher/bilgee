// lib/features/stats/screens/general_overview_screen.dart
import 'package:bilge_ai/core/theme/app_theme.dart';
import 'package:bilge_ai/data/models/test_model.dart';
import 'package:bilge_ai/data/providers/firestore_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
          String lastWhen = lastDate == null ? '—' : _humanize(lastDate!);

          final tiles = [
            _tile(context, icon: Icons.assignment_rounded, title: 'Toplam Deneme', value: '$testCount'),
            _tile(context, icon: Icons.show_chart_rounded, title: 'Ortalama Net', value: avgNet.toStringAsFixed(1)),
            _tile(context, icon: Icons.local_fire_department_rounded, title: 'Seri', value: '${user?.streak ?? 0} gün'),
            _tile(context, icon: Icons.flag_rounded, title: 'Haftalık Hedef', value: user?.weeklyStudyGoal != null ? '${user!.weeklyStudyGoal!.toStringAsFixed(1)} saat' : '—'),
            _tile(context, icon: Icons.history_edu_rounded, title: 'Son Deneme', value: lastNet != null ? '${lastNet!.toStringAsFixed(1)} net • $lastWhen' : lastWhen),
          ];

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            itemCount: tiles.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, i) => tiles[i]
                .animate()
                .fadeIn(duration: 200.ms, delay: (i * 60).ms)
                .slideY(begin: .05, curve: Curves.easeOut),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.secondaryColor)),
        error: (e, s) => Center(child: Text('Hata: $e')),
      ),
    );
  }

  Widget _tile(BuildContext context, {required IconData icon, required String title, required String value}) {
    return Card(
      elevation: 6,
      shadowColor: AppTheme.lightSurfaceColor.withOpacity(.4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ListTile(
        leading: Container(
          decoration: BoxDecoration(
            color: AppTheme.secondaryColor.withOpacity(.15),
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.all(10),
          child: Icon(icon, color: AppTheme.secondaryColor),
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
