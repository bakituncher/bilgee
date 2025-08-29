// lib/features/home/screens/library_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:bilge_ai/data/models/test_model.dart';
import 'package:bilge_ai/data/providers/firestore_providers.dart';
import 'package:bilge_ai/core/theme/app_theme.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:bilge_ai/features/quests/logic/quest_notifier.dart';

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
    final threshold = 200.0;
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
        title: const Text('Performans Arşivi'),
        backgroundColor: Colors.transparent,
        elevation: 0,
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
    );
  }

  Widget _buildBody(TextTheme textTheme) {
    if (_tests.isEmpty && _isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.secondaryColor));
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
              onPressed: () => context.go('/home/add-test'),
              child: const Text("İlk Kaydı Ekle"),
            )
          ],
        ).animate().fadeIn(duration: 800.ms),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        _lastVisible = null;
        await _loadInitial();
      },
      child: GridView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(16.0),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 0.75,
        ),
        itemCount: _tests.length + (_isLoading || _hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= _tests.length) {
            return const Center(child: CircularProgressIndicator(color: AppTheme.secondaryColor));
          }
          final test = _tests[index];
          return _TriumphPlaqueCard(test: test)
              .animate()
              .fadeIn(delay: (100 * (index % 10)).ms, duration: 500.ms)
              .slideY(begin: 0.5, curve: Curves.easeOutCubic);
        },
      ),
    );
  }
}

class _TriumphPlaqueCard extends StatefulWidget {
  final TestModel test;
  const _TriumphPlaqueCard({required this.test});

  @override
  State<_TriumphPlaqueCard> createState() => _TriumphPlaqueCardState();
}

class _TriumphPlaqueCardState extends State<_TriumphPlaqueCard> {
  bool _isHovered = false;

  double _calculateWisdomScore() {
    return widget.test.wisdomScore;
  }

  double _calculateAccuracy() {
    final attemptedQuestions = widget.test.totalCorrect + widget.test.totalWrong;
    if (attemptedQuestions == 0) return 0.0;
    return (widget.test.totalCorrect / attemptedQuestions) * 100;
  }

  Color _getTierColor(double score) {
    if (score > 85) return const Color(0xFF40E0D0); // Platin
    if (score > 70) return const Color(0xFFFFD700); // Altın
    if (score > 50) return const Color(0xFFC0C0C0); // Gümüş
    return const Color(0xFFCD7F32); // Bronz
  }

  @override
  Widget build(BuildContext context) {
    final wisdomScore = _calculateWisdomScore();
    final accuracy = _calculateAccuracy();
    final tierColor = _getTierColor(wisdomScore);
    final textTheme = Theme.of(context).textTheme;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: () => context.push('/home/test-result-summary', extra: widget.test),
        child: AnimatedContainer(
          duration: 300.ms,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: _isHovered
                    ? tierColor.withValues(alpha: tierColor.a * 0.5)
                    : Colors.black.withValues(alpha: 0.6),
                blurRadius: _isHovered ? 25 : 10,
              )
            ],
          ),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              color: AppTheme.cardColor,
              gradient: LinearGradient(
                colors: [
                  AppTheme.lightSurfaceColor.withValues(alpha: AppTheme.lightSurfaceColor.a * 0.1),
                  AppTheme.cardColor,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(color: AppTheme.lightSurfaceColor.withValues(alpha: AppTheme.lightSurfaceColor.a * 0.3)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.test.testName,
                    style: textTheme.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${widget.test.sectionName} • ${DateFormat.yMd('tr').format(widget.test.date)}',
                    style: textTheme.bodySmall?.copyWith(color: AppTheme.secondaryTextColor),
                  ),
                  const Spacer(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('NET', style: textTheme.bodySmall?.copyWith(color: AppTheme.secondaryTextColor)),
                          Text(
                            widget.test.totalNet.toStringAsFixed(2),
                            style: textTheme.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('Doğruluk', style: textTheme.bodySmall?.copyWith(color: AppTheme.secondaryTextColor)),
                          Text('%${accuracy.toStringAsFixed(1)}', style: textTheme.titleLarge?.copyWith(color: tierColor, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}



