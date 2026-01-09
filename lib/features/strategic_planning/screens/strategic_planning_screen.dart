// lib/features/strategic_planning/screens/strategic_planning_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:taktik/data/repositories/ai_service.dart';
import 'package:taktik/data/providers/firestore_providers.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:taktik/data/models/user_model.dart';
import 'package:taktik/core/navigation/app_routes.dart';
import 'package:intl/intl.dart';
import 'package:taktik/data/models/plan_model.dart';
import 'package:taktik/data/models/plan_document.dart';
import 'package:lottie/lottie.dart';
import 'package:taktik/core/safety/ai_content_safety.dart';

enum Pacing { relaxed, moderate, intense }
enum PlanningStep { dataCheck, confirmation, pacing, loading }

final selectedPacingProvider = StateProvider<Pacing>((ref) => Pacing.moderate);
final planningStepProvider = StateProvider.autoDispose<PlanningStep>((ref) => PlanningStep.dataCheck);

// Plan oluşturma Notifier'ı
class StrategyGenerationNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;
  StrategyGenerationNotifier(this._ref) : super(const AsyncValue.data(null));

  Future<void> _generateAndNavigate(BuildContext context, {String? revisionRequest}) async {
    state = const AsyncValue.loading();
    _ref.read(planningStepProvider.notifier).state = PlanningStep.loading;

    final pacing = _ref.read(selectedPacingProvider);
    final user = _ref.read(userProfileProvider).value;
    final tests = _ref.read(testsProvider).value;
    final performance = _ref.read(performanceProvider).value;
    final planDoc = _ref.read(planProvider).value;

    if (user == null || tests == null || performance == null) {
      state = AsyncValue.error("Kullanıcı, test veya performans verisi bulunamadı.", StackTrace.current);
      return;
    }

    try {
      final resultJson = await _ref.read(aiServiceProvider).generateGrandStrategy(
        user: user,
        tests: tests,
        performance: performance,
        planDoc: planDoc,
        pacing: pacing.name,
        revisionRequest: revisionRequest,
      );

      final decodedData = jsonDecode(resultJson);

      if (decodedData.containsKey('error')) {
        throw Exception(decodedData['error']);
      }

      // KÖK NEDEN ÇÖZÜMÜ: AI bazen creationDate alanını eski/random gönderiyor; planın anında expired görünmesini engellemek için şimdi ile ez.
      if (decodedData['weeklyPlan'] is Map<String, dynamic>) {
        (decodedData['weeklyPlan'] as Map<String, dynamic>)['creationDate'] = DateTime.now().toIso8601String();
      }

      final result = {
        // long-term strateji kaldırıldı
        'weeklyPlan': decodedData['weeklyPlan'],
        'pacing': pacing.name,
      };

      if (context.mounted) {
        context.push('/ai-hub/strategic-planning/${AppRoutes.strategyReview}', extra: result);
      }

      _ref.read(planningStepProvider.notifier).state = PlanningStep.dataCheck;
      state = const AsyncValue.data(null);
    } catch (e, s) {
      _ref.read(planningStepProvider.notifier).state = PlanningStep.pacing;
      state = AsyncValue.error(e, s);
    }
  }


  Future<void> generatePlan(BuildContext context) async {
    await _generateAndNavigate(context);
  }

  Future<void> regeneratePlanWithFeedback(BuildContext context, String feedback) async {
    await _generateAndNavigate(context, revisionRequest: feedback);
  }
}


final strategyGenerationProvider = StateNotifierProvider.autoDispose<StrategyGenerationNotifier, AsyncValue<void>>((ref) {
  return StrategyGenerationNotifier(ref);
});


class StrategicPlanningScreen extends ConsumerWidget {
  const StrategicPlanningScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(userProfileProvider);
    final tests = ref.watch(testsProvider).valueOrNull;
    final planDoc = ref.watch(planProvider).valueOrNull;
    final step = ref.watch(planningStepProvider);

    ref.listen<AsyncValue<void>>(strategyGenerationProvider, (_, state) {
      if (state.hasError && !state.isLoading) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Theme.of(context).colorScheme.error,
            content: Text('Strateji oluşturulurken bir hata oluştu: ${state.error}'),
          ),
        );
      }
    });

    return userAsync.when(
      data: (user) {
        if (user == null) {
          return const Scaffold(body: Center(child: Text("Kullanıcı verisi bulunamadı.")));
        }

        if (planDoc?.weeklyPlan != null) {
          if(step != PlanningStep.confirmation && step != PlanningStep.pacing && step != PlanningStep.loading) {
            return _buildStrategyDisplay(context, ref, user, planDoc!);
          }
        }

        final canPop = !(step == PlanningStep.pacing || step == PlanningStep.loading);
        return PopScope(
          canPop: canPop,
          onPopInvoked: (didPop) {
            if (!canPop) {
              ref.read(planningStepProvider.notifier).state = PlanningStep.confirmation;
            }
          },
          child: Scaffold(
            appBar: AppBar(title: const Text('Strateji Oturumu')),
            body: AnimatedSwitcher(
              duration: 400.ms,
              transitionBuilder: (child, animation) {
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0.0, 0.1),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                );
              },
              child: _buildStep(context, ref, step, tests?.isNotEmpty ?? false),
            ),
          ),
        );
      },
      loading: () => Scaffold(body: Center(child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary))),
      error: (e, s) => Scaffold(body: Center(child: Text("Hata: $e"))),
    );
  }

  Widget _buildStep(BuildContext context, WidgetRef ref, PlanningStep step, bool hasTests) {
    if (!hasTests) {
      return _buildDataMissingView(context);
    }

    if (step == PlanningStep.dataCheck && hasTests) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(planningStepProvider.notifier).state = PlanningStep.confirmation;
      });
      return const SizedBox.shrink();
    }

    switch (step) {
      case PlanningStep.confirmation:
        return _buildConfirmationView(context, ref);
      case PlanningStep.pacing:
        return _buildPacingView(context, ref);
      case PlanningStep.loading:
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Container(
          key: const ValueKey('loading'),
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(0, -0.5),
              radius: 1.5,
              colors: isDark
                  ? [
                      const Color(0xFF1A1F3A).withOpacity(0.4),
                      const Color(0xFF0A0E27),
                    ]
                  : [
                      Theme.of(context).colorScheme.primary.withOpacity(0.05),
                      const Color(0xFFF8F9FE),
                    ],
            ),
          ),
          child: Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 480),
              padding: const EdgeInsets.symmetric(horizontal: 32.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Lottie animasyonu
                  Animate(
                    effects: const [
                      FadeEffect(duration: Duration(milliseconds: 600)),
                      ScaleEffect(
                        begin: Offset(0.8, 0.8),
                        end: Offset(1.0, 1.0),
                        curve: Curves.easeOutBack,
                        duration: Duration(milliseconds: 600),
                      ),
                    ],
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
                            Theme.of(context).colorScheme.secondaryContainer.withOpacity(0.2),
                          ],
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: Lottie.asset(
                        'assets/lotties/Data Analysis.json',
                        width: 200,
                        height: 200,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  // Başlık
                  Animate(
                    effects: const [
                      FadeEffect(
                        delay: Duration(milliseconds: 300),
                        duration: Duration(milliseconds: 400),
                      ),
                    ],
                    child: Text(
                      "Strateji Oluşturuluyor",
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Alt metin
                  Animate(
                    effects: const [
                      FadeEffect(
                        delay: Duration(milliseconds: 500),
                        duration: Duration(milliseconds: 400),
                      ),
                    ],
                    child: Text(
                      "Verileriniz analiz ediliyor ve size özel haftalık plan hazırlanıyor",
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        height: 1.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  // İlerleme çubuğu - Modern stil
                  Animate(
                    onPlay: (controller) => controller.repeat(),
                    effects: [
                      const FadeEffect(
                        delay: Duration(milliseconds: 700),
                        duration: Duration(milliseconds: 400),
                      ),
                      ShimmerEffect(
                        duration: const Duration(milliseconds: 2000),
                        color: Theme.of(context).colorScheme.secondary.withOpacity(0.3),
                      ),
                    ],
                    child: Container(
                      width: 240,
                      height: 4,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(2),
                        color: isDark
                            ? const Color(0xFF1E2147)
                            : Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          backgroundColor: Colors.transparent,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildStrategyDisplay(BuildContext context, WidgetRef ref, UserModel user, PlanDocument planDoc) {
    final weeklyPlan = WeeklyPlan.fromJson(planDoc.weeklyPlan!);
    final isExpired = weeklyPlan.isExpired;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0E27) : const Color(0xFFF8F9FE),
      appBar: AppBar(
        title: Text(
          "Stratejik Plan",
          style: TextStyle(
            fontWeight: FontWeight.w600,
            letterSpacing: -0.5,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0, -1.5),
            radius: 2.0,
            colors: isDark
                ? [
                    const Color(0xFF1A1F3A).withOpacity(0.4),
                    const Color(0xFF0A0E27),
                  ]
                : [
                    Theme.of(context).colorScheme.primary.withOpacity(0.04),
                    const Color(0xFFF8F9FE),
                  ],
          ),
        ),
        child: Column(
          children: [
            // AI güvenlik uyarısı
            AiContentSafety.buildDisclaimerBanner(
              context,
              customMessage: 'Bu plan AI tarafından kişiselleştirilmiştir. Kendi durumunuza göre ayarlayabilirsiniz.',
            ),
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20.0),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Ana Kart - Modern Tasarım
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: isExpired
                                  ? (isDark
                                      ? [
                                          const Color(0xFF2D1F1F),
                                          const Color(0xFF1A1212),
                                        ]
                                      : [
                                          const Color(0xFFFFF3E0),
                                          const Color(0xFFFFE0B2),
                                        ])
                                  : (isDark
                                      ? [
                                          const Color(0xFF1E2147),
                                          const Color(0xFF141729),
                                        ]
                                      : [
                                          Colors.white,
                                          const Color(0xFFF5F7FF),
                                        ]),
                            ),
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(
                              color: isExpired
                                  ? (isDark ? Colors.amber.withOpacity(0.2) : Colors.orange.withOpacity(0.3))
                                  : (isDark
                                      ? Theme.of(context).colorScheme.primary.withOpacity(0.15)
                                      : Theme.of(context).colorScheme.primary.withOpacity(0.1)),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: isExpired
                                    ? Colors.orange.withOpacity(isDark ? 0.1 : 0.08)
                                    : Theme.of(context).colorScheme.primary.withOpacity(isDark ? 0.15 : 0.08),
                                blurRadius: 32,
                                offset: const Offset(0, 12),
                                spreadRadius: 0,
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.all(32.0),
                          child: Column(
                            children: [
                              // Icon Container - Gradient Style
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: isExpired
                                        ? [
                                            Colors.orange.withOpacity(0.8),
                                            Colors.deepOrange.withOpacity(0.9),
                                          ]
                                        : [
                                            Theme.of(context).colorScheme.primary,
                                            Theme.of(context).colorScheme.secondary,
                                          ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: (isExpired ? Colors.orange : Theme.of(context).colorScheme.primary)
                                          .withOpacity(0.4),
                                      blurRadius: 20,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  isExpired ? Icons.refresh_rounded : Icons.verified_rounded,
                                  size: 48,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 24),

                              // Başlık
                              Text(
                                isExpired ? "Plan Yenileme Zamanı!" : "Stratejik Plan Aktif",
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.5,
                                      color: isExpired
                                          ? (isDark ? Colors.amber : Colors.orange.shade800)
                                          : null,
                                    ),
                              ),
                              const SizedBox(height: 8),

                              Text(
                                isExpired
                                    ? "Planın 7 günlük süresi doldu"
                                    : "Bu haftanın odağı",
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                                      fontWeight: FontWeight.w500,
                                    ),
                              ),

                              // Motivasyon Alıntısı - Sadece aktif planda
                              if (!isExpired &&
                                  weeklyPlan.motivationalQuote != null &&
                                  weeklyPlan.motivationalQuote!.isNotEmpty) ...[
                                const SizedBox(height: 20),
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: isDark
                                          ? [
                                              Theme.of(context).colorScheme.primaryContainer.withOpacity(0.2),
                                              Theme.of(context).colorScheme.secondaryContainer.withOpacity(0.15),
                                            ]
                                          : [
                                              Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
                                              Theme.of(context).colorScheme.secondaryContainer.withOpacity(0.2),
                                            ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: Theme.of(context).colorScheme.primary.withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Icon(
                                          Icons.format_quote_rounded,
                                          size: 20,
                                          color: Theme.of(context).colorScheme.primary,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Padding(
                                          padding: const EdgeInsets.only(top: 4),
                                          child: Text(
                                            weeklyPlan.motivationalQuote!,
                                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                                  fontStyle: FontStyle.italic,
                                                  height: 1.5,
                                                  fontWeight: FontWeight.w500,
                                                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.9),
                                                ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],

                              // Süre doldu mesajı
                              if (isExpired) ...[
                                const SizedBox(height: 20),
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: (isDark ? Colors.orange.shade900 : Colors.orange.shade50).withOpacity(0.5),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: Colors.orange.withOpacity(0.3),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.info_outline_rounded,
                                        color: isDark ? Colors.orange.shade300 : Colors.orange.shade800,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          "Yeni bir haftalık plan oluşturarak güncel hedeflerinle devam edin",
                                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                color: isDark ? Colors.orange.shade200 : Colors.orange.shade900,
                                                fontWeight: FontWeight.w500,
                                                height: 1.4,
                                              ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],

                              const SizedBox(height: 20),

                              // Tarih Bilgisi
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.calendar_today_rounded,
                                      size: 16,
                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      "Oluşturulma: ${DateFormat.yMMMMd('tr').format(weeklyPlan.creationDate)}",
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                                            fontWeight: FontWeight.w500,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ).animate().fadeIn(duration: 400.ms).scale(
                              begin: const Offset(0.95, 0.95),
                              curve: Curves.easeOutCubic,
                            ),

                        const SizedBox(height: 24),

                        // Butonlar - Modern Instagram/Spotify Tarzı
                        if (isExpired) ...[
                          // Yeni Plan Oluştur - Primary Button
                          _ModernButton(
                            onPressed: () {
                              ref.read(planningStepProvider.notifier).state = PlanningStep.confirmation;
                            },
                            icon: Icons.auto_awesome_rounded,
                            label: "Yeni Strateji Oluştur",
                            isPrimary: true,
                            gradient: LinearGradient(
                              colors: [
                                Theme.of(context).colorScheme.primary,
                                Theme.of(context).colorScheme.secondary,
                              ],
                            ),
                          ),
                        ] else ...[
                          // Haftalık Planı Aç - Primary Button
                          _ModernButton(
                            onPressed: () => context.push('/home/weekly-plan'),
                            icon: Icons.playlist_play_rounded,
                            label: "Haftalık Planı Aç",
                            isPrimary: true,
                            gradient: LinearGradient(
                              colors: [
                                Theme.of(context).colorScheme.primary,
                                Theme.of(context).colorScheme.secondary,
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Yeni Strateji - Secondary Button
                          _ModernButton(
                            onPressed: () {
                              ref.read(planningStepProvider.notifier).state = PlanningStep.confirmation;
                            },
                            icon: Icons.refresh_rounded,
                            label: "Yeni Strateji Oluştur",
                            isPrimary: false,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _ActionCard(
      BuildContext context, {
        required String title,
        required String subtitle,
        required IconData icon,
        required VoidCallback onTap,
      }) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Row(
            children: [
              Icon(icon, size: 32, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
                    const SizedBox(height: 4),
                    Text(subtitle, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded, color: Theme.of(context).colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSealOfCommand(BuildContext context, WeeklyPlan weeklyPlan) {
    return Animate(
      onPlay: (controller) => controller.repeat(reverse: true),
      effects: [
        ShimmerEffect(
          duration: 4000.ms,
          color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
        ),
        ScaleEffect(
          curve: Curves.easeInOut,
          duration: 4000.ms,
          begin: const Offset(0.98, 0.98),
          end: const Offset(1, 1),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor.withOpacity(0.7),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.4)),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.15),
              blurRadius: 40,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          children: [
            const Icon(Icons.shield_moon_rounded, size: 56, color: Colors.green),
            const SizedBox(height: 16),
            Text(
              "Aktif Harekât Planı",
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              "Oluşturulma: ${DateFormat.yMMMMd('tr').format(weeklyPlan.creationDate)}",
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            const Divider(height: 32, indent: 20, endIndent: 20),
            Text(
              "Bu Haftanın Odağı:",
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              weeklyPlan.strategyFocus,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 600.ms);
  }

  Widget _buildDataMissingView(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textTheme = Theme.of(context).textTheme;

    return Center(
      key: const ValueKey('dataMissing'),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 450),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Lottie animasyonu
              Animate(
                effects: const [
                  FadeEffect(duration: Duration(milliseconds: 600)),
                  ScaleEffect(
                    begin: Offset(0.8, 0.8),
                    end: Offset(1.0, 1.0),
                    curve: Curves.easeOutBack,
                    duration: Duration(milliseconds: 600),
                  ),
                ],
                child: Lottie.asset(
                  'assets/lotties/Get things done.json',
                  width: 240,
                  height: 240,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 32),
              // Başlık
              Animate(
                effects: const [
                  FadeEffect(
                    delay: Duration(milliseconds: 300),
                    duration: Duration(milliseconds: 400),
                  ),
                ],
                child: Text(
                  "Strateji İçin Veri Gerekli",
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Açıklama
              Animate(
                effects: const [
                  FadeEffect(
                    delay: Duration(milliseconds: 500),
                    duration: Duration(milliseconds: 400),
                  ),
                ],
                child: Text(
                  "Sana özel bir strateji oluşturabilmem için önce düşmanı tanımam gerek. Lütfen en az bir deneme sonucu ekle.",
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              // Tıklanabilir kart - deneme arşivi gibi
              Animate(
                effects: const [
                  FadeEffect(
                    delay: Duration(milliseconds: 400),
                    duration: Duration(milliseconds: 500),
                  ),
                  SlideEffect(
                    begin: Offset(0, 0.15),
                    end: Offset.zero,
                    curve: Curves.easeOutCubic,
                    duration: Duration(milliseconds: 600),
                    delay: Duration(milliseconds: 400),
                  ),
                ],
                child: Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: InkWell(
                    onTap: () => context.push('/home/add-test'),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isDark
                              ? [
                            const Color(0xFF1A1F3A),
                            const Color(0xFF0F1729),
                          ]
                              : [
                            Colors.white,
                            const Color(0xFFF8F9FF),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isDark
                              ? const Color(0xFF2E3192).withValues(alpha: 0.3)
                              : const Color(0xFF2E3192).withValues(alpha: 0.15),
                          width: 1.5,
                        ),
                      ),
                      child: Column(
                        children: [
                          // Gradient Icon Container
                          Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: isDark
                                    ? [
                                  const Color(0xFF4D5FD1),
                                  const Color(0xFF1BFFFF),
                                ]
                                    : [
                                  const Color(0xFF2E3192),
                                  const Color(0xFF1BFFFF),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF2E3192).withValues(alpha: isDark ? 0.5 : 0.4),
                                  blurRadius: 16,
                                  offset: const Offset(0, 6),
                                ),
                                BoxShadow(
                                  color: const Color(0xFF1BFFFF).withValues(alpha: isDark ? 0.4 : 0.3),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
                                  spreadRadius: -4,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.add_chart_rounded,
                              color: Colors.white,
                              size: 36,
                            ),
                          ),
                          const SizedBox(height: 18),
                          // Gradient Text Başlık
                          ShaderMask(
                            shaderCallback: (bounds) => LinearGradient(
                              colors: isDark
                                  ? [
                                const Color(0xFF6B7FFF),
                                const Color(0xFF1BFFFF),
                              ]
                                  : [
                                const Color(0xFF2E3192),
                                const Color(0xFF1BFFFF),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ).createShader(bounds),
                            child: Text(
                              'İlk Denemeni Ekle',
                              style: textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w900,
                                fontSize: 22,
                                letterSpacing: -0.5,
                                color: Colors.white,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(height: 8),
                          // Açıklama
                          Text(
                            'Stratejini planlamaya başla',
                            style: textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              height: 1.4,
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.85)
                                  : Colors.black.withValues(alpha: 0.6),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ).animate(delay: 800.ms).shimmer(duration: 1500.ms),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConfirmationView(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userProfileProvider).value;
    final tests = ref.watch(testsProvider).valueOrNull ?? [];
    final performance = ref.watch(performanceProvider).value;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if(user == null || performance == null) return const Center(child: CircularProgressIndicator());

    final totalHours = user.weeklyAvailability.values.expand((slots) => slots).length * 2;
    final analyzedTopicsCount = performance.topicPerformances.values.expand((subject) => subject.values).where((topic) => topic.questionCount > 3).length;

    // DÜZELTME: Eskiden totalHours >= 10 kuralı vardı. Bu durum az saat seçen kullanıcıları engelliyordu.
    // Şimdi > 0 kontrolü ile en az bir slot seçilmesi yeterli.
    final isTimeMapOk = totalHours > 0;

    // DÜZELTME: Konu analizi (Galaxy) zorunluluğu kaldırıldı.
    // Kullanıcı henüz analiz yapmadıysa bile devam edebilir.
    final isGalaxyOk = true;

    final lastTestDate = tests.isNotEmpty ? tests.first.date : null;
    String testStatusText;
    bool isTestsOk;

    if (lastTestDate == null) {
      testStatusText = "Henüz deneme eklenmemiş (AI genel plan oluşturacak)";
      isTestsOk = true; // Test olmadan da plan oluşturulabilir
    } else {
      final daysSinceLastTest = DateTime.now().difference(lastTestDate).inDays;
      if (daysSinceLastTest == 0) {
        testStatusText = "Bugün eklendi";
      } else if (daysSinceLastTest == 1) {
        testStatusText = "Dün eklendi";
      } else {
        testStatusText = "$daysSinceLastTest gün önce";
      }
      isTestsOk = daysSinceLastTest <= 7;
    }

    return Container(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(0, -1.2),
          radius: 2.0,
          colors: isDark
              ? [
                  const Color(0xFF1A1F3A).withOpacity(0.3),
                  const Color(0xFF0A0E27),
                ]
              : [
                  Theme.of(context).colorScheme.primary.withOpacity(0.03),
                  const Color(0xFFF8F9FE),
                ],
        ),
      ),
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),
                  Text(
                    "Harekat Öncesi Son Kontrol",
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Tüm verilerin güncel olduğundan emin olalım",
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                  const SizedBox(height: 28),

                  _ChecklistItemCard(
                    icon: Icons.schedule_rounded,
                    title: "Zaman Haritası",
                    description: "Stratejin, haftalık olarak ayırdığın zamana göre şekillenecek.",
                    statusText: "$totalHours Saat",
                    statusDescription: "Haftalık Plan",
                    // isTimeMapOk artık > 0 olduğu için kullanıcı az saat seçse de yeşil yanacak
                    statusColor: isTimeMapOk ? Theme.of(context).colorScheme.secondary : Colors.amber,
                    buttonText: "Güncelle",
                    onTap: () => context.push(AppRoutes.availability),
                  ).animate().fadeIn(delay: 100.ms).slideX(begin: -0.15, curve: Curves.easeOut),

                  _ChecklistItemCard(
                    icon: Icons.insights_rounded,
                    title: "Ders Netlerim",
                    description: "Konu hakimiyetin, bu hafta hangi konulara odaklanacağımızı belirleyecek.",
                    statusText: "$analyzedTopicsCount",
                    statusDescription: "Konu Analiz Edildi",
                    // Her zaman yeşil yanar (zorunluluk kalktı)
                    statusColor: Theme.of(context).colorScheme.secondary,
                    buttonText: "Ziyaret Et",
                    onTap: () => context.push('/ai-hub/${AppRoutes.coachPushed}'),
                  ).animate().fadeIn(delay: 200.ms).slideX(begin: -0.15, curve: Curves.easeOut),

                  _ChecklistItemCard(
                    icon: Icons.history_edu_rounded,
                    title: "Deneme Arşivi",
                    description: "Güncel deneme sonuçların, planın isabet oranını doğrudan etkiler.",
                    statusText: "Son Deneme",
                    statusDescription: testStatusText,
                    statusColor: isTestsOk ? Theme.of(context).colorScheme.secondary : Colors.amber,
                    buttonText: "Yeni Ekle",
                    onTap: () => context.push('/home/add-test'),
                  ).animate().fadeIn(delay: 300.ms).slideX(begin: -0.15, curve: Curves.easeOut),

                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _ModernButton(
                  onPressed: isTimeMapOk && isGalaxyOk
                      ? () {
                          ref.read(planningStepProvider.notifier).state = PlanningStep.pacing;
                        }
                      : () {
                          if (!isTimeMapOk) {
                            context.push(AppRoutes.availability);
                          }
                        },
                  icon: isTimeMapOk && isGalaxyOk ? Icons.arrow_forward_rounded : Icons.info_outline_rounded,
                  label: isTimeMapOk && isGalaxyOk ? "Tüm Verilerim Güncel, İlerle" : "Zaman Haritasını Tamamla",
                  isPrimary: true,
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).colorScheme.primary,
                      Theme.of(context).colorScheme.secondary,
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn();
  }

  Widget _buildPacingView(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(0, -1.2),
          radius: 2.0,
          colors: isDark
              ? [
                  const Color(0xFF1A1F3A).withOpacity(0.3),
                  const Color(0xFF0A0E27),
                ]
              : [
                  Theme.of(context).colorScheme.primary.withOpacity(0.03),
                  const Color(0xFFF8F9FE),
                ],
        ),
      ),
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 20),
                  // Başlık Bölümü
                  Text(
                    "Haftalık Tempo Seçin",
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "Planınız seçtiğiniz tempoya göre optimize edilecek",
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),

                  // Pacing Cards
                  _PacingCard(
                    pacing: Pacing.relaxed,
                    icon: Icons.directions_walk_rounded,
                    title: "Rahat Tempo",
                    subtitle: "Temel tekrar ve konu pekiştirme odaklı yaklaşım",
                    isSelected: ref.watch(selectedPacingProvider) == Pacing.relaxed,
                    onTap: () => ref.read(selectedPacingProvider.notifier).state = Pacing.relaxed,
                  ).animate().fadeIn(delay: 100.ms).slideX(begin: -0.15, curve: Curves.easeOut),

                  const SizedBox(height: 12),

                  _PacingCard(
                    pacing: Pacing.moderate,
                    icon: Icons.directions_run_rounded,
                    title: "Dengeli Tempo",
                    subtitle: "Sağlam ve istikrarlı ilerleme stratejisi",
                    isSelected: ref.watch(selectedPacingProvider) == Pacing.moderate,
                    onTap: () => ref.read(selectedPacingProvider.notifier).state = Pacing.moderate,
                  ).animate().fadeIn(delay: 200.ms).slideX(begin: -0.15, curve: Curves.easeOut),

                  const SizedBox(height: 12),

                  _PacingCard(
                    pacing: Pacing.intense,
                    icon: Icons.rocket_launch_rounded,
                    title: "Yoğun Tempo",
                    subtitle: "Maksimum verimlilik ve yoğun çalışma programı",
                    isSelected: ref.watch(selectedPacingProvider) == Pacing.intense,
                    onTap: () => ref.read(selectedPacingProvider.notifier).state = Pacing.intense,
                  ).animate().fadeIn(delay: 300.ms).slideX(begin: -0.15, curve: Curves.easeOut),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),

          // Alt Butonlar
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _ModernButton(
                  onPressed: () => ref.read(strategyGenerationProvider.notifier).generatePlan(context),
                  icon: Icons.auto_awesome_rounded,
                  label: "Stratejiyi Oluştur",
                  isPrimary: true,
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).colorScheme.primary,
                      Theme.of(context).colorScheme.secondary,
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

// Modern Buton Widget - Instagram/Spotify Tarzı
class _ModernButton extends StatelessWidget {
  final VoidCallback onPressed;
  final IconData icon;
  final String label;
  final bool isPrimary;
  final Gradient? gradient;

  const _ModernButton({
    required this.onPressed,
    required this.icon,
    required this.label,
    this.isPrimary = false,
    this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (isPrimary) {
      return Container(
        decoration: BoxDecoration(
          gradient: gradient ??
              LinearGradient(
                colors: [
                  Theme.of(context).colorScheme.primary,
                  Theme.of(context).colorScheme.secondary,
                ],
              ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: Colors.white, size: 22),
                  const SizedBox(width: 12),
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.2, curve: Curves.easeOut);
    }

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2147).withOpacity(0.5) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
          width: 1.5,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: Theme.of(context).colorScheme.primary, size: 22),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.2, curve: Curves.easeOut);
  }
}

class _ChecklistItemCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final String statusText;
  final String statusDescription;
  final Color statusColor;
  final String buttonText;
  final VoidCallback onTap;

  const _ChecklistItemCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.statusText,
    required this.statusDescription,
    required this.statusColor,
    required this.buttonText,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  const Color(0xFF1E2147).withOpacity(0.6),
                  const Color(0xFF141729).withOpacity(0.4),
                ]
              : [
                  Colors.white,
                  const Color(0xFFF8F9FE),
                ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Theme.of(context).colorScheme.primary.withOpacity(0.15),
                        Theme.of(context).colorScheme.secondary.withOpacity(0.1),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: Theme.of(context).colorScheme.primary, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          height: 1.4,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14.0),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.4),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: statusColor.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          statusText,
                          style: textTheme.titleSmall?.copyWith(
                            color: statusColor,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          statusDescription,
                          style: textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                            fontSize: 12,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Theme.of(context).colorScheme.primary.withOpacity(0.1),
                            Theme.of(context).colorScheme.secondary.withOpacity(0.05),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: onTap,
                          borderRadius: BorderRadius.circular(10),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Text(
                              buttonText,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.primary,
                                letterSpacing: -0.2,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PacingCard extends StatelessWidget {
  final Pacing pacing;
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  const _PacingCard({
    required this.pacing,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        gradient: isSelected
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Theme.of(context).colorScheme.primary.withOpacity(isDark ? 0.25 : 0.15),
                  Theme.of(context).colorScheme.secondary.withOpacity(isDark ? 0.2 : 0.1),
                ],
              )
            : LinearGradient(
                colors: isDark
                    ? [
                        const Color(0xFF1E2147).withOpacity(0.5),
                        const Color(0xFF141729).withOpacity(0.3),
                      ]
                    : [
                        Colors.white,
                        const Color(0xFFF8F9FE),
                      ],
              ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isSelected
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
          width: isSelected ? 2.5 : 1.5,
        ),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.25),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.1 : 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Row(
              children: [
                // Icon Container
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: isSelected
                        ? LinearGradient(
                            colors: [
                              Theme.of(context).colorScheme.primary,
                              Theme.of(context).colorScheme.secondary,
                            ],
                          )
                        : LinearGradient(
                            colors: [
                              Theme.of(context).colorScheme.surfaceContainerHighest,
                              Theme.of(context).colorScheme.surfaceContainerHigh,
                            ],
                          ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: Theme.of(context).colorScheme.primary.withOpacity(0.4),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : null,
                  ),
                  child: Icon(
                    icon,
                    color: isSelected ? Colors.white : Theme.of(context).colorScheme.onSurfaceVariant,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                // Text Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.3,
                              color: isSelected ? Theme.of(context).colorScheme.primary : null,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                              height: 1.4,
                              fontSize: 13,
                            ),
                      ),
                    ],
                  ),
                ),
                // Selection Indicator
                if (isSelected)
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}