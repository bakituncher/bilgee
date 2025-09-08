// lib/features/quests/screens/quests_screen.dart
import 'package:bilge_ai/core/analytics/analytics_logger.dart';
import 'package:bilge_ai/core/theme/app_theme.dart';
import 'package:bilge_ai/data/providers/firestore_providers.dart';
import 'package:bilge_ai/features/quests/logic/quest_service.dart';
import 'package:bilge_ai/features/quests/logic/optimized_quests_provider.dart';
import 'package:bilge_ai/features/quests/models/quest_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

enum QuestFilter { all, daily, weekly, monthly, completed }

class QuestsScreen extends ConsumerStatefulWidget {
  const QuestsScreen({super.key});

  @override
  ConsumerState<QuestsScreen> createState() => _QuestsScreenState();
}

class _QuestsScreenState extends ConsumerState<QuestsScreen> {
  QuestFilter _selectedFilter = QuestFilter.all;
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userProfileProvider).value;
    if (user == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.primaryColor,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          _buildModernAppBar(context),
          _buildFilterBar(),
        ],
        body: _buildQuestsList(user.id),
      ),
    );
  }

  /// YENİ: Modern tasarımlı app bar
  Widget _buildModernAppBar(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 120,
      floating: true,
      pinned: true,
      backgroundColor: AppTheme.primaryColor,
      flexibleSpace: FlexibleSpaceBar(
        title: Text(
          'Fetih Görevleri',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 24,
          ),
        ),
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppTheme.primaryColor,
                AppTheme.primaryColor.withValues(alpha: 0.8),
              ],
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                right: -50,
                top: -50,
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.05),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        IconButton(
          icon: Icon(Icons.refresh_rounded, color: Colors.white),
          onPressed: () => _refreshQuests(),
        ),
      ],
    );
  }

  /// YENİ: Filtre çubuğu - artık modalBottomSheet yerine her zaman görünür
  Widget _buildFilterBar() {
    return SliverToBoxAdapter(
      child: Container(
        padding: const EdgeInsets.all(16),
        color: AppTheme.primaryColor,
        child: Column(
          children: [
            // Arama kutusu
            TextField(
              onChanged: (value) => setState(() => _searchQuery = value),
              decoration: InputDecoration(
                hintText: 'Görev ara...',
                prefixIcon: Icon(Icons.search, color: Colors.white70),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.1),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                hintStyle: TextStyle(color: Colors.white70),
              ),
              style: TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 12),

            // Filtre chip'leri
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: QuestFilter.values.map((filter) {
                  final isSelected = _selectedFilter == filter;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(_getFilterLabel(filter)),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() => _selectedFilter = filter);
                      },
                      backgroundColor: Colors.white.withValues(alpha: 0.1),
                      selectedColor: AppTheme.secondaryColor,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : Colors.white70,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                      checkmarkColor: Colors.white,
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getFilterLabel(QuestFilter filter) {
    switch (filter) {
      case QuestFilter.all: return 'Tümü';
      case QuestFilter.daily: return 'Günlük';
      case QuestFilter.weekly: return 'Haftalık';
      case QuestFilter.monthly: return 'Aylık';
      case QuestFilter.completed: return 'Tamamlanan';
    }
  }

  /// YENİ: İyileştirilmiş görevler listesi
  Widget _buildQuestsList(String userId) {
    return Consumer(
      builder: (context, ref, child) {
        final questsAsyncValue = ref.watch(optimizedQuestsProvider);

        return questsAsyncValue.when(
          data: (questsData) {
            final filteredQuests = _filterQuests(questsData.allQuests);

            if (filteredQuests.isEmpty) {
              return _buildEmptyState();
            }

            // Görevleri kategorilere ayır
            final activeQuests = filteredQuests.where((q) => !q.isCompleted).toList();
            final completedQuests = filteredQuests.where((q) => q.isCompleted).toList();

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (activeQuests.isNotEmpty) ...[
                  _buildSectionHeader('Aktif Görevler', activeQuests.length),
                  ...activeQuests.map((quest) =>
                    ModernQuestCard(
                      quest: quest,
                      userId: userId,
                      allQuestsMap: questsData.allQuestsMap,
                    ).animate().fadeIn(delay: (activeQuests.indexOf(quest) * 100).ms),
                  ),
                  const SizedBox(height: 24),
                ],

                if (completedQuests.isNotEmpty) ...[
                  _buildSectionHeader('Tamamlanan Görevler', completedQuests.length),
                  ...completedQuests.map((quest) =>
                    ModernQuestCard(
                      quest: quest,
                      userId: userId,
                      allQuestsMap: questsData.allQuestsMap,
                      isCompleted: true,
                    ).animate().fadeIn(delay: (completedQuests.indexOf(quest) * 100).ms),
                  ),
                ],
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.white54),
                const SizedBox(height: 16),
                Text(
                  'Görevler yüklenirken hata oluştu',
                  style: TextStyle(color: Colors.white70, fontSize: 16),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: _refreshQuests,
                  child: Text('Tekrar Dene'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(String title, int count) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Text(
            title,
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.secondaryColor.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              count.toString(),
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.assignment_turned_in,
            size: 80,
            color: Colors.white54,
          ),
          const SizedBox(height: 16),
          Text(
            'Görev bulunamadı',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Seçili filtreye uygun görev yok',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _refreshQuests,
            icon: Icon(Icons.refresh),
            label: Text('Görevleri Yenile'),
          ),
        ],
      ),
    );
  }

  List<Quest> _filterQuests(List<Quest> quests) {
    var filtered = quests;

    // Filtre uygula
    switch (_selectedFilter) {
      case QuestFilter.daily:
        filtered = filtered.where((q) => q.type == QuestType.daily).toList();
        break;
      case QuestFilter.weekly:
        filtered = filtered.where((q) => q.type == QuestType.weekly).toList();
        break;
      case QuestFilter.monthly:
        filtered = filtered.where((q) => q.type == QuestType.monthly).toList();
        break;
      case QuestFilter.completed:
        filtered = filtered.where((q) => q.isCompleted).toList();
        break;
      case QuestFilter.all:
        // Tümünü göster
        break;
    }

    // Arama uygula
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((quest) =>
        quest.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
        quest.description.toLowerCase().contains(_searchQuery.toLowerCase()) ||
        quest.tags.any((tag) => tag.toLowerCase().contains(_searchQuery.toLowerCase()))
      ).toList();
    }

    return filtered;
  }

  void _refreshQuests() async {
    final user = ref.read(userProfileProvider).value;
    if (user != null) {
      await ref.read(questServiceProvider).refreshDailyQuestsForUser(user, force: true);
      ref.invalidate(optimizedQuestsProvider);
    }
  }
}

/// YENİ: Modern ve kompakt quest card tasarımı
class ModernQuestCard extends ConsumerWidget {
  final Quest quest;
  final String userId;
  final Map<String, Quest> allQuestsMap;
  final bool isCompleted;

  const ModernQuestCard({
    super.key,
    required this.quest,
    required this.userId,
    required this.allQuestsMap,
    this.isCompleted = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userProfileProvider).value;
    final progress = quest.goalValue > 0
        ? (quest.currentProgress / quest.goalValue).clamp(0.0, 1.0)
        : 1.0;

    // Dinamik ödül hesapla
    int finalReward = quest.reward;
    if (user != null) {
      finalReward = quest.calculateDynamicReward(
        userLevel: (user.engagementScore / 100).floor(),
        currentStreak: user.currentQuestStreak,
        isStreakBonus: user.currentQuestStreak >= 3,
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _handleQuestTap(context, ref),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: _getGradientColors(),
              ),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.1),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Üst kısım - başlık ve kategori ikonu
                Row(
                  children: [
                    _buildCategoryIcon(),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            quest.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (!isCompleted) ...[
                            const SizedBox(height: 4),
                            Text(
                              quest.description,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.7),
                                fontSize: 13,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                    _buildRewardBadge(finalReward),
                  ],
                ),

                const SizedBox(height: 12),

                // Alt kısım - ilerleme veya tamamlanma durumu
                if (isCompleted)
                  _buildCompletedState(finalReward, ref)
                else
                  _buildProgressState(progress),

                // Özel etiketler
                if (_shouldShowTags()) ...[
                  const SizedBox(height: 8),
                  _buildTags(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryIcon() {
    IconData icon;
    Color color;

    switch (quest.category) {
      case QuestCategory.study:
        icon = Icons.book_rounded;
        color = Colors.blue;
        break;
      case QuestCategory.practice:
        icon = Icons.edit_note_rounded;
        color = Colors.green;
        break;
      case QuestCategory.engagement:
        icon = Icons.auto_awesome;
        color = Colors.purple;
        break;
      case QuestCategory.consistency:
        icon = Icons.event_repeat_rounded;
        color = Colors.orange;
        break;
      case QuestCategory.test_submission:
        icon = Icons.add_chart_rounded;
        color = Colors.red;
        break;
      case QuestCategory.focus:
        icon = Icons.center_focus_strong;
        color = Colors.cyan;
        break;
    }

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Icon(
        icon,
        color: color,
        size: 20,
      ),
    );
  }

  Widget _buildRewardBadge(int reward) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.goldColor.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppTheme.goldColor.withValues(alpha: 0.4),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.star_rounded,
            color: AppTheme.goldColor,
            size: 14,
          ),
          const SizedBox(width: 4),
          Text(
            '+$reward BP',
            style: TextStyle(
              color: AppTheme.goldColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressState(double progress) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                  valueColor: AlwaysStoppedAnimation(Colors.white),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '${quest.currentProgress}/${quest.goalValue}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCompletedState(int reward, WidgetRef ref) {
    return Row(
      children: [
        Icon(
          Icons.check_circle_rounded,
          color: AppTheme.successColor,
          size: 20,
        ),
        const SizedBox(width: 8),
        Text(
          'Tamamlandı',
          style: TextStyle(
            color: AppTheme.successColor,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const Spacer(),
        if (!quest.rewardClaimed)
          ElevatedButton.icon(
            onPressed: () => _claimReward(ref, reward),
            icon: Icon(Icons.star, size: 16),
            label: Text('Topla'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.goldColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
      ],
    );
  }

  bool _shouldShowTags() {
    return quest.tags.any((tag) =>
      ['high_value', 'weakness', 'adaptive', 'chain', 'onboarding'].contains(tag)
    );
  }

  Widget _buildTags() {
    final importantTags = quest.tags.where((tag) =>
      ['high_value', 'weakness', 'adaptive', 'chain', 'onboarding'].contains(tag)
    ).take(3).toList();

    return Wrap(
      spacing: 6,
      children: importantTags.map((tag) => _buildTag(tag)).toList(),
    );
  }

  Widget _buildTag(String tag) {
    String label;
    Color color;
    IconData icon;

    switch (tag) {
      case 'high_value':
        label = 'Öncelik';
        color = Colors.amber;
        icon = Icons.flash_on;
        break;
      case 'weakness':
        label = 'Zayıf Nokta';
        color = Colors.red;
        icon = Icons.warning_amber;
        break;
      case 'adaptive':
        label = 'Adaptif';
        color = Colors.lightBlue;
        icon = Icons.auto_fix_high;
        break;
      case 'chain':
        label = 'Zincir';
        color = Colors.teal;
        icon = Icons.link;
        break;
      case 'onboarding':
        label = 'Keşif';
        color = Colors.purple;
        icon = Icons.explore;
        break;
      default:
        label = tag;
        color = Colors.grey;
        icon = Icons.label;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: color.withValues(alpha: 0.4),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  List<Color> _getGradientColors() {
    if (isCompleted) {
      return [
        AppTheme.successColor.withValues(alpha: 0.2),
        AppTheme.successColor.withValues(alpha: 0.1),
      ];
    }

    switch (quest.category) {
      case QuestCategory.study:
        return [
          Colors.blue.withValues(alpha: 0.2),
          Colors.blue.withValues(alpha: 0.1),
        ];
      case QuestCategory.practice:
        return [
          Colors.green.withValues(alpha: 0.2),
          Colors.green.withValues(alpha: 0.1),
        ];
      case QuestCategory.engagement:
        return [
          Colors.purple.withValues(alpha: 0.2),
          Colors.purple.withValues(alpha: 0.1),
        ];
      case QuestCategory.consistency:
        return [
          Colors.orange.withValues(alpha: 0.2),
          Colors.orange.withValues(alpha: 0.1),
        ];
      case QuestCategory.test_submission:
        return [
          Colors.red.withValues(alpha: 0.2),
          Colors.red.withValues(alpha: 0.1),
        ];
      case QuestCategory.focus:
        return [
          Colors.cyan.withValues(alpha: 0.2),
          Colors.cyan.withValues(alpha: 0.1),
        ];
    }
  }

  void _handleQuestTap(BuildContext context, WidgetRef ref) {
    if (isCompleted) return;

    // Analytics log
    ref.read(analyticsLoggerProvider).logQuestEvent(
      userId: userId,
      event: 'quest_tap',
      data: {
        'questId': quest.id,
        'category': quest.category.name,
      },
    );

    // Navigate to quest action route
    String targetRoute = quest.actionRoute;

    // Coach için özel subject parameter ekleme
    if (targetRoute == '/coach') {
      final subjectTag = quest.tags.firstWhere(
        (t) => t.startsWith('subject:'),
        orElse: () => '',
      );
      if (subjectTag.isNotEmpty) {
        final subject = subjectTag.split(':').sublist(1).join(':');
        targetRoute = Uri(
          path: '/coach',
          queryParameters: {'subject': subject},
        ).toString();
      }
    }

    context.go(targetRoute);
  }

  void _claimReward(WidgetRef ref, int reward) async {
    try {
      await ref.read(firestoreServiceProvider).claimQuestReward(
        userId,
        quest,
      );

      // UI feedback
      ref.invalidate(optimizedQuestsProvider);
    } catch (e) {
      // Handle error
      print('Reward claim failed: $e');
    }
  }
}
