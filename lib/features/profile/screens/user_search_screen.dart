// lib/features/profile/screens/user_search_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:taktik/core/theme/app_theme.dart';
import 'package:taktik/data/providers/firestore_providers.dart';
import 'package:taktik/features/auth/application/auth_controller.dart';

enum SearchType { name, username }

class UserSearchScreen extends ConsumerStatefulWidget {
  const UserSearchScreen({super.key});

  @override
  ConsumerState<UserSearchScreen> createState() => _UserSearchScreenState();
}

class _UserSearchScreenState extends ConsumerState<UserSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  SearchType _searchType = SearchType.name;

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

  bool _looksLikeId(String s) {
    final t = s.trim();
    if (t.isEmpty) return false;
    return RegExp(r'^[A-Za-z0-9_-]{20,}$').hasMatch(t);
  }

  String _safeDisplayName(Map<String, dynamic>? data) {
    final raw = (data?['name'] as String?)?.trim() ?? '';
    if (raw.isEmpty || _looksLikeId(raw)) return 'İsimsiz Savaşçı';
    return raw;
  }

  String _getPlaceholderText() {
    return _searchType == SearchType.name
        ? 'İsim ile ara...'
        : 'Kullanıcı adı ile ara...';
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
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0B0F14), Color(0xFF2A155A), Color(0xFF061F38)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Arama türü seçici
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setState(() => _searchType = SearchType.name);
                            if (_searchController.text.isNotEmpty) {
                              ref.read(userSearchQueryProvider.notifier).state = _searchController.text;
                              ref.read(searchTypeProvider.notifier).state = SearchType.name;
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: _searchType == SearchType.name
                                  ? AppTheme.secondaryColor.withValues(alpha: 0.2)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.person,
                                  size: 18,
                                  color: _searchType == SearchType.name
                                      ? AppTheme.secondaryColor
                                      : Colors.white70,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'İsim',
                                  style: TextStyle(
                                    color: _searchType == SearchType.name
                                        ? AppTheme.secondaryColor
                                        : Colors.white70,
                                    fontWeight: _searchType == SearchType.name
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setState(() => _searchType = SearchType.username);
                            if (_searchController.text.isNotEmpty) {
                              ref.read(userSearchQueryProvider.notifier).state = _searchController.text;
                              ref.read(searchTypeProvider.notifier).state = SearchType.username;
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: _searchType == SearchType.username
                                  ? AppTheme.secondaryColor.withValues(alpha: 0.2)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.alternate_email,
                                  size: 18,
                                  color: _searchType == SearchType.username
                                      ? AppTheme.secondaryColor
                                      : Colors.white70,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Kullanıcı Adı',
                                  style: TextStyle(
                                    color: _searchType == SearchType.username
                                        ? AppTheme.secondaryColor
                                        : Colors.white70,
                                    fontWeight: _searchType == SearchType.username
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Arama çubuğu
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                  child: TextField(
                    controller: _searchController,
                    focusNode: _searchFocus,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                    decoration: InputDecoration(
                      hintText: _getPlaceholderText(),
                      hintStyle: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                      ),
                      prefixIcon: Icon(
                        Icons.search,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                      suffixIcon: searchQuery.isNotEmpty
                          ? IconButton(
                              icon: Icon(
                                Icons.clear,
                                color: Colors.white.withValues(alpha: 0.7),
                              ),
                              onPressed: () {
                                _searchController.clear();
                                ref.read(userSearchQueryProvider.notifier).state = '';
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                    ),
                    onChanged: (query) {
                      ref.read(userSearchQueryProvider.notifier).state = query;
                      ref.read(searchTypeProvider.notifier).state = _searchType;
                    },
                  ),
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
            color: Colors.white.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'Takip etmek istediğin kullanıcıları ara',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.7),
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Kullanıcı adı yazarak arama yapabilirsin',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.5),
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: CircularProgressIndicator(
        color: AppTheme.secondaryColor,
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
            color: Colors.red.withValues(alpha: 0.7),
          ),
          const SizedBox(height: 16),
          Text(
            'Arama sırasında bir hata oluştu',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.red.withValues(alpha: 0.7),
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Lütfen tekrar deneyin',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.5),
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
              color: Colors.white.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'Kullanıcı bulunamadı',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Farklı bir arama terimi deneyin',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.5),
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

  bool _looksLikeId(String s) {
    final t = s.trim();
    if (t.isEmpty) return false;
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
    final isFollowingAsync = ref.watch(isFollowingProvider(widget.userId));
    final countsAsync = ref.watch(followCountsProvider(widget.userId));

    // Kendini takip etme kontrolü
    if (me?.uid == widget.userId) {
      return const SizedBox.shrink();
    }

    final displayName = _safeDisplayName(widget.userData);
    final avatarStyle = widget.userData['avatarStyle'] as String?;
    final avatarSeed = widget.userData['avatarSeed'] as String?;
    final isFollowing = _optimistic ?? (isFollowingAsync.valueOrNull ?? false);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
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
                  backgroundColor: Colors.white.withValues(alpha: 0.06),
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
                            displayName.substring(0, 1).toUpperCase(),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 16),

                // Kullanıcı bilgileri
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
                              color: Colors.white,
                            ),
                      ),
                      const SizedBox(height: 4),
                      countsAsync.when(
                        data: (counts) => Text(
                          'Takipçi ${counts.$1} • Takip ${counts.$2}',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: Colors.white.withValues(alpha: 0.7),
                              ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        loading: () => Container(
                          height: 14,
                          width: 120,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(7),
                          ),
                        ),
                        error: (e, s) => const SizedBox.shrink(),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 12),

                // Takip butonu
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: isFollowing
                      ? OutlinedButton.icon(
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
                                  backgroundColor: Colors.red,
                                ),
                              );
                            } finally {
                              if (mounted) setState(() => _optimistic = null);
                            }
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.redAccent,
                            side: const BorderSide(color: Colors.redAccent),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            minimumSize: const Size(0, 40),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          icon: const Icon(Icons.person_remove_alt_1, size: 18),
                          label: const Text('Takipten Çıkar'),
                        )
                      : FilledButton.tonalIcon(
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
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('$displayName takip edildi!'),
                                  backgroundColor: AppTheme.secondaryColor,
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            } catch (e) {
                              // Hata durumunda geri al
                              if (mounted) setState(() => _optimistic = false);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Takip etme hatası: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            } finally {
                              if (mounted) setState(() => _optimistic = null);
                            }
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: AppTheme.secondaryColor.withValues(alpha: 0.18),
                            foregroundColor: AppTheme.secondaryColor,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                            minimumSize: const Size(0, 40),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          icon: const Icon(Icons.person_add_alt_1, size: 18),
                          label: const Text('Takip Et'),
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
