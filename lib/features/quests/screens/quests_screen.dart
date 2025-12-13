// lib/features/quests/screens/quests_screen.dart
import 'dart:async';
import 'package:taktik/data/providers/firestore_providers.dart';
import 'package:taktik/data/providers/premium_provider.dart';
import 'package:taktik/features/quests/logic/quest_service.dart';
import 'package:taktik/features/quests/logic/optimized_quests_provider.dart';
import 'package:taktik/features/quests/models/quest_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';

class QuestsScreen extends ConsumerStatefulWidget {
  const QuestsScreen({super.key});

  @override
  ConsumerState<QuestsScreen> createState() => _QuestsScreenState();
}

class _QuestsScreenState extends ConsumerState<QuestsScreen> with SingleTickerProviderStateMixin {
  late AnimationController _bgController;

  @override
  void initState() {
    super.initState();
    // Pil tasarrufu için: repeat() yerine sadece bir kez çalıştır
    _bgController = AnimationController(vsync: this, duration: const Duration(seconds: 20))..forward();
    // İlk frame sonrası gün kontrolü ve gerekirse yenileme
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshQuestsIfNeeded());
  }

  void _refreshQuestsIfNeeded() {
    if (!mounted) return;
    final questsState = ref.read(optimizedQuestsProvider);
    final lastUpdate = questsState.lastDailyUpdate;
    final now = DateTime.now();
    final needsRefresh = lastUpdate == null ||
        lastUpdate.year != now.year ||
        lastUpdate.month != now.month ||
        lastUpdate.day != now.day;
    if (needsRefresh) {
      _refreshQuests();
    }
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
    _bgController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final questsState = ref.watch(optimizedQuestsProvider);
    final user = ref.watch(userProfileProvider).value;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          // Animated Grid Background
          Positioned.fill(
            child: CustomPaint(
              painter: AnimatedGridPainter(_bgController, Theme.of(context).colorScheme),
            ),
          ),
          // Main Content
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(context),
                  const SizedBox(height: 24),
                  if (questsState.isLoaded && questsState.allQuests != null)
                    _buildQuestList(questsState.allQuests!, user?.id ?? '')
                  else
                    _buildLoadingState(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                icon: Icon(Icons.arrow_back_ios_new_rounded, color: Theme.of(context).colorScheme.onSurface),
                onPressed: () => context.pop(),
              ),
              const SizedBox(width: 8),
              Text(
                'Günlük Görevler',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 500.ms).slideY(begin: -0.2);
  }

  Widget _buildLoadingState() {
    return Expanded(
      child: Center(
        child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary)
            .animate()
            .scale(),
      ),
    );
  }

  Widget _buildQuestList(List<Quest> quests, String userId) {
    if (quests.isEmpty) {
      return _buildEmptyState();
    }

    // GÖREVLERİ SIRALA
    quests.sort((a, b) {
      final aClaimable = a.isCompleted && !a.rewardClaimed;
      final bClaimable = b.isCompleted && !b.rewardClaimed;
      if (aClaimable && !bClaimable) return -1;
      if (!aClaimable && bClaimable) return 1;

      final aCompleted = a.isCompleted && a.rewardClaimed;
      final bCompleted = b.isCompleted && b.rewardClaimed;
      if (aCompleted && !bCompleted) return 1;
      if (!aCompleted && bCompleted) return -1;

      return 0;
    });

    return Expanded(
      child: ListView.builder(
        padding: EdgeInsets.zero,
        itemCount: quests.length,
        itemBuilder: (context, index) {
          final quest = quests[index];
          return GamifiedQuestCard(
            quest: quest,
            userId: userId,
          )
              .animate()
              .fadeIn(delay: (index * 150).ms, duration: 600.ms)
              .slideY(begin: 0.5, curve: Curves.easeOutCubic);
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Expanded(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Modern Lottie animasyonu
              Lottie.asset(
                'assets/lotties/Done.json',
                width: 200,
                height: 200,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 32),
              Text(
                'Tüm Görevler Tamamlandı!',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              // Modern card container
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest.withAlpha(100),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant.withAlpha(80),
                    width: 1,
                  ),
                ),
                child: Text(
                  'Harika iş çıkardın, Savaşçı! Yeni görevler için yarını bekle.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 16,
                    height: 1.6,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ).animate().fadeIn(duration: 600.ms).scale(delay: 100.ms),
        ),
      ),
    );
  }
}

class GamifiedQuestCard extends ConsumerStatefulWidget {
  final Quest quest;
  final String userId;

  const GamifiedQuestCard({
    super.key,
    required this.quest,
    required this.userId,
  });

  @override
  ConsumerState<GamifiedQuestCard> createState() => _GamifiedQuestCardState();
}

class _GamifiedQuestCardState extends ConsumerState<GamifiedQuestCard> {
  // ÇÖZÜM: Race condition önleme için loading state
  bool _isClaimingReward = false;

  // Premium gerektiren route'lar için özel offer verileri
  Map<String, dynamic>? _getPremiumOfferData(String route) {
    switch (route) {
      case '/ai-hub/strategic-planning':
        return {
          'title': 'Haftalık Stratejist',
          'subtitle': 'Hedefine giden en kısa yol.',
          'icon': Icons.map_rounded,
          'color': const Color(0xFF10B981),
          'marketingTitle': 'Rotanı Çiz!',
          'marketingSubtitle': 'Rastgele çalışarak vakit kaybetme. Taktik Tavşan senin için en verimli haftalık planı saniyeler içinde oluştursun.',
          'redirectRoute': '/ai-hub/strategic-planning',
        };
      case '/ai-hub/weakness-workshop':
        return {
          'title': 'Cevher Atölyesi',
          'subtitle': 'Zayıflıkları güce çevir.',
          'icon': Icons.diamond_rounded,
          'color': const Color(0xFF8B5CF6),
          'heroTag': 'weakness-workshop-offer',
          'marketingTitle': 'Ustalaşmadan Çıkma!',
          'marketingSubtitle': 'Sadece eksik olduğun konuya odaklan. Taktik Tavşan sana özel sorularla o konuyu halletmeden seni bırakmasın.',
          'redirectRoute': '/ai-hub/weakness-workshop',
        };
      case '/ai-hub/motivation-chat':
        return {
          'title': 'Taktik Tavşan',
          'subtitle': 'Sadece ders değil, kriz anlarını yönet.',
          'icon': Icons.psychology_rounded,
          'color': Colors.indigoAccent,
          'marketingTitle': 'Koçun Cebinde!',
          'marketingSubtitle': 'Netlerin neden artmıyor? Stresle nasıl başa çıkarsın? Taktik Tavşan seni analiz edip nokta atışı yönlendirme yapsın.',
          'redirectRoute': '/ai-hub/motivation-chat',
          'imageAsset': 'assets/images/bunnyy.png',
        };
      case '/ai-hub/analysis-strategy':
        return {
          'title': 'Analiz & Strateji',
          'subtitle': 'Verilerle konuşan koç.',
          'icon': Icons.radar_rounded,
          'color': const Color(0xFFF43F5E),
          'heroTag': 'analysis-strategy-offer',
          'marketingTitle': 'Tuzağı Fark Et!',
          'marketingSubtitle': 'Denemelerde neden takılıyorsun? Detaylı analiz sistemi, seni aşağı çeken konuları nokta atışı tespit etsin.',
          'redirectRoute': '/ai-hub/analysis-strategy',
        };
      default:
        return null;
    }
  }

  void _handleQuestTap(BuildContext context) {
    // Analytics logging kaldırıldı - artık başka bir analitik aracı kullanılıyor

    String targetRoute = widget.quest.actionRoute;
    if (targetRoute == '/coach') {
      final subjectTag = widget.quest.tags.firstWhere((t) => t.startsWith('subject:'), orElse: () => '');
      if (subjectTag.isNotEmpty) {
        final subject = subjectTag.split(':').sublist(1).join(':');
        targetRoute = Uri(path: '/coach', queryParameters: {'subject': subject}).toString();
      }
    }

    // Premium kontrolü yap
    final isPremium = ref.read(premiumStatusProvider);
    final offerData = _getPremiumOfferData(targetRoute);

    // Debug log
    print('🎯 Quest tap - Route: $targetRoute, isPremium: $isPremium, hasOfferData: ${offerData != null}');

    // Eğer premium gerektiren bir route ise ve kullanıcı premium değilse
    if (!isPremium && offerData != null) {
      print('📱 Redirecting to offer screen');
      context.go('/ai-hub/offer', extra: offerData);
    } else {
      print('✅ Navigating directly to: $targetRoute');
      context.go(targetRoute);
    }
  }

  Future<void> _handleClaimReward(BuildContext context) async {
    // ÇÖZÜM: Zaten işlem yapılıyorsa, tekrar izin verme
    if (_isClaimingReward) return;

    setState(() => _isClaimingReward = true);

    try {
      final questService = ref.read(questServiceProvider);
      final success = await questService.claimReward(widget.userId, widget.quest.id);

      if (!mounted) return;

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${widget.quest.reward} BP kazandın!'),
            backgroundColor: Colors.green,
          ),
        );
        ref.invalidate(optimizedQuestsProvider);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Ödül alınırken bir hata oluştu.'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isClaimingReward = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = widget.quest.goalValue > 0
        ? (widget.quest.currentProgress / widget.quest.goalValue).clamp(0.0, 1.0)
        : (widget.quest.isCompleted ? 1.0 : 0.0);
    final isCompleted = widget.quest.isCompleted;
    final isClaimable = isCompleted && !widget.quest.rewardClaimed;
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    VoidCallback? onTapAction;
    // ÇÖZÜM: Loading sırasında butonu disable et
    if (isClaimable && !_isClaimingReward) {
      onTapAction = () => _handleClaimReward(context);
    } else if (!isCompleted && !_isClaimingReward) {
      onTapAction = () => _handleQuestTap(context);
    }

    return GestureDetector(
      onTap: onTapAction,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        decoration: BoxDecoration(
          color: isClaimable
              ? (isDark ? const Color(0xFF17294D) : Colors.amber.withOpacity(0.1))
              : colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isClaimable ? Colors.amber : colorScheme.surfaceContainerHighest.withOpacity(0.5),
            width: isClaimable ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isClaimable
                  ? Colors.amber.withOpacity(0.3)
                  : (isDark ? Colors.black.withOpacity(0.3) : Colors.black.withOpacity(0.08)),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildCategoryIcon(isCompleted, isClaimable),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.quest.title,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.quest.description,
                        style: TextStyle(
                          fontSize: 14,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                // ÇÖZÜM: Loading sırasında indicator göster
                _isClaimingReward
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : _buildRewardChip(isClaimable),
              ],
            ),
            // Yükleme durumunda hiçbir şey gösterme, sadece sağ üstteki indicator yeterli
            if (!_isClaimingReward && (!isCompleted || isClaimable)) ...[
              const SizedBox(height: 20),
              if (isClaimable)
                _buildClaimRewardPrompt()
              else
                _buildProgressBar(context, progress),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryIcon(bool isCompleted, bool isClaimable) {
    IconData icon;
    Color color;

    if (isClaimable) {
      icon = Icons.military_tech_rounded;
      color = Colors.amber;
    } else if (isCompleted) {
      icon = Icons.check_circle_rounded;
      color = Colors.green;
    } else {
      switch (widget.quest.category) {
        case QuestCategory.study: icon = Icons.menu_book_rounded; color = Colors.blueAccent; break;
        case QuestCategory.practice: icon = Icons.edit_note_rounded; color = Colors.greenAccent; break;
        case QuestCategory.engagement: icon = Icons.auto_awesome_rounded; color = Colors.purpleAccent; break;
        case QuestCategory.consistency: icon = Icons.event_repeat_rounded; color = Colors.orangeAccent; break;
        case QuestCategory.test_submission: icon = Icons.add_chart_rounded; color = Colors.redAccent; break;
        case QuestCategory.focus: icon = Icons.center_focus_strong; color = Colors.blue; break;
      }
    }

    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withOpacity(0.1),
        border: Border.all(color: color.withOpacity(0.5), width: 2),
      ),
      child: Icon(icon, color: color, size: 28),
    );
  }

  Widget _buildRewardChip(bool isClaimable) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: (isClaimable ? Colors.amber : Colors.amber).withOpacity(0.1),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: (isClaimable ? Colors.amber : Colors.amber).withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(isClaimable ? Icons.military_tech_rounded : Icons.star_rounded, color: Colors.amber, size: 18),
          const SizedBox(width: 6),
          Text(
            '+${widget.quest.reward}',
            style: const TextStyle(color: Colors.amber, fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildClaimRewardPrompt() {

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Ödülünü Topla!',
          style: TextStyle(
            color: Colors.amber,
            fontWeight: FontWeight.bold,
            fontSize: 16,
            shadows: [
              Shadow(
                blurRadius: 10.0,
                color: Colors.amber.withOpacity(0.5),
                offset: const Offset(0, 0),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        const Icon(Icons.touch_app_rounded, color: Colors.amber),
      ],
    ).animate(onPlay: (controller) => controller.repeat())
        .shimmer(delay: 400.ms, duration: 1800.ms, color: Colors.amber.withOpacity(0.3));
  }

  Widget _buildProgressBar(BuildContext context, double progress) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 8,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(4),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: progress,
                  child: Container(color: Theme.of(context).colorScheme.primary),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          '${widget.quest.currentProgress} / ${widget.quest.goalValue}',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}


class AnimatedGridPainter extends CustomPainter {
  final Animation<double> animation;
  final ColorScheme colorScheme;

  AnimatedGridPainter(this.animation, this.colorScheme) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = colorScheme.surfaceContainerHighest.withOpacity(0.1)
      ..strokeWidth = 1.0;

    final path = Path();
    const gridSize = 50.0;

    // Animate grid lines
    final offset = animation.value * gridSize * 2;

    for (double i = -offset; i < size.width + offset; i += gridSize) {
      path.moveTo(i, -offset);
      path.lineTo(i, size.height + offset);
    }
    for (double i = -offset; i < size.height + offset; i += gridSize) {
      path.moveTo(-offset, i);
      path.lineTo(size.width + offset, i);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
