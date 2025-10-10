// lib/shared/widgets/side_panel_drawer.dart
import 'package:taktik/core/theme/app_theme.dart';
import 'package:taktik/data/providers/firestore_providers.dart';
import 'package:taktik/data/providers/admin_providers.dart';
import 'package:taktik/data/providers/premium_provider.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:taktik/features/profile/logic/rank_service.dart';

class SidePanelDrawer extends ConsumerStatefulWidget {
  const SidePanelDrawer({super.key});

  @override
  ConsumerState<SidePanelDrawer> createState() => _SidePanelDrawerState();
}

class _SidePanelDrawerState extends ConsumerState<SidePanelDrawer> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 280));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    _slide = Tween<Offset>(begin: const Offset(-0.05, 0), end: Offset.zero).animate(_fade);
    WidgetsBinding.instance.addPostFrameCallback((_) => _ctrl.forward());
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userProfileProvider).value;
    final isPremium = ref.watch(premiumStatusProvider);
    final rankInfo = RankService.getRankInfo(user?.engagementScore ?? 0);
    final location = GoRouter.of(context).routeInformationProvider.value.location ?? '';

    return Drawer(
      backgroundColor: AppTheme.cardColor,
      child: SafeArea(
        child: SlideTransition(
          position: _slide,
          child: FadeTransition(
            opacity: _fade,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header (sade)
                InkWell(
                  onTap: () { Navigator.of(context).pop(); context.go('/profile'); },
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      color: AppTheme.lightSurfaceColor.withOpacity(.18),
                      border: Border.all(color: AppTheme.lightSurfaceColor.withOpacity(.28)),
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
                                  const Icon(Icons.workspace_premium_rounded, size: 16, color: AppTheme.secondaryColor),
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
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: _SectionLabel('Genel'),
                ),
                const SizedBox(height: 4),
                // Navigation items
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      _navTile(context, currentLocation: location, icon: Icons.dashboard_rounded, title: 'Ana Panel', route: '/home'),
                      _navTile(context, currentLocation: location, icon: Icons.bar_chart_rounded, title: 'Deneme Gelişimi', route: '/home/stats'),
                      _navTile(context, currentLocation: location, icon: Icons.insights_rounded, title: 'Genel Bakış', route: '/stats/overview'),
                      _navTile(context, currentLocation: location, icon: Icons.shield_moon_rounded, title: 'Günlük Görevler', route: '/home/quests'),
                      // Odaklanma Mabedi kaldırıldı
                      _navTile(context, currentLocation: location, icon: Icons.inventory_2_outlined, title: 'Deneme Arşivi', route: '/library'),
                      _navTile(context, currentLocation: location, icon: Icons.article_rounded, title: 'Taktik Blog', route: '/blog'),
                      const SizedBox(height: 12),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: _SectionLabel('Öne Çıkan'),
                      ),
                      const SizedBox(height: 8),
                      if (!isPremium)
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
                      Consumer(builder: (context, ref, _) {
                        final isAdminAsync = ref.watch(adminClaimProvider);
                        return isAdminAsync.maybeWhen(
                          data: (isAdmin) {
                            if (!isAdmin) return const SizedBox.shrink();
                            return const Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 16),
                                  child: _SectionLabel('Yönetim'),
                                ),
                                SizedBox(height: 8),
                              ],
                            );
                          },
                          orElse: () => const SizedBox.shrink(),
                        );
                      }),
                    ],
                  ),
                ),
                const Divider(height: 1, color: Colors.white12),
                // Footer actions
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Column(
                    children: [
                      _actionTile(
                        context,
                        icon: Icons.settings_rounded,
                        title: 'Ayarlar',
                        onTap: () { Navigator.of(context).pop(); context.go('/settings'); },
                      ),
                      _actionTile(
                        context,
                        icon: Icons.logout_rounded,
                        title: 'Çıkış Yap',
                        iconColor: AppTheme.accentColor,
                        onTap: () async {
                          Navigator.of(context).pop();
                          await fb.FirebaseAuth.instance.signOut();
                          if (context.mounted) context.go('/');
                        },
                      ),
                      const SizedBox(height: 6),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _navTile(
    BuildContext context, {
    required String currentLocation,
    required IconData icon,
    required String title,
    required String route,
  }) {
    final bool selected = currentLocation == route || currentLocation.startsWith(route);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () { Navigator.of(context).pop(); context.go(route); },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: selected ? AppTheme.lightSurfaceColor.withOpacity(.30) : Colors.transparent,
            border: Border.all(
              color: AppTheme.lightSurfaceColor.withOpacity(selected ? .45 : .20),
            ),
          ),
          child: Row(
            children: [
              _IconCapsule(icon: icon, selected: selected),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: selected ? Colors.white : AppTheme.secondaryTextColor,
                  ),
                ),
              ),
              AnimatedOpacity(
                opacity: selected ? 1 : 0,
                duration: const Duration(milliseconds: 180),
                child: const Icon(Icons.chevron_right_rounded, color: Colors.white70),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _actionTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    Color iconColor = AppTheme.secondaryTextColor,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      leading: Icon(icon, color: iconColor),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      onTap: onTap,
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
    const radius = 28.0;
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

class _IconCapsule extends StatelessWidget {
  final IconData icon;
  final bool selected;
  const _IconCapsule({required this.icon, required this.selected});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: selected
            ? AppTheme.secondaryColor.withOpacity(.20)
            : AppTheme.lightSurfaceColor.withOpacity(.25),
        border: Border.all(
          color: selected
              ? AppTheme.secondaryColor.withOpacity(.35)
              : AppTheme.lightSurfaceColor.withOpacity(.25),
        ),
      ),
      child: Icon(
        icon,
        size: 20,
        color: selected ? AppTheme.secondaryColor : AppTheme.secondaryTextColor,
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 6),
      child: Text(
        text.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              letterSpacing: 1.1,
              color: AppTheme.secondaryTextColor.withOpacity(.8),
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}
