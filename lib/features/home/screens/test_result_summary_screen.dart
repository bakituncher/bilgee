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
              padding: EdgeInsets.fromLTRB(16, MediaQuery.of(context).padding.top + 56, 16, 100),
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
                const SizedBox(height: 16),
                KeyStatsRow(test: test),
                const SizedBox(height: 16),

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
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor.withOpacity(0.95),
          border: Border(top: BorderSide(color: theme.dividerColor.withOpacity(0.1))),
        ),
        child: SafeArea(
          child: SizedBox(
            height: 52, // Standart rahat basılabilir buton yüksekliği
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
                elevation: 4,
                shadowColor: theme.colorScheme.primary.withOpacity(0.3),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: () => context.go('/home'),
              child: const Text("Ana Panele Dön", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ),
        ),
      ),
    );
  }
}

// --- 1. HEADER (Dengeli & Şık) ---
class _MediumHeaderCard extends StatelessWidget {
  final TestModel test;
  final bool isDark;

  const _MediumHeaderCard({required this.test, required this.isDark});

  @override
  Widget build(BuildContext context) {
    // Kart görünümü yerine temiz bir zemin üstü yerleşim daha ferah durur
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2230) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Theme.of(context).dividerColor.withOpacity(0.05),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Üst Satır: Sınav Tipi
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF2E3192).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  test.sectionName.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF2E3192),
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Alt Satır: İsim (Sol) ve Tarih (Sağ) - Yan Yana
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(
                  test.testName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    height: 1.2,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Icon(Icons.calendar_today_rounded, size: 16, color: Theme.of(context).colorScheme.primary.withOpacity(0.7)),
                  const SizedBox(height: 4),
                  Text(
                    DateFormat.MMMd('tr').format(test.date),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// --- 2. AKSİYON KARTI (Orta Ölçekli) ---
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
      padding: const EdgeInsets.all(16), // Rahat padding (önceki 12, orijinal 20 idi)
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: deepBlue.withOpacity(0.12),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: deepBlue.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  gradient: const LinearGradient(
                    colors: [deepBlue, cyan],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: const Icon(Icons.bolt_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hızlı Aksiyon',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : deepBlue,
                      ),
                    ),
                    if (!isPremium)
                      const Text(
                        'Premium avantajları keşfet',
                        style: TextStyle(fontSize: 11, color: deepBlue, fontWeight: FontWeight.w600),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            isGoodResult
                ? 'Sonuçlar gayet iyi. Detaylara inip ustalığını pekiştirmek için harika bir zaman.'
                : 'Eksikleri tespit ettik. Stratejik bir planla netleri artırabiliriz.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 44, // İdeal buton yüksekliği
                  child: _MediumGradientButton(
                    text: 'Detaylı Analiz',
                    icon: Icons.analytics_rounded,
                    onPressed: onDetailedPressed,
                    gradient: const LinearGradient(
                      colors: [deepBlue, Color(0xFF4A4EBD)],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: _MediumGradientButton(
                    text: 'Koçluk Al',
                    icon: Icons.chat_bubble_outline_rounded,
                    onPressed: onCoachPressed,
                    isOutlined: true,
                    gradient: const LinearGradient(colors: [deepBlue, deepBlue]),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MediumGradientButton extends StatelessWidget {
  final String text;
  final IconData icon;
  final VoidCallback onPressed;
  final LinearGradient gradient;
  final bool isOutlined;

  const _MediumGradientButton({
    required this.text,
    required this.icon,
    required this.onPressed,
    required this.gradient,
    this.isOutlined = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isOutlined) {
      return OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(text, style: const TextStyle(fontWeight: FontWeight.w600)),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: gradient.colors.first.withOpacity(0.3), width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          foregroundColor: Theme.of(context).colorScheme.onSurface,
        ),
      );
    }
    return Container(
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: gradient.colors.first.withOpacity(0.25),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18, color: Colors.white),
        label: Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}

// --- 3. DERS LİSTESİ (Dengeli Görünüm) ---
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
            "Performans Detayı",
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
        ...entries.map((e) {
          final s = e.value;
          final net = subjectNet(s);
          final d = s['dogru'] ?? 0;
          final y = s['yanlis'] ?? 0;

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E2230) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Theme.of(context).dividerColor.withOpacity(0.05),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.2 : 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                // Sol: Ders ve Bar
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        e.key,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      // Visual Bar (Orta kalınlıkta)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: SizedBox(
                          height: 6,
                          child: Row(
                            children: [
                              Flexible(flex: d, child: Container(color: const Color(0xFF00C853))), // Yeşil
                              Flexible(flex: y, child: Container(color: const Color(0xFFFF3D00))), // Kırmızı
                              Flexible(flex: (s['bos'] ?? 0), child: Container(color: Theme.of(context).disabledColor.withOpacity(0.2))),
                              if ((d+y+(s['bos']??0)) == 0) Flexible(child: Container(color: Theme.of(context).disabledColor.withOpacity(0.2))),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                // Sağ: Net Bilgisi
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2E3192).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    children: [
                      Text(
                        net.toStringAsFixed(1),
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                          color: Color(0xFF2E3192),
                        ),
                      ),
                      const Text(
                        "NET",
                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF2E3192)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ],
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