
import 'package.flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:taktik/features/profile/application/profile_controller.dart';
import 'package:taktik/data/providers/firestore_providers.dart';
import 'package:taktik/shared/widgets/app_loader.dart';

class BlockedUsersScreen extends ConsumerWidget {
  const BlockedUsersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final blockedUsersAsync = ref.watch(blockedUsersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Engellenen Kullanıcılar'),
      ),
      body: blockedUsersAsync.when(
        data: (blockedIds) {
          if (blockedIds.isEmpty) {
            return const Center(
              child: Text('Engellenmiş kullanıcınız bulunmuyor.'),
            );
          }

          return ListView.builder(
            itemCount: blockedIds.length,
            itemBuilder: (context, index) {
              final userId = blockedIds[index];
              // Her bir kullanıcı için profil bilgilerini getiren bir provider
              final userProfileAsync = ref.watch(publicUserProfileProvider(userId));

              return userProfileAsync.when(
                data: (userData) {
                  if (userData == null) {
                    return ListTile(
                      title: Text('Kullanıcı bulunamadı ($userId)'),
                      trailing: ElevatedButton(
                        onPressed: () {
                          ref.read(profileControllerProvider.notifier).unblockUser(userId);
                        },
                        child: const Text('Engeli Kaldır'),
                      ),
                    );
                  }
                  return ListTile(
                    leading: const Icon(Icons.person),
                    title: Text(userData['name'] ?? 'İsimsiz'),
                    subtitle: Text(userData['username'] ?? ''),
                    trailing: ElevatedButton(
                      onPressed: () {
                        ref.read(profileControllerProvider.notifier).unblockUser(userId);
                      },
                      child: const Text('Engeli Kaldır'),
                    ),
                  );
                },
                loading: () => const ListTile(title: AppLoader()),
                error: (e, s) => ListTile(title: Text('Hata: $e')),
              );
            },
          );
        },
        loading: () => const AppLoader(),
        error: (e, s) => Center(child: Text('Engellenen kullanıcılar yüklenemedi: $e')),
      ),
    );
  }
}
