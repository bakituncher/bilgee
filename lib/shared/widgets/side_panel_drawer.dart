// lib/shared/widgets/side_panel_drawer.dart
import 'package:taktik/data/providers/firestore_providers.dart';
import 'package:taktik/data/providers/admin_providers.dart';
import 'package:taktik/data/providers/premium_provider.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:taktik/features/profile/logic/rank_service.dart';
import 'package:taktik/shared/widgets/premium_badge.dart';

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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Drawer(
      backgroundColor: theme.cardColor,
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
                      color: colorScheme.surfaceContainerHighest.withOpacity(.18),
                      border: Border.all(color: colorScheme.surfaceContainerHighest.withOpacity(.28)),
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
                                style: theme.textTheme.titleLarge,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(Icons.workspace_premium_rounded, size: 16, color: colorScheme.primary),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      rankInfo.current.name,
                                      style: theme.textTheme.titleMedium?.copyWith(color: colorScheme.primary, fontWeight: FontWeight.w700),
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
                                  backgroundColor: colorScheme.surfaceContainerHighest.withOpacity(.25),
                                  valueColor: AlwaysStoppedAnimation(colorScheme.primary),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text('BP ${user?.engagementScore ?? 0}', style: theme.textTheme.labelSmall?.copyWith(color: colorScheme.onSurfaceVariant)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(Icons.chevron_right_rounded, color: colorScheme.onSurfaceVariant),
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
                      _navTile(context, currentLocation: location, icon: Icons.bar_chart_rounded, title: 'Deneme Gelişimi', route: '/home/stats', isPremium: true, showPremiumBadge: !isPremium),
                      _navTile(context, currentLocation: location, icon: Icons.insights_rounded, title: 'Genel Bakış', route: '/stats/overview'),
                      _navTile(context, currentLocation: location, icon: Icons.shield_moon_rounded, title: 'Günlük Görevler', route: '/home/quests'),
                      _navTile(context, currentLocation: location, icon: Icons.inventory_2_outlined, title: 'Deneme Arşivi', route: '/library', isPremium: true, showPremiumBadge: !isPremium),
                      _navTile(context, currentLocation: location, icon: Icons.article_rounded, title: 'Taktik Blog', route: '/blog'),
                      const SizedBox(height: 12),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: _SectionLabel('Öne Çıkan'),
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: isPremium
                            ? const PremiumBadge()
                            : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _PremiumButton(onTap: () { Navigator.of(context).pop(); context.go('/premium'); }),
                            const SizedBox(height: 6),
                            Text(
                              'Premium avantajlarını keşfet',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                            ),
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
                const Divider(height: 1),
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
                        iconColor: Theme.of(context).colorScheme.error,
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
        bool isPremium = false,
        bool showPremiumBadge = false,
      }) {
    final bool selected = currentLocation == route || (route != '/home' && currentLocation.startsWith(route));
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final userIsPremium = ref.watch(premiumStatusProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.of(context).pop();
          if (isPremium && !userIsPremium) {
            // Deneme Arşivi için source=archive parametresi ekle
            if (route == '/library') {
              context.push('/stats-premium-offer?source=archive');
            } else {
              context.go('/stats-premium-offer');
            }
          } else {
            context.go(route);
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: selected ? colorScheme.surfaceContainerHighest.withOpacity(.30) : Colors.transparent,
            border: Border.all(
              color: colorScheme.surfaceContainerHighest.withOpacity(selected ? .45 : .20),
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
                    color: selected ? colorScheme.onSurface : colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              if (showPremiumBadge) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [colorScheme.primary.withOpacity(0.2), Colors.amber.withOpacity(0.2)],
                    ),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: colorScheme.primary.withOpacity(0.3), width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.workspace_premium_rounded, size: 12, color: colorScheme.primary),
                      const SizedBox(width: 2),
                      Text(
                        'PRO',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w800,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
              ],
              AnimatedOpacity(
                opacity: selected ? 1 : 0,
                duration: const Duration(milliseconds: 180),
                child: Icon(Icons.chevron_right_rounded, color: colorScheme.onSurfaceVariant.withOpacity(0.7)),
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
        Color? iconColor,
        required VoidCallback onTap,
      }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      leading: Icon(icon, color: iconColor ?? Theme.of(context).colorScheme.onSurfaceVariant),
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
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Text(initials.isEmpty ? 'G' : initials.characters.first.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold)),
      );
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: ClipOval(
        child: SvgPicture.network(
          url,
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
          placeholderBuilder: (_) => Icon(Icons.person, color: Theme.of(context).colorScheme.onSurfaceVariant),
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [colorScheme.primary, Colors.amber]),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(color: Colors.amber.withOpacity(.25), blurRadius: 18, offset: const Offset(0, 8)),
        ],
      ),
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(Icons.workspace_premium_rounded, color: colorScheme.onPrimary, size: 26),
        label: Text('Premium Ol', style: TextStyle(color: colorScheme.onPrimary, fontWeight: FontWeight.w800)),
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: selected
            ? colorScheme.primary.withOpacity(.20)
            : colorScheme.surfaceContainerHighest.withOpacity(.25),
        border: Border.all(
          color: selected
              ? colorScheme.primary.withOpacity(.35)
              : colorScheme.surfaceContainerHighest.withOpacity(.25),
        ),
      ),
      child: Icon(
        icon,
        size: 20,
        color: selected ? colorScheme.primary : colorScheme.onSurfaceVariant,
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
          color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(.8),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}