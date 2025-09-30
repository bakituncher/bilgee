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

  Widget _buildLoadingState() {
    return Scaffold(
      appBar: AppBar(title: const Text('Deneme Gelişimi')),
      body: const LogoLoader(),
    );
  }

  Widget _buildErrorState(String error) {
    return Scaffold(
      appBar: AppBar(title: const Text('Deneme Gelişimi')),
      body: Center(child: Text(error)),
    );
  }

  Widget _buildEmptyState(BuildContext context, {bool isCompletelyEmpty = false, String sectionName = ''}) {
    return Scaffold(
      appBar: AppBar(title: const Text('Deneme Gelişimi')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.insights_rounded, size: 80, color: AppTheme.secondaryTextColor),
              const SizedBox(height: 16),
              Text(
                'Kale Henüz İnşa Edilmedi',
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                isCompletelyEmpty
                    ? 'Stratejik analizleri ve fetih haritalarını görmek için deneme sonuçları ekleyerek kalenin temellerini atmalısın.'
                    : 'Bu cephede anlamlı bir strateji oluşturmak için en az 2 adet "$sectionName" denemesi eklemelisin.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppTheme.secondaryTextColor, height: 1.5),
              ),
            ],
          ).animate().fadeIn(duration: 600.ms).scale(begin: const Offset(0.8, 0.8)),
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

    return userAsyncValue.when(
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

              return Scaffold(
                appBar: AppBar(
                  title: const Text('Deneme Gelişimi'),
                ),
                body: Column(
                  children: [
                    FortressTabSelector(
                      tabs: sortedGroups.map((e) => e.key).toList(),
                    ),
                    Expanded(
                      child: PageView(
                        controller: _pageController,
                        onPageChanged: (index) {
                          ref.read(selectedTabIndexProvider.notifier).state = index;
                        },
                        children: sortedGroups.map((entry) {
                          if(entry.value.length < 2) {
                            return _buildEmptyState(context, sectionName: entry.key);
                          }
                          return CachedAnalysisView(
                            key: ValueKey(entry.key),
                            sectionName: entry.key,
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
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
  }
}