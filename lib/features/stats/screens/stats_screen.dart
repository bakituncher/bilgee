// lib/features/stats/screens/stats_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:taktik/data/models/exam_model.dart';
import 'package:taktik/data/models/test_model.dart';
import 'package:taktik/data/providers/firestore_providers.dart';
import 'package:taktik/core/theme/app_theme.dart';
import 'package:taktik/features/stats/widgets/fortress_tab_selector.dart';
import 'package:taktik/features/stats/widgets/cached_analysis_view.dart';
import 'package:taktik/features/quests/logic/quest_notifier.dart';
import 'package:taktik/shared/widgets/logo_loader.dart';
import 'dart:ui';

final selectedTabIndexProvider = StateProvider<int>((ref) => 0);

class StatsScreen extends ConsumerStatefulWidget {
  const StatsScreen({super.key});

  @override
  ConsumerState<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends ConsumerState<StatsScreen> {
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    // --- KALICI ÇÖZÜM ---
    // Ekran açılır açılmaz "engagement" kategorisindeki görevleri tetikle.
    // Bu, "Komutanın Raporu" görevinin tamamlanmasını sağlar.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(questNotifierProvider.notifier).userViewedStatsReport();
      }
    });
    // --- BİTTİ ---
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // Yükleme/hata/boş state'lerde sadece içerik döndür.
  Widget _buildLoadingState() => const Center(child: LogoLoader());

  Widget _buildErrorState(String error) => Center(child: Text(error));

  Widget _buildEmptyState(BuildContext context, {bool isCompletelyEmpty = false, String sectionName = ''}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    AppTheme.secondaryColor.withOpacity(0.2),
                    AppTheme.primaryColor.withOpacity(0.1),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Icon(
                Icons.insights_rounded,
                size: 60,
                color: AppTheme.secondaryColor,
              ),
            ).animate().scale(duration: 600.ms, curve: Curves.elasticOut),
            const SizedBox(height: 20),
            Text(
              'Kale Henüz İnşa Edilmedi',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ).animate().fadeIn(delay: 200.ms, duration: 400.ms),
            const SizedBox(height: 10),
            Text(
              isCompletelyEmpty
                  ? 'Stratejik analizleri ve fetih haritalarını görmek için deneme sonuçları ekleyerek kalenin temellerini atmalısın.'
                  : 'Bu cephede anlamlı bir strateji oluşturmak için en az 2 adet "$sectionName" denemesi eklemelisin.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.secondaryTextColor,
                height: 1.5,
              ),
            ).animate().fadeIn(delay: 300.ms, duration: 400.ms),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.lightSurfaceColor.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.secondaryColor.withOpacity(0.3),
                  width: 1.5,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.tips_and_updates_rounded,
                    color: AppTheme.secondaryColor, size: 18),
                  const SizedBox(width: 10),
                  Text(
                    'İlk denemeyi ekle ve yükselişini izle',
                    style: TextStyle(
                      color: AppTheme.secondaryColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(delay: 400.ms, duration: 400.ms).shimmer(
              delay: 1500.ms,
              duration: 1500.ms,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final testsAsyncValue = ref.watch(testsProvider);
    final userAsyncValue = ref.watch(userProfileProvider);

    ref.listen(selectedTabIndexProvider, (previous, next) {
      if (_pageController.hasClients && _pageController.page?.round() != next) {
        _pageController.animateToPage(
          next,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOut,
        );
      }
    });

    // Durumdan bağımsız tek Scaffold kullanmak için 'body'yi üret.
    final Widget body = userAsyncValue.when(
      data: (user) => testsAsyncValue.when(
        data: (tests) {
          if (user == null || tests.isEmpty) {
            return _buildEmptyState(context, isCompletelyEmpty: true);
          }

          final examType = ExamType.values.byName(user.selectedExam!);

          return FutureBuilder<Exam>(
            future: ExamData.getExamByType(examType),
            builder: (context, examSnapshot) {
              if (examSnapshot.connectionState == ConnectionState.waiting) {
                return _buildLoadingState();
              }
              if (examSnapshot.hasError || !examSnapshot.hasData) {
                return _buildErrorState('Sınav verileri yüklenemedi: ${examSnapshot.error}');
              }
              final exam = examSnapshot.data!;

              final groupedTests = <String, List<TestModel>>{};
              for (final test in tests) {
                (groupedTests[test.sectionName] ??= []).add(test);
              }

              final sortedGroups = groupedTests.entries.toList()
                ..sort((a, b) {
                  if (a.key == 'TYT') return -1;
                  if (b.key == 'TYT') return 1;
                  if (a.key.contains('Sayısal')) return -1;
                  if (b.key.contains('Sayısal')) return 1;
                  return a.key.compareTo(b.key);
                });

              if (sortedGroups.isEmpty) {
                return _buildEmptyState(context, isCompletelyEmpty: true);
              }

              final selectedIndex = ref.watch(selectedTabIndexProvider);
              if (selectedIndex >= sortedGroups.length) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    ref.read(selectedTabIndexProvider.notifier).state = 0;
                  }
                });
              }

              // İç Scaffold yerine içerik döndür.
              return Column(
                children: [
                  FortressTabSelector(
                    tabs: sortedGroups.map((e) => e.key).toList(),
                  ),
                  Expanded(
                    child: IndexedStack(
                      key: ValueKey('stack-${sortedGroups.map((e) => e.key).join('-')}'),
                      index: selectedIndex.clamp(0, sortedGroups.length - 1),
                      children: sortedGroups.map((entry) {
                        if (entry.value.length < 2) {
                          return _buildEmptyState(context, sectionName: entry.key);
                        }
                        return CachedAnalysisView(
                          key: ValueKey('analysis-${entry.key}'),
                          sectionName: entry.key,
                        );
                      }).toList(),
                    ),
                  ),
                ],
              );
            },
          );
        },
        loading: () => _buildLoadingState(),
        error: (err, stack) => _buildErrorState('Test verileri yüklenemedi: $err'),
      ),
      loading: () => _buildLoadingState(),
      error: (err, stack) => _buildErrorState('Kullanıcı verisi yüklenemedi: $err'),
    );

    return Scaffold(
      extendBodyBehindAppBar: false,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppTheme.primaryColor.withOpacity(0.05),
                AppTheme.secondaryColor.withOpacity(0.05),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            centerTitle: true,
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppTheme.secondaryColor,
                        AppTheme.secondaryColor.withOpacity(0.7),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.secondaryColor.withOpacity(0.25),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.insights_rounded,
                    color: AppTheme.primaryColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Deneme Gelişimi',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 350),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.02),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          );
        },
        child: body,
      ),
    );
  }
}