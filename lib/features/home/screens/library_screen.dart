// lib/features/home/screens/library_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:taktik/data/models/test_model.dart';
import 'package:taktik/data/providers/firestore_providers.dart';
import 'package:taktik/data/providers/premium_provider.dart';
import 'package:taktik/data/providers/temporary_access_provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:taktik/features/quests/logic/quest_notifier.dart';
import 'package:taktik/shared/widgets/logo_loader.dart';
import 'package:lottie/lottie.dart';

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  final ScrollController _scrollController = ScrollController();
  final List<TestModel> _tests = [];
  bool _isLoading = false;
  bool _hasMore = true;
  static const int _pageSize = 10; // 20 -> 10
  DocumentSnapshot? _lastVisible; // UI tarafında doküman referansı tutacağız

  // YENI: UI durumları
  String _searchQuery = '';
  String _selectedSection = 'Tümü';
  _SortOption _sortOption = const _SortOption(field: _SortField.date, descending: true);

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadInitial();
    // Engagement: Kütüphane ziyareti eylemini bildir
    WidgetsBinding.instance.addPostFrameCallback((_){
      if (!mounted) return;
      ref.read(questNotifierProvider.notifier).userVisitedLibrary();
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients || _isLoading || !_hasMore) return;
    const threshold = 200.0;
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - threshold) {
      _loadMore();
    }
  }

  Future<void> _syncLastVisibleFromLastItem() async {
    if (_tests.isEmpty) {
      _lastVisible = null;
      return;
    }
    final lastId = _tests.last.id;
    final snap = await FirebaseFirestore.instance.collection('tests').doc(lastId).get();
    _lastVisible = snap;
  }

  Future<void> _loadInitial() async {
    final service = ref.read(firestoreServiceProvider);
    final userId = service.getUserId();
    if (userId == null) return;
    setState(() => _isLoading = true);
    try {
      final items = await service.getTestResultsPaginated(userId, limit: _pageSize);
      setState(() {
        _tests.clear();
        _tests.addAll(items);
        _hasMore = items.length == _pageSize;
      });
      await _syncLastVisibleFromLastItem();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_isLoading || !_hasMore) return;
    final service = ref.read(firestoreServiceProvider);
    final userId = service.getUserId();
    if (userId == null) return;
    setState(() => _isLoading = true);
    try {
      // _lastVisible yoksa senkronize et
      if (_lastVisible == null && _tests.isNotEmpty) {
        await _syncLastVisibleFromLastItem();
      }
      final items = await service.getTestResultsPaginated(userId, lastVisible: _lastVisible, limit: _pageSize);
      if (items.isEmpty) {
        setState(() => _hasMore = false);
        return;
      }
      setState(() {
        _tests.addAll(items);
        _hasMore = items.length == _pageSize;
      });
      await _syncLastVisibleFromLastItem();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/home');
            }
          },
        ),
        title: const Text('Deneme Arşivi'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          // Sıralama
          IconButton(
            tooltip: 'Sırala',
            icon: const Icon(Icons.sort_rounded),
            onPressed: _showSortSheet,
          ),
        ],
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
                    theme.cardColor.withValues(alpha: 0.5),
                  ]
                : [
                    theme.scaffoldBackgroundColor,
                    theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                  ],
          ),
        ),
        child: _buildBody(textTheme),
      ),
    );
  }

  // YENI: Filtre/Sıralama uygulayan yardımcı
  List<TestModel> _applyFiltersAndSort() {
    Iterable<TestModel> list = _tests;
    // Arama
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((t) => t.testName.toLowerCase().contains(q));
    }
    // Bölüm filtresi
    if (_selectedSection != 'Tümü') {
      list = list.where((t) => t.sectionName == _selectedSection);
    }

    var tmp = list.toList();

    int compareByField(TestModel a, TestModel b) {
      switch (_sortOption.field) {
        case _SortField.date:
          return a.date.compareTo(b.date);
        case _SortField.net:
          return a.totalNet.compareTo(b.totalNet);
        case _SortField.accuracy:
          final accA = _accuracy(a);
          final accB = _accuracy(b);
          return accA.compareTo(accB);
      }
    }

    tmp.sort(compareByField);
    if (_sortOption.descending) {
      tmp = tmp.reversed.toList();
    }
    return tmp;
  }

  double _accuracy(TestModel t) {
    // Doğruluk: boş sorular da yüzdelik hesabında paydada yer almalı.
    // Önceki hali: correct/(correct+wrong) -> boşlar %'yi şişiriyordu.
    final total = t.totalCorrect + t.totalWrong + t.totalBlank;
    if (total == 0) return 0.0; // Hiç soru yoksa 0%
    return (t.totalCorrect / total) * 100.0;
  }

  // YENI: Mevcut bölümler
  List<String> _availableSections() {
    final set = <String>{}..addAll(_tests.map((e) => e.sectionName));
    final list = set.toList()..sort();
    return ['Tümü', ...list];
  }

  // YENI: Sıralama alt sayfası
  void _showSortSheet() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      backgroundColor: Theme.of(context).cardColor,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.today_rounded),
                title: const Text('Tarih'),
                trailing: _sortOption.field == _SortField.date ? _sortIcon() : null,
                onTap: () => setState(() {
                  _sortOption = _SortOption(field: _SortField.date, descending: _sortOption.field == _SortField.date ? !_sortOption.descending : true);
                  Navigator.pop(ctx);
                }),
              ),
              ListTile(
                leading: const Icon(Icons.score_rounded),
                title: const Text('Toplam Net'),
                trailing: _sortOption.field == _SortField.net ? _sortIcon() : null,
                onTap: () => setState(() {
                  _sortOption = _SortOption(field: _SortField.net, descending: _sortOption.field == _SortField.net ? !_sortOption.descending : true);
                  Navigator.pop(ctx);
                }),
              ),
              ListTile(
                leading: const Icon(Icons.check_circle_outline_rounded),
                title: const Text('Doğruluk'),
                trailing: _sortOption.field == _SortField.accuracy ? _sortIcon() : null,
                onTap: () => setState(() {
                  _sortOption = _SortOption(field: _SortField.accuracy, descending: _sortOption.field == _SortField.accuracy ? !_sortOption.descending : true);
                  Navigator.pop(ctx);
                }),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _sortIcon() {
    return Icon(_sortOption.descending ? Icons.south_rounded : Icons.north_rounded, color: Theme.of(context).colorScheme.primary);
  }

  Widget _buildBody(TextTheme textTheme) {
    if (_tests.isEmpty && _isLoading) {
      return const LogoLoader();
    }
    if (_tests.isEmpty) {
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
                    'assets/lotties/empty.json',
                    fit: BoxFit.contain,
                    repeat: true,
                  ),
                ).animate()
                  .fadeIn(duration: 500.ms)
                  .scale(begin: const Offset(0.8, 0.8), duration: 600.ms, curve: Curves.easeOutBack),

                const SizedBox(height: 24),

                // Başlık
                Text(
                  'Arşivin Henüz Boş',
                  style: textTheme.titleLarge?.copyWith(
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
                  'Her deneme, gelecekteki başarın için bir kanıtıdır. İlk kaydını ekleyerek yolculuğuna başla ve gelişimini takip et.',
                  textAlign: TextAlign.center,
                  style: textTheme.bodyMedium?.copyWith(
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
                          Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                          Theme.of(context).colorScheme.secondary.withValues(alpha: 0.15),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
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
                            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
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
                          'İlk Denemeni Ekle',
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                            letterSpacing: -0.3,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Başarı yolculuğunu arşivlemeye başla',
                          style: textTheme.bodySmall?.copyWith(
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

    final filtered = _applyFiltersAndSort();

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      children: [
        // Arama ve filtre barı - compact ve elegant
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark
                        ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.3)
                        : colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                    width: 1,
                  ),
                  boxShadow: isDark
                      ? []
                      : [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                ),
                child: TextField(
                  decoration: InputDecoration(
                    prefixIcon: Icon(Icons.search_rounded, color: colorScheme.primary),
                    hintText: 'Deneme adı ara...',
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  onChanged: (v) => setState(() => _searchQuery = v),
                ),
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _availableSections().map((s) {
                    final selected = _selectedSection == s;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6.0),
                      child: FilterChip(
                        label: Text(
                          s,
                          style: textTheme.labelMedium?.copyWith(
                            fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                        selected: selected,
                        onSelected: (_) => setState(() => _selectedSection = s),
                        backgroundColor: theme.cardColor,
                        selectedColor: colorScheme.primary.withValues(alpha: 0.15),
                        checkmarkColor: colorScheme.primary,
                        side: BorderSide(
                          color: selected
                              ? colorScheme.primary.withValues(alpha: 0.5)
                              : colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                          width: 1,
                        ),
                        labelStyle: TextStyle(
                          color: selected ? colorScheme.primary : colorScheme.onSurface,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              _lastVisible = null;
              await _loadInitial();
            },
            child: ListView.separated(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              itemCount: filtered.length + (_isLoading || _hasMore ? 1 : 0),
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                if (index >= filtered.length) {
                  return Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Center(child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary)),
                  );
                }
                final test = filtered[index];
                return _ArchiveListTile(test: test);
              },
            ),
          ),
        ),
      ],
    );
  }
}

// YENI: Sıralama seçenekleri
enum _SortField { date, net, accuracy }

class _SortOption {
  final _SortField field;
  final bool descending;
  const _SortOption({required this.field, required this.descending});
}

// YENI: Liste görünümü satırı
class _ArchiveListTile extends ConsumerWidget {
  final TestModel test;
  const _ArchiveListTile({required this.test});

  double _accuracy(TestModel t) {
    // Doğruluk: boş sorular da yüzdelik hesabında paydada yer almalı.
    final total = t.totalCorrect + t.totalWrong + t.totalBlank;
    if (total == 0) return 0.0;
    return (t.totalCorrect / total) * 100.0;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final acc = _accuracy(test);
    final isDark = theme.brightness == Brightness.dark;
    final isPremium = ref.watch(premiumStatusProvider);
    final hasTemporaryAccess = ref.watch(hasPremiumFeaturesAccessProvider);

    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.3)
              : colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
          width: 1.5,
        ),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            if (isPremium || hasTemporaryAccess) {
              context.push('/home/test-result-summary', extra: test);
            } else {
              context.push('/stats-premium-offer?source=archive');
            }
          },
          onLongPress: () => context.push('/home/test-detail', extra: test),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
            child: Row(
              children: [
                // Sol rozet - daha compact
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        colorScheme.primary.withValues(alpha: 0.15),
                        colorScheme.secondary.withValues(alpha: 0.1),
                      ],
                    ),
                    border: Border.all(
                      color: colorScheme.primary.withValues(alpha: 0.2),
                      width: 1,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    test.totalNet.toStringAsFixed(1),
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Orta içerik - daha compact
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Hero(
                        tag: 'test_title_${test.id}',
                        child: Material(
                          color: Colors.transparent,
                          child: Text(
                            test.testName,
                            style: textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${test.sectionName} • ${DateFormat.yMd('tr').format(test.date)}',
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Sağ metrikler - daha compact ve elegant
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: colorScheme.secondary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: colorScheme.secondary.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle_rounded, size: 14, color: colorScheme.secondary),
                          const SizedBox(width: 3),
                          Text(
                            '%${acc.toStringAsFixed(0)}',
                            style: textTheme.labelLarge?.copyWith(
                              color: colorScheme.secondary,
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${test.totalCorrect}/${test.totalWrong}/${test.totalBlank}',
                        style: textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: 10,
                        ),
                      ),
                    ],
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
