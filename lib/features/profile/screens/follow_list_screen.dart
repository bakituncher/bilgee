// lib/features/profile/screens/follow_list_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:bilge_ai/core/theme/app_theme.dart';
import 'package:bilge_ai/data/providers/firestore_providers.dart';
import 'package:bilge_ai/data/repositories/firestore_service.dart';
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
      body: idsAsync.when(
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
            separatorBuilder: (_, __) => const SizedBox(height: 8),
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

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(authControllerProvider).value;
    final publicAsync = ref.watch(publicProfileRawProvider(widget.targetUserId));
    final isFollowingAsync = ref.watch(isFollowingProvider(widget.targetUserId));

    return publicAsync.when(
      data: (data) {
        final name = (data?['name'] as String?)?.trim() ?? '';
        final displayName = name.isNotEmpty ? name : '';
        final avatarStyle = data?['avatarStyle'] as String?;
        final avatarSeed = data?['avatarSeed'] as String?;
        final isFollowing = _optimistic ?? (isFollowingAsync.valueOrNull ?? false);

        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0x1AFFFFFF), Color(0x0FFFFFFF)]),
            border: Border.all(color: Colors.white.withOpacity(0.12), width: 1),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => context.push('/arena/${widget.targetUserId}'),
                child: CircleAvatar(
                  radius: 22,
                  backgroundColor: Colors.white10,
                  child: ClipOval(
                    child: (avatarStyle != null && avatarSeed != null)
                        ? SvgPicture.network('https://api.dicebear.com/9.x/$avatarStyle/svg?seed=$avatarSeed', fit: BoxFit.cover)
                        : Text(
                            (displayName.isNotEmpty ? displayName.substring(0,1) : widget.targetUserId.substring(0,1)).toUpperCase(),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: () => context.push('/arena/${widget.targetUserId}'),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (displayName.isNotEmpty)
                        Text(displayName, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600))
                      else
                        Text(widget.targetUserId, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white70)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () async {
                  HapticFeedback.selectionClick();
                  final svc = ref.read(firestoreServiceProvider);
                  final current = isFollowing;
                  setState(() => _optimistic = !current);
                  try {
                    if (current) {
                      await svc.unfollowUser(currentUserId: me!.uid, targetUserId: widget.targetUserId);
                    } else {
                      await svc.followUser(currentUserId: me!.uid, targetUserId: widget.targetUserId);
                    }
                  } finally {
                    if (mounted) setState(() => _optimistic = null); // stream kontrolü geri al
                  }
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: isFollowing ? Colors.redAccent : AppTheme.secondaryColor,
                  side: BorderSide(color: isFollowing ? Colors.redAccent : AppTheme.secondaryColor),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  minimumSize: const Size(0, 36),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                icon: Icon(isFollowing ? Icons.person_remove_alt_1 : Icons.person_add_alt_1, size: 18),
                label: Text(isFollowing ? 'Takipten Çıkar' : 'Takip Et'),
              ),
            ],
          ),
        );
      },
      loading: () => Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.white.withOpacity(0.04),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        padding: const EdgeInsets.all(12),
        child: Row(
          children: const [
            CircleAvatar(child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))),
            SizedBox(width: 12),
            Expanded(child: LinearProgressIndicator(minHeight: 10)),
          ],
        ),
      ),
      error: (e, s) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.red.withOpacity(0.06),
          border: Border.all(color: Colors.red.withOpacity(0.2)),
        ),
        child: Text('Kullanıcı yüklenemedi: $e', style: const TextStyle(color: Colors.redAccent)),
      ),
    );
  }
}
