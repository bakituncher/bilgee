import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:taktik/data/providers/admin_providers.dart';

class AdminPanelScreen extends ConsumerWidget {
  const AdminPanelScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Paneli'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          Text(
            'Yönetim Araçları',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
          ),
          const SizedBox(height: 16),
          // Conditionally show User Management for Super Admins
          Consumer(
            builder: (context, ref, child) {
              final isSuperAdmin = ref.watch(superAdminProvider);
              return isSuperAdmin.when(
                data: (isSuper) {
                  if (!isSuper) return const SizedBox.shrink();
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ListTile(
                        leading: const Icon(Icons.people_alt_outlined),
                        title: const Text('Kullanıcı Yönetimi'),
                        subtitle: const Text('Admin yetkisi ver/al'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => context.push('/admin/user-management'),
                      ),
                      const Divider(),
                    ],
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              );
            },
          ),
          // Placeholder for Push Composer
          ListTile(
            leading: const Icon(Icons.send_outlined),
            title: const Text('Push Bildirim Gönder'),
            subtitle: const Text('Tüm kullanıcılara bildirim gönder'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/admin/push-composer'),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.flag_outlined),
            title: const Text('Soru Raporları'),
            subtitle: const Text('Kullanıcıların raporladığı sorular'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/admin/reports'),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.report_gmailerrorred_rounded),
            title: const Text('Kullanıcı Raporları'),
            subtitle: const Text('Uygunsuz davranışları incele'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/admin/user-reports'),
          ),
        ],
      ),
    );
  }
}
