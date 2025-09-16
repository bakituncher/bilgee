// lib/features/arena/screens/public_profile_screen.dart
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bilge_ai/data/providers/firestore_providers.dart';
import 'package:bilge_ai/core/theme/app_theme.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/services.dart';
import 'package:bilge_ai/features/profile/logic/rank_service.dart';
import 'package:share_plus/share_plus.dart';
import 'package:bilge_ai/features/auth/application/auth_controller.dart';
import 'package:intl/intl.dart';
import 'package:flutter/rendering.dart';
import 'package:bilge_ai/shared/widgets/logo_loader.dart';

// NovaPulse accent renkleri (arena ile uyumlu)
const _accentProfile1 = Color(0xFF7F5BFF);
const _accentProfile2 = Color(0xFF6BFF7A);
const _profileBgGradient = [Color(0xFF0B0F14), Color(0xFF2A155A), Color(0xFF061F38)];

// Bu provider, ID'ye göre tek bir kullanıcı profili getirmek için kullanılır.
final publicUserProfileProvider = FutureProvider.family.autoDispose<Map<String, dynamic>?, String>((ref, userId) async {
  final svc = ref.watch(firestoreServiceProvider);
  final data = await svc.getPublicProfileRaw(userId);
  if (data != null) return data;
  // public_profiles yoksa: mevcut kullanıcının examType'ına göre liderlikten tekil kullanıcıyı dene
  final myExam = ref.watch(userProfileProvider).value?.selectedExam;
  if (myExam != null) {
    return await svc.getLeaderboardUserRaw(myExam, userId);
  }
  return null;
});

class PublicProfileScreen extends ConsumerStatefulWidget {
  final String userId;
  const PublicProfileScreen({super.key, required this.userId});

  @override
  ConsumerState<PublicProfileScreen> createState() => _PublicProfileScreenState();
}

class _PublicProfileScreenState extends ConsumerState<PublicProfileScreen> {
  final GlobalKey _shareKey = GlobalKey();
  bool _sharing = false;

  Future<void> _shareProfileImage() async {
    if (_sharing) return;
    setState(() => _sharing = true);
    try {
      final boundary = _shareKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;
      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;
      final bytes = byteData.buffer.asUint8List();
      final xfile = XFile.fromData(bytes, name: 'warrior_card.png', mimeType: 'image/png');
      await Share.shareXFiles([xfile], text: 'Savaşçı Künyem');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Paylaşım hatası: $e')));
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  void _showPublicAchievements(BuildContext context, {required String displayName, required int testCount, required double avgNet, required int streak, required int engagement}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        final items = [
          {'icon': Icons.flag, 'title': 'Denemeler', 'value': testCount.toString()},
          {'icon': Icons.track_changes_rounded, 'title': 'Ortalama Net', 'value': avgNet.toStringAsFixed(1)},
          {'icon': Icons.local_fire_department_rounded, 'title': 'Günlük Seri', 'value': streak.toString()},
          {'icon': Icons.flash_on_rounded, 'title': 'Rütbe Puanı', 'value': engagement.toString()},
        ];
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(4)))),
              const SizedBox(height: 12),
              Text('$displayName — Başarılar', style: Theme.of(ctx).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: items.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: 2.6),
                itemBuilder: (_, i) {
                  final it = items[i];
                  return Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0x221F1F1F), Color(0x111F1F1F)]),
                      border: Border.all(color: Colors.white.withValues(alpha: (Colors.white.a * 0.12).toDouble())),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    child: Row(children: [
                      Icon(it['icon'] as IconData, color: _accentProfile2),
                      const SizedBox(width: 8),
                      Expanded(child: Text(it['title'] as String, style: Theme.of(ctx).textTheme.labelLarge)),
                      Text(it['value'] as String, style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    ]),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showPublicProgress(BuildContext context, {required int testCount, required double avgNet, required int streak, required int engagement}) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('İlerleme Özeti'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _kv('Deneme', testCount.toString(), ctx),
            _kv('Ortalama Net', avgNet.toStringAsFixed(1), ctx),
            _kv('Günlük Seri', streak.toString(), ctx),
            _kv('Rütbe Puanı', engagement.toString(), ctx),
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Kapat'))],
      ),
    );
  }

  Widget _kv(String k, String v, BuildContext ctx) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4.0),
    child: Row(children: [Expanded(child: Text(k, style: Theme.of(ctx).textTheme.bodyLarge?.copyWith(color: Colors.white70))), Text(v, style: Theme.of(ctx).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold))]),
  );

  @override
  Widget build(BuildContext context) {
    final userProfileAsync = ref.watch(publicUserProfileProvider(widget.userId));
    final statsAsync = ref.watch(userStatsForUserProvider(widget.userId));
    final followCountsAsync = ref.watch(followCountsProvider(widget.userId));
    final isFollowingAsync = ref.watch(isFollowingProvider(widget.userId));
    final me = ref.watch(authControllerProvider).value;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Savaşçı Künyesi'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: _sharing ? 'Hazırlanıyor...' : 'Paylaş',
            onPressed: _sharing ? null : () { HapticFeedback.selectionClick(); _shareProfileImage(); },
            icon: const Icon(Icons.ios_share_rounded, color: _accentProfile2),
          ),
        ],
      ),
      body: userProfileAsync.when(
        data: (data) {
          if (data == null) {
            return const Center(child: Text('Savaşçı bulunamadı.'));
          }
          final String displayName = (data['name'] as String?) ?? 'İsimsiz Savaşçı';
          final int testCount = (data['testCount'] as num?)?.toInt() ?? 0;
          final double totalNetSum = (data['totalNetSum'] as num?)?.toDouble() ?? 0.0;
          final double avgNet = testCount > 0 ? totalNetSum / testCount : 0.0;
          final int engagement = (data['engagementScore'] as num?)?.toInt() ?? 0;
          final int streak = (data['streak'] as num?)?.toInt() ?? 0;
          final String? avatarStyle = data['avatarStyle'] as String?;
          final String? avatarSeed = data['avatarSeed'] as String?;
          final rankInfo = RankService.getRankInfo(engagement);
          final rankName = rankInfo.current.name;
          final rankIcon = rankInfo.current.icon;
          final rankColor = rankInfo.current.color;
          final currentLevel = RankService.ranks.indexOf(rankInfo.current) + 1;
          final updatedAt = statsAsync.valueOrNull?.updatedAt;

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
                          // Paylaşılabilir kart
                          RepaintBoundary(
                            key: _shareKey,
                            child: _ShareableProfileCard(
                              displayName: displayName,
                              avatarStyle: avatarStyle,
                              avatarSeed: avatarSeed,
                              rankColor: rankColor,
                              rankIcon: rankIcon,
                              rankName: rankName,
                              avgNet: avgNet,
                              testCount: testCount,
                              streak: streak,
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Takip arayüzü ve sayaçlar
                          Row(
                            children: [
                              Expanded(
                                child: followCountsAsync.when(
                                  data: (counts) => Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                    children: [
                                      _CountPill(label: 'Takipçi', value: counts.$1),
                                      _CountPill(label: 'Takip', value: counts.$2),
                                    ],
                                  ),
                                  loading: () => const LinearProgressIndicator(minHeight: 2),
                                  error: (e, s) => const SizedBox.shrink(),
                                ),
                              ),
                              const SizedBox(width: 12),
                              if (me?.uid != widget.userId)
                                _FollowButton(targetUserId: widget.userId),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (updatedAt != null)
                            Align(
                              alignment: Alignment.centerRight,
                              child: Text(
                                "Son güncelleme: ${DateFormat('dd MMM yyyy HH:mm', 'tr_TR').format(updatedAt)}",
                                style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.white70),
                              ),
                            ),
                          const SizedBox(height: 16),
                          // 4'lü eylem kartları — geri eklendi
                          GridView.count(
                            crossAxisCount: 2,
                            crossAxisSpacing: 14,
                            mainAxisSpacing: 14,
                            childAspectRatio: 2.8,
                            physics: const NeverScrollableScrollPhysics(),
                            shrinkWrap: true,
                            children: [
                              _ActionTile(icon: Icons.emoji_events_outlined, label: 'Başarılar', onTap: () {
                                HapticFeedback.selectionClick();
                                _showPublicAchievements(context,
                                  displayName: displayName,
                                  testCount: testCount,
                                  avgNet: avgNet,
                                  streak: streak,
                                  engagement: engagement,
                                );
                              }),
                              _ActionTile(icon: Icons.timeline_rounded, label: 'İlerleme', onTap: () {
                                HapticFeedback.selectionClick();
                                _showPublicProgress(context, testCount: testCount, avgNet: avgNet, streak: streak, engagement: engagement);
                              }),
                              _ActionTile(icon: Icons.people_alt_rounded, label: 'Takip', onTap: () async {
                                HapticFeedback.selectionClick();
                                final svc = ref.read(firestoreServiceProvider);
                                final isFollowingNow = isFollowingAsync.valueOrNull ?? false;
                                if (me?.uid == null || me!.uid == widget.userId) return;
                                if (isFollowingNow) {
                                  await svc.unfollowUser(currentUserId: me!.uid, targetUserId: widget.userId);
                                } else {
                                  await svc.followUser(currentUserId: me!.uid, targetUserId: widget.userId);
                                }
                              }),
                              _ActionTile(icon: Icons.share_rounded, label: 'Paylaş', onTap: () {
                                HapticFeedback.selectionClick();
                                _shareProfileImage();
                              }),
                            ],
                          ),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
        loading: () => const LogoLoader(),
        error: (e, s) => Center(child: Text('Savaşçı Künyesi Yüklenemedi: $e')),
      ),
    );
  }
}

class _ShareableProfileCard extends StatelessWidget {
  final String displayName; final String? avatarStyle; final String? avatarSeed; final Color rankColor; final IconData rankIcon; final String rankName; final double avgNet; final int testCount; final int streak;
  const _ShareableProfileCard({
    required this.displayName,
    required this.avatarStyle,
    required this.avatarSeed,
    required this.rankColor,
    required this.rankIcon,
    required this.rankName,
    required this.avgNet,
    required this.testCount,
    required this.streak,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0x221F1F1F), Color(0x111F1F1F)]),
        border: Border.all(color: Colors.white.withValues(alpha: (Colors.white.a * 0.12).toDouble()), width: 1),
      ),
      child: Column(
        children: [
          _AvatarHalo(displayName: displayName, avatarStyle: avatarStyle, avatarSeed: avatarSeed, rankColor: rankColor),
          const SizedBox(height: 10),
          Text(displayName, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          _RankCapsule(rankName: rankName, icon: rankIcon, color: rankColor),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _StatCard(label: 'Deneme', value: testCount.toString(), icon: Icons.library_books_rounded, delay: 0.ms)),
              const SizedBox(width: 10),
              Expanded(child: _StatCard(label: 'Ort. Net', value: avgNet.toStringAsFixed(1), icon: Icons.track_changes_rounded, delay: 0.ms)),
              const SizedBox(width: 10),
              Expanded(child: _StatCard(label: 'Seri', value: streak.toString(), icon: Icons.local_fire_department_rounded, delay: 0.ms)),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset('assets/images/bilge_baykus.png', width: 28, height: 28),
              const SizedBox(width: 8),
              Text('TaktikAI', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: _accentProfile2, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }
}

class _CountPill extends StatelessWidget {
  final String label; final int value; const _CountPill({required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white.withValues(alpha: (Colors.white.a * 0.06).toDouble()),
        border: Border.all(color: Colors.white.withValues(alpha: (Colors.white.a * 0.12).toDouble())),
      ),
      child: Row(
        children: [
          Text(value.toString(), style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(width: 6),
          Text(label, style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Colors.white70)),
        ],
      ),
    );
  }
}

class _FollowButton extends ConsumerStatefulWidget {
  final String targetUserId;
  const _FollowButton({required this.targetUserId});
  @override
  ConsumerState<_FollowButton> createState() => _FollowButtonState();
}

class _FollowButtonState extends ConsumerState<_FollowButton> {
  bool? _optimistic; // null: stream belirleyici, true/false: anlık gösterim
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(authControllerProvider).value;
    final isFollowingAsync = ref.watch(isFollowingProvider(widget.targetUserId));
    final bool? streamVal = isFollowingAsync.valueOrNull;
    final bool? loading = isFollowingAsync.isLoading ? true : null;
    final bool isFollowing = _optimistic ?? (streamVal ?? false);

    final bg = isFollowing ? Colors.transparent : _accentProfile2;
    final fg = isFollowing ? _accentProfile2 : Colors.black;
    final icon = isFollowing ? Icons.check_rounded : Icons.person_add_alt_1_rounded;
    final label = isFollowing ? 'Takipten Çık' : 'Takip Et';

    return ElevatedButton.icon(
      onPressed: _busy || me?.uid == null || me!.uid == widget.targetUserId
          ? null
          : () async {
              HapticFeedback.selectionClick();
              setState(() { _busy = true; _optimistic = !isFollowing; });
              try {
                final svc = ref.read(firestoreServiceProvider);
                if (isFollowing) {
                  await svc.unfollowUser(currentUserId: me!.uid, targetUserId: widget.targetUserId);
                } else {
                  await svc.followUser(currentUserId: me!.uid, targetUserId: widget.targetUserId);
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('İşlem başarısız: $e')));
                  setState(() { _optimistic = null; });
                }
              } finally {
                if (mounted) setState(() { _busy = false; _optimistic = null; });
              }
            },
      style: ElevatedButton.styleFrom(
        backgroundColor: bg,
        foregroundColor: fg,
        elevation: 0,
        side: BorderSide(color: _accentProfile2.withValues(alpha: (_accentProfile2.a * 0.8).toDouble())),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        minimumSize: const Size(0, 40),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      ),
      icon: (loading == true && _optimistic == null) || _busy
          ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: _accentProfile2))
          : Icon(icon),
      label: Text(label),
    );
  }
}

// Aşağıdaki bileşenler eski dosyadan alınmış uyumlu kopyalardır
class _AvatarHalo extends StatelessWidget {
  final String displayName; final String? avatarStyle; final String? avatarSeed; final Color rankColor;
  const _AvatarHalo({required this.displayName, required this.avatarStyle, required this.avatarSeed, required this.rankColor});
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150,
      height: 150,
      child: Stack(
        alignment: Alignment.center,
        children: [
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
                child: avatarStyle != null && avatarSeed != null
                    ? SvgPicture.network(
                        "https://api.dicebear.com/9.x/${avatarStyle}/svg?seed=${avatarSeed}",
                        fit: BoxFit.cover,
                      )
                    : Text(
                        (displayName.isNotEmpty ? displayName[0] : 'T').toUpperCase(),
                        style: Theme.of(context).textTheme.displayMedium?.copyWith(color: _accentProfile2, fontWeight: FontWeight.bold),
                      ),
              ),
            ).animate().fadeIn(duration: 500.ms).scale(curve: Curves.easeOutBack),
          ),
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

class _StatCard extends StatelessWidget {
  final String label; final String value; final IconData icon; final Duration delay;
  const _StatCard({required this.label, required this.value, required this.icon, required this.delay});
  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label istatistiği: $value',
      child: Container(
        height: 80,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0x1FFFFFFF), Color(0x0DFFFFFF)]),
          border: Border.all(color: Colors.white.withValues(alpha: (Colors.white.a * 0.12).toDouble()), width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 20, color: _accentProfile2),
              const Spacer(),
              Text(value, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.white70)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionTile extends StatefulWidget {
  final IconData icon; final String label; final VoidCallback onTap; const _ActionTile({required this.icon, required this.label, required this.onTap});
  @override
  State<_ActionTile> createState() => _ActionTileState();
}

class _ActionTileState extends State<_ActionTile> {
  bool _pressed = false;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) { setState(() => _pressed = false); widget.onTap(); },
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1,
        duration: 120.ms,
        curve: Curves.easeOut,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0x221F1F1F), Color(0x111F1F1F)]),
            border: Border.all(color: Colors.white.withValues(alpha: (Colors.white.a * 0.12).toDouble())),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(widget.icon, color: _accentProfile1, size: 22),
              const SizedBox(width: 8),
              Text(widget.label, style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}

// Yardımcı: kısa kullanım için ekstension
extension _ColorAlphaX on Color { Color oa(double f)=> withValues(alpha: (a * f).toDouble()); }
