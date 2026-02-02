// lib/features/stats/screens/stats_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';
import 'package:taktik/data/models/exam_model.dart';
import 'package:taktik/data/models/test_model.dart';
import 'package:taktik/data/providers/firestore_providers.dart';
import 'package:taktik/data/providers/premium_provider.dart';
import 'package:taktik/data/providers/temporary_access_provider.dart';
import 'package:taktik/features/stats/widgets/fortress_tab_selector.dart';
import 'package:taktik/features/stats/widgets/cached_analysis_view.dart';
import 'package:taktik/features/quests/logic/quest_notifier.dart';
import 'package:taktik/shared/widgets/pro_badge.dart';

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
  Widget _buildLoadingState() => Center(
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: Theme.of(context).colorScheme.primary,
        ),
      );

  Widget _buildErrorState(String error) => Center(child: Text(error));

  Widget _buildTemporaryAccessBanner(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.secondary.withOpacity(0.2),
            Theme.of(context).colorScheme.secondary.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.secondary.withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.verified_rounded,
            color: Theme.of(context).colorScheme.secondary,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Geçici Erişim Aktif',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
          TextButton(
            onPressed: () => context.go('/premium'),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              'Pro\'ya Geç',
              style: TextStyle(
                color: Theme.of(context).colorScheme.secondary,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.2, end: 0);
  }

  Widget _buildEmptyState(BuildContext context, {bool isCompletelyEmpty = false, String sectionName = ''}) {
    return Center(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Lottie Animasyonu
              Container(
                constraints: const BoxConstraints(
                  maxWidth: 280,
                  maxHeight: 280,
                ),
                child: Lottie.asset(
                  'assets/lotties/cevher.json',
                  fit: BoxFit.contain,
                  repeat: true,
                ),
              ).animate()
                  .fadeIn(duration: 500.ms)
                  .scale(begin: const Offset(0.8, 0.8), duration: 600.ms, curve: Curves.easeOutBack),

              const SizedBox(height: 24),

              // Başlık
              Text(
                isCompletelyEmpty
                    ? 'Kale Henüz İnşa Edilmedi'
                    : 'Daha Fazla Veri Gerekli',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: 24,
                  letterSpacing: -0.5,
                ),
                textAlign: TextAlign.center,
              ).animate(delay: 200.ms)
                  .fadeIn(duration: 400.ms)
                  .slideY(begin: 0.1, duration: 500.ms),

              const SizedBox(height: 12),

              // Açıklama
              Text(
                isCompletelyEmpty
                    ? 'Stratejik analizleri ve fetih haritalarını görmek için deneme sonuçları ekleyerek kalenin temellerini atmalısın.'
                    : 'Bu cephede anlamlı bir strateji oluşturmak için en az 2 adet "$sectionName" denemesi eklemelisin.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.5,
                  fontSize: 15,
                ),
              ).animate(delay: 300.ms)
                  .fadeIn(duration: 400.ms)
                  .slideY(begin: 0.1, duration: 500.ms),

              const SizedBox(height: 32),

              // Deneme Ekle Butonu
              InkWell(
                onTap: () => context.push('/home/add-test'),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
                  constraints: const BoxConstraints(maxWidth: 320),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Theme.of(context).colorScheme.primary.withOpacity(0.2),
                        Theme.of(context).colorScheme.secondary.withOpacity(0.15),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.add_chart_rounded,
                          color: Theme.of(context).colorScheme.primary,
                          size: 32,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Deneme Ekle',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                          letterSpacing: -0.3,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Analizini başlatmak için ilk denemeni ekle',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w500,
                          fontSize: 13,
                          height: 1.3,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ).animate(delay: 400.ms)
                  .fadeIn(duration: 500.ms)
                  .slideY(begin: 0.15, duration: 600.ms, curve: Curves.easeOutCubic)
                  .shimmer(delay: 800.ms, duration: 1500.ms),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isPremium = ref.watch(premiumStatusProvider);
    final hasTemporaryAccess = ref.watch(hasPremiumFeaturesAccessProvider);

    // Artık herkes ekrana girebilir - premium kontrol sekme bazında yapılacak

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
          // Sadece ana sınav denemeleri gösterilsin (branş denemeleri hariç)
          final mainExamTests = tests.where((t) => !t.isBranchTest).toList();

          if (user == null || mainExamTests.isEmpty) {
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
              for (final test in mainExamTests) {
                // --- DÜZELTME: Normalizasyon ---
                // Eğer bölüm adı "Yabancı Dil" ise bunu "YDT" olarak kabul et
                String sectionKey = test.sectionName;
                if (sectionKey == 'Yabancı Dil') {
                  sectionKey = 'YDT';
                }

                (groupedTests[sectionKey] ??= []).add(test);
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
        preferredSize: const Size.fromHeight(kToolbarHeight + 8),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Theme.of(context).scaffoldBackgroundColor,
                Theme.of(context).scaffoldBackgroundColor.withOpacity(0.95),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0,
            centerTitle: false,
            titleSpacing: 12,
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Theme.of(context).colorScheme.primary,
                        Theme.of(context).colorScheme.secondary,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Theme.of(context).colorScheme.primary.withOpacity(0.35),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.insights_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Deneme Gelişimi',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          letterSpacing: -0.5,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Performans takibi',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 10,
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              if (isPremium)
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => context.push('/premium'),
                    child: const ProBadge(
                      fontSize: 10,
                      horizontalPadding: 8,
                      verticalPadding: 4,
                      borderRadius: 8,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          // Geçici erişim banner'ı (sadece premium değilse ve geçici erişimi varsa)
          if (!isPremium && hasTemporaryAccess)
            _buildTemporaryAccessBanner(context),
          Expanded(
            child: AnimatedSwitcher(
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
          ),
        ],
      ),
    );
  }
}