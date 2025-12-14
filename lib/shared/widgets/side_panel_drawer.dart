// lib/shared/widgets/side_panel_drawer.dart
import 'package:taktik/data/providers/firestore_providers.dart';
import 'package:taktik/data/providers/premium_provider.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:taktik/features/profile/logic/rank_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:taktik/core/navigation/app_routes.dart';

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
                      _navTile(context, currentLocation: location, icon: Icons.article_rounded, title: 'Taktik Blog', route: '/blog'),
                      const SizedBox(height: 6),
                      _whatsappChannelTile(context, user: user),
                      const SizedBox(height: 6),
                      _socialMediaTile(context),
                    ],
                  ),
                ),

                // Premium Section - GÜNCELLENMİŞ PAZARLAMA ALANI
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
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

                // Footer actions
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
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
                      const SizedBox(width: 8),
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

          // Premium değilse: Haftalık Strateji paywall ("Rotanı çiz!")
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
              // imageAsset kaldırıldı: JSON Lottie dosyası Image.asset ile yüklenemez
            });
            return;
          }

          // Premium kullanıcılar için mevcut davranış
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
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: colorScheme.surfaceContainerHighest.withOpacity(.2),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 19, color: iconColor ?? colorScheme.onSurfaceVariant),
            const SizedBox(width: 8),
            Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
                fontSize: 13,
                color: iconColor ?? colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _whatsappChannelTile(BuildContext context, {required dynamic user}) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 2),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showWhatsappDialog(context, user),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              colors: [
                const Color(0xFF25D366).withOpacity(0.12),
                const Color(0xFF128C7E).withOpacity(0.08),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(
              color: const Color(0xFF25D366).withOpacity(0.3),
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: const Color(0xFF25D366).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const FaIcon(
                  FontAwesomeIcons.whatsapp,
                  size: 17,
                  color: Color(0xFF25D366),
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'WhatsApp Kanalımız',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        fontSize: 13.5,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Güncel duyurular için katıl 💬',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant.withOpacity(0.8),
                        fontSize: 10.5,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.open_in_new_rounded,
                size: 16,
                color: const Color(0xFF25D366),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showWhatsappDialog(BuildContext context, dynamic user) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Determine the WhatsApp channel URL based on exam type
    String channelUrl = 'https://whatsapp.com/channel/0029VbBdCY96BIEo5XqCbK1V'; // Default KPSS
    String examType = 'KPSS';

    if (user?.selectedExam != null) {
      final exam = user!.selectedExam.toString().toLowerCase();
      if (exam.contains('yks') || exam.contains('tyt') || exam.contains('ayt')) {
        channelUrl = 'https://whatsapp.com/channel/0029VbB9FtNDp2Q09xHfAq0E';
        examType = 'YKS';
      } else if (exam.contains('lgs')) {
        channelUrl = 'https://whatsapp.com/channel/0029VbBVIRTKbYMJI3tqsl3u';
        examType = 'LGS';
      } else if (exam.contains('kpss')) {
        channelUrl = 'https://whatsapp.com/channel/0029VbBdCY96BIEo5XqCbK1V';
        examType = 'KPSS';
      }
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: theme.cardColor,
        title: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 30),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF25D366).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const FaIcon(
                      FontAwesomeIcons.whatsapp,
                      color: Color(0xFF25D366),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'WhatsApp Kanalımıza Katıl',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          'Taktik $examType',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              right: -12,
              top: -12,
              child: IconButton(
                icon: Icon(Icons.close, color: colorScheme.onSurfaceVariant),
                onPressed: () => Navigator.of(context).pop(),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: colorScheme.primary.withOpacity(0.2),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    color: colorScheme.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'WhatsApp uygulamasına yönlendirileceksiniz.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurface.withOpacity(0.8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Taktik $examType WhatsApp kanalımızda:',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            _dialogBenefit(
              icon: Icons.notifications_active_rounded,
              text: 'Önemli duyurular',
              colorScheme: colorScheme,
              theme: theme,
            ),
            const SizedBox(height: 8),
            _dialogBenefit(
              icon: Icons.tips_and_updates_rounded,
              text: 'Güncel ipuçları',
              colorScheme: colorScheme,
              theme: theme,
            ),
            const SizedBox(height: 8),
            _dialogBenefit(
              icon: Icons.campaign_rounded,
              text: 'Özel kampanyalar',
              colorScheme: colorScheme,
              theme: theme,
            ),
          ],
        ),
        actions: [
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.of(context).pop();
              final Uri url = Uri.parse(channelUrl);
              if (await canLaunchUrl(url)) {
                await launchUrl(
                  url,
                  mode: LaunchMode.externalApplication,
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF25D366),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.open_in_new_rounded, size: 18),
            label: Text(
              'Katıl',
              style: theme.textTheme.titleSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _socialMediaTile(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 2),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showSocialMediaDialog(context),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              colors: [
                colorScheme.primary.withOpacity(0.12),
                colorScheme.secondary.withOpacity(0.08),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border.all(
              color: colorScheme.primary.withOpacity(0.3),
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(
                  Icons.share_rounded,
                  size: 17,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sosyal Medya',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        fontSize: 13.5,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Bizi takip edin 🎯',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant.withOpacity(0.8),
                        fontSize: 10.5,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.open_in_new_rounded,
                size: 16,
                color: colorScheme.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSocialMediaDialog(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: theme.cardColor,
        title: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 30),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          colorScheme.primary.withOpacity(0.2),
                          colorScheme.secondary.withOpacity(0.15),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.share_rounded,
                      color: colorScheme.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Bizi Takip Edin',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              right: -12,
              top: -12,
              child: IconButton(
                icon: Icon(Icons.close, color: colorScheme.onSurfaceVariant),
                onPressed: () => Navigator.of(context).pop(),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Güncel içerikler, motivasyon ve ipuçları için sosyal medya hesaplarımızı takip edin! 🚀',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface.withOpacity(0.8),
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            _socialMediaButton(
              context: context,
              icon: FontAwesomeIcons.instagram,
              label: 'Instagram',
              gradient: const LinearGradient(
                colors: [Color(0xFFE1306C), Color(0xFFFD1D1D), Color(0xFFF77737)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              url: 'https://www.instagram.com/taktik_tr?igsh=NTdvaTh1amN0MHB4',
              theme: theme,
              colorScheme: colorScheme,
            ),
            const SizedBox(height: 12),
            _socialMediaButton(
              context: context,
              icon: FontAwesomeIcons.tiktok,
              label: 'TikTok',
              gradient: const LinearGradient(
                colors: [Color(0xFF000000), Color(0xFF00F2EA), Color(0xFFFF0050)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              url: 'https://www.tiktok.com/@tr_taktik?_r=1&_t=ZS-91pXgBzmmkq',
              theme: theme,
              colorScheme: colorScheme,
            ),
          ],
        ),
        actions: const [],
      ),
    );
  }

  Widget _socialMediaButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required Gradient gradient,
    required String url,
    required ThemeData theme,
    required ColorScheme colorScheme,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () async {
        Navigator.of(context).pop();
        final Uri uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(
            uri,
            mode: LaunchMode.externalApplication,
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FaIcon(icon, color: Colors.white, size: 22),
            const SizedBox(width: 12),
            Text(
              label,
              style: theme.textTheme.titleMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
            const Spacer(),
            const Icon(
              Icons.open_in_new_rounded,
              color: Colors.white,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  Widget _dialogBenefit({
    required IconData icon,
    required String text,
    required ColorScheme colorScheme,
    required ThemeData theme,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: 18,
          color: colorScheme.primary.withOpacity(0.8),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurface.withOpacity(0.75),
            ),
          ),
        ),
        Icon(
          Icons.check_circle,
          size: 16,
          color: const Color(0xFF25D366),
        ),
      ],
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

// -----------------------------------------------------------------------------
// PREMIUM PAZARLAMA WIDGETLARI
// -----------------------------------------------------------------------------

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
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFF2E3192),
              const Color(0xFF1BFFFF).withOpacity(0.9),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF2E3192).withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
              spreadRadius: -2,
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              right: -15,
              top: -15,
              child: Icon(
                Icons.workspace_premium_rounded,
                size: 80,
                color: Colors.white.withOpacity(0.05),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(9),
                          border: Border.all(color: Colors.white.withOpacity(0.3)),
                        ),
                        child: const Icon(Icons.diamond_rounded, color: Colors.white, size: 18),
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Taktik PRO',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 15,
                                letterSpacing: -0.3,
                              ),
                            ),
                            Text(
                              'Rakiplerine fark at',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.white.withOpacity(0.9),
                                fontWeight: FontWeight.w500,
                                fontSize: 10.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ..._buildBenefitsList(),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(11),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Zirveye Oyna 🚀',
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: const Color(0xFF2E3192),
                            fontWeight: FontWeight.w900,
                            fontSize: 13.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildBenefitsList() {
    final benefits = [
      {'icon': Icons.block_rounded, 'text': 'Reklamsız Deneyim'},
      {'icon': Icons.psychology_rounded, 'text': 'Taktik Tavşan Desteği'},
      {'icon': Icons.radar_rounded, 'text': 'Eksik Analizi'},
      {'icon': Icons.all_inclusive_rounded, 'text': 'Sınırsız Arşiv'},
      {'icon': Icons.trending_up_rounded, 'text': 'Detaylı Raporlar'},
    ];

    return benefits.map((benefit) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 5),
        child: Row(
          children: [
            Icon(
              benefit['icon'] as IconData,
              color: Colors.white.withOpacity(0.85),
              size: 13,
            ),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                benefit['text'] as String,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                  letterSpacing: -0.1,
                  height: 1.2,
                ),
              ),
            ),
            Icon(
              Icons.check_circle,
              color: Colors.greenAccent.shade100,
              size: 13,
            ),
          ],
        ),
      );
    }).toList();
  }
}

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
            const Color(0xFFFFD700).withOpacity(0.15),
            colorScheme.primary.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFFFD700).withOpacity(0.4),
          width: 1.5,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -10,
            top: -10,
            child: Icon(
              Icons.verified_rounded,
              size: 60,
              color: Colors.amber.withOpacity(0.08),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Taktik PRO',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: colorScheme.onSurface,
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.verified, color: Colors.amber, size: 15),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.green.withOpacity(0.3)),
                      ),
                      child: Text(
                        'AKTİF',
                        style: TextStyle(
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.w800,
                          fontSize: 9,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 9),
                _buildActiveFeature(Icons.block_rounded, "Reklamsız"),
                const SizedBox(height: 5),
                _buildActiveFeature(Icons.psychology_rounded, "Taktik Tavşan"),
                const SizedBox(height: 5),
                _buildActiveFeature(Icons.all_inclusive_rounded, "Sınırsız Arşiv"),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveFeature(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 13, color: colorScheme.primary),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface.withOpacity(0.8),
              fontSize: 11,
            ),
          ),
        ),
        Icon(Icons.check_circle, size: 12, color: Colors.green.withOpacity(0.7)),
      ],
    );
  }
}
