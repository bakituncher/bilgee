// lib/features/profile/screens/follow_list_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:bilge_ai/core/theme/app_theme.dart';
import 'package:bilge_ai/data/providers/firestore_providers.dart';
import 'package:bilge_ai/features/auth/application/auth_controller.dart';

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
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0B0F14), Color(0xFF2A155A), Color(0xFF061F38)],
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
                      const Icon(Icons.group_outlined, size: 56, color: AppTheme.secondaryTextColor),
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
            loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.secondaryColor)),
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
    final raw = (data?['name'] as String?)?.trim() ?? '';
    if (raw.isEmpty || _looksLikeId(raw)) return 'İsimsiz Savaşçı';
    return raw;
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(authControllerProvider).value;
    final publicAsync = ref.watch(publicProfileRawProvider(widget.targetUserId));
    final isFollowingAsync = ref.watch(isFollowingProvider(widget.targetUserId));
    final countsAsync = ref.watch(followCountsProvider(widget.targetUserId));

    return publicAsync.when(
      data: (data) {
        final displayName = _safeDisplayName(data);
        final avatarStyle = data?['avatarStyle'] as String?;
        final avatarSeed = data?['avatarSeed'] as String?;
        final isFollowing = _optimistic ?? (isFollowingAsync.valueOrNull ?? false);

        return Material(
          color: Colors.white.withValues(alpha: 0.03),
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
                    backgroundColor: Colors.white.withValues(alpha: 0.06),
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
                              displayName.substring(0, 1).toUpperCase(),
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
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.white70),
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
                              foregroundColor: Colors.redAccent,
                              side: const BorderSide(color: Colors.redAccent),
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
                              backgroundColor: AppTheme.secondaryColor.withValues(alpha: 0.18),
                              foregroundColor: AppTheme.secondaryColor,
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
          color: Colors.white.withValues(alpha: 0.04),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        padding: const EdgeInsets.all(12),
        child: Row(
          children: const [
            CircleAvatar(radius: 24, backgroundColor: Colors.white12),
            SizedBox(width: 12),
            Expanded(child: LinearProgressIndicator(minHeight: 8)),
          ],
        ),
      ),
      error: (e, s) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.red.withValues(alpha: 0.06),
          border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
        ),
        child: Text('Kullanıcı yüklenemedi: $e', style: const TextStyle(color: Colors.redAccent)),
      ),
    );
  }
}
