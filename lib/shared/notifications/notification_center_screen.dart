import 'package:bilge_ai/core/theme/app_theme.dart';
import 'package:bilge_ai/data/providers/firestore_providers.dart';
import 'package:bilge_ai/shared/notifications/in_app_notification_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:bilge_ai/features/auth/application/auth_controller.dart';

class NotificationCenterScreen extends ConsumerWidget {
  const NotificationCenterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(inAppNotificationsProvider);
    final user = ref.watch(authControllerProvider).value;

    return WillPopScope(
      onWillPop: () async {
        if (Navigator.of(context).canPop()) return true;
        context.go('/home');
        return false;
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
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) => _NotificationTile(item: items[index]),
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.secondaryColor)),
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
    final Color bg = unread
        ? AppTheme.secondaryColor.withValues(alpha: 0.08)
        : Theme.of(context).colorScheme.surfaceContainerLowest.withValues(alpha: 0.5);
    final Color border = unread
        ? AppTheme.secondaryColor.withValues(alpha: 0.35)
        : Theme.of(context).dividerColor.withValues(alpha: 0.25);

    final leading = item.imageUrl != null && item.imageUrl!.isNotEmpty
        ? ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.network(item.imageUrl!, width: 56, height: 56, fit: BoxFit.cover),
          )
        : Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppTheme.cardColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.notifications_rounded, color: AppTheme.secondaryColor),
          );

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () async {
        // Okundu işaretle
        if (user != null && !item.read) {
          await ref.read(firestoreServiceProvider).markInAppNotificationRead(user.uid, item.id);
        }
        // Detay alt sayfasını aç
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
                            color: AppTheme.secondaryColor,
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
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  if (createdAtText != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.schedule_rounded, size: 14, color: Colors.grey),
                        const SizedBox(width: 6),
                        Text(
                          createdAtText,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.secondaryTextColor),
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
                child: Image.network(item.imageUrl!, fit: BoxFit.cover),
              ),
            ),
          const SizedBox(height: 12),
          Text(item.title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
          if (createdAtText != null) ...[
            const SizedBox(height: 4),
            Text(createdAtText, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.secondaryTextColor)),
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
                    // İlgili sayfayı aç
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
    final two = (int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}.${two(d.month)}.${d.year} ${two(d.hour)}:${two(d.minute)}';
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
            const Icon(Icons.notifications_none_rounded, size: 64, color: AppTheme.secondaryTextColor),
            const SizedBox(height: 12),
            const Text('Henüz bildirimin yok', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text('Yeni duyurular ve hatırlatmalar burada görünecek.', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.secondaryTextColor), textAlign: TextAlign.center),
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
