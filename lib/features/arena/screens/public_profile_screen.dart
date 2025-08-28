// lib/features/arena/screens/public_profile_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bilge_ai/data/models/user_model.dart';
import 'package:bilge_ai/data/providers/firestore_providers.dart';
import 'package:bilge_ai/core/theme/app_theme.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_svg/flutter_svg.dart'; // YENİ: Avatar için
import 'package:flutter/services.dart'; // haptic
import 'package:bilge_ai/features/profile/logic/rank_service.dart'; // RankService import geri eklendi

// Bu provider, ID'ye göre tek bir kullanıcı profili getirmek için kullanılır.
final publicUserProfileProvider = FutureProvider.family.autoDispose<UserModel?, String>((ref, userId) {
  return ref.watch(firestoreServiceProvider).getUserById(userId);
});

// NovaPulse accent renkleri (arena ile uyumlu)
const _accentProfile1 = Color(0xFF7F5BFF); // elektrik moru
const _accentProfile2 = Color(0xFF6BFF7A); // neon lime
const _profileBgGradient = [Color(0xFF0B0F14), Color(0xFF2A155A), Color(0xFF061F38)];

class PublicProfileScreen extends ConsumerWidget {
  final String userId;
  const PublicProfileScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userProfileAsync = ref.watch(publicUserProfileProvider(userId));

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Savaşçı Künyesi'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Paylaş',
            onPressed: () => HapticFeedback.selectionClick(),
            icon: const Icon(Icons.ios_share_rounded, color: _accentProfile2),
          ),
        ],
      ),
      body: userProfileAsync.when(
        data: (user) {
          if (user == null) {
            return const Center(child: Text('Savaşçı bulunamadı.'));
          }
          final testCount = user.testCount;
          final avgNet = testCount > 0 ? user.totalNetSum / testCount : 0.0;
          final rankInfo = RankService.getRankInfo(user.engagementScore);
          final rankName = rankInfo.current.name;
          final rankIcon = rankInfo.current.icon;
          final rankColor = rankInfo.current.color;
          final currentLevel = RankService.ranks.indexOf(rankInfo.current) + 1; // level hesaplama

          return Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: _profileBgGradient),
            ),
            child: SafeArea(
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                      child: Column(
                        children: [
                          const SizedBox(height: 12),
                          // Avatar + halo
                          _AvatarHalo(user: user, rankColor: rankColor),
                          const SizedBox(height: 14),
                          Text(
                            user.name ?? 'İsimsiz Savaşçı',
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700, letterSpacing: 0.5),
                            textAlign: TextAlign.center,
                          ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0),
                          const SizedBox(height: 8),
                          _RankCapsule(rankName: rankName, icon: rankIcon, color: rankColor)
                              .animate()
                              .fadeIn(duration: 400.ms, delay: 150.ms)
                              .slideY(begin: 0.2, end: 0, curve: Curves.easeOutCubic),
                          const SizedBox(height: 20),
                          _XpBarNeo(
                            currentXp: user.engagementScore,
                            nextLevelXp: rankInfo.next.requiredScore,
                          ).animate().fadeIn(duration: 450.ms, delay: 250.ms),
                          const SizedBox(height: 28),
                          Row(
                            children: [
                              Expanded(
                                child: _StatCard(
                                  label: 'Deneme',
                                  value: testCount.toString(),
                                  icon: Icons.library_books_rounded,
                                  delay: 350.ms,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: _StatCard(
                                  label: 'Ort. Net',
                                  value: avgNet.toStringAsFixed(1),
                                  icon: Icons.track_changes_rounded,
                                  delay: 420.ms,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: _StatCard(
                                  label: 'Günlük Seri',
                                  value: user.streak.toString(),
                                  icon: Icons.local_fire_department_rounded,
                                  delay: 490.ms,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: _StatCard(
                                  label: 'Seviye',
                                  value: currentLevel.toString(), // rankInfo.current.level yerine
                                  icon: Icons.military_tech_rounded,
                                  delay: 560.ms,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 32),
                          _QuickActions(user: user).animate().fadeIn(delay: 600.ms).slideY(begin: 0.15),
                          const SizedBox(height: 48),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.secondaryColor)),
        error: (e, s) => Center(child: Text('Savaşçı Künyesi Yüklenemedi: $e')),
      ),
    );
  }
}

class _AvatarHalo extends StatelessWidget {
  final UserModel user; final Color rankColor;
  const _AvatarHalo({required this.user, required this.rankColor});
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150,
      height: 150,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Pulsing halo
          _HaloCircle(color: _accentProfile1.withValues(alpha: (_accentProfile1.a * 0.25).toDouble()), size: 140, begin: 0.85, end: 1.05, delay: 0.ms),
          _HaloCircle(color: _accentProfile2.withValues(alpha: (_accentProfile2.a * 0.18).toDouble()), size: 110, begin: 0.9, end: 1.08, delay: 400.ms),
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [_accentProfile2, _accentProfile1]),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: _accentProfile2.withValues(alpha: (_accentProfile2.a * 0.4).toDouble()), blurRadius: 20, spreadRadius: 2),
              ],
            ),
            child: CircleAvatar(
              radius: 56,
              backgroundColor: Colors.black,
              child: ClipOval(
                child: user.avatarStyle != null && user.avatarSeed != null
                    ? SvgPicture.network(
                        "https://api.dicebear.com/9.x/${user.avatarStyle}/svg?seed=${user.avatarSeed}",
                        fit: BoxFit.cover,
                      )
                    : Text(
                        user.name?.substring(0, 1).toUpperCase() ?? 'B',
                        style: Theme.of(context).textTheme.displayMedium?.copyWith(color: _accentProfile2, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ).animate().fadeIn(duration: 500.ms).scale(curve: Curves.easeOutBack),
        ],
      ),
    );
  }
}

class _HaloCircle extends StatelessWidget {
  final Color color; final double size; final double begin; final double end; final Duration delay;
  const _HaloCircle({required this.color, required this.size, required this.begin, required this.end, required this.delay});
  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, Colors.transparent]),
      ),
    ).animate(onPlay: (c) => c.repeat(reverse: true))
        .scale(begin: Offset(begin, begin), end: Offset(end, end), duration: 3000.ms, curve: Curves.easeInOut, delay: delay)
        .fadeIn(duration: 1200.ms, delay: delay);
  }
}

class _RankCapsule extends StatelessWidget {
  final String rankName; final IconData icon; final Color color;
  const _RankCapsule({required this.rankName, required this.icon, required this.color});
  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: 400.ms,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: LinearGradient(colors: [color.withValues(alpha: (color.a * 0.2).toDouble()), color.withValues(alpha: (color.a * 0.05).toDouble())]),
        border: Border.all(color: color.withValues(alpha: (color.a * 0.6).toDouble()), width: 1.2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Text(rankName, style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _XpBarNeo extends StatelessWidget {
  final int currentXp; final int nextLevelXp;
  const _XpBarNeo({required this.currentXp, required this.nextLevelXp});
  @override
  Widget build(BuildContext context) {
    final progress = (currentXp / nextLevelXp).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.flash_on_rounded, size: 18, color: _accentProfile2),
            const SizedBox(width: 6),
            Text('Rütbe Puanı', style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold)),
            const Spacer(),
            Text('$currentXp / $nextLevelXp', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.white70)),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: const LinearGradient(colors: [_accentProfile1, _accentProfile2]),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final w = constraints.maxWidth;
              return Stack(
                children: [
                  Container(
                    height: 22,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      color: Colors.black.withValues(alpha: (Colors.black.a * 0.55).toDouble()),
                    ),
                  ),
                  AnimatedContainer(
                    duration: 700.ms,
                    curve: Curves.easeOutCubic,
                    width: (w - 0) * progress,
                    height: 22,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: const LinearGradient(begin: Alignment.centerLeft, end: Alignment.centerRight, colors: [_accentProfile2, _accentProfile1]),
                      boxShadow: [
                        BoxShadow(color: _accentProfile2.withValues(alpha: (_accentProfile2.a * 0.4).toDouble()), blurRadius: 18, spreadRadius: 1),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label; final String value; final IconData icon; final Duration delay;
  const _StatCard({required this.label, required this.value, required this.icon, required this.delay});
  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label istatistiği: $value',
      child: Container(
        height: 110,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0x1FFFFFFF), Color(0x0DFFFFFF)]),
          border: Border.all(color: Colors.white.withValues(alpha: (Colors.white.a * 0.12).toDouble()), width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 22, color: _accentProfile2),
              const Spacer(),
              Text(value, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
              Text(label, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: Colors.white70)),
            ],
          ),
        ),
      ).animate().fadeIn(duration: 400.ms, delay: delay).slideY(begin: 0.25, end: 0, curve: Curves.easeOutCubic),
    );
  }
}

class _QuickActions extends StatelessWidget {
  final UserModel user; const _QuickActions({required this.user});
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Hızlı Eylemler', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(child: _ActionButton(icon: Icons.emoji_events_outlined, label: 'Başarılar')),
            const SizedBox(width: 14),
            Expanded(child: _ActionButton(icon: Icons.timeline_rounded, label: 'İlerleme')),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _ActionButton(icon: Icons.people_alt_rounded, label: 'Takip')),
            const SizedBox(width: 14),
            Expanded(child: _ActionButton(icon: Icons.share_rounded, label: 'Paylaş')),
          ],
        ),
      ],
    );
  }
}

class _ActionButton extends StatefulWidget {
  final IconData icon; final String label; const _ActionButton({required this.icon, required this.label});
  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> {
  bool _pressed = false;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) {
        setState(() => _pressed = false);
        HapticFeedback.selectionClick();
      },
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1,
        duration: 120.ms,
        curve: Curves.easeOut,
        child: Container(
          height: 64,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0x221F1F1F), Color(0x111F1F1F)]),
            border: Border.all(color: Colors.white.withValues(alpha: (Colors.white.a * 0.12).toDouble()), width: 1),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(widget.icon, color: _accentProfile1, size: 22),
              const SizedBox(width: 8),
              Text(widget.label, style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ));
  }
}

// Yardımcı: kısa kullanım için ekstension
extension _ColorAlphaX on Color { Color oa(double f)=> withValues(alpha: (a * f).toDouble()); }
