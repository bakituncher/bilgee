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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bildirimler'),
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
            return const Center(child: Text('Henüz bildirimin yok.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) => _NotificationTile(item: items[index]),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.secondaryColor)),
        error: (e, s) => Center(child: Text('Hata: $e')),
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
    final subtitle = Text(item.body, maxLines: 2, overflow: TextOverflow.ellipsis);
    final leading = item.imageUrl != null && item.imageUrl!.isNotEmpty
        ? ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(item.imageUrl!, width: 56, height: 56, fit: BoxFit.cover),
          )
        : CircleAvatar(
            backgroundColor: AppTheme.cardColor,
            child: const Icon(Icons.notifications_rounded, color: AppTheme.secondaryColor),
          );

    return ListTile(
      onTap: () async {
        if (user != null && !item.read) {
          await ref.read(firestoreServiceProvider).markInAppNotificationRead(user.uid, item.id);
        }
        if (context.mounted) context.go(item.route);
      },
      leading: leading,
      title: Row(
        children: [
          Expanded(child: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis)),
          if (!item.read)
            Padding(
              padding: const EdgeInsets.only(left: 8.0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.secondaryColor.withValues(alpha: .15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.secondaryColor.withValues(alpha: .4)),
                ),
                child: const Text('Yeni', style: TextStyle(color: AppTheme.secondaryColor, fontSize: 11, fontWeight: FontWeight.w600)),
              ),
            ),
        ],
      ),
      subtitle: subtitle,
      trailing: const Icon(Icons.chevron_right_rounded),
    );
  }
}
