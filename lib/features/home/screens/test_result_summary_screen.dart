// lib/features/home/screens/test_result_summary_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Savaş Raporu"),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              theme.scaffoldBackgroundColor,
              theme.cardColor.withOpacity(0.3),
              theme.scaffoldBackgroundColor,
            ],
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            // Başlık özeti - kompakt ve şık
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: theme.cardColor,
                border: Border.all(
                  color: isDark 
                    ? colorScheme.surfaceContainerHighest.withOpacity(0.3)
                    : colorScheme.onSurface.withOpacity(0.08),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isDark 
                      ? Colors.black.withOpacity(0.2)
                      : colorScheme.primary.withOpacity(0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
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
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 16,
                    runSpacing: 8,
                    children: [
                      _InfoChip(
                        icon: Icons.category_outlined,
                        label: test.sectionName,
                        colorScheme: colorScheme,
                      ),
                      _InfoChip(
                        icon: Icons.calendar_today_outlined,
                        label: DateFormat.yMd('tr').format(test.date),
                        colorScheme: colorScheme,
                      ),
                      _InfoChip(
                        icon: Icons.percent_outlined,
                        label: 'Ceza: ${test.penaltyCoefficient}',
                        colorScheme: colorScheme,
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
            if (test.scores.isNotEmpty) const SizedBox(height: 12),
            if (keySubjects.isNotEmpty)
              SubjectHighlights(keySubjects: keySubjects),
            if (keySubjects.isNotEmpty) const SizedBox(height: 12),
            // Hızlı eylemler - daha kompakt
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.analytics_rounded, size: 20),
                    label: const Text('Detaylı', style: TextStyle(fontSize: 13)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () => context.push('/home/test-detail', extra: test),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.forum_rounded, size: 20),
                    label: Text(
                      isGoodResult ? "Kutla!" : "Değerlendir",
                      style: const TextStyle(fontSize: 13),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      foregroundColor: isGoodResult ? colorScheme.secondary : colorScheme.primary,
                      side: BorderSide(color: isGoodResult ? colorScheme.secondary : colorScheme.primary, width: 1.5),
                    ),
                    onPressed: () {
                      final prompt = isGoodResult ? 'new_test_good' : 'new_test_bad';
                      context.push('${AppRoutes.aiHub}/${AppRoutes.motivationChat}', extra: prompt);
                    },
                  ),
                ),
              ],
            ).animate().fadeIn(duration: 300.ms, delay: 80.ms).slideY(begin: 0.1),
            const SizedBox(height: 12),
          ].animate(interval: 80.ms).fadeIn(duration: 350.ms).slideY(begin: 0.15),
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: theme.cardColor,
          border: Border(
            top: BorderSide(
              color: isDark 
                ? colorScheme.surfaceContainerHighest.withOpacity(0.2)
                : colorScheme.onSurface.withOpacity(0.08),
              width: 1,
            ),
          ),
        ),
        child: SafeArea(
          child: ElevatedButton.icon(
            icon: const Icon(Icons.home_rounded),
            label: const Text("Ana Panele Dön"),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            onPressed: () => context.go('/home'),
          ),
        ),
      ),
    );
  }
}

// Yeni widget: Bilgi chip'i
class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final ColorScheme colorScheme;

  const _InfoChip({
    required this.icon,
    required this.label,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: colorScheme.onSurfaceVariant.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
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
    
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: theme.cardColor,
        border: Border.all(
          color: isDark 
            ? colorScheme.surfaceContainerHighest.withOpacity(0.3)
            : colorScheme.onSurface.withOpacity(0.08),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark 
              ? Colors.black.withOpacity(0.15)
              : colorScheme.primary.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.insights_rounded, color: colorScheme.primary, size: 20),
              ),
              const SizedBox(width: 10),
              Text(
                'Ders Bazlı Sonuçlar',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...entries.map((e) {
            final s = e.value;
            final net = subjectNet(s);
            final acc = subjectAcc(s);
            return Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest.withOpacity(isDark ? 0.2 : 0.3),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark
                        ? colorScheme.surfaceContainerHighest.withOpacity(0.3)
                        : colorScheme.onSurface.withOpacity(0.06),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              e.key,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: colorScheme.onSurface,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: (net >= 0 ? colorScheme.secondary : colorScheme.error).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: (net >= 0 ? colorScheme.secondary : colorScheme.error).withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Net: ',
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  net.toStringAsFixed(1),
                                  style: theme.textTheme.labelLarge?.copyWith(
                                    color: net >= 0 ? colorScheme.secondary : colorScheme.error,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          _chip(context, 'D: ${s['dogru'] ?? 0}', colorScheme.secondary.withOpacity(0.15), colorScheme.secondary),
                          const SizedBox(width: 6),
                          _chip(context, 'Y: ${s['yanlis'] ?? 0}', colorScheme.error.withOpacity(0.15), colorScheme.error),
                          const SizedBox(width: 6),
                          _chip(context, 'B: ${s['bos'] ?? 0}', colorScheme.onSurface.withOpacity(0.08), colorScheme.onSurfaceVariant),
                          const Spacer(),
                          Icon(Icons.check_circle, size: 16, color: colorScheme.primary),
                          const SizedBox(width: 4),
                          Text(
                            '%${acc.toStringAsFixed(0)}',
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: colorScheme.primary,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _chip(BuildContext context, String text, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: fg.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: fg,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
