// lib/features/home/screens/library_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:taktik/data/models/test_model.dart';
import 'package:taktik/data/providers/firestore_providers.dart';
import 'package:taktik/core/theme/app_theme.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:taktik/features/quests/logic/quest_notifier.dart';
import 'package:taktik/shared/widgets/logo_loader.dart';

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
      backgroundColor: AppTheme.primaryColor,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppTheme.primaryColor,
              AppTheme.cardColor.withValues(alpha: 0.8),
            ],
          ),
        ),
        child: _buildBody(textTheme),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/home/add-test'),
        icon: const Icon(Icons.add_chart_rounded),
        label: const Text('Deneme Ekle'),
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
    final attempted = t.totalCorrect + t.totalWrong;
    if (attempted == 0) return 0.0;
    return (t.totalCorrect / attempted) * 100.0;
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
      backgroundColor: AppTheme.cardColor,
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
    return Icon(_sortOption.descending ? Icons.south_rounded : Icons.north_rounded, color: AppTheme.secondaryColor);
  }

  Widget _buildBody(TextTheme textTheme) {
    if (_tests.isEmpty && _isLoading) {
      return const LogoLoader();
    }
    if (_tests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.inventory_2_outlined, size: 80, color: AppTheme.secondaryTextColor),
            const SizedBox(height: 16),
            Text('Arşivin Henüz Boş', style: textTheme.headlineSmall),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0),
              child: Text(
                'Her deneme, gelecekteki başarın için bir kanıtıdır. İlk kanıtı arşive ekle.',
                textAlign: TextAlign.center,
                style: textTheme.bodyLarge?.copyWith(color: AppTheme.secondaryTextColor),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.push('/home/add-test'),
              child: const Text("İlk Kaydı Ekle"),
            )
          ],
        ).animate().fadeIn(duration: 800.ms),
      );
    }

    final filtered = _applyFiltersAndSort();

    return Column(
      children: [
        // Arama ve filtre barı
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search_rounded),
                  hintText: 'Deneme adı ara...',
                  filled: true,
                  fillColor: AppTheme.cardColor,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                ),
                onChanged: (v) => setState(() => _searchQuery = v),
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _availableSections().map((s) {
                    final selected = _selectedSection == s;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: ChoiceChip(
                        label: Text(s),
                        selected: selected,
                        onSelected: (_) => setState(() => _selectedSection = s),
                        selectedColor: AppTheme.secondaryColor.withValues(alpha: AppTheme.secondaryColor.a * 0.2),
                        labelStyle: TextStyle(color: selected ? AppTheme.secondaryColor : Colors.white),
                        backgroundColor: AppTheme.cardColor,
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
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
                  return const Padding(
                    padding: EdgeInsets.all(12.0),
                    child: Center(child: CircularProgressIndicator(color: AppTheme.secondaryColor)),
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
class _ArchiveListTile extends StatelessWidget {
  final TestModel test;
  const _ArchiveListTile({required this.test});

  double _accuracy(TestModel t) {
    final attempted = t.totalCorrect + t.totalWrong;
    if (attempted == 0) return 0.0;
    return (t.totalCorrect / attempted) * 100.0;
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final acc = _accuracy(test);

    return Material(
      color: AppTheme.cardColor,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => context.push('/home/test-result-summary', extra: test),
        onLongPress: () => context.push('/home/test-detail', extra: test),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              // Sol rozet
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: AppTheme.lightSurfaceColor.withValues(alpha: AppTheme.lightSurfaceColor.a * 0.2),
                ),
                alignment: Alignment.center,
                child: Text(
                  test.totalNet.toStringAsFixed(1),
                  style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800, color: Colors.white),
                ),
              ),
              const SizedBox(width: 12),
              // Orta içerik
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Hero: Savaş Raporu başlığı ile akıcı geçiş
                    Hero(
                      tag: 'test_title_${test.id}',
                      child: Material(
                        color: Colors.transparent,
                        child: Text(
                          test.testName,
                          style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${test.sectionName} • ${DateFormat.yMd('tr').format(test.date)}',
                      style: textTheme.bodySmall?.copyWith(color: AppTheme.secondaryTextColor),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Sağ metrikler
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(children: [
                    const Icon(Icons.check_rounded, size: 16, color: AppTheme.successColor),
                    const SizedBox(width: 4),
                    Text('%${acc.toStringAsFixed(1)}', style: textTheme.bodyMedium?.copyWith(color: AppTheme.successColor, fontWeight: FontWeight.w700)),
                  ]),
                  const SizedBox(height: 4),
                  Text('${test.totalCorrect}/${test.totalWrong}/${test.totalBlank}', style: textTheme.labelSmall?.copyWith(color: AppTheme.secondaryTextColor)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
