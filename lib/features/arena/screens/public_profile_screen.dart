// lib/features/arena/screens/public_profile_screen.dart
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:taktik/data/providers/firestore_providers.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/services.dart';
import 'package:taktik/features/profile/logic/rank_service.dart';
import 'package:share_plus/share_plus.dart';
import 'package:taktik/features/auth/application/auth_controller.dart';
import 'package:intl/intl.dart';
import 'package:flutter/rendering.dart';
import 'package:taktik/shared/widgets/app_loader.dart';
import 'package:taktik/features/profile/widgets/user_moderation_menu.dart';

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
  final GlobalKey _shareKey = GlobalKey();
  bool _sharing = false;

  Future<void> _shareProfileImage() async {
    if (_sharing) return;
    setState(() => _sharing = true);
    try {
      final boundary = _shareKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;
      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;
      final bytes = byteData.buffer.asUint8List();
      final xfile = XFile.fromData(bytes, name: 'warrior_card.png', mimeType: 'image/png');

      // iOS için sharePositionOrigin gerekli
      final box = context.findRenderObject() as RenderBox?;
      final sharePositionOrigin = box != null
          ? box.localToGlobal(Offset.zero) & box.size
          : null;

      // ignore: deprecated_member_use
      await Share.shareXFiles(
        [xfile],
        text: 'Savaşçı Künyem',
        sharePositionOrigin: sharePositionOrigin,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Paylaşım hatası: $e')));
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  void _showPublicAchievements(BuildContext context, {required String displayName, required int testCount, required double avgNet, required int streak, required int engagement}) {
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
              Text('$displayName — Taktik Puanı', style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 20),
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Theme.of(context).colorScheme.surface.withOpacity(0.5),
                          Theme.of(context).colorScheme.surface.withOpacity(0.2)
                        ]),
                    border: Border.all(color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.flash_on_rounded, color: Theme.of(context).colorScheme.primary, size: 48),
                      const SizedBox(height: 12),
                      Text(
                        engagement.toString(),
                        style: Theme.of(ctx).textTheme.displaySmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Taktik Puanı',
                        style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showPublicProgress(BuildContext context, {required int testCount, required double avgNet, required int streak, required int engagement}) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('İlerleme Özeti'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _kv('Deneme', testCount.toString(), ctx),
            _kv('Ortalama Net', avgNet.toStringAsFixed(1), ctx),
            _kv('Günlük Seri', streak.toString(), ctx),
            _kv('Taktik Puanı', engagement.toString(), ctx),
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Kapat'))],
      ),
    );
  }

  Widget _kv(String k, String v, BuildContext ctx) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4.0),
    child: Row(children: [
      Expanded(
          child: Text(k,
              style: Theme.of(ctx)
                  .textTheme
                  .bodyLarge
                  ?.copyWith(color: Theme.of(ctx).colorScheme.onSurfaceVariant))),
      Text(v, style: Theme.of(ctx).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold))
    ]),
  );

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
          // Moderasyon menüsü (kendi profilinde gösterme)
          if (me?.uid != widget.userId)
            Builder(
              builder: (context) {
                return userProfileAsync.maybeWhen(
                  data: (data) {
                    if (data == null) return const SizedBox.shrink();
                    // GÜVENLİK: Username kullan
                    final username = (data['username'] as String?) ?? '';
                    final displayName = username.isNotEmpty ? '@$username' : 'İsimsiz Savaşçı';
                    return UserModerationMenu(
                      targetUserId: widget.userId,
                      targetUserName: displayName,
                      onBlocked: () {
                        // Engelleme sonrası ana ekrana dön
                        Navigator.of(context).pop();
                      },
                    );
                  },
                  orElse: () => const SizedBox.shrink(),
                );
              },
            ),
          IconButton(
            tooltip: _sharing ? 'Hazırlanıyor...' : 'Paylaş',
            onPressed: _sharing ? null : () { HapticFeedback.selectionClick(); _shareProfileImage(); },
            icon: Icon(Icons.ios_share_rounded, color: Theme.of(context).colorScheme.primary),
          ),
        ],
      ),
      body: userProfileAsync.when(
        data: (data) {
          if (data == null) {
            return const Center(child: Text('Savaşçı bulunamadı.'));
          }
          // GÜVENLİK: Gerçek isim yerine kullanıcı adı (13-17 yaş koruması)
          final String username = (data['username'] as String?) ?? '';
          final String displayName = username.isNotEmpty ? '@$username' : 'İsimsiz Savaşçı';
          final int testCount = (data['testCount'] as num?)?.toInt() ?? 0;
          final double totalNetSum = (data['totalNetSum'] as num?)?.toDouble() ?? 0.0;
          final double avgNet = testCount > 0 ? totalNetSum / testCount : 0.0;
          final int engagement = (data['engagementScore'] as num?)?.toInt() ?? 0;
          final int streak = (data['streak'] as num?)?.toInt() ?? 0;
          final String? avatarStyle = data['avatarStyle'] as String?;
          final String? avatarSeed = data['avatarSeed'] as String?;
          final rankInfo = RankService.getRankInfo(engagement);
          final rankName = rankInfo.current.name;
          final rankIcon = rankInfo.current.icon;
          final rankColor = rankInfo.current.color;
          final currentLevel = RankService.ranks.indexOf(rankInfo.current) + 1;
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
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                      child: Column(
                        children: [
                          const SizedBox(height: 12),
                          // Paylaşılabilir kart
                          RepaintBoundary(
                            key: _shareKey,
                            child: _ShareableProfileCard(
                              displayName: displayName,
                              avatarStyle: avatarStyle,
                              avatarSeed: avatarSeed,
                              rankColor: rankColor,
                              rankIcon: rankIcon,
                              rankName: rankName,
                              avgNet: avgNet,
                              testCount: testCount,
                              streak: streak,
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Takipçi/Takip sayıları
                          followCountsAsync.when(
                            data: (counts) => Row(
                              children: [
                                Expanded(child: _CountPill(label: 'Takipçi', value: counts.$1)),
                                const SizedBox(width: 12),
                                Expanded(child: _CountPill(label: 'Takip', value: counts.$2)),
                              ],
                            ),
                            loading: () => const LinearProgressIndicator(minHeight: 2),
                            error: (e, s) => const SizedBox.shrink(),
                          ),
                          const SizedBox(height: 12),
                          // Takip Et butonu - tam genişlikte
                          if (me?.uid != widget.userId)
                            SizedBox(
                              width: double.infinity,
                              child: _FollowButton(targetUserId: widget.userId),
                            ),
                          const SizedBox(height: 8),
                          if (updatedAt != null)
                            Align(
                              alignment: Alignment.centerRight,
                              child: Text(
                                "Son güncelleme: ${DateFormat('dd MMM yyyy HH:mm', 'tr_TR').format(updatedAt)}",
                                style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.white70),
                              ),
                            ),
                          const SizedBox(height: 16),
                          // Başarılar butonu - tam genişlikte
                          _ActionTile(
                            icon: Icons.emoji_events_outlined,
                            label: 'Başarılar',
                            onTap: () {
                              HapticFeedback.selectionClick();
                              _showPublicAchievements(context,
                                displayName: displayName,
                                testCount: testCount,
                                avgNet: avgNet,
                                streak: streak,
                                engagement: engagement,
                              );
                            }
                          ),
                          const SizedBox(height: 20),
                        ],
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

class _ShareableProfileCard extends StatelessWidget {
  final String displayName; final String? avatarStyle; final String? avatarSeed; final Color rankColor; final IconData rankIcon; final String rankName; final double avgNet; final int testCount; final int streak;
  const _ShareableProfileCard({
    required this.displayName,
    required this.avatarStyle,
    required this.avatarSeed,
    required this.rankColor,
    required this.rankIcon,
    required this.rankName,
    required this.avgNet,
    required this.testCount,
    required this.streak,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
        children: [
          _AvatarHalo(displayName: displayName, avatarStyle: avatarStyle, avatarSeed: avatarSeed, rankColor: rankColor),
          const SizedBox(height: 10),
          Text(displayName, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          _RankCapsule(rankName: rankName, icon: rankIcon, color: rankColor),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _StatCard(label: 'Deneme', value: testCount.toString(), icon: Icons.library_books_rounded, delay: 0.ms)),
              const SizedBox(width: 10),
              Expanded(child: _StatCard(label: 'Ort. Net', value: avgNet.toStringAsFixed(1), icon: Icons.track_changes_rounded, delay: 0.ms)),
              const SizedBox(width: 10),
              Expanded(child: _StatCard(label: 'Seri', value: streak.toString(), icon: Icons.local_fire_department_rounded, delay: 0.ms)),
            ],
          ),
          const SizedBox(height: 14),
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

class _CountPill extends StatelessWidget {
  final String label;
  final int value;
  const _CountPill({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity, // Tam genişlik
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
          const SizedBox(width: 6),
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
  bool? _optimistic; // null: stream belirleyici, true/false: anlık gösterim
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

// Aşağıdaki bileşenler eski dosyadan alınmış uyumlu kopyalardır
class _AvatarHalo extends StatelessWidget {
  final String displayName; final String? avatarStyle; final String? avatarSeed; final Color rankColor;
  const _AvatarHalo({required this.displayName, required this.avatarStyle, required this.avatarSeed, required this.rankColor});
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 150,
      height: 150,
      child: Stack(
        alignment: Alignment.center,
        children: [
          _HaloCircle(
              color: colorScheme.primary.withOpacity(0.25),
              size: 140,
              begin: 0.85,
              end: 1.05,
              delay: 0.ms),
          _HaloCircle(
              color: colorScheme.secondary.withOpacity(0.18),
              size: 110,
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
              radius: 56,
              backgroundColor: Colors.black,
              child: ClipOval(
                child: avatarStyle != null && avatarSeed != null
                    ? SvgPicture.network(
                  "https://api.dicebear.com/9.x/$avatarStyle/svg?seed=$avatarSeed",
                  fit: BoxFit.cover,
                )
                    : Text(
                  // @ işaretini atla, username'in ilk harfini al
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
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: LinearGradient(colors: [color.withOpacity(0.2), color.withOpacity(0.05)]),
        border: Border.all(color: color.withOpacity(0.6), width: 1.2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Text(rankName, style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label; final String value; final IconData icon; final Duration delay;
  const _StatCard({required this.label, required this.value, required this.icon, required this.delay});
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Semantics(
      label: '$label istatistiği: $value',
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [colorScheme.onSurface.withOpacity(0.1), colorScheme.onSurface.withOpacity(0.05)]),
          border: Border.all(color: colorScheme.onSurface.withOpacity(0.12), width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 20, color: colorScheme.secondary),
              const SizedBox(height: 8),
              Text(value,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(label,
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(color: colorScheme.onSurface.withOpacity(0.7)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionTile extends StatefulWidget {
  final IconData icon; final String label; final VoidCallback onTap; const _ActionTile({required this.icon, required this.label, required this.onTap});
  @override
  State<_ActionTile> createState() => _ActionTileState();
}

class _ActionTileState extends State<_ActionTile> {
  bool _pressed = false;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) { setState(() => _pressed = false); widget.onTap(); },
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1,
        duration: 120.ms,
        curve: Curves.easeOut,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Theme.of(context).colorScheme.surface.withOpacity(0.5),
                  Theme.of(context).colorScheme.surface.withOpacity(0.2)
                ]),
            border: Border.all(color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(widget.icon, color: Theme.of(context).colorScheme.primary, size: 22),
              const SizedBox(width: 8),
              Text(widget.label, style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}

// Yardımcı: kısa kullanım için ekstension
extension _ColorAlphaX on Color { Color oa(double f)=> withValues(alpha: (a * f).toDouble()); }
