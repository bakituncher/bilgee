import 'package:taktik/data/providers/firestore_providers.dart';
import 'package:taktik/shared/notifications/in_app_notification_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:taktik/features/auth/application/auth_controller.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:taktik/shared/widgets/logo_loader.dart';

class NotificationCenterScreen extends ConsumerWidget {
  const NotificationCenterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(inAppNotificationsProvider);
    final user = ref.watch(authControllerProvider).value;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).maybePop();
        } else {
          if (context.mounted) context.go('/home');
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Bildirimler'),
          leading: IconButton(
            tooltip: 'Geri',
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () async {
              final popped = await Navigator.of(context).maybePop();
              if (!popped) {
                if (context.mounted) context.go('/home');
              }
            },
          ),
          actions: [
            IconButton(
              tooltip: 'Tümünü okundu işaretle',
              onPressed: user == null
                  ? null
                  : () async {
                      await ref.read(firestoreServiceProvider).markAllInAppNotificationsRead(user.uid);
                    },
              icon: const Icon(Icons.done_all_rounded),
            ),
            IconButton(
              tooltip: 'Tümünü sil',
              onPressed: user == null
                  ? null
                  : () async {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Tümünü sil'),
                          content: const Text('Tüm bildirimleri silmek istediğine emin misin?'),
                          actions: [
                            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Vazgeç')),
                            FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Sil')),
                          ],
                        ),
                      );
                      if (ok == true) {
                        try {
                          await ref.read(firestoreServiceProvider).clearAllInAppNotifications(user.uid);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tüm bildirimler silindi')));
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Silinemedi: $e')));
                          }
                        }
                      }
                    },
              icon: const Icon(Icons.delete_sweep_rounded),
            ),
          ],
        ),
        body: itemsAsync.when(
          data: (items) {
            if (items.isEmpty) {
              return _EmptyNotifications(onBack: () async {
                final popped = await Navigator.of(context).maybePop();
                if (!popped) {
                  if (context.mounted) context.go('/home');
                }
              });
            }
            return RefreshIndicator(
              onRefresh: () async { await Future<void>.delayed(const Duration(milliseconds: 350)); },
              child: ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                cacheExtent: 600,
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final n = items[index];
                  return Dismissible(
                    key: ValueKey(n.id),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.error.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(Icons.delete_rounded, color: Theme.of(context).colorScheme.error),
                    ),
                    confirmDismiss: (_) async {
                      final u = ref.read(authControllerProvider).value;
                      if (u == null) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Silinemedi: oturum yok')));
                        }
                        return false;
                      }
                      try {
                        await ref.read(firestoreServiceProvider).deleteInAppNotification(u.uid, n.id);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bildirim silindi')));
                        }
                        return true;
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Silinemedi: $e')));
                        }
                        return false;
                      }
                    },
                    child: _NotificationTile(item: n),
                  );
                },
              ),
            );
          },
          loading: () => const LogoLoader(),
          error: (e, s) => Center(child: Text('Hata: $e')),
        ),
      ),
    );
  }
}

class _NotificationTile extends ConsumerWidget {
  const _NotificationTile({required this.item});
  final InAppNotification item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).value;
    final createdAtText = item.createdAt != null ? _formatDate(item.createdAt!.toDate()) : null;

    final bool unread = !item.read;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final Color bg = unread
        ? colorScheme.primary.withOpacity(0.08)
        : theme.colorScheme.surfaceContainerLowest.withOpacity(0.5);
    final Color border = unread
        ? colorScheme.primary.withOpacity(0.35)
        : theme.dividerColor.withOpacity(0.25);

    final leading = item.imageUrl != null && item.imageUrl!.isNotEmpty
        ? ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: CachedNetworkImage(
              imageUrl: item.imageUrl!,
              width: 56,
              height: 56,
              fit: BoxFit.cover,
              fadeInDuration: const Duration(milliseconds: 150),
              placeholder: (ctx, _) => Container(
                width: 56,
                height: 56,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
              ),
              errorWidget: (ctx, _, __) => Container(
                width: 56,
                height: 56,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.broken_image_rounded, color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ),
          )
        : Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.notifications_rounded, color: Theme.of(context).colorScheme.primary),
          );

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () async {
        if (user != null && !item.read) {
          await ref.read(firestoreServiceProvider).markInAppNotificationRead(user.uid, item.id);
        }
        if (context.mounted) {
          await showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            useSafeArea: true,
            showDragHandle: true,
            builder: (c) {
              return _NotificationDetailSheet(item: item);
            },
          );
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border),
        ),
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            leading,
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: unread ? FontWeight.w700 : FontWeight.w600,
                              ),
                        ),
                      ),
                      if (unread)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: colorScheme.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item.body,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium,
                  ),
                  if (createdAtText != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.schedule_rounded, size: 14, color: colorScheme.onSurfaceVariant),
                        const SizedBox(width: 6),
                        Text(
                          createdAtText,
                          style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}.${two(d.month)}.${d.year} • ${two(d.hour)}:${two(d.minute)}';
  }
}

class _NotificationDetailSheet extends ConsumerWidget {
  const _NotificationDetailSheet({required this.item});
  final InAppNotification item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final createdAtText = item.createdAt != null
        ? _formatDate(item.createdAt!.toDate())
        : null;
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
        top: 8,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (item.imageUrl != null && item.imageUrl!.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: CachedNetworkImage(
                  imageUrl: item.imageUrl!,
                  fit: BoxFit.cover,
                  fadeInDuration: const Duration(milliseconds: 150),
                  placeholder: (ctx, _) => const Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))),
                  errorWidget: (ctx, _, __) => Center(child: Icon(Icons.broken_image_rounded, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                ),
              ),
            ),
          const SizedBox(height: 12),
          Text(item.title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
          if (createdAtText != null) ...[
            const SizedBox(height: 4),
            Text(createdAtText, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ],
          const SizedBox(height: 12),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(item.body, style: Theme.of(context).textTheme.bodyMedium),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.close_rounded),
                  label: const Text('Kapat'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.of(context).maybePop();
                    context.go(item.route);
                  },
                  icon: const Icon(Icons.open_in_new_rounded),
                  label: const Text('İlgili sayfayı aç'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}.${two(d.month)}.${two(d.year)} ${two(d.hour)}:${two(d.minute)}';
  }
}

class _EmptyNotifications extends StatelessWidget {
  const _EmptyNotifications({required this.onBack});
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.notifications_none_rounded, size: 64, color: Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(height: 12),
            const Text('Henüz bildirimin yok', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text('Yeni duyurular ve hatırlatmalar burada görünecek.', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back_rounded),
              label: const Text('Geri dön'),
            ),
          ],
        ),
      ),
    );
  }
}
