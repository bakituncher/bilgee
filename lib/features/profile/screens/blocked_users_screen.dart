// lib/features/profile/screens/blocked_users_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:taktik/data/providers/moderation_providers.dart';
import 'package:taktik/shared/widgets/logo_loader.dart';
import 'package:intl/intl.dart';

class BlockedUsersScreen extends ConsumerWidget {
  const BlockedUsersScreen({super.key});

  String _avatarUrl(String? style, String? seed) {
    if (style == null || seed == null) {
      return 'https://api.dicebear.com/9.x/avataaars/svg?seed=default';
    }
    return 'https://api.dicebear.com/9.x/$style/svg?seed=$seed&backgroundColor=transparent&margin=0&scale=110&size=256';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final blockedUsersAsync = ref.watch(blockedUsersProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Engellenen Kullanıcılar'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              theme.scaffoldBackgroundColor,
              theme.cardColor,
              theme.scaffoldBackgroundColor,
            ],
          ),
        ),
        child: blockedUsersAsync.when(
          data: (blockedUsers) {
            if (blockedUsers.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.block_outlined,
                      size: 80,
                      color: colorScheme.onSurface.withOpacity(0.3),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Engellenen kullanıcı yok',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 48.0),
                      child: Text(
                        'Bir kullanıcıyı engellediğinizde, burada görünecek',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurface.withOpacity(0.5),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: blockedUsers.length,
              itemBuilder: (context, index) {
                final blockedUser = Map<String, dynamic>.from(blockedUsers[index]);
                return _BlockedUserCard(
                  userId: blockedUser['userId'] as String,
                  name: blockedUser['name'] as String? ?? 'İsimsiz Kullanıcı',
                  username: blockedUser['username'] as String? ?? '',
                  avatarStyle: blockedUser['avatarStyle'] as String?,
                  avatarSeed: blockedUser['avatarSeed'] as String?,
                  blockedAt: blockedUser['blockedAt'],
                  reason: blockedUser['reason'] as String?,
                  avatarUrl: _avatarUrl(
                    blockedUser['avatarStyle'] as String?,
                    blockedUser['avatarSeed'] as String?,
                  ),
                );
              },
            );
          },
          loading: () => const LogoLoader(),
          error: (error, stack) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: colorScheme.error),
                const SizedBox(height: 16),
                Text(
                  'Hata: ${error.toString()}',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: colorScheme.error),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BlockedUserCard extends ConsumerStatefulWidget {
  final String userId;
  final String name;
  final String username;
  final String? avatarStyle;
  final String? avatarSeed;
  final dynamic blockedAt;
  final String? reason;
  final String avatarUrl;

  const _BlockedUserCard({
    required this.userId,
    required this.name,
    required this.username,
    this.avatarStyle,
    this.avatarSeed,
    required this.blockedAt,
    this.reason,
    required this.avatarUrl,
  });

  @override
  ConsumerState<_BlockedUserCard> createState() => _BlockedUserCardState();
}

class _BlockedUserCardState extends ConsumerState<_BlockedUserCard> {
  bool _isUnblocking = false;

  Future<void> _unblockUser() async {
    if (_isUnblocking) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Engeli Kaldır'),
        content: Text('${widget.name} kullanıcısının engelini kaldırmak istediğinizden emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Engeli Kaldır'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isUnblocking = true);

    try {
      final service = ref.read(moderationServiceProvider);
      await service.unblockUser(widget.userId);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Engel başarıyla kaldırıldı')),
      );

      // Provider'ı yenile
      ref.invalidate(blockedUsersProvider);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hata: ${e.toString()}')),
      );
    } finally {
      if (mounted) {
        setState(() => _isUnblocking = false);
      }
    }
  }

  String _formatDate(dynamic timestamp) {
    try {
      if (timestamp == null) return 'Bilinmiyor';

      DateTime date;
      if (timestamp is DateTime) {
        date = timestamp;
      } else if (timestamp.runtimeType.toString().contains('Timestamp')) {
        // Firebase Timestamp
        date = (timestamp as dynamic).toDate();
      } else {
        return 'Bilinmiyor';
      }

      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inDays > 7) {
        return DateFormat('dd MMM yyyy', 'tr_TR').format(date);
      } else if (difference.inDays > 0) {
        return '${difference.inDays} gün önce';
      } else if (difference.inHours > 0) {
        return '${difference.inHours} saat önce';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes} dakika önce';
      } else {
        return 'Az önce';
      }
    } catch (e) {
      return 'Bilinmiyor';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: colorScheme.onSurface.withOpacity(0.2),
                  width: 2,
                ),
              ),
              child: ClipOval(
                child: SvgPicture.network(
                  widget.avatarUrl,
                  fit: BoxFit.cover,
                  placeholderBuilder: (context) => Icon(
                    Icons.person,
                    size: 32,
                    color: colorScheme.onSurface.withOpacity(0.3),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            // Kullanıcı Bilgileri
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.name,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (widget.username.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      '@${widget.username}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurface.withOpacity(0.6),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    'Engellendi: ${_formatDate(widget.blockedAt)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurface.withOpacity(0.5),
                    ),
                  ),
                ],
              ),
            ),
            // Engeli Kaldır Butonu
            IconButton(
              onPressed: _isUnblocking ? null : _unblockUser,
              icon: _isUnblocking
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colorScheme.primary,
                      ),
                    )
                  : Icon(
                      Icons.block,
                      color: colorScheme.error,
                    ),
              tooltip: 'Engeli Kaldır',
            ),
          ],
        ),
      ),
    );
  }
}

