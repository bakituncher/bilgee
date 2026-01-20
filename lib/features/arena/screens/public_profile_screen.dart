// lib/features/arena/screens/public_profile_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:taktik/data/providers/firestore_providers.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/services.dart';
import 'package:taktik/features/profile/logic/rank_service.dart';
import 'package:taktik/features/auth/application/auth_controller.dart';
import 'package:intl/intl.dart';
import 'package:taktik/shared/widgets/app_loader.dart';
import 'package:taktik/data/providers/moderation_providers.dart';
import 'package:taktik/features/profile/widgets/user_report_dialog.dart';

// Bu provider, ID'ye göre tek bir kullanıcı profili getirmek için kullanılır.
final publicUserProfileProvider = FutureProvider.family.autoDispose<Map<String, dynamic>?, String>((ref, userId) async {
  final svc = ref.watch(firestoreServiceProvider);
  final data = await svc.getPublicProfileRaw(userId);
  if (data != null) return data;
  // public_profiles yoksa: mevcut kullanıcının examType'ına göre liderlikten tekil kullanıcıyı dene
  final myExam = ref.watch(userProfileProvider).value?.selectedExam;
  if (myExam != null) {
    return await svc.getLeaderboardUserRaw(myExam, userId);
  }
  return null;
});


class PublicProfileScreen extends ConsumerStatefulWidget {
  final String userId;
  const PublicProfileScreen({super.key, required this.userId});

  @override
  ConsumerState<PublicProfileScreen> createState() => _PublicProfileScreenState();
}

class _PublicProfileScreenState extends ConsumerState<PublicProfileScreen> {

  int _calculateUnlockedBadges(Map<String, dynamic> data) {
    int count = 0;
    final int testCount = (data['testCount'] as num?)?.toInt() ?? 0;
    final int streak = (data['streak'] as num?)?.toInt() ?? 0;
    final int engagement = (data['engagementScore'] as num?)?.toInt() ?? 0;

    if (testCount >= 1) count++;
    if (testCount >= 5) count++;
    if (testCount >= 15) count++;
    if (testCount >= 50) count++;
    if (streak >= 3) count++;
    if (streak >= 14) count++;
    if (streak >= 30) count++;
    if (engagement > 0) count++;

    return count;
  }

  void _showModerationMenu(BuildContext context, String targetUserId, String displayName) {
    final colorScheme = Theme.of(context).colorScheme;

    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(4)))),
              const SizedBox(height: 12),
              Text('Kullanıcı Ayarları', style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              ListTile(
                leading: Icon(Icons.block, color: colorScheme.error),
                title: const Text('Kullanıcıyı Engelle'),
                onTap: () {
                  Navigator.pop(ctx);
                  _blockUser(targetUserId, displayName);
                },
              ),
              ListTile(
                leading: Icon(Icons.flag_outlined, color: colorScheme.error),
                title: const Text('Kullanıcıyı Raporla'),
                onTap: () {
                  Navigator.pop(ctx);
                  _reportUser(targetUserId, displayName);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _blockUser(String targetUserId, String displayName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Kullanıcıyı Engelle'),
        content: Text('$displayName kullanıcısını engellemek istediğinizden emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Engelle'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      final service = ref.read(moderationServiceProvider);
      await service.blockUser(targetUserId);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kullanıcı başarıyla engellendi')),
      );

      ref.invalidate(blockedUsersProvider);
      ref.invalidate(isUserBlockedProvider(targetUserId));
      ref.invalidate(blockStatusProvider(targetUserId));

      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hata: ${e.toString()}')),
      );
    }
  }

  Future<void> _reportUser(String targetUserId, String displayName) async {
    final reported = await showUserReportDialog(
      context,
      targetUserId: targetUserId,
      targetUserName: displayName,
    );

    if (reported == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kullanıcı rapor edildi')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final userProfileAsync = ref.watch(publicUserProfileProvider(widget.userId));
    final statsAsync = ref.watch(userStatsForUserProvider(widget.userId));
    final followCountsAsync = ref.watch(followCountsProvider(widget.userId));
    final me = ref.watch(authControllerProvider).value;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Savaşçı Künyesi'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (me?.uid != widget.userId)
            Builder(
              builder: (context) {
                return userProfileAsync.maybeWhen(
                  data: (data) {
                    if (data == null) return const SizedBox.shrink();
                    final username = (data['username'] as String?) ?? '';
                    final displayName = username.isNotEmpty ? '@$username' : 'İsimsiz Savaşçı';
                    return _ModernIconButton(
                      tooltip: 'Diğer',
                      icon: Icons.more_vert,
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        _showModerationMenu(context, widget.userId, displayName);
                      },
                    );
                  },
                  orElse: () => const SizedBox.shrink(),
                );
              },
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: userProfileAsync.when(
        data: (data) {
          if (data == null) {
            return const Center(child: Text('Savaşçı bulunamadı.'));
          }
          final String username = (data['username'] as String?) ?? '';
          final String displayName = username.isNotEmpty ? '@$username' : 'İsimsiz Savaşçı';
          final int testCount = (data['testCount'] as num?)?.toInt() ?? 0;
          final int engagement = (data['engagementScore'] as num?)?.toInt() ?? 0;
          final int streak = (data['streak'] as num?)?.toInt() ?? 0;
          final String? avatarStyle = data['avatarStyle'] as String?;
          final String? avatarSeed = data['avatarSeed'] as String?;

          final rankInfo = RankService.getRankInfo(engagement);
          final rankName = rankInfo.current.name;
          final rankIcon = rankInfo.current.icon;
          final rankColor = rankInfo.current.color;
          final rankIndex = RankService.ranks.indexOf(rankInfo.current);

          // XP Bar hesaplamaları
          final nextRank = rankInfo.next;
          final progressToNext = rankInfo.progress;
          // Eğer son seviyedeyse, hedef puanı mevcut seviye puanı yapalım
          final nextLevelXp = nextRank.requiredScore == rankInfo.current.requiredScore
              ? rankInfo.current.requiredScore
              : nextRank.requiredScore;

          final int unlockedBadges = _calculateUnlockedBadges(data);
          final int totalBadges = 8;
          final updatedAt = statsAsync.valueOrNull?.updatedAt;

          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Theme.of(context).scaffoldBackgroundColor,
                    Theme.of(context).cardColor,
                  ]),
            ),
            child: SafeArea(
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  // SliverFillRemaining ile ekrana ortalama yapıyoruz, ancak Spacer yerine Center kullanıyoruz
                  // bu sayede layout hatası riskini (unbounded height) ortadan kaldırıyoruz.
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Column(
                          mainAxisSize: MainAxisSize.min, // İçeriği sıkıştır
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Profil kartı
                            followCountsAsync.when(
                              data: (counts) => _ShareableProfileCard(
                                displayName: displayName,
                                avatarStyle: avatarStyle,
                                avatarSeed: avatarSeed,
                                rankColor: rankColor,
                                rankIcon: rankIcon,
                                rankName: rankName,
                                testCount: testCount,
                                streak: streak,
                                followerCount: counts.$1,
                                followingCount: counts.$2,
                                currentUserId: me?.uid,
                                targetUserId: widget.userId,
                                engagement: engagement,
                                unlockedBadges: unlockedBadges,
                                totalBadges: totalBadges,
                                rankIndex: rankIndex,
                                nextLevelXp: nextLevelXp,
                                progress: progressToNext,
                              ),
                              loading: () => const _ShareableProfileCardSkeleton(),
                              error: (e, s) => const _ShareableProfileCardSkeleton(),
                            ),
                            if (updatedAt != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                "Son güncelleme: ${DateFormat('dd MMM yyyy HH:mm', 'tr_TR').format(updatedAt)}",
                                style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.white70),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
        loading: () => const AppLoader(),
        error: (e, s) => Center(child: Text('Savaşçı Künyesi Yüklenemedi: $e')),
      ),
    );
  }
}

class _ShareableProfileCardSkeleton extends StatelessWidget {
  const _ShareableProfileCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 400,
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        color: Theme.of(context).colorScheme.surface.withOpacity(0.1),
        border: Border.all(color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5)),
      ),
      child: const Center(child: CircularProgressIndicator()),
    );
  }
}

class _ShareableProfileCard extends StatelessWidget {
  final String displayName;
  final String? avatarStyle;
  final String? avatarSeed;
  final Color rankColor;
  final IconData rankIcon;
  final String rankName;
  final int testCount;
  final int streak;
  final int followerCount;
  final int followingCount;
  final String? currentUserId;
  final String targetUserId;
  final int engagement;
  final int unlockedBadges;
  final int totalBadges;
  final int rankIndex;
  final int nextLevelXp;
  final double progress;

  const _ShareableProfileCard({
    required this.displayName,
    required this.avatarStyle,
    required this.avatarSeed,
    required this.rankColor,
    required this.rankIcon,
    required this.rankName,
    required this.testCount,
    required this.streak,
    required this.followerCount,
    required this.followingCount,
    required this.currentUserId,
    required this.targetUserId,
    required this.engagement,
    required this.unlockedBadges,
    required this.totalBadges,
    required this.rankIndex,
    required this.nextLevelXp,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity, // Kartın yatayda tam yer kaplamasını sağla
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).colorScheme.surface.withOpacity(0.5),
              Theme.of(context).colorScheme.surface.withOpacity(0.2)
            ]),
        border: Border.all(color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5), width: 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min, // İçeriği kadar yer kapla
        children: [
          _AvatarHalo(displayName: displayName, avatarStyle: avatarStyle, avatarSeed: avatarSeed, rankColor: rankColor),
          const SizedBox(height: 10),
          Text(displayName, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          _RankCapsule(rankName: rankName, icon: rankIcon, color: rankColor),
          const SizedBox(height: 12),

          // Taktik Puanı Çubuğu (XP Bar)
          // Genişliği garanti altına almak için SizedBox kullanıyoruz
          SizedBox(
            width: double.infinity,
            child: _NeoXpBar(
              currentXp: engagement,
              nextLevelXp: nextLevelXp,
              progress: progress,
            ),
          ).animate()
              .fadeIn(duration: 500.ms, delay: 200.ms)
              .slideX(begin: -0.2, end: 0, duration: 500.ms, curve: Curves.easeOutCubic),

          const SizedBox(height: 12),
          // İstatistik Grid
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
              border: Border.all(
                color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
                width: 1,
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _StatButton(
                        icon: Icons.military_tech_rounded,
                        iconColor: Colors.amber.shade600,
                        value: '$unlockedBadges/$totalBadges',
                        label: 'Madalyalar',
                        delay: 0.ms,
                      ),
                    ),
                    Container(
                      width: 1.5,
                      height: 60,
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Theme.of(context).colorScheme.outline.withOpacity(0.0),
                            Theme.of(context).colorScheme.outline.withOpacity(0.3),
                            Theme.of(context).colorScheme.outline.withOpacity(0.0),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      child: _StatButton(
                        icon: Icons.workspace_premium,
                        iconColor: rankColor,
                        value: '${rankIndex + 1}',
                        label: 'Seviye',
                        delay: 0.ms,
                      ),
                    ),
                  ],
                ),
                Container(
                  height: 1.5,
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        Theme.of(context).colorScheme.outline.withOpacity(0.0),
                        Theme.of(context).colorScheme.outline.withOpacity(0.3),
                        Theme.of(context).colorScheme.outline.withOpacity(0.0),
                      ],
                    ),
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: _StatButton(
                        icon: Icons.library_books_rounded,
                        iconColor: Theme.of(context).colorScheme.primary,
                        value: testCount.toString(),
                        label: 'Deneme',
                        delay: 0.ms,
                      ),
                    ),
                    Container(
                      width: 1.5,
                      height: 60,
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Theme.of(context).colorScheme.outline.withOpacity(0.0),
                            Theme.of(context).colorScheme.outline.withOpacity(0.3),
                            Theme.of(context).colorScheme.outline.withOpacity(0.0),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      child: _StatButton(
                        icon: Icons.local_fire_department_rounded,
                        iconColor: Colors.orange.shade700,
                        value: streak.toString(),
                        label: 'Seri',
                        delay: 0.ms,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _CountPill(label: 'Takipçi', value: followerCount)),
              const SizedBox(width: 8),
              Expanded(child: _CountPill(label: 'Takip', value: followingCount)),
            ],
          ),
          const SizedBox(height: 12),
          if (currentUserId != null && currentUserId != targetUserId) ...[
            SizedBox(
              width: double.infinity,
              child: _FollowButton(targetUserId: targetUserId),
            ),
            const SizedBox(height: 12),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset('assets/images/splash.png', width: 28, height: 28),
              const SizedBox(width: 8),
              Text('Taktik App', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }
}

class _NeoXpBar extends StatelessWidget {
  final int currentXp; final int nextLevelXp; final double progress;
  const _NeoXpBar({required this.currentXp, required this.nextLevelXp, required this.progress});
  @override
  Widget build(BuildContext context) {
    final capped = progress.clamp(0.0, 1.0);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final accentProfile1 = colorScheme.primary;
    final accentProfile2 = colorScheme.secondary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min, // Önemli: Yüksekliği içerik kadar olsun
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: accentProfile2.withOpacity(0.15),
                borderRadius: BorderRadius.circular(7),
              ),
              child: Icon(Icons.flash_on_rounded, size: 16, color: accentProfile2),
            ),
            const SizedBox(width: 6),
            Text(
              'Taktik Puanı',
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w800,
                fontSize: 12,
                letterSpacing: 0.3,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: colorScheme.outline.withOpacity(0.1),
                  width: 1,
                ),
              ),
              child: Text(
                '$currentXp / $nextLevelXp',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurface.withOpacity(0.8),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        // Genişlik garantisi için Container kullanıyoruz
        Container(
          width: double.infinity,
          height: 24, // Yükseklik vererek layout belirsizliğini önlüyoruz
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: [accentProfile1, accentProfile2, accentProfile1],
            ),
            boxShadow: [
              BoxShadow(
                color: accentProfile2.withOpacity(0.3),
                blurRadius: 12,
                spreadRadius: 0,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Genişlik kontrolü: Eğer sonsuz gelirse varsayılan bir değer kullan
              final w = constraints.maxWidth.isFinite ? constraints.maxWidth : 200.0;
              return Stack(
                children: [
                  Container(
                    height: 20,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      color: colorScheme.surface.withOpacity(0.7),
                    ),
                  ),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 900),
                    curve: Curves.easeOutCubic,
                    width: (w) * capped,
                    height: 20,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          accentProfile2,
                          accentProfile1,
                          accentProfile2,
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: accentProfile2.withOpacity(0.5),
                          blurRadius: 16,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
                  if (capped > 0.05)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 900),
                      curve: Curves.easeOutCubic,
                      width: (w) * capped,
                      height: 20,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            Colors.white.withOpacity(0.0),
                            Colors.white.withOpacity(0.2),
                            Colors.white.withOpacity(0.0),
                          ],
                          stops: const [0.0, 0.5, 1.0],
                        ),
                      ),
                    ).animate(onPlay: (controller) => controller.repeat())
                        .shimmer(duration: 2000.ms, delay: 500.ms),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _CountPill extends StatelessWidget {
  final String label;
  final int value;
  const _CountPill({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: colorScheme.onSurface.withOpacity(0.06),
        border: Border.all(color: colorScheme.onSurface.withOpacity(0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value.toString(),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(width: 5),
          Text(label, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: colorScheme.onSurface.withOpacity(0.7))),
        ],
      ),
    );
  }
}

class _FollowButton extends ConsumerStatefulWidget {
  final String targetUserId;
  const _FollowButton({required this.targetUserId});
  @override
  ConsumerState<_FollowButton> createState() => _FollowButtonState();
}

class _FollowButtonState extends ConsumerState<_FollowButton> {
  bool? _optimistic;
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(authControllerProvider).value;
    final isFollowingAsync = ref.watch(isFollowingProvider(widget.targetUserId));
    final bool? streamVal = isFollowingAsync.valueOrNull;
    final bool? loading = isFollowingAsync.isLoading ? true : null;
    final bool isFollowing = _optimistic ?? (streamVal ?? false);
    final colorScheme = Theme.of(context).colorScheme;

    final bg = isFollowing ? Colors.transparent : colorScheme.secondary;
    final fg = isFollowing ? colorScheme.secondary : colorScheme.onSecondary;
    final icon = isFollowing ? Icons.check_rounded : Icons.person_add_alt_1_rounded;
    final label = isFollowing ? 'Takipten Çık' : 'Takip Et';

    return ElevatedButton.icon(
      onPressed: _busy || me?.uid == null || me!.uid == widget.targetUserId
          ? null
          : () async {
        HapticFeedback.selectionClick();
        setState(() {
          _busy = true;
          _optimistic = !isFollowing;
        });
        try {
          final svc = ref.read(firestoreServiceProvider);
          if (isFollowing) {
            await svc.unfollowUser(currentUserId: me.uid, targetUserId: widget.targetUserId);
          } else {
            await svc.followUser(currentUserId: me.uid, targetUserId: widget.targetUserId);
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('İşlem başarısız: $e')));
            setState(() {
              _optimistic = null;
            });
          }
        } finally {
          if (mounted) {
            setState(() {
              _busy = false;
              _optimistic = null;
            });
          }
        }
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: bg,
        foregroundColor: fg,
        elevation: 0,
        side: BorderSide(color: colorScheme.secondary.withOpacity(0.8)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        minimumSize: const Size(0, 40),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      icon: (loading == true && _optimistic == null) || _busy
          ? SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2, color: colorScheme.secondary))
          : Icon(icon, size: 18),
      label: Text(label, style: const TextStyle(fontSize: 13)),
    );
  }
}

class _AvatarHalo extends StatelessWidget {
  final String displayName; final String? avatarStyle; final String? avatarSeed; final Color rankColor;
  const _AvatarHalo({required this.displayName, required this.avatarStyle, required this.avatarSeed, required this.rankColor});
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 120,
      height: 120,
      child: Stack(
        alignment: Alignment.center,
        children: [
          _HaloCircle(
              color: colorScheme.primary.withOpacity(0.25),
              size: 110,
              begin: 0.85,
              end: 1.05,
              delay: 0.ms),
          _HaloCircle(
              color: colorScheme.secondary.withOpacity(0.18),
              size: 88,
              begin: 0.9,
              end: 1.08,
              delay: 400.ms),
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [colorScheme.secondary, colorScheme.primary]),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: colorScheme.secondary.withOpacity(0.4), blurRadius: 20, spreadRadius: 2),
              ],
            ),
            child: CircleAvatar(
              radius: 44,
              backgroundColor: Colors.black,
              child: ClipOval(
                child: avatarStyle != null && avatarSeed != null
                    ? SvgPicture.network(
                  "https://api.dicebear.com/9.x/$avatarStyle/svg?seed=$avatarSeed",
                  fit: BoxFit.cover,
                  placeholderBuilder: (BuildContext context) => Container(
                      padding: const EdgeInsets.all(30.0),
                      child: const CircularProgressIndicator()),
                )
                    : Text(
                  (displayName.isNotEmpty && displayName.startsWith('@')
                      ? displayName.substring(1, displayName.length > 1 ? 2 : 1)
                      : displayName.isNotEmpty ? displayName[0] : 'T').toUpperCase(),
                  style: Theme.of(context)
                      .textTheme
                      .displayMedium
                      ?.copyWith(color: colorScheme.secondary, fontWeight: FontWeight.bold),
                ),
              ),
            ).animate().fadeIn(duration: 500.ms).scale(curve: Curves.easeOutBack),
          ),
        ],
      ),
    );
  }
}

class _HaloCircle extends StatelessWidget {
  final Color color; final double size; final double begin; final double end; final Duration delay;
  const _HaloCircle({required this.color, required this.size, required this.begin, required this.end, required this.delay});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, Colors.transparent]),
      ),
    ).animate(onPlay: (c) => c.repeat(reverse: true))
        .scale(begin: Offset(begin, begin), end: Offset(end, end), duration: 3000.ms, curve: Curves.easeInOut, delay: delay)
        .fadeIn(duration: 1200.ms, delay: delay);
  }
}

class _RankCapsule extends StatelessWidget {
  final String rankName;
  final IconData icon;
  final Color color;
  const _RankCapsule({required this.rankName, required this.icon, required this.color});
  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: 400.ms,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: LinearGradient(colors: [color.withOpacity(0.2), color.withOpacity(0.05)]),
        border: Border.all(color: color.withOpacity(0.6), width: 1.2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 6),
          Text(rankName, style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _StatButton extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;
  final Duration delay;

  const _StatButton({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
    required this.delay,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            style: textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
              color: iconColor,
              fontSize: 18,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            label,
            style: textTheme.bodySmall?.copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _ModernIconButton extends StatefulWidget {
  final String? tooltip;
  final IconData icon;
  final VoidCallback? onPressed;

  const _ModernIconButton({
    this.tooltip,
    required this.icon,
    this.onPressed,
  });

  @override
  State<_ModernIconButton> createState() => _ModernIconButtonState();
}

class _ModernIconButtonState extends State<_ModernIconButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Tooltip(
        message: widget.tooltip ?? '',
        child: GestureDetector(
          onTapDown: widget.onPressed != null ? (_) => setState(() => _isPressed = true) : null,
          onTapUp: widget.onPressed != null ? (_) {
            setState(() => _isPressed = false);
            widget.onPressed?.call();
          } : null,
          onTapCancel: () => setState(() => _isPressed = false),
          child: AnimatedScale(
            scale: _isPressed ? 0.85 : 1.0,
            duration: const Duration(milliseconds: 100),
            curve: Curves.easeOut,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _isPressed
                    ? colorScheme.primaryContainer.withOpacity(0.8)
                    : colorScheme.surfaceContainerHighest.withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: colorScheme.outline.withOpacity(0.1),
                  width: 1,
                ),
              ),
              child: Icon(
                widget.icon,
                size: 22,
                color: widget.onPressed != null
                    ? colorScheme.onSurface
                    : colorScheme.onSurface.withOpacity(0.3),
              ),
            ),
          ),
        ),
      ),
    );
  }
}