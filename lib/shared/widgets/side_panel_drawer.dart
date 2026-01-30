// lib/shared/widgets/side_panel_drawer.dart
import 'package:taktik/data/providers/firestore_providers.dart';
import 'package:taktik/data/providers/premium_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:taktik/features/profile/logic/rank_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:taktik/core/navigation/app_routes.dart';
import 'package:in_app_review/in_app_review.dart';

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
    final planDoc = ref.watch(planProvider).value;
    final rankInfo = RankService.getRankInfo(user?.engagementScore ?? 0);
    final location = GoRouter.of(context).routeInformationProvider.value.location ?? '';
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Genişlik Ayarı: Ekranın %75'i kadar yer kaplasın (Max 320px)
    final screenWidth = MediaQuery.of(context).size.width;
    final drawerWidth = screenWidth * 0.75 > 320.0 ? 320.0 : screenWidth * 0.75;

    return SizedBox(
      width: drawerWidth, // BURASI PANELİN ÇOK AÇILMASINI ENGELLER
      child: Drawer(
        backgroundColor: theme.cardColor,
        child: SafeArea(
          child: SlideTransition(
            position: _slide,
            child: FadeTransition(
              opacity: _fade,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header - Kullanıcı Profili
                  InkWell(
                    onTap: () { Navigator.of(context).pop(); context.go('/profile'); },
                    child: Container(
                      margin: const EdgeInsets.fromLTRB(10, 10, 10, 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        color: colorScheme.surfaceContainerHighest.withOpacity(.12),
                        border: Border.all(color: colorScheme.surfaceContainerHighest.withOpacity(.2)),
                      ),
                      child: Row(
                        children: [
                          _Avatar(userName: user?.name, style: user?.avatarStyle, seed: user?.avatarSeed),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  user?.name ?? 'Gezgin',
                                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700, fontSize: 14),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    Icon(Icons.workspace_premium_rounded, size: 12, color: colorScheme.primary),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        rankInfo.current.name,
                                        style: theme.textTheme.labelSmall?.copyWith(color: colorScheme.primary, fontWeight: FontWeight.w600, fontSize: 11),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Text('${user?.engagementScore ?? 0} TP', style: theme.textTheme.labelSmall?.copyWith(color: colorScheme.onSurfaceVariant.withOpacity(.65), fontSize: 10)),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(3),
                                  child: LinearProgressIndicator(
                                    value: rankInfo.progress,
                                    minHeight: 4,
                                    backgroundColor: colorScheme.surfaceContainerHighest.withOpacity(.25),
                                    valueColor: AlwaysStoppedAnimation(colorScheme.primary),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          Icon(Icons.chevron_right_rounded, size: 18, color: colorScheme.onSurfaceVariant.withOpacity(.5)),
                        ],
                      ),
                    ),
                  ),

                  // Navigation items
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(6, 4, 6, 4),
                      children: [
                        _navTile(context, currentLocation: location, icon: Icons.dashboard_rounded, title: 'Ana Panel', route: '/home'),
                        _navTile(context, currentLocation: location, icon: Icons.timer_rounded, title: 'Odaklan (Pomodoro)', route: '/home/pomodoro'),
                        _navTile(context, currentLocation: location, icon: Icons.bar_chart_rounded, title: 'Deneme Gelişimi', route: '/home/stats'),
                        _navTile(context, currentLocation: location, icon: Icons.insights_rounded, title: 'Genel Bakış', route: '/stats/overview'),
                        _navTileStrategy(context, currentLocation: location, planDoc: planDoc),
                        _navTile(context, currentLocation: location, icon: Icons.inventory_2_outlined, title: 'Deneme Arşivi', route: '/library'),

                        // --- EKLENEN SORU KUTUSU ---
                        _navTile(context, currentLocation: location, icon: Icons.all_inbox_rounded, title: 'Soru Kutusu', route: '/question-box'),

                        _navTile(context, currentLocation: location, icon: Icons.article_rounded, title: 'Taktik Blog', route: '/blog'),
                      ],
                    ),
                  ),

                  // --- MODERN SOSYAL MEDYA ALANI (AYIRICILI) --
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 4, 10, 8),
                    child: _buildCompactSocialRow(context, user),
                  ),

                  // --- BİZİ DEĞERLENDİRİN BÖLÜMÜ ---
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 4, 10, 8),
                    child: _buildRateUsSection(context),
                  ),

                  const Divider(height: 1),

                  // Footer actions (Taktik PRO)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () {
                        Navigator.of(context).pop();
                        if (isPremium) {
                          context.go('/premium-welcome');
                        } else {
                          context.go('/premium');
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: colorScheme.surfaceContainerHighest.withOpacity(.2),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Image.asset(
                              'assets/images/bunnyy.png',
                              width: 24,
                              height: 24,
                              fit: BoxFit.contain,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Taktik',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w900,
                                fontSize: 14,
                                letterSpacing: 0.3,
                                color: Colors.black,
                                fontFamily: 'Poppins',
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.amber.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.amber.withOpacity(0.5), width: 1),
                              ),
                              child: const Text(
                                'PRO',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                  fontFamily: 'Poppins',
                                  color: Colors.amber,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // --- MODERN SOSYAL MEDYA WIDGETI ---
  Widget _buildCompactSocialRow(BuildContext context, dynamic user) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Sade Dikey Ayırıcı
    Widget buildDivider() {
      return Container(
        height: 24,
        width: 1,
        color: colorScheme.onSurface.withOpacity(0.1),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 4),
          child: Text(
            'BİZİ TAKİP EDİN',
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: colorScheme.onSurfaceVariant.withOpacity(0.7),
              letterSpacing: 0.5,
              fontSize: 10,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: colorScheme.surfaceContainerHighest.withOpacity(.2),
          ),
          child: Row(
            children: [
              // WhatsApp
              Expanded(
                child: _socialIconButton(
                  context,
                  icon: FontAwesomeIcons.whatsapp,
                  color: const Color(0xFF25D366),
                  onTap: () async {
                    Navigator.of(context).pop();
                    String channelUrl = 'https://whatsapp.com/channel/0029VbBdCY96BIEo5XqCbK1V';
                    if (user?.selectedExam != null) {
                      final exam = user!.selectedExam.toString().toLowerCase();
                      if (exam.contains('yks') || exam.contains('tyt') || exam.contains('ayt')) {
                        channelUrl = 'https://whatsapp.com/channel/0029VbB9FtNDp2Q09xHfAq0E';
                      } else if (exam.contains('lgs')) {
                        channelUrl = 'https://whatsapp.com/channel/0029VbBVIRTKbYMJI3tqsl3u';
                      }
                    }
                    await _launchURL(channelUrl);
                  },
                ),
              ),

              buildDivider(), // AYIRICI

              // Instagram
              Expanded(
                child: _socialIconButton(
                  context,
                  icon: FontAwesomeIcons.instagram,
                  color: const Color(0xFFE1306C),
                  onTap: () {
                    Navigator.of(context).pop();
                    _launchURL('https://www.instagram.com/taktik_tr?igsh=NTdvaTh1amN0MHB4');
                  },
                ),
              ),

              buildDivider(), // AYIRICI

              // TikTok
              Expanded(
                child: _socialIconButton(
                  context,
                  icon: FontAwesomeIcons.tiktok,
                  color: theme.brightness == Brightness.dark ? Colors.white : Colors.black,
                  onTap: () {
                    Navigator.of(context).pop();
                    _launchURL('https://www.tiktok.com/@tr_taktik?_r=1&_t=ZS-91pXgBzmmkq');
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // --- BİZİ DEĞERLENDİRİN BÖLÜMÜ ---
  Widget _buildRateUsSection(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 4),
          child: Text(
            'UYGULAMAYI SEVDİN Mİ?',
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: colorScheme.onSurfaceVariant.withOpacity(0.7),
              letterSpacing: 0.5,
              fontSize: 10,
            ),
          ),
        ),
        InkWell(
          onTap: () async {
            Navigator.of(context).pop();
            try {
              final InAppReview inAppReview = InAppReview.instance;

              if (await inAppReview.isAvailable()) {
                await inAppReview.requestReview();
              } else {
                await inAppReview.openStoreListing(
                  appStoreId: '6755930518',
                );
              }
            } catch (_) {
              // Hata durumunda sessiz kal
            }
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: colorScheme.surfaceContainerHighest.withOpacity(.2),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.favorite_rounded,
                  color: Colors.red,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Değerlendir',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.arrow_forward_rounded,
                  color: colorScheme.onSurfaceVariant,
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _socialIconButton(
      BuildContext context, {
        required IconData icon,
        required Color color,
        required VoidCallback onTap,
      }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 48,
        alignment: Alignment.center,
        child: FaIcon(
          icon,
          color: color,
          size: 24,
        ),
      ),
    );
  }

  Future<void> _launchURL(String urlString) async {
    try {
      final Uri url = Uri.parse(urlString);
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
    } catch (_) {
      // URL açılamasa bile crash olmasın
    }
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
      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 2),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.of(context).pop();
          if (isPremium && !userIsPremium) {
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
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: selected ? colorScheme.primary.withOpacity(.12) : Colors.transparent,
            border: selected ? Border.all(color: colorScheme.primary.withOpacity(.3), width: 1.5) : null,
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 21,
                color: selected ? colorScheme.primary : colorScheme.onSurfaceVariant.withOpacity(.85),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    fontSize: 13.5,
                    color: selected ? colorScheme.onSurface : colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              if (showPremiumBadge) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [colorScheme.primary.withOpacity(0.2), Colors.amber.withOpacity(0.2)],
                    ),
                    borderRadius: BorderRadius.circular(7),
                    border: Border.all(color: colorScheme.primary.withOpacity(0.35), width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.workspace_premium_rounded, size: 11, color: colorScheme.primary),
                      const SizedBox(width: 3),
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
              if (selected)
                Icon(Icons.chevron_right_rounded, size: 18, color: colorScheme.primary.withOpacity(0.7)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navTileStrategy(
      BuildContext context, {
        required String currentLocation,
        required dynamic planDoc,
      }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final bool selected = currentLocation.contains('weekly-plan') || currentLocation.contains('strategic-planning');
    final bool userIsPremium = ref.watch(premiumStatusProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 2),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.of(context).pop();

          if (!userIsPremium) {
            context.go('/ai-hub/offer', extra: {
              'title': 'Haftalık Stratejist',
              'subtitle': 'Haftalık stratejist ile verimli planını saniyeler içinde oluştur',
              'icon': Icons.map_rounded,
              'color': const Color(0xFF10B981),
              'heroTag': 'offer-weekly-strategist',
              'marketingTitle': 'Rotanı Çiz!',
              'marketingSubtitle': 'Rastgele çalışarak vakit kaybetme. Taktik Tavşan senin için en verimli haftalık planı saniyeler içinde oluştursun.',
              'redirectRoute': '/home/weekly-plan',
            });
            return;
          }

          if (planDoc?.weeklyPlan != null) {
            context.push('/home/weekly-plan');
          } else {
            context.push('${AppRoutes.aiHub}/${AppRoutes.strategicPlanning}');
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: selected ? colorScheme.primary.withOpacity(.12) : Colors.transparent,
            border: selected ? Border.all(color: colorScheme.primary.withOpacity(.3), width: 1.5) : null,
          ),
          child: Row(
            children: [
              Icon(
                Icons.map_rounded,
                size: 21,
                color: selected ? colorScheme.primary : colorScheme.onSurfaceVariant.withOpacity(.85),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Haftalık Strateji',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    fontSize: 13.5,
                    color: selected ? colorScheme.onSurface : colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              if (selected)
                Icon(Icons.chevron_right_rounded, size: 18, color: colorScheme.primary.withOpacity(0.7)),
            ],
          ),
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
    const radius = 22.0;
    if (url == null) {
      final initials = (userName ?? 'G').trim();
      return CircleAvatar(
        radius: radius,
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Text(
          initials.isEmpty ? 'G' : initials.characters.first.toUpperCase(),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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
          placeholderBuilder: (_) => Icon(Icons.person, size: 20, color: Theme.of(context).colorScheme.onSurfaceVariant),
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