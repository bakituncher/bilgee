// lib/shared/widgets/side_panel_drawer.dart
import 'package:taktik/data/providers/firestore_providers.dart';
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
                // Header - Büyük ve Şık
                InkWell(
                  onTap: () { Navigator.of(context).pop(); context.go('/profile'); },
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(12, 12, 12, 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      color: colorScheme.surfaceContainerHighest.withOpacity(.15),
                      border: Border.all(color: colorScheme.surfaceContainerHighest.withOpacity(.25)),
                    ),
                    child: Row(
                      children: [
                        _Avatar(userName: user?.name, style: user?.avatarStyle, seed: user?.avatarSeed),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                user?.name ?? 'Gezgin',
                                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 3),
                              Row(
                                children: [
                                  Icon(Icons.workspace_premium_rounded, size: 14, color: colorScheme.primary),
                                  const SizedBox(width: 5),
                                  Expanded(
                                    child: Text(
                                      rankInfo.current.name,
                                      style: theme.textTheme.labelMedium?.copyWith(color: colorScheme.primary, fontWeight: FontWeight.w600),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text('${user?.engagementScore ?? 0} TP', style: theme.textTheme.labelSmall?.copyWith(color: colorScheme.onSurfaceVariant.withOpacity(.7))),
                                ],
                              ),
                              const SizedBox(height: 5),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: rankInfo.progress,
                                  minHeight: 5,
                                  backgroundColor: colorScheme.surfaceContainerHighest.withOpacity(.25),
                                  valueColor: AlwaysStoppedAnimation(colorScheme.primary),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(Icons.chevron_right_rounded, size: 20, color: colorScheme.onSurfaceVariant.withOpacity(.6)),
                      ],
                    ),
                  ),
                ),
                // Navigation items - Tam Ekran Kullanımı
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                    children: [
                      _navTile(context, currentLocation: location, icon: Icons.dashboard_rounded, title: 'Ana Panel', route: '/home'),
                      _navTile(context, currentLocation: location, icon: Icons.timer_rounded, title: 'Odaklan (Pomodoro)', route: '/home/pomodoro'),
                      _navTile(context, currentLocation: location, icon: Icons.bar_chart_rounded, title: 'Deneme Gelişimi', route: '/home/stats'),
                      _navTile(context, currentLocation: location, icon: Icons.insights_rounded, title: 'Genel Bakış', route: '/stats/overview'),
                      _navTile(context, currentLocation: location, icon: Icons.inventory_2_outlined, title: 'Deneme Arşivi', route: '/library'),
                      _navTile(context, currentLocation: location, icon: Icons.article_rounded, title: 'Taktik Blog', route: '/blog'),
                    ],
                  ),
                ),
                // Premium Section - Sektör Seviyesinde Şık Tasarım
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  child: isPremium
                      ? _PremiumActiveCard(colorScheme: colorScheme, theme: theme)
                      : _PremiumOfferCard(
                          onTap: () {
                            Navigator.of(context).pop();
                            context.go('/premium');
                          },
                          colorScheme: colorScheme,
                          theme: theme,
                        ),
                ),
                const Divider(height: 1),
                // Footer actions - Büyük ve Belirgin
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 12, 8, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: _actionTileCompact(
                          context,
                          icon: Icons.settings_rounded,
                          title: 'Ayarlar',
                          onTap: () { Navigator.of(context).pop(); context.go('/settings'); },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _actionTileCompact(
                          context,
                          icon: Icons.logout_rounded,
                          title: 'Çıkış',
                          iconColor: colorScheme.error,
                          onTap: () async {
                            Navigator.of(context).pop();
                            await fb.FirebaseAuth.instance.signOut();
                            if (context.mounted) context.go('/');
                          },
                        ),
                      ),
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
      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
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
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: selected ? colorScheme.primary.withOpacity(.12) : Colors.transparent,
            border: selected ? Border.all(color: colorScheme.primary.withOpacity(.3), width: 1.5) : null,
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 24,
                color: selected ? colorScheme.primary : colorScheme.onSurfaceVariant.withOpacity(.85),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    color: selected ? colorScheme.onSurface : colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              if (showPremiumBadge) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [colorScheme.primary.withOpacity(0.2), Colors.amber.withOpacity(0.2)],
                    ),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: colorScheme.primary.withOpacity(0.35), width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.workspace_premium_rounded, size: 12, color: colorScheme.primary),
                      const SizedBox(width: 4),
                      Text(
                        'PRO',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
              ],
              if (selected)
                Icon(Icons.chevron_right_rounded, size: 20, color: colorScheme.primary.withOpacity(0.7)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _actionTileCompact(
      BuildContext context, {
        required IconData icon,
        required String title,
        Color? iconColor,
        required VoidCallback onTap,
      }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: colorScheme.surfaceContainerHighest.withOpacity(.2),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 22, color: iconColor ?? colorScheme.onSurfaceVariant),
            const SizedBox(width: 10),
            Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: iconColor ?? colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
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
    const radius = 26.0;
    if (url == null) {
      final initials = (userName ?? 'G').trim();
      return CircleAvatar(
        radius: radius,
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Text(
          initials.isEmpty ? 'G' : initials.characters.first.toUpperCase(),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
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
          placeholderBuilder: (_) => Icon(Icons.person, size: 24, color: Theme.of(context).colorScheme.onSurfaceVariant),
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

// Premium Offer Card - Satın Almayı Teşvik Eden Tasarım
class _PremiumOfferCard extends StatelessWidget {
  final VoidCallback onTap;
  final ColorScheme colorScheme;
  final ThemeData theme;

  const _PremiumOfferCard({
    required this.onTap,
    required this.colorScheme,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              colorScheme.primary.withOpacity(0.95),
              Colors.amber.shade600.withOpacity(0.95),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: colorScheme.primary.withOpacity(0.4),
              blurRadius: 20,
              offset: const Offset(0, 8),
              spreadRadius: -2,
            ),
          ],
        ),
        child: Container(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.25),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.workspace_premium_rounded,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Premium\'a Yükselt',
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 19,
                            letterSpacing: -0.5,
                          ),
                        ),
                        Text(
                          'Sınırsız öğrenmenin tadını çıkar',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.white.withOpacity(0.9),
                            fontWeight: FontWeight.w500,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ..._buildBenefitsList(),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.rocket_launch_rounded,
                      color: colorScheme.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Hemen Başla',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildBenefitsList() {
    final benefits = [
      {'icon': Icons.bar_chart_rounded, 'text': 'Sınırsız Detaylı İstatistikler'},
      {'icon': Icons.inventory_2_outlined, 'text': 'Tüm Denemelere Erişim'},
      {'icon': Icons.auto_awesome_rounded, 'text': 'Yapay Zeka Analizi'},
      {'icon': Icons.history_rounded, 'text': 'Sınırsız Deneme Arşivi'},
    ];

    return benefits.map((benefit) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                benefit['icon'] as IconData,
                color: Colors.white,
                size: 16,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                benefit['text'] as String,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  height: 1.2,
                ),
              ),
            ),
            Icon(
              Icons.check_circle_rounded,
              color: Colors.white.withOpacity(0.9),
              size: 18,
            ),
          ],
        ),
      );
    }).toList();
  }
}

// Premium Active Card - Premium Kullanıcılar İçin Özel Tasarım
class _PremiumActiveCard extends StatelessWidget {
  final ColorScheme colorScheme;
  final ThemeData theme;

  const _PremiumActiveCard({
    required this.colorScheme,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colorScheme.primary.withOpacity(0.12),
            Colors.amber.shade100.withOpacity(0.15),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: colorScheme.primary.withOpacity(0.4),
          width: 2,
        ),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      colorScheme.primary.withOpacity(0.2),
                      Colors.amber.withOpacity(0.2),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: colorScheme.primary.withOpacity(0.4),
                    width: 1.5,
                  ),
                ),
                child: Icon(
                  Icons.workspace_premium_rounded,
                  color: colorScheme.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Premium',
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: Colors.green.withOpacity(0.4),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            'AKTİF',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: Colors.green.shade700,
                              fontWeight: FontWeight.w900,
                              fontSize: 10,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      'Tüm özelliklere erişim',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ..._buildActiveBenefitsList(),
        ],
      ),
    );
  }

  List<Widget> _buildActiveBenefitsList() {
    final benefits = [
      {'icon': Icons.check_circle_rounded, 'text': 'Sınırsız İstatistikler', 'color': Colors.green},
      {'icon': Icons.check_circle_rounded, 'text': 'Tüm Deneme Arşivi', 'color': Colors.green},
      {'icon': Icons.check_circle_rounded, 'text': 'Yapay Zeka Analizi', 'color': Colors.green},
      {'icon': Icons.check_circle_rounded, 'text': 'Öncelikli Destek', 'color': Colors.green},
    ];

    return benefits.map((benefit) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          children: [
            Icon(
              benefit['icon'] as IconData,
              color: (benefit['color'] as Color).withOpacity(0.8),
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                benefit['text'] as String,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurface.withOpacity(0.85),
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  height: 1.2,
                ),
              ),
            ),
          ],
        ),
      );
    }).toList();
  }
}


