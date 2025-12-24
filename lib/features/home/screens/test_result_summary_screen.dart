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
import 'dart:ui';

class TestResultSummaryScreen extends ConsumerWidget {
  final TestModel test;

  const TestResultSummaryScreen({super.key, required this.test});

  double _subjectNet(Map<String, int> s) =>
      (s['dogru'] ?? 0) - (s['yanlis'] ?? 0) * test.penaltyCoefficient;

  double _subjectAcc(Map<String, int> s) {
    final d = (s['dogru'] ?? 0);
    final y = (s['yanlis'] ?? 0);
    final b = (s['bos'] ?? 0);
    final totalQuestions = d + y + b;
    if (totalQuestions == 0) return 0.0;
    return (d / totalQuestions) * 100.0;
  }

  // Premium Renk Paleti (Şıklık için)
  static const Color _colDeepBlue = Color(0xFF2E3192);
  static const Color _colCyan = Color(0xFF1BFFFF);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool fromArchive =
        GoRouterState.of(context).uri.queryParameters['fromArchive'] == 'true';

    final wisdomScore = test.wisdomScore;
    final verdict = test.expertVerdict;
    final keySubjects = test.findKeySubjects();
    final isGoodResult = wisdomScore > 60;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isPremium = ref.watch(premiumStatusProvider);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(
            fromArchive ? Icons.arrow_back_ios_new_rounded : Icons.close_rounded,
            size: 22,
            color: theme.colorScheme.onSurface.withOpacity(0.9),
          ),
          onPressed: () => fromArchive ? context.pop() : context.go('/home'),
        ),
        title: Text(
          "Savaş Raporu",
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            fontSize: 17,
            letterSpacing: 0.5,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(color: Colors.transparent),
          ),
        ),
      ),
      backgroundColor: theme.scaffoldBackgroundColor,
      body: PopScope(
        canPop: fromArchive,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          if (!fromArchive) context.go('/home');
        },
        child: Stack(
          children: [
            // Arka Plan (Hafif ve Premium Gradient)
            Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.8),
                  radius: 1.6,
                  colors: isDark
                      ? [
                    _colDeepBlue.withOpacity(0.12),
                    theme.scaffoldBackgroundColor,
                  ]
                      : [
                    _colCyan.withOpacity(0.08),
                    theme.scaffoldBackgroundColor,
                  ],
                  stops: const [0.0, 1.0],
                ),
              ),
            ),

            // Ana İçerik
            ListView(
              padding: EdgeInsets.fromLTRB(
                20, // Kenarlardan daha uzak
                MediaQuery.of(context).padding.top + 70,
                20,
                MediaQuery.of(context).padding.bottom + 100,
              ),
              physics: const BouncingScrollPhysics(),
              children: [

                // 1. HEADER (Dengeli: İsim ve Tarih Yan Yana)
                _MediumHeaderCard(test: test, isDark: isDark),

                const SizedBox(height: 16),

                // 2. AKSİYON KARTI (Orta Ölçekli & Premium)
                _MediumActionCard(
                  test: test,
                  isPremium: isPremium,
                  isDark: isDark,
                  isGoodResult: isGoodResult,
                  onDetailedPressed: () async {
                    if (isPremium) {
                      context.push('/home/test-detail', extra: test);
                      return;
                    }
                    final unlocked = await _showPremiumDetailGateDialog(
                      context: context,
                      ref: ref,
                      isDark: isDark,
                    );
                    if (unlocked == true && context.mounted) {
                      context.push('/home/test-detail', extra: test);
                    }
                  },
                  onCoachPressed: () {
                    if (isPremium) {
                      final prompt = isGoodResult ? 'new_test_good' : 'new_test_bad';
                      context.push('${AppRoutes.aiHub}/${AppRoutes.motivationChat}', extra: prompt);
                    } else {
                      context.push('/ai-hub/offer', extra: {
                        'title': 'Analiz & Strateji',
                        'subtitle': 'Deneme değerlendirme ve strateji danışmanı',
                        'icon': Icons.dashboard_customize_rounded,
                        'color': Colors.amberAccent,
                        'heroTag': 'analysis-strategy-offer',
                        'redirectRoute': '/ai-hub/analysis-strategy',
                      });
                    }
                  },
                ),

                const SizedBox(height: 16),

                // 3. İstatistik ve Yorum Kartları
                VerdictCard(verdict: verdict, wisdomScore: wisdomScore),
                const SizedBox(height: 12),
                KeyStatsRow(test: test),
                const SizedBox(height: 20),

                // 4. Ders Listesi (Visual & Balanced)
                if (test.scores.isNotEmpty)
                  _BalancedSubjectList(
                    test: test,
                    subjectNet: _subjectNet,
                    subjectAcc: _subjectAcc,
                    isDark: isDark,
                  ),

                const SizedBox(height: 16),
                if (keySubjects.isNotEmpty) SubjectHighlights(keySubjects: keySubjects),
              ],
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF1E2230).withOpacity(0.98)
              : Colors.white.withOpacity(0.98),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.2 : 0.06),
              blurRadius: 10,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: SizedBox(
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark
                    ? const Color(0xFF4A4EBD)
                    : theme.colorScheme.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () => context.go('/home'),
              child: const Text(
                "Ana Panele Dön",
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// --- 1. HEADER (Premium & Şık) ---
class _MediumHeaderCard extends StatelessWidget {
  final TestModel test;
  final bool isDark;

  const _MediumHeaderCard({required this.test, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2230) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Sol: Badge + İsim
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2E3192).withOpacity(isDark ? 0.2 : 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    test.sectionName.toUpperCase(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isDark ? const Color(0xFF8B8FFF) : const Color(0xFF2E3192),
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  test.testName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 17,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // Sağ: Tarih
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF2A2E3D) : const Color(0xFFF5F5F7),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.calendar_today_rounded,
                  size: 16,
                  color: isDark ? Colors.white54 : Colors.black45,
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat.MMMd('tr').format(test.date),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white70 : Colors.black54,
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

// --- 2. AKSİYON KARTI (Premium & Şık) ---
class _MediumActionCard extends StatelessWidget {
  final TestModel test;
  final bool isPremium;
  final bool isDark;
  final bool isGoodResult;
  final VoidCallback onCoachPressed;
  final Future<void> Function() onDetailedPressed;

  const _MediumActionCard({
    required this.test,
    required this.isPremium,
    required this.isDark,
    required this.isGoodResult,
    required this.onCoachPressed,
    required this.onDetailedPressed,
  });

  @override
  Widget build(BuildContext context) {
    const deepBlue = Color(0xFF2E3192);
    const cyan = Color(0xFF1BFFFF);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2230) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Üst Satır: İkon ve Başlık
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: LinearGradient(
                    colors: isDark
                        ? [const Color(0xFF4A4EBD), const Color(0xFF6B6FD6)]
                        : [deepBlue, cyan],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: const Icon(Icons.bolt_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isGoodResult ? 'Harika performans!' : 'Gelişim fırsatı',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isGoodResult
                          ? 'Detaylara inip ustalığını pekiştir'
                          : 'Stratejik planla netleri artır',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white54 : Colors.black45,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Butonlar
          Row(
            children: [
              Expanded(
                child: _PremiumButton(
                  text: 'Detaylı Analiz',
                  icon: Icons.analytics_rounded,
                  onPressed: onDetailedPressed,
                  isDark: isDark,
                  isPrimary: true,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _PremiumButton(
                  text: 'Koça Danış',
                  emoji: '💎',
                  icon: Icons.auto_awesome,
                  onPressed: onCoachPressed,
                  isDark: isDark,
                  isPrimary: false,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PremiumButton extends StatelessWidget {
  final String text;
  final IconData icon;
  final String? emoji;
  final VoidCallback onPressed;
  final bool isDark;
  final bool isPrimary;

  const _PremiumButton({
    required this.text,
    required this.icon,
    this.emoji,
    required this.onPressed,
    required this.isDark,
    required this.isPrimary,
  });

  @override
  Widget build(BuildContext context) {
    const deepBlue = Color(0xFF2E3192);

    if (!isPrimary) {
      return SizedBox(
        height: 44,
        child: OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            side: BorderSide(
              color: isDark ? Colors.white24 : deepBlue.withOpacity(0.2),
              width: 1.5,
            ),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            foregroundColor: isDark ? Colors.white : deepBlue,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (emoji != null) ...[
                Text(emoji!, style: const TextStyle(fontSize: 14)),
                const SizedBox(width: 6),
              ],
              Text(
                text,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      );
    }

    return SizedBox(
      height: 44,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [const Color(0xFF4A4EBD), const Color(0xFF5A5EC9)]
                : [deepBlue, const Color(0xFF4A4EBD)],
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: deepBlue.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ElevatedButton.icon(
          onPressed: onPressed,
          icon: Icon(icon, size: 16, color: Colors.white),
          label: Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
    );
  }
}

// --- 3. DERS LİSTESİ (Premium & Şık) ---
class _BalancedSubjectList extends StatelessWidget {
  final TestModel test;
  final double Function(Map<String, int>) subjectNet;
  final double Function(Map<String, int>) subjectAcc;
  final bool isDark;

  const _BalancedSubjectList({
    required this.test,
    required this.subjectNet,
    required this.subjectAcc,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final entries = test.scores.entries.toList()
      ..sort((a, b) => subjectNet(b.value).compareTo(subjectNet(a.value)));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            "Ders Performansı",
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E2230) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.2 : 0.06),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: entries.asMap().entries.map((entry) {
              final index = entry.key;
              final e = entry.value;
              final s = e.value;
              final net = subjectNet(s);
              final d = s['dogru'] ?? 0;
              final y = s['yanlis'] ?? 0;
              final b = s['bos'] ?? 0;
              final isFirst = index == 0;
              final isLast = index == entries.length - 1;

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  border: !isLast ? Border(
                    bottom: BorderSide(
                      color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
                    ),
                  ) : null,
                ),
                child: Row(
                  children: [
                    // Ders İsmi
                    Expanded(
                      flex: 5,
                      child: Text(
                        e.key,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // D/Y/B Mini İstatistik
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _StatChip(value: d, color: const Color(0xFF00C853), isDark: isDark),
                        const SizedBox(width: 8),
                        _StatChip(value: y, color: const Color(0xFFFF5252), isDark: isDark),
                        const SizedBox(width: 8),
                        _StatChip(value: b, color: isDark ? Colors.white38 : Colors.grey.shade400, isDark: isDark),
                      ],
                    ),
                    const SizedBox(width: 12),
                    // Net Badge
                    Container(
                      width: 48,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF2E3192).withOpacity(0.2)
                            : const Color(0xFF2E3192).withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        net.toStringAsFixed(1),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          color: isDark ? const Color(0xFF8B8FFF) : const Color(0xFF2E3192),
                        ),
                      ),
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

class _StatChip extends StatelessWidget {
  final int value;
  final Color color;
  final bool isDark;

  const _StatChip({required this.value, required this.color, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: color.withOpacity(isDark ? 0.2 : 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Center(
        child: Text(
          '$value',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ),
    );
  }
}

Future<bool> _showPremiumDetailGateDialog({
  required BuildContext context,
  required WidgetRef ref,
  required bool isDark,
}) async {
  final theme = Theme.of(context);
  const deepBlue = Color(0xFF2E3192);

  Future<bool> goPaywallAndCheck() async {
    await context.push('/premium');
    return ref.read(premiumStatusProvider);
  }

  final result = await showGeneralDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'PremiumGate',
    barrierColor: Colors.black.withOpacity(isDark ? 0.6 : 0.4),
    transitionDuration: const Duration(milliseconds: 200),
    pageBuilder: (ctx, a1, a2) {
      return Center(
        child: Material(
          type: MaterialType.transparency,
          child: Container(
            width: double.infinity,
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF161A1F) : Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: deepBlue.withOpacity(0.2)),
              boxShadow: [
                BoxShadow(color: deepBlue.withOpacity(0.1), blurRadius: 40, offset: const Offset(0, 10)),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: deepBlue.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.lock_person_rounded, color: deepBlue, size: 24),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Detaylı analiz kilitli',
                  style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800, fontSize: 20, color: isDark ? Colors.white : deepBlue),
                ),
                const SizedBox(height: 10),
                Text(
                  'Bu denemedeki hatalarının kök nedenlerini ve konu kırılımlarını görmek için Pro\'ya geç.',
                  style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: deepBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  onPressed: () async {
                    final unlocked = await goPaywallAndCheck();
                    if (ctx.mounted) Navigator.of(ctx).pop(unlocked);
                  },
                  child: const Text('Taktik Pro’ya Geç', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: Text('Şimdilik İnceleme', style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.5))),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
  return result ?? false;
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
        final latest = list.first;
        return TestResultSummaryScreen(test: latest);
      },
    );
  }
}