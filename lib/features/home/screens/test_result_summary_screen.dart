// lib/features/home/screens/test_result_summary_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:bilge_ai/core/theme/app_theme.dart';
import 'package:bilge_ai/data/models/test_model.dart';
import 'package:bilge_ai/features/home/widgets/summary_widgets/verdict_card.dart';
import 'package:bilge_ai/features/home/widgets/summary_widgets/key_stats_row.dart';
import 'package:bilge_ai/features/home/widgets/summary_widgets/subject_highlights.dart';
import 'package:bilge_ai/core/navigation/app_routes.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bilge_ai/features/auth/application/auth_controller.dart';
import 'package:bilge_ai/data/providers/firestore_providers.dart';
import 'package:intl/intl.dart';

class TestResultSummaryScreen extends StatelessWidget {
  final TestModel test;

  const TestResultSummaryScreen({super.key, required this.test});

  double _subjectNet(Map<String, int> s) => (s['dogru'] ?? 0) - (s['yanlis'] ?? 0) * test.penaltyCoefficient;
  double _subjectAcc(Map<String, int> s) {
    final d = (s['dogru'] ?? 0);
    final y = (s['yanlis'] ?? 0);
    final attempted = d + y;
    if (attempted == 0) return 0.0;
    return (d / attempted) * 100.0;
  }

  @override
  Widget build(BuildContext context) {
    final wisdomScore = test.wisdomScore;
    final verdict = test.expertVerdict;
    final keySubjects = test.findKeySubjects();
    final isGoodResult = wisdomScore > 60;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Savaş Raporu"),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20.0),
        children: [
          // Başlık özeti
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Hero(
                    tag: 'test_title_${test.id}',
                    child: Material(
                      color: Colors.transparent,
                      child: Text(
                        test.testName,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(children: [
                    Icon(Icons.category_rounded, size: 18, color: AppTheme.secondaryTextColor),
                    const SizedBox(width: 6),
                    Text(test.sectionName, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.secondaryTextColor)),
                    const SizedBox(width: 12),
                    Icon(Icons.event_rounded, size: 18, color: AppTheme.secondaryTextColor),
                    const SizedBox(width: 6),
                    Text(DateFormat.yMd('tr').format(test.date), style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.secondaryTextColor)),
                  ]),
                  const SizedBox(height: 6),
                  Text('Ceza katsayısı: ${test.penaltyCoefficient}', style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AppTheme.secondaryTextColor)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          VerdictCard(verdict: verdict, wisdomScore: wisdomScore),
          const SizedBox(height: 24),
          KeyStatsRow(test: test),
          const SizedBox(height: 24),
          if (test.scores.isNotEmpty) _SubjectBreakdown(test: test, subjectNet: _subjectNet, subjectAcc: _subjectAcc),
          const SizedBox(height: 24),
          if (keySubjects.isNotEmpty)
            SubjectHighlights(keySubjects: keySubjects),
          const SizedBox(height: 24),
          // Hızlı eylemler
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.analytics_rounded),
                  label: const Text('Detaylı Görünüm'),
                  onPressed: () => context.push('/home/test-detail', extra: test),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.forum_rounded),
                  label: Text(isGoodResult ? "Zaferi Kutla!" : "Durumu Değerlendir"),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isGoodResult ? AppTheme.successColor : AppTheme.secondaryColor,
                    side: BorderSide(color: isGoodResult ? AppTheme.successColor : AppTheme.secondaryColor),
                  ),
                  onPressed: () {
                    final prompt = isGoodResult ? 'new_test_good' : 'new_test_bad';
                    context.push('${AppRoutes.aiHub}/${AppRoutes.motivationChat}', extra: prompt);
                  },
                ),
              ),
            ],
          ).animate().fadeIn(duration: 300.ms, delay: 80.ms).slideY(begin: 0.1),
        ].animate(interval: 100.ms).fadeIn(duration: 400.ms).slideY(begin: 0.2),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(20.0),
        child: ElevatedButton.icon(
          icon: const Icon(Icons.dashboard_customize_rounded),
          label: const Text("Ana Panele Dön"),
          onPressed: () => context.go('/home'),
        ),
      ),
    );
  }
}

class TestResultSummaryEntry extends ConsumerWidget {
  final TestModel? test;
  const TestResultSummaryEntry({super.key, this.test});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (test != null) return TestResultSummaryScreen(test: test!);

    final user = ref.watch(authControllerProvider).value;
    if (user == null) {
      return const Scaffold(body: Center(child: Text('Özet verisi yok')));
    }

    return FutureBuilder(
      future: ref.read(firestoreServiceProvider).getTestResultsPaginated(user.uid, limit: 1),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snap.hasError) {
          return Scaffold(body: Center(child: Text('Özet yüklenemedi: ${snap.error}')));
        }
        final list = snap.data ?? <TestModel>[];
        if (list.isEmpty) {
          return const Scaffold(body: Center(child: Text('Özet verisi yok')));
        }
        final latest = list.first; // tarihine göre desc okuyoruz
        return TestResultSummaryScreen(test: latest);
      },
    );
  }
}

class _SubjectBreakdown extends StatelessWidget {
  final TestModel test;
  final double Function(Map<String, int>) subjectNet;
  final double Function(Map<String, int>) subjectAcc;
  const _SubjectBreakdown({required this.test, required this.subjectNet, required this.subjectAcc});

  @override
  Widget build(BuildContext context) {
    final entries = test.scores.entries.toList()
      ..sort((a, b) => subjectNet(b.value).compareTo(subjectNet(a.value)));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.insights_rounded, color: AppTheme.secondaryColor),
                const SizedBox(width: 8),
                Text('Ders Bazlı Sonuçlar', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            ...entries.map((e) {
              final s = e.value;
              final net = subjectNet(s);
              final acc = subjectAcc(s);
              return Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(e.key, style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
                      ),
                      Text('Net: ', style: Theme.of(context).textTheme.labelLarge?.copyWith(color: AppTheme.secondaryTextColor)),
                      Text(net.toStringAsFixed(2), style: Theme.of(context).textTheme.labelLarge?.copyWith(color: net >= 0 ? AppTheme.successColor : AppTheme.accentColor, fontWeight: FontWeight.w700)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _chip(context, 'D: ${s['dogru'] ?? 0}', AppTheme.successColor.withValues(alpha: AppTheme.successColor.a * 0.2), AppTheme.successColor),
                      const SizedBox(width: 6),
                      _chip(context, 'Y: ${s['yanlis'] ?? 0}', AppTheme.accentColor.withValues(alpha: AppTheme.accentColor.a * 0.15), AppTheme.accentColor),
                      const SizedBox(width: 6),
                      _chip(context, 'B: ${s['bos'] ?? 0}', Colors.white10, AppTheme.secondaryTextColor),
                      const Spacer(),
                      Icon(Icons.check_circle_outline_rounded, size: 16, color: AppTheme.secondaryColor),
                      const SizedBox(width: 4),
                      Text('%${acc.toStringAsFixed(1)}', style: Theme.of(context).textTheme.labelLarge?.copyWith(color: AppTheme.secondaryColor, fontWeight: FontWeight.w700)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Divider(height: 1),
                  const SizedBox(height: 10),
                ],
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _chip(BuildContext context, String text, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(text, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: fg, fontWeight: FontWeight.w700)),
    );
  }
}
