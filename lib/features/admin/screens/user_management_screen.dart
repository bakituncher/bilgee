import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bilge_ai/data/models/user_model.dart';
import 'package:bilge_ai/data/providers/admin_providers.dart';
import 'package:bilge_ai/core/theme/app_theme.dart';

final allUsersAdminProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final functions = ref.watch(functionsProvider);
  final result = await functions.httpsCallable('admin-getUsers').call();
  return List<Map<String, dynamic>>.from(result.data['users']);
});

class UserManagementScreen extends ConsumerWidget {
  const UserManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allUsersAsync = ref.watch(allUsersAdminProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kullanıcı Yönetimi'),
      ),
      body: allUsersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Kullanıcılar yüklenemedi: $err')),
        data: (users) {
          return ListView.builder(
            itemCount: users.length,
            itemBuilder: (context, index) {
              final user = users[index];
              final isAdmin = user['admin'] as bool;

              return ListTile(
                title: Text(user['displayName'] ?? 'İsimsiz'),
                subtitle: Text(user['email'] ?? 'E-posta yok'),
                trailing: Switch(
                  value: isAdmin,
                  activeColor: AppTheme.successColor,
                  onChanged: (bool value) async {
                    try {
                      final functions = ref.read(functionsProvider);
                      await functions.httpsCallable('admin-setAdminClaim').call({
                        'uid': user['uid'],
                        'makeAdmin': value,
                      });
                      ref.invalidate(allUsersAdminProvider);
                       ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('${user['displayName']} için admin yetkisi güncellendi.')),
                      );
                    } catch (e) {
                       ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Hata: $e')),
                      );
                    }
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
