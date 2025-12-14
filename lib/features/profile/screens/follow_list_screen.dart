// lib/features/profile/screens/follow_list_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // DocumentSnapshot için gerekli
import 'package:taktik/data/providers/firestore_providers.dart';
import 'package:taktik/features/auth/application/auth_controller.dart';
import 'package:taktik/features/profile/widgets/user_moderation_menu.dart';

class FollowListScreen extends ConsumerStatefulWidget {
  final String mode; // 'followers' | 'following'
  const FollowListScreen({super.key, required this.mode});

  @override
  ConsumerState<FollowListScreen> createState() => _FollowListScreenState();
}

class _FollowListScreenState extends ConsumerState<FollowListScreen> {
  final ScrollController _scrollController = ScrollController();

  List<String> _userIds = [];
  DocumentSnapshot? _lastDoc;
  bool _isLoading = false;
  bool _hasMore = true;
  bool _isInitialLoad = true;

  bool get _isFollowers => widget.mode == 'followers';

  @override
  void initState() {
    super.initState();
    _loadUsers();

    // Listenin sonuna gelince tetiklenen dinleyici
    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200 &&
          !_isLoading &&
          _hasMore) {
        _loadUsers();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    if (_isLoading || !_hasMore) return;

    setState(() => _isLoading = true);

    try {
      final me = ref.read(authControllerProvider).value;
      if (me == null) return;

      final service = ref.read(firestoreServiceProvider);

      // Hangi fonksiyonu çağıracağımızı seçiyoruz
      final result = _isFollowers
          ? await service.getFollowersPaginated(me.uid, startAfter: _lastDoc)
          : await service.getFollowingPaginated(me.uid, startAfter: _lastDoc);

      // Kendini listeden çıkar (ID'leri eklemeden önce filtrele)
      final newIds = result.$1.where((id) => id != me.uid).toList();
      final lastDoc = result.$2;

      if (mounted) {
        setState(() {
          _userIds.addAll(newIds);
          _lastDoc = lastDoc;
          // Eğer gelen veri limiti doldurmuyorsa, daha fazla veri yok demektir
          if (newIds.length < 20) {
            _hasMore = false;
          }
          _isLoading = false;
          _isInitialLoad = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isInitialLoad = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Yükleme hatası: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(authControllerProvider).value;
    if (me == null) return const Scaffold(body: Center(child: Text('Oturum bulunamadı.')));

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
          child: RefreshIndicator(
            onRefresh: () async {
              setState(() {
                _userIds.clear();
                _lastDoc = null;
                _hasMore = true;
                _isInitialLoad = true;
              });
              await _loadUsers();
            },
            child: _isInitialLoad
              ? Center(child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary))
              : _userIds.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(height: MediaQuery.of(context).size.height * 0.3),
                        Center(
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
                        ),
                      ],
                    )
                  : ListView.separated(
                      controller: _scrollController,
                      physics: const AlwaysScrollableScrollPhysics(), // Liste boşken de yenileme çalışsın
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      itemCount: _userIds.length + (_hasMore ? 1 : 0), // Loader için +1
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        // Yükleme göstergesi (Listenin en altı)
                        if (index == _userIds.length) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(16.0),
                              child: CircularProgressIndicator.adaptive(),
                            ),
                          );
                        }

                        final uid = _userIds[index];
                        return _FollowListTile(targetUserId: uid);
                      },
                    ),
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
        // Username verisini doğrudan kaynaktan alıyoruz
        final usernameRaw = (data?['username'] as String?) ?? '';
        final avatarStyle = data?['avatarStyle'] as String?;
        final avatarSeed = data?['avatarSeed'] as String?;
        final isFollowing = _optimistic ?? (isFollowingAsync.valueOrNull ?? false);

        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.03),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.08),
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => context.push('/arena/${widget.targetUserId}'),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.06),
                      child: ClipOval(
                        child: (avatarStyle != null && avatarSeed != null)
                            ? SvgPicture.network(
                                'https://api.dicebear.com/9.x/$avatarStyle/svg?seed=$avatarSeed',
                                fit: BoxFit.cover,
                                width: 48,
                                height: 48,
                                placeholderBuilder: (_) => const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              )
                            : Text(
                                displayName.startsWith('@') && displayName.length > 1
                                    ? displayName.substring(1, 2).toUpperCase()
                                    : displayName.substring(0, 1).toUpperCase(),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: Theme.of(context).colorScheme.onSurface,
                                ),
                          ),
                          const SizedBox(height: 4),
                          countsAsync.when(
                            data: (c) => Text(
                              'Takipçi ${c.$1} • Takip ${c.$2}',
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                                  ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            loading: () => Container(
                              height: 14,
                              width: 80,
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(7),
                              ),
                            ),
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
                      if (me != null) {
                        ref.invalidate(followerIdsProvider(me.uid));
                        ref.invalidate(followingIdsProvider(me.uid));
                      }
                    },
                    ),
                    const SizedBox(width: 8),
                    // Takip butonu - sadece ikon
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: isFollowing
                          ? IconButton.outlined(
                              key: const ValueKey('unfollow'),
                              onPressed: () async {
                                HapticFeedback.lightImpact();
                                final svc = ref.read(firestoreServiceProvider);
                                setState(() => _optimistic = false);
                                try {
                                  await svc.unfollowUser(
                                    currentUserId: me!.uid,
                                    targetUserId: widget.targetUserId,
                                  );
                                } catch (e) {
                                  // Hata durumunda geri al
                                  if (mounted) setState(() => _optimistic = true);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Takipten çıkarma hatası: $e'),
                                      backgroundColor: Theme.of(context).colorScheme.error,
                                    ),
                                  );
                                } finally {
                                  if (mounted) setState(() => _optimistic = null);
                                }
                              },
                              style: IconButton.styleFrom(
                                foregroundColor: Theme.of(context).colorScheme.error,
                                side: BorderSide(color: Theme.of(context).colorScheme.error),
                              ),
                              icon: const Icon(Icons.person_remove_alt_1, size: 20),
                              tooltip: 'Takipten Çıkar',
                            )
                          : IconButton.filledTonal(
                              key: const ValueKey('follow'),
                              onPressed: () async {
                                HapticFeedback.lightImpact();
                                final svc = ref.read(firestoreServiceProvider);
                                setState(() => _optimistic = true);
                                try {
                                  await svc.followUser(
                                    currentUserId: me!.uid,
                                    targetUserId: widget.targetUserId,
                                  );
                                  // Başarılı takip için bildirim göster
                                  // 1. Önce varsa ekrandaki eski bildirimleri temizle (Seri basma sorunu çözümü)
                                  ScaffoldMessenger.of(context).clearSnackBars();

                                  // 2. Yeni ve şık bildirimi göster
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      // İçerik: İkon + Metin yan yana
                                      content: Row(
                                        children: [
                                          const Icon(Icons.check_circle_rounded, color: Colors.white),
                                          const SizedBox(width: 12), // İkon ile yazı arası boşluk
                                          Expanded(
                                            child: Text(
                                              '${usernameRaw.isNotEmpty ? "@$usernameRaw" : "Kullanıcı"} takip edildi!',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w600, // Yazıyı biraz kalınlaştır
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                      // Görünüm Ayarları
                                      behavior: SnackBarBehavior.floating, // Alt tarafta havada asılı durur
                                      backgroundColor: const Color(0xFF323232), // Koyu gri modern arka plan
                                      elevation: 4, // Hafif gölge
                                      margin: const EdgeInsets.all(16), // Kenarlardan boşluk bırakır
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12), // Kenarları yumuşat
                                      ),
                                      duration: const Duration(milliseconds: 1500), // 1.5 saniye (daha seri hissettirir)
                                    ),
                                  );
                                } catch (e) {
                                  // Hata durumunda geri al
                                  if (mounted) setState(() => _optimistic = false);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Takip etme hatası: $e'),
                                      backgroundColor: Theme.of(context).colorScheme.error,
                                    ),
                                  );
                                } finally {
                                  if (mounted) setState(() => _optimistic = null);
                                }
                              },
                              style: IconButton.styleFrom(
                                backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.18),
                                foregroundColor: Theme.of(context).colorScheme.primary,
                              ),
                              icon: const Icon(Icons.person_add_alt_1, size: 20),
                              tooltip: 'Takip Et',
                            ),
                    ),
                  ],
                ),
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
