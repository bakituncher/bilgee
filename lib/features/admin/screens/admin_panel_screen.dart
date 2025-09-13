import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:bilge_ai/core/theme/app_theme.dart';

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
                  color: AppTheme.primaryColor,
                ),
          ),
          const SizedBox(height: 16),
          // Placeholder for User Management
          ListTile(
            leading: const Icon(Icons.people_alt_outlined),
            title: const Text('Kullanıcı Yönetimi'),
            subtitle: const Text('Admin yetkisi ver/al'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/admin/user-management'),
          ),
          const Divider(),
          // Placeholder for Push Composer
          ListTile(
            leading: const Icon(Icons.send_outlined),
            title: const Text('Push Bildirim Gönder'),
            subtitle: const Text('Tüm kullanıcılara bildirim gönder'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/admin/push-composer'),
          ),
          const Divider(),
          // Placeholder for Question Reports
          ListTile(
            leading: const Icon(Icons.flag_outlined),
            title: const Text('Soru Raporları'),
            subtitle: const Text('Kullanıcıların raporladığı sorular'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/admin/question-reports'),
          ),
        ],
      ),
    );
  }
}
