// lib/features/profile/screens/user_search_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:taktik/data/providers/firestore_providers.dart';
import 'package:taktik/features/auth/application/auth_controller.dart';

class UserSearchScreen extends ConsumerStatefulWidget {
  const UserSearchScreen({super.key});

  @override
  ConsumerState<UserSearchScreen> createState() => _UserSearchScreenState();
}

class _UserSearchScreenState extends ConsumerState<UserSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    // Ekran açıldığında klavyeyi otomatik açmak için delay ekleyelim
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final searchResults = ref.watch(searchResultsProvider);
    final searchQuery = ref.watch(userSearchQueryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kullanıcı Ara'),
        backgroundColor: Colors.transparent,
        elevation: 0,
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
          child: Column(
            children: [

              // Arama çubuğu
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: TextField(
                  controller: _searchController,
                  focusNode: _searchFocus,
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 16),
                  decoration: InputDecoration(
                    hintText: 'Kullanıcı adı ile ara...',
                    hintStyle: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                    ),
                    prefixIcon: Icon(
                      Icons.alternate_email,
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                    ),
                    suffixIcon: searchQuery.isNotEmpty
                        ? IconButton(
                            icon: Icon(
                              Icons.clear,
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                            ),
                            onPressed: () {
                              _searchController.clear();
                              ref.read(userSearchQueryProvider.notifier).state = '';
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.05),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                        color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
                        width: 2,
                      ),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                  ),
                  onChanged: (query) {
                    ref.read(userSearchQueryProvider.notifier).state = query;
                  },
                ),
              ),

              // Arama sonuçları
              Expanded(
                child: searchQuery.trim().isEmpty
                    ? _buildEmptyState()
                    : searchResults.when(
                        data: (results) => _buildSearchResults(results),
                        loading: () => _buildLoadingState(),
                        error: (error, stack) => _buildErrorState(error),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search,
            size: 64,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'Takip etmek istediğin kullanıcıları ara',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Kullanıcı adı yazarak arama yapabilirsin',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: CircularProgressIndicator(
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }

  Widget _buildErrorState(Object error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Theme.of(context).colorScheme.error.withOpacity(0.7),
          ),
          const SizedBox(height: 16),
          Text(
            'Arama sırasında bir hata oluştu',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.error.withOpacity(0.7),
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Lütfen tekrar deneyin',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults(List<Map<String, dynamic>> results) {
    if (results.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.person_search,
              size: 64,
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'Kullanıcı bulunamadı',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Farklı bir arama terimi deneyin',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                  ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      itemCount: results.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final userData = results[index];
        final userId = userData['userId'] as String;
        return _UserSearchTile(userData: userData, userId: userId);
      },
    );
  }
}

class _UserSearchTile extends ConsumerStatefulWidget {
  final Map<String, dynamic> userData;
  final String userId;

  const _UserSearchTile({
    required this.userData,
    required this.userId,
  });

  @override
  ConsumerState<_UserSearchTile> createState() => _UserSearchTileState();
}

class _UserSearchTileState extends ConsumerState<_UserSearchTile> {
  bool? _optimistic; // null: stream belirleyici, true/false: anlık göster

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(authControllerProvider).value;
    final isFollowingAsync = ref.watch(isFollowingProvider(widget.userId));
    final countsAsync = ref.watch(followCountsProvider(widget.userId));

    // Kendini takip etme kontrolü
    if (me?.uid == widget.userId) {
      return const SizedBox.shrink();
    }

    final username = widget.userData['username'] as String? ?? '';
    final avatarStyle = widget.userData['avatarStyle'] as String?;
    final avatarSeed = widget.userData['avatarSeed'] as String?;
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
          onTap: () => context.push('/arena/${widget.userId}'),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                // Avatar
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
                            username.isNotEmpty
                                ? username.substring(0, 1).toUpperCase()
                                : '?',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 16),

                // Kullanıcı bilgileri - GÜVENLİK: Sadece username (13-17 yaş koruması)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        username.isNotEmpty ? '@$username' : 'İsimsiz Kullanıcı',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                      ),
                      const SizedBox(height: 4),
                      countsAsync.when(
                        data: (counts) => Text(
                          'Takipçi ${counts.$1} • Takip ${counts.$2}',
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
                                targetUserId: widget.userId,
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
                                targetUserId: widget.userId,
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
                                          '${username.isNotEmpty ? "@$username" : "Kullanıcı"} takip edildi!',
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
  }
}
