// lib/features/home/screens/library_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:taktik/data/models/test_model.dart';
import 'package:taktik/data/models/exam_model.dart';
import 'package:taktik/data/providers/firestore_providers.dart';
import 'package:taktik/data/providers/premium_provider.dart';
import 'package:taktik/data/providers/temporary_access_provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:taktik/features/quests/logic/quest_notifier.dart';
import 'package:taktik/shared/widgets/logo_loader.dart';
import 'package:lottie/lottie.dart';
import 'dart:ui';

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
  static const int _pageSize = 50;
  DocumentSnapshot? _lastVisible;

  String _searchQuery = '';
  String _selectedCategory = 'Tümü';
  _SortOption _sortOption = const _SortOption(field: _SortField.date, descending: true);

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadInitial();
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

  Future<void> _loadInitial({bool showLoader = true}) async {
    final service = ref.read(firestoreServiceProvider);
    final userId = service.getUserId();
    if (userId == null) return;

    if (showLoader) {
      setState(() => _isLoading = true);
    }

    try {
      final items = await service.getTestResultsPaginated(userId, limit: _pageSize);
      setState(() {
        _tests.clear();
        _tests.addAll(items);
        _hasMore = items.length == _pageSize;
      });
      await _syncLastVisibleFromLastItem();
    } finally {
      if (showLoader && mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadMore() async {
    if (_isLoading || !_hasMore) return;
    final service = ref.read(firestoreServiceProvider);
    final userId = service.getUserId();
    if (userId == null) return;
    setState(() => _isLoading = true);
    try {
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

  // --- YARDIMCI METODLAR ---

  // AGS Ortak sınav bölümleri (ÖABT'den ayırt etmek için)
  static const _agsCommonSections = {
    'Genel Yetenek',
    'Genel Kültür ve Eğitim Bilgisi',
    'AGS',
    'AGS Ortak',
  };

  // Filtreleme için kategori belirleme (UI'da göstermiyoruz ama filtrede kullanıyoruz)
  String _getDisplayCategory(TestModel test) {
    if (test.isBranchTest) {
      return test.smartDisplayName; // "Türkçe", "Matematik" vb.
    }

    // AGS - ÖABT ayrımı
    if (test.examType == ExamType.ags) {
      // sectionName AGS ortak bölümlerinden biri mi kontrol et
      if (_agsCommonSections.contains(test.sectionName)) {
        return 'AGS';
      }
      // Değilse ÖABT branşı
      return 'ÖABT';
    }

    // YKS - TYT/AYT ayrımı
    if (test.examType == ExamType.yks) {
      final sectionUpper = test.sectionName.toUpperCase();
      final testNameUpper = test.testName.toUpperCase();

      // sectionName'e göre TYT mi AYT mi kontrol et
      if (sectionUpper.contains('TYT')) {
        return 'TYT';
      } else if (sectionUpper.contains('AYT')) {
        return 'AYT';
      } else if (sectionUpper.contains('YDT')) { // - YDT kontrolü eklendi
        return 'YDT';
      }

      // Eğer sectionName'de bulamazsak, testName'e bakalım
      if (testNameUpper.contains('TYT')) {
        return 'TYT';
      } else if (testNameUpper.contains('AYT')) {
        return 'AYT';
      } else if (testNameUpper.contains('YDT')) { // - YDT kontrolü eklendi
        return 'YDT';
      }
    }

    // Ana deneme ise Sınav Türünü kullan (Örn: KPSS Lisans)
    return test.examType.displayName;
  }

  List<TestModel> _applyFiltersAndSort() {
    Iterable<TestModel> list = _tests;

    // Arama
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((t) => t.testName.toLowerCase().contains(q));
    }

    // Kategori filtresi
    if (_selectedCategory != 'Tümü') {
      list = list.where((t) => _getDisplayCategory(t) == _selectedCategory);
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
    final total = t.totalCorrect + t.totalWrong + t.totalBlank;
    if (total == 0) return 0.0;
    return (t.totalCorrect / total) * 100.0;
  }

  List<String> _availableCategories() {
    final set = <String>{};
    for (final t in _tests) {
      set.add(_getDisplayCategory(t));
    }
    final list = set.toList()..sort();
    return ['Tümü', ...list];
  }

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

  static const Color _colDeepBlue = Color(0xFF2E3192);
  static const Color _colCyan = Color(0xFF1BFFFF);

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 22,
            color: theme.colorScheme.onSurface.withOpacity(0.9),
          ),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/home');
            }
          },
        ),
        title: Text(
          'Deneme Arşivi',
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
        actions: [
          IconButton(
            tooltip: 'Sırala',
            icon: Icon(
              Icons.sort_rounded,
              color: theme.colorScheme.onSurface.withOpacity(0.9),
            ),
            onPressed: _showSortSheet,
          ),
        ],
      ),
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
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
          _buildBody(textTheme),
        ],
      ),
    );
  }

  Widget _buildBody(TextTheme textTheme) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Cihazın alt güvenli alan boşluğunu alıyoruz
    final bottomPadding = MediaQuery.of(context).padding.bottom;

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
                Container(
                  constraints: const BoxConstraints(maxWidth: 280, maxHeight: 280),
                  child: Lottie.asset('assets/lotties/empty.json', fit: BoxFit.contain, repeat: true),
                ).animate().fadeIn(duration: 500.ms).scale(begin: const Offset(0.8, 0.8), duration: 600.ms, curve: Curves.easeOutBack),
                const SizedBox(height: 24),
                Text(
                  'Arşivin Henüz Boş',
                  style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800, fontSize: 24, letterSpacing: -0.5),
                  textAlign: TextAlign.center,
                ).animate(delay: 200.ms).fadeIn(duration: 400.ms).slideY(begin: 0.1, duration: 500.ms),
                const SizedBox(height: 12),
                Text(
                  'Her deneme, gelecekteki başarının bir kanıtıdır. İlk kaydını ekleyerek yolculuğuna başla ve gelişimini takip et.',
                  textAlign: TextAlign.center,
                  style: textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant, height: 1.5, fontSize: 15),
                ).animate(delay: 300.ms).fadeIn(duration: 400.ms).slideY(begin: 0.1, duration: 500.ms),
                const SizedBox(height: 32),
                InkWell(
                  onTap: () => context.push('/home/add-test'),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                    constraints: const BoxConstraints(maxWidth: 340),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: isDark
                            ? [const Color(0xFF3D4DB7).withOpacity(0.35), const Color(0xFF1BFFFF).withOpacity(0.25)]
                            : [const Color(0xFF2E3192).withOpacity(0.08), const Color(0xFF1BFFFF).withOpacity(0.05)],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: isDark ? const Color(0xFF1BFFFF).withOpacity(0.5) : const Color(0xFF2E3192).withOpacity(0.25), width: 2),
                      boxShadow: [
                        BoxShadow(color: const Color(0xFF2E3192).withOpacity(isDark ? 0.4 : 0.15), blurRadius: 20, offset: const Offset(0, 8), spreadRadius: -2),
                        BoxShadow(color: const Color(0xFF1BFFFF).withOpacity(isDark ? 0.35 : 0.2), blurRadius: 24, offset: const Offset(0, 12), spreadRadius: -4),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: isDark ? [const Color(0xFF4D5FD1), const Color(0xFF1BFFFF)] : [const Color(0xFF2E3192), const Color(0xFF1BFFFF)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(color: const Color(0xFF2E3192).withOpacity(isDark ? 0.5 : 0.4), blurRadius: 16, offset: const Offset(0, 6)),
                              BoxShadow(color: const Color(0xFF1BFFFF).withOpacity(isDark ? 0.4 : 0.3), blurRadius: 20, offset: const Offset(0, 8), spreadRadius: -4),
                            ],
                          ),
                          child: const Icon(Icons.add_chart_rounded, color: Colors.white, size: 36),
                        ),
                        const SizedBox(height: 18),
                        ShaderMask(
                          shaderCallback: (bounds) => LinearGradient(
                            colors: isDark ? [const Color(0xFF6B7FFF), const Color(0xFF1BFFFF)] : [const Color(0xFF2E3192), const Color(0xFF1BFFFF)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ).createShader(bounds),
                          child: Text(
                            'İlk Denemeni Ekle',
                            style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900, fontSize: 22, letterSpacing: -0.5, color: Colors.white),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Başarı yolculuğunu arşivlemeye başla',
                          style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600, fontSize: 14, height: 1.4, color: isDark ? Colors.white.withOpacity(0.85) : Colors.black.withOpacity(0.6)),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ).animate(delay: 400.ms).fadeIn(duration: 500.ms).slideY(begin: 0.15, duration: 600.ms, curve: Curves.easeOutCubic).shimmer(delay: 800.ms, duration: 1500.ms),
              ],
            ),
          ),
        ),
      );
    }

    final filtered = _applyFiltersAndSort();

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 70, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E2230) : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(isDark ? 0.2 : 0.06),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: TextField(
                  decoration: InputDecoration(
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      color: isDark ? const Color(0xFF8B8FFF) : const Color(0xFF2E3192),
                    ),
                    hintText: 'Deneme adı ara...',
                    hintStyle: TextStyle(
                      color: isDark ? Colors.white38 : Colors.black38,
                    ),
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                  onChanged: (v) => setState(() => _searchQuery = v),
                ),
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _availableCategories().map((s) {
                    final selected = _selectedCategory == s;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: FilterChip(
                        label: Text(
                          s,
                          style: TextStyle(
                            fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                            fontSize: 12,
                            color: selected
                                ? (isDark ? const Color(0xFF8B8FFF) : const Color(0xFF2E3192))
                                : (isDark ? Colors.white70 : Colors.black54),
                          ),
                        ),
                        selected: selected,
                        onSelected: (_) => setState(() => _selectedCategory = s),
                        backgroundColor: isDark ? const Color(0xFF1E2230) : Colors.white,
                        selectedColor: isDark
                            ? const Color(0xFF2E3192).withOpacity(0.2)
                            : const Color(0xFF2E3192).withOpacity(0.08),
                        checkmarkColor: isDark ? const Color(0xFF8B8FFF) : const Color(0xFF2E3192),
                        side: BorderSide(
                          color: selected
                              ? (isDark ? const Color(0xFF8B8FFF).withOpacity(0.5) : const Color(0xFF2E3192).withOpacity(0.3))
                              : (isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.08)),
                          width: 1,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              _lastVisible = null;
              await _loadInitial(showLoader: false);
            },
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              controller: _scrollController,
              // GÜVENLİ ALAN DÜZELTMESİ:
              // Standart 24 padding'e ek olarak bottomPadding ekliyoruz.
              padding: EdgeInsets.fromLTRB(20, 8, 20, 24 + bottomPadding),
              itemCount: filtered.length + (_isLoading && filtered.isNotEmpty ? 1 : 0),
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                if (index >= filtered.length) {
                  return Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                  );
                }
                final test = filtered[index];
                return _ArchiveListTile(
                  test: test,
                  onDeleted: () async {
                    _lastVisible = null;
                    await _loadInitial(showLoader: false);
                  },
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

enum _SortField { date, net, accuracy }

class _SortOption {
  final _SortField field;
  final bool descending;
  const _SortOption({required this.field, required this.descending});
}

class _ArchiveListTile extends ConsumerWidget {
  final TestModel test;
  final VoidCallback onDeleted;

  const _ArchiveListTile({
    required this.test,
    required this.onDeleted,
  });

  double _accuracy(TestModel t) {
    final total = t.totalCorrect + t.totalWrong + t.totalBlank;
    if (total == 0) return 0.0;
    return (t.totalCorrect / total) * 100.0;
  }

  void _goToWarReport(BuildContext context) {
    context.push(
        '/home/test-result-summary?fromArchive=true',
        extra: test
    );
  }

  void _showOptionsSheet(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      backgroundColor: theme.cardColor,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Text(
                    test.testName,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Divider(),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.analytics_rounded, color: theme.colorScheme.primary),
                  ),
                  title: const Text('Deneme Raporunu İncele'),
                  subtitle: const Text('Netlerini ve detaylı analizini gör'),
                  onTap: () {
                    Navigator.pop(ctx);
                    _goToWarReport(context);
                  },
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.error.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.delete_outline_rounded, color: theme.colorScheme.error),
                  ),
                  title: Text(
                    'Denemeyi Sil',
                    style: TextStyle(color: theme.colorScheme.error, fontWeight: FontWeight.bold),
                  ),
                  onTap: () async {
                    Navigator.pop(ctx);
                    _confirmAndDelete(context, ref);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmAndDelete(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: const Text('Denemeyi Sil'),
        content: Text('${test.testName} silinsin mi? Bu işlem geri alınamaz.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Sil',
              style: TextStyle(color: Theme.of(context).colorScheme.error, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await ref.read(firestoreServiceProvider).deleteTest(test.id);

        // Provider'ları invalidate et ki dashboard ve profile güncellensin
        ref.invalidate(testsProvider);

        onDeleted(); // Listeyi hemen yenile
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${test.testName} başarıyla silindi.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Hata: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final acc = _accuracy(test);
    final isDark = theme.brightness == Brightness.dark;

    final isPremium = ref.watch(premiumStatusProvider);
    final hasTemporaryAccess = ref.watch(hasPremiumFeaturesAccessProvider);

    return Container(
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            if (isPremium || hasTemporaryAccess) {
              _goToWarReport(context);
            } else {
              context.push('/stats-premium-offer?source=archive');
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(14.0),
            child: Row(
              children: [
                // 1. SOL ROZET (NET Puanı)
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2E3192).withOpacity(isDark ? 0.2 : 0.08),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        test.totalNet.toStringAsFixed(1),
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          color: isDark ? const Color(0xFF8B8FFF) : const Color(0xFF2E3192),
                          height: 1.0,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'NET',
                        style: TextStyle(
                          fontSize: 9,
                          color: isDark ? const Color(0xFF8B8FFF).withOpacity(0.7) : const Color(0xFF2E3192).withOpacity(0.7),
                          fontWeight: FontWeight.w700,
                        ),
                      )
                    ],
                  ),
                ),

                const SizedBox(width: 14),

                // 2. ORTA BİLGİ ALANI
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        test.testName,
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.calendar_today_rounded, size: 12, color: isDark ? Colors.white54 : Colors.black45),
                          const SizedBox(width: 4),
                          Text(
                            DateFormat.yMMMd('tr').format(test.date),
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.white54 : Colors.black45,
                            ),
                          ),

                          const Spacer(),

                          // Doğruluk Oranı Rozeti
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF00C853).withOpacity(isDark ? 0.2 : 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '%${acc.toStringAsFixed(0)}',
                              style: const TextStyle(
                                color: Color(0xFF00C853),
                                fontWeight: FontWeight.w700,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // 3. MENU BUTONU
                IconButton(
                  icon: Icon(
                    Icons.more_vert_rounded,
                    color: isDark ? Colors.white54 : Colors.black45,
                  ),
                  onPressed: () => _showOptionsSheet(context, ref),
                  tooltip: 'Seçenekler',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}