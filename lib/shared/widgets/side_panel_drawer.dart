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
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';

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
            await _showReviewPrompt(context);
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
                  'Bizi Değerlendir',
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

  Future<void> _showReviewPrompt(BuildContext context) async {
    if (!mounted) return;

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // İlk adım: Uygulamayı beğenip beğenmediğini sor
    final liked = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                colorScheme.surface,
                colorScheme.surfaceContainerHighest.withOpacity(0.95),
              ],
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Drag handle
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colorScheme.onSurfaceVariant.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Animated emoji icon
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          colorScheme.primary.withOpacity(0.15),
                          colorScheme.secondary.withOpacity(0.15),
                        ],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Text(
                        '💙',
                        style: TextStyle(fontSize: 40),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Title
                  Text(
                    'Taktik\'i beğendin mi?',
                    style: GoogleFonts.montserrat(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                      color: colorScheme.onSurface,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 12),

                  // Description
                  Text(
                    'Görüşlerin bizim için çok değerli! 🙏',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      height: 1.6,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 32),

                  // Choice buttons with icons
                  Row(
                    children: [
                      // Dislike button
                      Expanded(
                        child: _buildChoiceButton(
                          context: ctx,
                          icon: Icons.sentiment_dissatisfied_rounded,
                          label: 'Beğenmedim',
                          gradient: LinearGradient(
                            colors: [
                              colorScheme.errorContainer.withOpacity(0.3),
                              colorScheme.error.withOpacity(0.2),
                            ],
                          ),
                          iconColor: colorScheme.error,
                          onTap: () => Navigator.of(ctx).pop(false),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Like button
                      Expanded(
                        child: _buildChoiceButton(
                          context: ctx,
                          icon: Icons.favorite_rounded,
                          label: 'Beğendim',
                          gradient: LinearGradient(
                            colors: [
                              colorScheme.primary,
                              colorScheme.secondary,
                            ],
                          ),
                          iconColor: Colors.white,
                          textColor: Colors.white,
                          onTap: () => Navigator.of(ctx).pop(true),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Maybe later button
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                    ),
                    child: Text(
                      'Şimdi Değil',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurfaceVariant.withOpacity(0.7),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.1, curve: Curves.easeOut);
      },
    );

    if (liked == null || !mounted) return;

    // Geçiş için kısa bir bekleme
    await Future.delayed(const Duration(milliseconds: 300));

    if (liked) {
      // Kullanıcı beğendiyse - değerlendirme isteği göster
      await _showRatingDialog(context);
    }
    // Beğenmeyenler için hiçbir şey gösterme, sadece kapat
  }

  Widget _buildChoiceButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required Gradient gradient,
    required Color iconColor,
    Color? textColor,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      height: 120,
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: iconColor.withOpacity(0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 40,
                color: iconColor,
              ),
              const SizedBox(height: 12),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: textColor ?? colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showRatingDialog(BuildContext context) async {
    if (!mounted) return;

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                colorScheme.surface,
                colorScheme.surfaceContainerHighest.withOpacity(0.95),
              ],
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Drag handle
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colorScheme.onSurfaceVariant.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Success icon
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          colorScheme.primary.withOpacity(0.2),
                          colorScheme.secondary.withOpacity(0.2),
                        ],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.stars_rounded,
                      size: 40,
                      color: colorScheme.primary,
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Title
                  Text(
                    'Desteğin çok değerli! 🙏',
                    style: GoogleFonts.montserrat(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                      color: colorScheme.onSurface,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 12),

                  // Description
                  Text(
                    'Görüşünü paylaşarak bize destek olabilirsin! 💙',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      height: 1.6,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 28),

                  // Rate button
                  Container(
                    width: double.infinity,
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          colorScheme.primary,
                          colorScheme.secondary,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: colorScheme.primary.withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () async {
                          Navigator.of(ctx).pop();
                          final InAppReview inAppReview = InAppReview.instance;

                          if (await inAppReview.isAvailable()) {
                            await inAppReview.requestReview();
                          } else {
                            await inAppReview.openStoreListing(
                              appStoreId: '6755930518',
                            );
                          }
                        },
                        borderRadius: BorderRadius.circular(28),
                        child: Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.star_rounded,
                                color: Colors.white,
                                size: 24,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Mağazada Değerlendir',
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Maybe later
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                    ),
                    child: Text(
                      'Belki Sonra',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurfaceVariant.withOpacity(0.7),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ).animate().fadeIn(duration: 300.ms).scale(begin: const Offset(0.95, 0.95), curve: Curves.easeOut);
      },
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