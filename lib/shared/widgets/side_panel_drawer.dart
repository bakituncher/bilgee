// lib/shared/widgets/side_panel_drawer.dart
import 'package:taktik/core/theme/app_theme.dart';
import 'package:taktik/data/providers/firestore_providers.dart';
import 'package:taktik/data/providers/admin_providers.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:taktik/features/profile/logic/rank_service.dart';

class SidePanelDrawer extends ConsumerWidget {
  const SidePanelDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userProfileProvider).value;
    final rankInfo = RankService.getRankInfo(user?.engagementScore ?? 0);

    return Drawer(
      backgroundColor: Colors.transparent,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppTheme.cardColor,
              AppTheme.primaryColor,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header (custom)
              InkWell(
                onTap: () {
                  Navigator.of(context).pop();
                  context.go('/profile');
                },
                child: Container(
                  margin: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    gradient: LinearGradient(
                      colors: [AppTheme.lightSurfaceColor.withOpacity(.25), AppTheme.cardColor.withOpacity(.6)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: Border.all(color: AppTheme.lightSurfaceColor.withOpacity(.35)),
                  ),
                  child: Row(
                    children: [
                      _Avatar(userName: user?.name, style: user?.avatarStyle, seed: user?.avatarSeed),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user?.name ?? 'Gezgin',
                              style: Theme.of(context).textTheme.titleLarge,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(Icons.workspace_premium_rounded, size: 16, color: AppTheme.secondaryColor),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    rankInfo.current.name,
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppTheme.secondaryColor, fontWeight: FontWeight.w700),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: LinearProgressIndicator(
                                value: rankInfo.progress,
                                minHeight: 6,
                                backgroundColor: AppTheme.lightSurfaceColor.withOpacity(.25),
                                valueColor: const AlwaysStoppedAnimation(AppTheme.secondaryColor),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text('BP ${user?.engagementScore ?? 0}', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppTheme.secondaryTextColor)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.chevron_right_rounded, color: AppTheme.secondaryTextColor),
                    ],
                  ),
                ),
              ),
              const Divider(height: 1, color: Colors.white12),
              // Navigation items
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    _navTile(context, icon: Icons.dashboard_rounded, title: 'Ana Panel', route: '/home'),
                    _navTile(context, icon: Icons.bar_chart_rounded, title: 'İstatistik Kalen', route: '/home/stats'),
                    _navTile(context, icon: Icons.insights_rounded, title: 'Genel Bakış', route: '/stats/overview'),
                    _navTile(context, icon: Icons.shield_moon_rounded, title: 'Günlük Fetihler', route: '/home/quests'),
                    _navTile(context, icon: Icons.timer_rounded, title: 'Odaklanma Mabedi', route: '/home/pomodoro'),
                    _navTile(context, icon: Icons.inventory_2_outlined, title: 'Performans Arşivi', route: '/library'),
                    _navTile(context, icon: Icons.article_rounded, title: 'Taktik Yazıları', route: '/blog'),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _PremiumButton(onTap: () { Navigator.of(context).pop(); context.go('/premium'); }),
                          const SizedBox(height: 6),
                          Text('Premium avantajlarını keşfet', textAlign: TextAlign.center, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppTheme.secondaryTextColor)),
                        ],
                      ),
                    ),
                    // Admin-only section
                    Consumer(builder: (context, ref, _) {
                      final isAdminAsync = ref.watch(adminClaimProvider);
                      return isAdminAsync.maybeWhen(
                        data: (isAdmin) {
                          if (!isAdmin) return const SizedBox.shrink();
                          return const SizedBox.shrink();
                        },
                        orElse: () => const SizedBox.shrink(),
                      );
                    }),
                  ],
                ),
              ),
              const Divider(height: 1, color: Colors.white12),
              // Footer actions
              Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.settings_rounded, color: AppTheme.secondaryTextColor),
                    title: const Text('Ayarlar', style: TextStyle(fontWeight: FontWeight.bold)),
                    onTap: () { Navigator.of(context).pop(); context.go('/settings'); },
                  ),
                  ListTile(
                    leading: const Icon(Icons.logout_rounded, color: AppTheme.accentColor),
                    title: const Text('Çıkış Yap', style: TextStyle(fontWeight: FontWeight.bold)),
                    onTap: () async {
                      Navigator.of(context).pop();
                      await fb.FirebaseAuth.instance.signOut();
                      if (context.mounted) context.go('/');
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  ListTile _navTile(BuildContext context, {required IconData icon, required String title, required String route}) {
    return ListTile(
      leading: Icon(icon, color: AppTheme.secondaryTextColor),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      onTap: () { Navigator.of(context).pop(); context.go(route); },
    );
  }
}

class _Avatar extends StatelessWidget {
  final String? userName;
  final String? style;
  final String? seed;
  const _Avatar({required this.userName, required this.style, required this.seed});

  @override
  Widget build(BuildContext context) {
    final url = _buildSvgUrl();
    final radius = 28.0;
    if (url == null) {
      final initials = (userName ?? 'G').trim();
      return CircleAvatar(
        radius: radius,
        backgroundColor: AppTheme.lightSurfaceColor,
        child: Text(initials.isEmpty ? 'G' : initials.characters.first.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold)),
      );
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppTheme.lightSurfaceColor,
      child: ClipOval(
        child: SvgPicture.network(
          url,
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
          placeholderBuilder: (_) => const Icon(Icons.person, color: AppTheme.secondaryTextColor),
        ),
      ),
    );
  }

  String? _buildSvgUrl() {
    if (style == null && seed == null) return null;
    final s = style ?? 'thumbs';
    final sd = Uri.encodeComponent(seed ?? userName ?? 'Taktik');
    return 'https://api.dicebear.com/7.x/$s/svg?seed=$sd';
  }
}

class _PremiumButton extends StatelessWidget {
  final VoidCallback onTap;
  const _PremiumButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [AppTheme.secondaryColor, Colors.amber]),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: Colors.amber.withOpacity(.25), blurRadius: 18, offset: const Offset(0, 8)),
        ],
      ),
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: const Icon(Icons.workspace_premium_rounded, color: AppTheme.primaryColor, size: 26),
        label: const Text('Premium Ol', style: TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.w800)),
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
      ),
    );
  }
}
