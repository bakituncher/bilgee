// lib/features/home/screens/test_result_summary_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:taktik/data/models/test_model.dart';
import 'package:taktik/features/home/widgets/summary_widgets/verdict_card.dart';
import 'package:taktik/features/home/widgets/summary_widgets/key_stats_row.dart';
import 'package:taktik/features/home/widgets/summary_widgets/subject_highlights.dart';
import 'package:taktik/core/navigation/app_routes.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:taktik/features/auth/application/auth_controller.dart';
import 'package:taktik/data/providers/firestore_providers.dart';
import 'package:intl/intl.dart';
import 'package:taktik/shared/widgets/logo_loader.dart';
import 'package:taktik/data/providers/premium_provider.dart';

class TestResultSummaryScreen extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final wisdomScore = test.wisdomScore;
    final verdict = test.expertVerdict;
    final keySubjects = test.findKeySubjects();
    final isGoodResult = wisdomScore > 60;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final isPremium = ref.watch(premiumStatusProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Savaş Raporu"),
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [
                    theme.scaffoldBackgroundColor,
                    theme.cardColor.withOpacity(0.3),
                  ]
                : [
                    theme.scaffoldBackgroundColor,
                    colorScheme.surfaceContainerHighest.withOpacity(0.2),
                  ],
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          physics: const BouncingScrollPhysics(),
          children: [
            // Compact header card
            Container(
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark
                      ? colorScheme.surfaceContainerHighest.withOpacity(0.3)
                      : colorScheme.surfaceContainerHighest.withOpacity(0.5),
                  width: 1,
                ),
                boxShadow: isDark
                    ? []
                    : [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
              ),
              padding: const EdgeInsets.all(14.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Hero(
                    tag: 'test_title_${test.id}',
                    child: Material(
                      color: Colors.transparent,
                      child: Text(
                        test.testName,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          fontSize: 20,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: colorScheme.primary.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.category_rounded, size: 14, color: colorScheme.primary),
                            const SizedBox(width: 4),
                            Text(
                              test.sectionName,
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: colorScheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.event_rounded, size: 14, color: colorScheme.onSurfaceVariant),
                            const SizedBox(width: 4),
                            Text(
                              DateFormat.yMd('tr').format(test.date),
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            VerdictCard(verdict: verdict, wisdomScore: wisdomScore),
            const SizedBox(height: 12),
            KeyStatsRow(test: test),
            const SizedBox(height: 12),
            if (test.scores.isNotEmpty) _SubjectBreakdown(test: test, subjectNet: _subjectNet, subjectAcc: _subjectAcc),
            const SizedBox(height: 12),
            if (keySubjects.isNotEmpty) SubjectHighlights(keySubjects: keySubjects),
            const SizedBox(height: 12),
            // Compact action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.analytics_rounded, size: 18),
                    label: const Text('Detaylı Görünüm', style: TextStyle(fontSize: 13)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: BorderSide(color: colorScheme.primary),
                    ),
                    onPressed: () => context.push('/home/test-detail', extra: test),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.forum_rounded, size: 18),
                    label: Text(
                      isGoodResult ? "Zaferi Kutla!" : "Değerlendir",
                      style: const TextStyle(fontSize: 13),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      foregroundColor: isGoodResult ? colorScheme.secondary : colorScheme.primary,
                      side: BorderSide(color: isGoodResult ? colorScheme.secondary : colorScheme.primary),
                    ),
                    onPressed: () {
                      if (isPremium) {
                        // Premium kullanıcı - AI sohbete yönlendir
                        final prompt = isGoodResult ? 'new_test_good' : 'new_test_bad';
                        context.push('${AppRoutes.aiHub}/${AppRoutes.motivationChat}', extra: prompt);
                      } else {
                        // Premium olmayan kullanıcı - Tool Offer Screen'e yönlendir (Analiz & Strateji)
                        context.push('/ai-hub/offer', extra: {
                          'title': 'Analiz & Strateji',
                          'subtitle': 'Deneme değerlendirme ve strateji danışmanı',
                          'icon': Icons.dashboard_customize_rounded,
                          'color': Colors.amberAccent,
                          'heroTag': 'analysis-strategy-offer',
                          'marketingTitle': 'Akıllı Deneme Analizi',
                          'marketingSubtitle': 'Deneme sınavlarınızı yapay zeka ile derinlemesine analiz edin. Hangi konulara odaklanmanız gerektiğini öğrenin, her zaman zirvede kalın.',
                          'redirectRoute': '/ai-hub/analysis-strategy',
                        });
                      }
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ElevatedButton.icon(
          icon: const Icon(Icons.dashboard_customize_rounded),
          label: const Text("Ana Panele Dön"),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
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
          return const Scaffold(body: LogoLoader());
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
                Icon(Icons.insights_rounded, color: Theme.of(context).colorScheme.primary),
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
                      Text('Net: ', style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                      Text(net.toStringAsFixed(2), style: Theme.of(context).textTheme.labelLarge?.copyWith(color: net >= 0 ? Theme.of(context).colorScheme.secondary : Theme.of(context).colorScheme.error, fontWeight: FontWeight.w700)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _chip(context, 'D: ${s['dogru'] ?? 0}', Theme.of(context).colorScheme.secondary.withOpacity(0.2), Theme.of(context).colorScheme.secondary),
                      const SizedBox(width: 6),
                      _chip(context, 'Y: ${s['yanlis'] ?? 0}', Theme.of(context).colorScheme.error.withOpacity(0.15), Theme.of(context).colorScheme.error),
                      const SizedBox(width: 6),
                      _chip(context, 'B: ${s['bos'] ?? 0}', Theme.of(context).colorScheme.onSurface.withOpacity(0.1), Theme.of(context).colorScheme.onSurfaceVariant),
                      const Spacer(),
                      Icon(Icons.check_circle_outline_rounded, size: 16, color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 4),
                      Text('%${acc.toStringAsFixed(1)}', style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w700)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Divider(height: 1),
                  const SizedBox(height: 10),
                ],
              );
            }),
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
