// lib/features/strategic_planning/screens/strategic_planning_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:taktik/data/repositories/ai_service.dart';
import 'package:taktik/data/providers/firestore_providers.dart';
import 'package:taktik/core/theme/app_theme.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:taktik/data/models/user_model.dart';
import 'package:taktik/core/navigation/app_routes.dart';
import 'package:intl/intl.dart';
import 'package:taktik/data/models/plan_model.dart';
import 'package:taktik/data/models/plan_document.dart';


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
            backgroundColor: AppTheme.accentColor,
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
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator(color: AppTheme.secondaryColor))),
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
        return Center(
            key: const ValueKey('loading'),
            child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(color: AppTheme.secondaryColor),
                  const SizedBox(height: 24),
                  Text("Strateji güncelleniyor,\nbekleyin komutanım...",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppTheme.secondaryTextColor, fontSize: 16)
                  )
                ]
            )
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildStrategyDisplay(BuildContext context, WidgetRef ref, UserModel user, PlanDocument planDoc) {
    final weeklyPlan = WeeklyPlan.fromJson(planDoc.weeklyPlan!);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Stratejik Plan"),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0, -1.2),
            radius: 1.5,
            colors: [AppTheme.secondaryColor.withValues(alpha: AppTheme.secondaryColor.a * 0.1), AppTheme.primaryColor],
            stops: const [0.0, 0.7],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    elevation: 0,
                    clipBehavior: Clip.antiAlias,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 28.0, horizontal: 24.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppTheme.secondaryColor.withValues(alpha: AppTheme.secondaryColor.a * 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.calendar_month_rounded, size: 40, color: AppTheme.secondaryColor),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            "Stratejik Plan Hazır",
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            "Bu haftanın odağı",
                            style: Theme.of(context).textTheme.labelLarge?.copyWith(color: AppTheme.secondaryTextColor),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                            decoration: BoxDecoration(
                              color: AppTheme.lightSurfaceColor.withValues(alpha: AppTheme.lightSurfaceColor.a * 0.35),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppTheme.lightSurfaceColor.withValues(alpha: AppTheme.lightSurfaceColor.a * 0.5)),
                            ),
                            child: Text(
                              weeklyPlan.strategyFocus,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            "Oluşturulma: ${DateFormat.yMMMMd('tr').format(weeklyPlan.creationDate)}",
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.secondaryTextColor),
                          ),
                        ],
                      ),
                    ),
                  ).animate().fadeIn(duration: 300.ms).scale(begin: const Offset(0.98, 0.98), curve: Curves.easeOut),

                  const SizedBox(height: 20),

                  ElevatedButton.icon(
                    onPressed: () => context.push('/home/weekly-plan'),
                    icon: const Icon(Icons.playlist_add_check_rounded),
                    label: const Text("Haftalık Planı Aç"),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () {
                      ref.read(planningStepProvider.notifier).state = PlanningStep.confirmation;
                    },
                    icon: const Icon(Icons.auto_awesome),
                    label: const Text("Yeni Strateji Oluştur"),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _ActionCard({
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
              Icon(icon, size: 32, color: AppTheme.secondaryColor),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                    const SizedBox(height: 4),
                    Text(subtitle, style: const TextStyle(color: AppTheme.secondaryTextColor)),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded, color: AppTheme.secondaryTextColor),
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
          color: AppTheme.secondaryColor.withValues(alpha: AppTheme.secondaryColor.a * 0.1),
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
          color: AppTheme.cardColor.withValues(alpha: AppTheme.cardColor.a * 0.7),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppTheme.secondaryColor.withValues(alpha: AppTheme.secondaryColor.a * 0.4)),
          boxShadow: [
            BoxShadow(
              color: AppTheme.secondaryColor.withValues(alpha: AppTheme.secondaryColor.a * 0.15),
              blurRadius: 40,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          children: [
            const Icon(Icons.shield_moon_rounded, size: 56, color: AppTheme.successColor),
            const SizedBox(height: 16),
            Text(
              "Aktif Harekât Planı",
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              "Oluşturulma: ${DateFormat.yMMMMd('tr').format(weeklyPlan.creationDate)}",
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.secondaryTextColor),
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
                color: AppTheme.secondaryTextColor,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 600.ms);
  }

  Widget _buildDataMissingView(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.report_problem_outlined, color: Colors.amber, size: 64),
            const SizedBox(height: 24),
            Text(
              "Strateji İçin Veri Gerekli",
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              "Sana özel bir strateji oluşturabilmem için önce düşmanı tanımam gerek. Lütfen en az bir deneme sonucu ekle.",
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppTheme.secondaryTextColor),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => context.push('/home/add-test'),
              icon: const Icon(Icons.add_chart_rounded),
              label: const Text("İlk Denemeni Ekle"),
            )
          ],
        ).animate().fadeIn(),
      ),
    );
  }

  Widget _buildConfirmationView(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userProfileProvider).value;
    final tests = ref.watch(testsProvider).valueOrNull ?? [];
    final performance = ref.watch(performanceProvider).value;

    if(user == null || performance == null) return const Center(child: CircularProgressIndicator());

    final totalHours = user.weeklyAvailability.values.expand((slots) => slots).length * 2;
    final analyzedTopicsCount = performance.topicPerformances.values.expand((subject) => subject.values).where((topic) => topic.questionCount > 3).length;
    final isTimeMapOk = totalHours >= 10;
    final isGalaxyOk = analyzedTopicsCount >= 5;

    final lastTestDate = tests.isNotEmpty ? tests.first.date : null;
    String testStatusText;
    bool isTestsOk;

    if (lastTestDate == null) {
      testStatusText = "Hiç deneme eklenmemiş";
      isTestsOk = false;
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

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Harekat Öncesi Son Kontrol",
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  "En isabetli strateji için tüm verilerinin güncel olduğundan emin olalım.",
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppTheme.secondaryTextColor),
                ),
                const SizedBox(height: 32),

                _ChecklistItemCard(
                  icon: Icons.map_rounded,
                  title: "Zaman Haritası",
                  description: "Stratejin, haftalık olarak ayırdığın zamana göre şekillenecek.",
                  statusText: "$totalHours Saat",
                  statusDescription: "Haftalık Plan",
                  statusColor: isTimeMapOk ? AppTheme.successColor : Colors.amber,
                  buttonText: "Güncelle",
                  onTap: () => context.push(AppRoutes.availability),
                ).animate().fadeIn(delay: 200.ms).slideX(begin: -0.2),

                _ChecklistItemCard(
                  icon: Icons.insights_rounded,
                  title: "Ders Netlerim",
                  description: "Konu hakimiyetin, bu hafta hangi konulara odaklanacağımızı belirleyecek.",
                  statusText: "$analyzedTopicsCount",
                  statusDescription: "Konu Analiz Edildi",
                  statusColor: isGalaxyOk ? AppTheme.successColor : Colors.amber,
                  buttonText: "Ziyaret Et",
                  onTap: () => context.push('/ai-hub/${AppRoutes.coachPushed}'),
                ).animate().fadeIn(delay: 300.ms).slideX(begin: -0.2),

                _ChecklistItemCard(
                  icon: Icons.history_edu_rounded,
                  title: "Deneme Arşivi",
                  description: "Güncel deneme sonuçların, planın isabet oranını doğrudan etkiler.",
                  statusText: "Son Deneme",
                  statusDescription: testStatusText,
                  statusColor: isTestsOk ? AppTheme.successColor : Colors.amber,
                  buttonText: "Yeni Ekle",
                  onTap: () => context.push('/home/add-test'),
                ).animate().fadeIn(delay: 400.ms).slideX(begin: -0.2),

              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(24.0),
          child: ElevatedButton(
            onPressed: () {
              ref.read(planningStepProvider.notifier).state = PlanningStep.pacing;
            },
            child: const Text("Tüm Verilerim Güncel, İlerle"),
          ),
        ),
      ],
    ).animate().fadeIn();
  }

  Widget _buildPacingView(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "Haftalık Taarruz Temponu Seç",
                  style: Theme.of(context).textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  "Planın yoğunluğu, seçtiğin tempoya göre ayarlanacak.",
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppTheme.secondaryTextColor),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                _PacingCard(
                  pacing: Pacing.relaxed,
                  icon: Icons.directions_walk_rounded,
                  title: "Rahat Tempo",
                  subtitle: "Temel tekrar ve konu pekiştirme.",
                  isSelected: ref.watch(selectedPacingProvider) == Pacing.relaxed,
                  onTap: () => ref.read(selectedPacingProvider.notifier).state = Pacing.relaxed,
                ).animate().fadeIn(delay: 200.ms).slideX(begin: -0.2),
                _PacingCard(
                  pacing: Pacing.moderate,
                  icon: Icons.directions_run_rounded,
                  title: "Dengeli Tempo",
                  subtitle: "Sağlam ve istikrarlı ilerleme.",
                  isSelected: ref.watch(selectedPacingProvider) == Pacing.moderate,
                  onTap: () => ref.read(selectedPacingProvider.notifier).state = Pacing.moderate,
                ).animate().fadeIn(delay: 300.ms).slideX(begin: -0.2),
                _PacingCard(
                  pacing: Pacing.intense,
                  icon: Icons.rocket_launch_rounded,
                  title: "Yoğun Tempo",
                  subtitle: "Maksimum odaklanma ve tam taarruz.",
                  isSelected: ref.watch(selectedPacingProvider) == Pacing.intense,
                  onTap: () => ref.read(selectedPacingProvider.notifier).state = Pacing.intense,
                ).animate().fadeIn(delay: 400.ms).slideX(begin: -0.2),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ElevatedButton.icon(
                onPressed: () => ref.read(strategyGenerationProvider.notifier).generatePlan(context),
                icon: const Icon(Icons.auto_awesome),
                label: const Text("Stratejiyi Oluştur"),
              ),
              TextButton(
                  onPressed: () {
                    ref.read(planningStepProvider.notifier).state = PlanningStep.confirmation;
                  },
                  child: const Text("Geri Dön")),
            ],
          ),
        )
      ],
    );
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
    return Card(
      margin: const EdgeInsets.only(bottom: 20),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: AppTheme.secondaryTextColor, size: 28),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: textTheme.titleLarge),
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: textTheme.bodyMedium?.copyWith(color: AppTheme.secondaryTextColor, height: 1.4),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: AppTheme.lightSurfaceColor.withValues(alpha: AppTheme.lightSurfaceColor.a * 0.3),
                borderRadius: BorderRadius.circular(12),
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
                          style: textTheme.headlineSmall?.copyWith(
                            color: statusColor,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          statusDescription,
                          style: textTheme.bodyMedium?.copyWith(color: AppTheme.secondaryTextColor),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: TextButton(
                      onPressed: onTap,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: Text(buttonText),
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
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isSelected ? AppTheme.secondaryColor : AppTheme.lightSurfaceColor.withValues(alpha: AppTheme.lightSurfaceColor.a * 0.5),
          width: 2,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Row(
            children: [
              Icon(icon, size: 32, color: isSelected ? AppTheme.secondaryColor : AppTheme.secondaryTextColor),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isSelected ? AppTheme.secondaryColor : Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.secondaryTextColor),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              AnimatedOpacity(
                opacity: isSelected ? 1.0 : 0.0,
                duration: 200.ms,
                child: const Icon(Icons.check_circle_rounded, color: AppTheme.secondaryColor),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

