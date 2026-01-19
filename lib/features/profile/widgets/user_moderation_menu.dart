// lib/features/profile/widgets/user_moderation_menu.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:taktik/data/providers/moderation_providers.dart';
import 'package:taktik/features/profile/widgets/user_report_dialog.dart';

/// Kullanıcı moderasyon menüsü (engelleme/raporlama)
class UserModerationMenu extends ConsumerStatefulWidget {
  final String targetUserId;
  final String targetUserName;
  final VoidCallback? onBlocked;
  final VoidCallback? onReported;

  const UserModerationMenu({
    super.key,
    required this.targetUserId,
    required this.targetUserName,
    this.onBlocked,
    this.onReported,
  });

  @override
  ConsumerState<UserModerationMenu> createState() => _UserModerationMenuState();
}

class _UserModerationMenuState extends ConsumerState<UserModerationMenu> {
  bool _isProcessing = false;

  Future<void> _blockUser() async {
    if (_isProcessing) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Kullanıcıyı Engelle'),
        content: Text(
          '${widget.targetUserName} kullanıcısını engellemek istediğinizden emin misiniz?',
        ),
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

    setState(() => _isProcessing = true);

    try {
      final service = ref.read(moderationServiceProvider);
      await service.blockUser(widget.targetUserId);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kullanıcı başarıyla engellendi')),
      );

      // Provider'ları yenile
      ref.invalidate(blockedUsersProvider);
      ref.invalidate(isUserBlockedProvider(widget.targetUserId));
      ref.invalidate(blockStatusProvider(widget.targetUserId));

      widget.onBlocked?.call();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hata: ${e.toString()}')),
      );
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _reportUser() async {
    if (_isProcessing) return;

    final reported = await showUserReportDialog(
      context,
      targetUserId: widget.targetUserId,
      targetUserName: widget.targetUserName,
    );

    if (reported == true) {
      widget.onReported?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final blockStatusAsync = ref.watch(blockStatusProvider(widget.targetUserId));
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return PopupMenuButton<String>(
      icon: Icon(Icons.more_vert, color: colorScheme.onSurface),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (value) {
        switch (value) {
          case 'block':
            _blockUser();
            break;
          case 'report':
            _reportUser();
            break;
        }
      },
      itemBuilder: (context) {
        return blockStatusAsync.when(
          data: (blockStatus) {
            if (blockStatus.isBlockingMe) {
              // Karşı taraf beni engellemiş
              return [
                PopupMenuItem<String>(
                  value: 'report',
                  child: Row(
                    children: [
                      Icon(Icons.flag_outlined, color: colorScheme.error),
                      const SizedBox(width: 12),
                      const Text('Kullanıcıyı Raporla'),
                    ],
                  ),
                ),
              ];
            } else if (blockStatus.isBlockedByMe) {
              // Ben engellemişim
              return [
                PopupMenuItem<String>(
                  enabled: false,
                  child: Row(
                    children: [
                      Icon(Icons.block, color: colorScheme.onSurface.withOpacity(0.5)),
                      const SizedBox(width: 12),
                      Text(
                        'Engellenmiş',
                        style: TextStyle(color: colorScheme.onSurface.withOpacity(0.5)),
                      ),
                    ],
                  ),
                ),
                PopupMenuItem<String>(
                  value: 'report',
                  child: Row(
                    children: [
                      Icon(Icons.flag_outlined, color: colorScheme.error),
                      const SizedBox(width: 12),
                      const Text('Kullanıcıyı Raporla'),
                    ],
                  ),
                ),
              ];
            } else {
              // Normal durum
              return [
                PopupMenuItem<String>(
                  value: 'block',
                  child: Row(
                    children: [
                      Icon(Icons.block, color: colorScheme.error),
                      const SizedBox(width: 12),
                      const Text('Kullanıcıyı Engelle'),
                    ],
                  ),
                ),
                PopupMenuItem<String>(
                  value: 'report',
                  child: Row(
                    children: [
                      Icon(Icons.flag_outlined, color: colorScheme.error),
                      const SizedBox(width: 12),
                      const Text('Kullanıcıyı Raporla'),
                    ],
                  ),
                ),
              ];
            }
          },
          loading: () => [
            PopupMenuItem<String>(
              enabled: false,
              child: Row(
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text('Yükleniyor...'),
                ],
              ),
            ),
          ],
          error: (_, __) => [
            PopupMenuItem<String>(
              value: 'block',
              child: Row(
                children: [
                  Icon(Icons.block, color: colorScheme.error),
                  const SizedBox(width: 12),
                  const Text('Kullanıcıyı Engelle'),
                ],
              ),
            ),
            PopupMenuItem<String>(
              value: 'report',
              child: Row(
                children: [
                  Icon(Icons.flag_outlined, color: colorScheme.error),
                  const SizedBox(width: 12),
                  const Text('Kullanıcıyı Raporla'),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

