// lib/features/quests/screens/quests_screen.dart
import 'dart:async';
import 'package:bilge_ai/core/analytics/analytics_logger.dart';
import 'package:bilge_ai/core/theme/app_theme.dart';
import 'package:bilge_ai/data/providers/firestore_providers.dart';
import 'package:bilge_ai/features/quests/logic/quest_service.dart';
import 'package:bilge_ai/features/quests/logic/optimized_quests_provider.dart';
import 'package:bilge_ai/features/quests/models/quest_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

enum QuestFilter { active, completed }

class QuestsScreen extends ConsumerStatefulWidget {
  const QuestsScreen({super.key});

  @override
  ConsumerState<QuestsScreen> createState() => _QuestsScreenState();
}

class _QuestsScreenState extends ConsumerState<QuestsScreen> {
  QuestFilter _selectedFilter = QuestFilter.active;
  String _searchQuery = '';

  Timer? _searchDebounce;
  List<Quest>? _lastAllQuestsIdentity;
  String _cacheSearch = '';
  QuestFilter _cacheFilter = QuestFilter.active;
  List<Quest>? _cacheFiltered;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userProfileProvider).value;
    if (user == null) {
      return const Scaffold(
        backgroundColor: AppTheme.scaffoldBackgroundColor,
        body: Center(child: CircularProgressIndicator(color: AppTheme.secondaryColor)),
      );
    }
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          _buildThemedAppBar(context),
          _buildThemedFilterBar(),
          _buildQuestsSliver(user.id),
        ],
      ),
    );
  }

  Widget _buildThemedAppBar(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 140,
      floating: false,
      pinned: true,
      automaticallyImplyLeading: false,
      backgroundColor: AppTheme.scaffoldBackgroundColor,
      elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.only(left: 16, bottom: 16, right: 16),
        centerTitle: false,
        title: Text(
          'Fetih Görevleri',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        background: Stack(
          children: [
            Positioned(
              right: -50,
              top: -50,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.secondaryColor.withOpacity(0.1),
                ),
              ).animate().fadeIn(duration: 800.ms),
            ),
          ],
        ),
      ),
      actions: [
        IconButton(
          tooltip: 'Yenile',
          icon: const Icon(Icons.sync_rounded, color: AppTheme.secondaryTextColor),
          onPressed: () => _refreshQuests(),
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildThemedFilterBar() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: CupertinoSlidingSegmentedControl<QuestFilter>(
          backgroundColor: AppTheme.cardColor,
          thumbColor: AppTheme.secondaryColor,
          groupValue: _selectedFilter,
          onValueChanged: (QuestFilter? value) {
            if (value != null) {
              setState(() => _selectedFilter = value);
            }
          },
          children: <QuestFilter, Widget>{
            QuestFilter.active: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Text(
                'Aktif',
                style: TextStyle(
                  color: _selectedFilter == QuestFilter.active ? Colors.black : Colors.white,
                  fontWeight: FontWeight.bold
                ),
              ),
            ),
            QuestFilter.completed: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Text(
                'Tamamlanmış',
                 style: TextStyle(
                  color: _selectedFilter == QuestFilter.completed ? Colors.black : Colors.white,
                  fontWeight: FontWeight.bold
                ),
              ),
            ),
          },
        ),
      ),
    );
  }

  Widget _buildQuestsSliver(String userId) {
    return Consumer(builder: (context, ref, _) {
      final questsState = ref.watch(optimizedQuestsProvider);

      if (questsState.error != null && questsState.error!.isNotEmpty) {
        return SliverFillRemaining(
          hasScrollBody: false,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 64, color: AppTheme.secondaryTextColor),
                  const SizedBox(height: 16),
                  const Text('Görevler yüklenirken hata oluştu', style: TextStyle(color: AppTheme.secondaryTextColor, fontSize: 16)),
                  const SizedBox(height: 8),
                  ElevatedButton(onPressed: _refreshQuests, child: const Text('Tekrar Dene')),
                ],
              ),
            ),
        );
      }

      if (!questsState.isLoaded) {
        return SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => _buildSkeletonCard(),
              childCount: 5,
            ),
          ),
        );
      }

      final questsDataList = questsState.allQuests ?? [];
      final filteredQuests = _filterQuests(questsDataList);

      if (filteredQuests.isEmpty) {
        return SliverFillRemaining(
          hasScrollBody: false,
          child: _buildEmptyState(),
        );
      }

      return SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final quest = filteredQuests[index];
              return ThemedQuestCard(
                quest: quest,
                userId: userId,
              ).animate().fadeIn(delay: (index * 80).ms, duration: 400.ms).slideY(begin: 0.2, curve: Curves.easeOut);
            },
            childCount: filteredQuests.length,
          ),
        ),
      );
    });
  }

  Widget _buildSkeletonCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      height: 110,
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
    ).animate(onPlay: (c) => c.repeat()).shimmer(
      duration: 1500.ms,
      color: AppTheme.lightSurfaceColor.withOpacity(0.5),
    );
  }

  Widget _buildEmptyState() {
    final isCompletedFilter = _selectedFilter == QuestFilter.completed;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isCompletedFilter ? Icons.history_edu_rounded : Icons.checklist_rtl_rounded,
            size: 90,
            color: AppTheme.secondaryTextColor.withOpacity(0.4),
          ).animate().scale(delay: 100.ms, duration: 600.ms, curve: Curves.elasticOut),
          const SizedBox(height: 24),
          Text(
            isCompletedFilter ? 'Henüz Görev Tamamlanmadı' : 'Tüm Görevler Tamamlandı!',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40.0),
            child: Text(
              isCompletedFilter
                  ? 'Tamamladığın görevler burada görünecek.'
                  : 'Harika iş çıkardın! Yarın yeni görevler için tekrar gel.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.secondaryTextColor,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ).animate().fadeIn(duration: 400.ms),
    );
  }

  List<Quest> _filterQuests(List<Quest> quests) {
    if (identical(quests, _lastAllQuestsIdentity) && _selectedFilter == _cacheFilter && _cacheFiltered != null) {
      return _cacheFiltered!;
    }

    List<Quest> filtered;
    switch (_selectedFilter) {
      case QuestFilter.active:
        filtered = quests.where((q) => !q.isCompleted).toList();
        break;
      case QuestFilter.completed:
        filtered = quests.where((q) => q.isCompleted).toList();
        break;
    }

    _lastAllQuestsIdentity = quests;
    _cacheFilter = _selectedFilter;
    _cacheFiltered = filtered;
    return filtered;
  }

  void _refreshQuests() async {
    if (!mounted) return;
    final user = ref.read(userProfileProvider).value;
    if (user != null && mounted) {
      await ref.read(questServiceProvider).refreshDailyQuestsForUser(user, force: true);
      if (mounted) {
        ref.invalidate(optimizedQuestsProvider);
      }
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }
}

class ThemedQuestCard extends ConsumerWidget {
  final Quest quest;
  final String userId;

  const ThemedQuestCard({
    super.key,
    required this.quest,
    required this.userId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = quest.goalValue > 0 ? (quest.currentProgress / quest.goalValue).clamp(0.0, 1.0) : (quest.isCompleted ? 1.0 : 0.0);
    final isCompleted = quest.isCompleted;

    return GestureDetector(
      onTap: isCompleted ? null : () => _handleQuestTap(context, ref),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            colors: isCompleted
                ? [AppTheme.successColor.withOpacity(0.2), AppTheme.cardColor.withOpacity(0.1)]
                : [AppTheme.lightSurfaceColor.withOpacity(0.5), AppTheme.cardColor],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(
            color: isCompleted ? AppTheme.successColor.withOpacity(0.4) : AppTheme.lightSurfaceColor,
            width: 1,
          ),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: progress,
                    child: Container(color: AppTheme.secondaryColor.withOpacity(isCompleted ? 0.2 : 0.1)),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                children: [
                  _buildCategoryIcon(isCompleted),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          quest.title,
                          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (!isCompleted) ...[
                          const SizedBox(height: 4),
                          Text(
                            quest.description,
                            style: TextStyle(color: AppTheme.secondaryTextColor, fontSize: 13),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildRewardBadge(isCompleted),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryIcon(bool isCompleted) {
    if (isCompleted) {
      return Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppTheme.successColor.withOpacity(0.3),
        ),
        child: const Icon(Icons.check_circle_rounded, color: AppTheme.successColor, size: 28),
      );
    }

    IconData icon;
    Color color;
    switch (quest.category) {
      case QuestCategory.study: icon = Icons.menu_book_rounded; color = Colors.blue; break;
      case QuestCategory.practice: icon = Icons.edit_note_rounded; color = Colors.green; break;
      case QuestCategory.engagement: icon = Icons.auto_awesome_rounded; color = Colors.purple; break;
      case QuestCategory.consistency: icon = Icons.event_repeat_rounded; color = Colors.orange; break;
      case QuestCategory.test_submission: icon = Icons.add_chart_rounded; color = Colors.red; break;
      case QuestCategory.focus: icon = Icons.center_focus_strong; color = Colors.cyan; break;
    }

    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        shape: BoxShape.circle,
        border: Border.all(color: color.withOpacity(0.3), width: 2),
      ),
      child: Icon(icon, color: color, size: 24),
    );
  }

  Widget _buildRewardBadge(bool isCompleted) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isCompleted ? AppTheme.goldColor.withOpacity(0.2) : AppTheme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.goldColor.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star_rounded, color: AppTheme.goldColor, size: 16),
          const SizedBox(width: 4),
          Text(
            '+${quest.reward}',
            style: const TextStyle(color: AppTheme.goldColor, fontSize: 14, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  void _handleQuestTap(BuildContext context, WidgetRef ref) {
    ref.read(analyticsLoggerProvider).logQuestEvent(userId: userId, event: 'quest_tap', data: {'questId': quest.id, 'category': quest.category.name});
    String targetRoute = quest.actionRoute;
    if (targetRoute == '/coach') {
      final subjectTag = quest.tags.firstWhere((t) => t.startsWith('subject:'), orElse: () => '');
      if (subjectTag.isNotEmpty) {
        final subject = subjectTag.split(':').sublist(1).join(':');
        targetRoute = Uri(path: '/coach', queryParameters: {'subject': subject}).toString();
      }
    }
    context.go(targetRoute);
  }
}
