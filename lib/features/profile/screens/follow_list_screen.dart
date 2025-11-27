// lib/features/profile/screens/follow_list_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:taktik/data/providers/firestore_providers.dart';
import 'package:taktik/data/repositories/firestore_service.dart';
import 'package:taktik/features/auth/application/auth_controller.dart';
import 'package:taktik/features/profile/widgets/user_moderation_menu.dart';

class FollowListScreen extends ConsumerWidget {
  final String mode; // 'followers' | 'following'
  const FollowListScreen({super.key, required this.mode});

  bool get _isFollowers => mode == 'followers';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(authControllerProvider).value;
    final userId = me?.uid;
    if (userId == null) {
      return const Scaffold(body: Center(child: Text('Oturum bulunamadı.')));
    }

    final idsAsync = _isFollowers
        ? ref.watch(followerIdsProvider(userId))
        : ref.watch(followingIdsProvider(userId));

    return Scaffold(
      appBar: AppBar(
        title: Text(_isFollowers ? 'Takipçiler' : 'Takip Edilenler'),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Theme.of(context).scaffoldBackgroundColor,
              Theme.of(context).cardColor,
              Theme.of(context).scaffoldBackgroundColor,
            ],
          ),
        ),
        child: SafeArea(
          child: idsAsync.when(
            data: (ids) {
              if (ids.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.group_outlined, size: 56, color: Theme.of(context).colorScheme.onSurfaceVariant),
                      const SizedBox(height: 12),
                      Text(
                        _isFollowers ? 'Henüz takipçin yok.' : 'Henüz kimseyi takip etmiyorsun.',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                itemCount: ids.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final uid = ids[index];
                  if (uid == me!.uid) return const SizedBox.shrink();
                  return _FollowListTile(targetUserId: uid);
                },
              );
            },
            loading: () => Center(child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary)),
            error: (e, s) => Center(child: Text('Liste yüklenemedi: $e')),
          ),
        ),
      ),
    );
  }
}

class _FollowListTile extends ConsumerStatefulWidget {
  final String targetUserId;
  const _FollowListTile({required this.targetUserId});

  @override
  ConsumerState<_FollowListTile> createState() => _FollowListTileState();
}

class _FollowListTileState extends ConsumerState<_FollowListTile> {
  bool? _optimistic; // null: stream belirleyici, true/false: anlık göster

  bool _looksLikeId(String s) {
    final t = s.trim();
    if (t.isEmpty) return false;
    // Çok uzun ve alfasayısal UID benzeri dizeleri isim olarak kabul etme
    return RegExp(r'^[A-Za-z0-9_-]{20,}$').hasMatch(t);
  }

  String _safeDisplayName(Map<String, dynamic>? data) {
    // GÜVENLİK: Gerçek isim yerine username (13-17 yaş koruması)
    final username = (data?['username'] as String?)?.trim() ?? '';
    if (username.isNotEmpty) return '@$username';
    return 'İsimsiz Savaşçı';
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(authControllerProvider).value;
    final publicAsync = ref.watch(publicProfileRawProvider(widget.targetUserId));
    final isFollowingAsync = ref.watch(isFollowingProvider(widget.targetUserId));
    final countsAsync = ref.watch(followCountsProvider(widget.targetUserId));
    final firestoreService = ref.watch(firestoreServiceProvider);

    return publicAsync.when(
      data: (data) {
        // LAZY CLEANUP: Kullanıcı silinmişse (data == null) listeden temizle
        if (data == null && me != null) {
          // Arka planda sessizce temizle (UI'ı bloke etme)
          Future.microtask(() {
            firestoreService.lazyCleanupDeletedUser(
              currentUserId: me.uid,
              deletedUserId: widget.targetUserId,
            );
          });
          // UI'da gösterme (zaten silinmiş kullanıcı)
          return const SizedBox.shrink();
        }

        final displayName = _safeDisplayName(data);
        final avatarStyle = data?['avatarStyle'] as String?;
        final avatarSeed = data?['avatarSeed'] as String?;
        final isFollowing = _optimistic ?? (isFollowingAsync.valueOrNull ?? false);

        return Material(
          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.03),
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => context.push('/arena/${widget.targetUserId}'),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.06),
                    child: ClipOval(
                      child: (avatarStyle != null && avatarSeed != null)
                          ? SvgPicture.network(
                              'https://api.dicebear.com/9.x/$avatarStyle/svg?seed=$avatarSeed',
                              fit: BoxFit.cover,
                              width: 44,
                              height: 44,
                              placeholderBuilder: (_) => const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
                            )
                          : Text(
                              displayName.startsWith('@') && displayName.length > 1
                                  ? displayName.substring(1, 2).toUpperCase()
                                  : displayName.substring(0, 1).toUpperCase(),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        countsAsync.when(
                          data: (c) => Text(
                            'Takipçi ${c.$1} • Takip ${c.$2}',
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          loading: () => const SizedBox(height: 14, child: LinearProgressIndicator(minHeight: 6)),
                          error: (e, s) => const SizedBox.shrink(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Moderasyon menüsü
                  UserModerationMenu(
                    targetUserId: widget.targetUserId,
                    targetUserName: displayName,
                    onBlocked: () {
                      // Engelleme sonrası listeyi yenile
                      ref.invalidate(followerIdsProvider(me!.uid));
                      ref.invalidate(followingIdsProvider(me!.uid));
                    },
                  ),
                  const SizedBox(width: 4),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    switchInCurve: Curves.easeOut,
                    switchOutCurve: Curves.easeIn,
                    child: isFollowing
                        ? OutlinedButton.icon(
                            key: const ValueKey('unfollow'),
                            onPressed: () async {
                              HapticFeedback.selectionClick();
                              final svc = ref.read(firestoreServiceProvider);
                              setState(() => _optimistic = false);
                              try {
                                await svc.unfollowUser(currentUserId: me!.uid, targetUserId: widget.targetUserId);
                              } finally {
                                if (mounted) setState(() => _optimistic = null);
                              }
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Theme.of(context).colorScheme.error,
                              side: BorderSide(color: Theme.of(context).colorScheme.error),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              minimumSize: const Size(0, 40),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            icon: const Icon(Icons.person_remove_alt_1, size: 18),
                            label: const Text('Takipten Çıkar'),
                          )
                        : FilledButton.tonalIcon(
                            key: const ValueKey('follow'),
                            onPressed: () async {
                              HapticFeedback.selectionClick();
                              final svc = ref.read(firestoreServiceProvider);
                              setState(() => _optimistic = true);
                              try {
                                await svc.followUser(currentUserId: me!.uid, targetUserId: widget.targetUserId);
                              } finally {
                                if (mounted) setState(() => _optimistic = null);
                              }
                            },
                            style: FilledButton.styleFrom(
                              backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.18),
                              foregroundColor: Theme.of(context).colorScheme.primary,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              minimumSize: const Size(0, 40),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            icon: const Icon(Icons.person_add_alt_1, size: 18),
                            label: const Text('Takip Et'),
                          ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
      loading: () => Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.04),
          border: Border.all(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.08)),
        ),
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            CircleAvatar(radius: 24, backgroundColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.12)),
            const SizedBox(width: 12),
            const Expanded(child: LinearProgressIndicator(minHeight: 8)),
          ],
        ),
      ),
      error: (e, s) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Theme.of(context).colorScheme.error.withOpacity(0.06),
          border: Border.all(color: Theme.of(context).colorScheme.error.withOpacity(0.2)),
        ),
        child: Text('Kullanıcı yüklenemedi: $e', style: TextStyle(color: Theme.of(context).colorScheme.error)),
      ),
    );
  }
}
