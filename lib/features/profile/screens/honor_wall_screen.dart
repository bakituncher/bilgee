// lib/features/profile/screens/honor_wall_screen.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:bilge_ai/core/theme/app_theme.dart';
import 'package:bilge_ai/features/profile/models/badge_model.dart' as app_badge;
import 'package:confetti/confetti.dart'; // YENİ: Partikül efekti için

class HonorWallScreen extends StatelessWidget {
  final List<app_badge.Badge> allBadges;
  const HonorWallScreen({super.key, required this.allBadges});

  @override
  Widget build(BuildContext context) {
    final unlockedBadges = allBadges.where((b) => b.isUnlocked).toList();
    final lockedBadges = allBadges.where((b) => !b.isUnlocked).toList();
    final progress = allBadges.isNotEmpty ? unlockedBadges.length / allBadges.length : 0.0;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            title: const Text("Şeref Duvarı"),
            expandedHeight: 120.0,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Padding(
                padding: const EdgeInsets.only(top: 80.0, left: 20, right: 20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("Madalya Koleksiyonu", style: Theme.of(context).textTheme.titleMedium),
                        Text("${unlockedBadges.length} / ${allBadges.length}", style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppTheme.secondaryColor)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 8,
                        backgroundColor: AppTheme.lightSurfaceColor.withValues(alpha: AppTheme.lightSurfaceColor.a * 0.5),
                        valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.secondaryColor),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          _SliverSectionHeader(title: "Kazanılan Zaferler (${unlockedBadges.length})"),
          _buildBadgeGrid(context, unlockedBadges, true),
          _SliverSectionHeader(title: "Gelecek Hedefler (${lockedBadges.length})"),
          _buildBadgeGrid(context, lockedBadges, false),
        ],
      ),
    );
  }

  Widget _buildBadgeGrid(BuildContext context, List<app_badge.Badge> badges, bool isUnlocked) {
    if (badges.isEmpty) {
      return SliverToBoxAdapter(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 48.0),
            child: Column(
              children: [
                Icon( isUnlocked ? Icons.shield_moon_rounded : Icons.flag_rounded, size: 64, color: AppTheme.secondaryTextColor),
                const SizedBox(height: 16),
                Text( isUnlocked ? 'Henüz Madalya Kazanılmadı' : 'Tüm Hedefler Fethedildi!', style: Theme.of(context).textTheme.headlineSmall),
              ],
            ),
          ),
        ),
      );
    }
    return SliverPadding(
      padding: const EdgeInsets.all(20),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3, crossAxisSpacing: 20, mainAxisSpacing: 20, childAspectRatio: 0.85,
        ),
        delegate: SliverChildBuilderDelegate(
              (context, index) => BadgeCard(badge: badges[index])
              .animate()
              .fadeIn(delay: (100 * (index % 9)).ms)
              .slideY(begin: 0.5, curve: Curves.easeOutCubic),
          childCount: badges.length,
        ),
      ),
    );
  }
}

// YENİ WIDGET: Kaydırılabilir Başlık
class _SliverSectionHeader extends StatelessWidget {
  final String title;
  const _SliverSectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
        child: Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
      ),
    );
  }
}


class BadgeCard extends StatelessWidget {
  final app_badge.Badge badge;
  const BadgeCard({super.key, required this.badge});

  Color _getRarityColor(app_badge.BadgeRarity rarity) {
    switch (rarity) {
      case app_badge.BadgeRarity.rare: return Colors.blueAccent;
      case app_badge.BadgeRarity.epic: return Colors.purpleAccent;
      case app_badge.BadgeRarity.legendary: return Colors.amber;
      default: return badge.color;
    }
  }

  @override
  Widget build(BuildContext context) {
    final rarityColor = _getRarityColor(badge.rarity);
    Widget cardContent = Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: badge.isUnlocked ? rarityColor.withValues(alpha: rarityColor.a * 0.1) : AppTheme.cardColor.withValues(alpha: AppTheme.cardColor.a * 0.5),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: badge.isUnlocked ? rarityColor : AppTheme.lightSurfaceColor.withValues(alpha: AppTheme.lightSurfaceColor.a * 0.5), width: 2),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Icon( badge.isUnlocked ? badge.icon : Icons.question_mark_rounded, size: 40, color: badge.isUnlocked ? rarityColor : AppTheme.secondaryTextColor,),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text( badge.name, textAlign: TextAlign.center, style: TextStyle( fontWeight: FontWeight.bold, fontSize: 13, color: badge.isUnlocked ? Colors.white : AppTheme.secondaryTextColor,)),
          ),
        ],
      ),
    );

    // EFSANEVİ VE DESTANSI MADALYALARA IŞILTI EFEKTİ
    if (badge.isUnlocked && (badge.rarity == app_badge.BadgeRarity.epic || badge.rarity == app_badge.BadgeRarity.legendary)) {
      cardContent = Animate(
        onPlay: (c) => c.repeat(),
        effects: [ShimmerEffect(duration: 3000.ms, color: rarityColor.withValues(alpha: rarityColor.a * 0.5))],
        child: cardContent,
      );
    }

    return InkWell(
      onTap: () => _showBadgeDetails(context, rarityColor),
      borderRadius: BorderRadius.circular(24),
      child: cardContent,
    );
  }

  void _showBadgeDetails(BuildContext context, Color rarityColor) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.5),
      builder: (context) {
        return BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: _BadgeDetailsDialog(badge: badge, rarityColor: rarityColor),
        );
      },
    );
  }
}

class _BadgeDetailsDialog extends StatefulWidget {
  final app_badge.Badge badge;
  final Color rarityColor;
  const _BadgeDetailsDialog({required this.badge, required this.rarityColor});

  @override
  State<_BadgeDetailsDialog> createState() => _BadgeDetailsDialogState();
}

class _BadgeDetailsDialogState extends State<_BadgeDetailsDialog> {
  late final ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 1));
    if (widget.badge.isUnlocked) {
      _confettiController.play();
    }
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.topCenter,
      children: [
        Dialog(
          backgroundColor: Colors.transparent,
          child: Animate(
            effects: const [FadeEffect(duration: Duration(milliseconds: 300)), ScaleEffect(duration: Duration(milliseconds: 400), curve: Curves.elasticOut)],
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                  color: AppTheme.cardColor.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: widget.badge.isUnlocked ? widget.rarityColor : AppTheme.secondaryTextColor, width: 2),
                  boxShadow: [BoxShadow(color: (widget.badge.isUnlocked ? widget.rarityColor : AppTheme.secondaryTextColor).withValues(alpha: 0.3), blurRadius: 20)]
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    widget.badge.isUnlocked ? widget.badge.icon : Icons.lock_outline_rounded,
                    color: widget.badge.isUnlocked ? widget.rarityColor : AppTheme.secondaryTextColor,
                    size: 60,
                  ),
                  const SizedBox(height: 16),
                  Text(widget.badge.name, style: Theme.of(context).textTheme.headlineSmall, textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  Text(
                    widget.badge.isUnlocked ? widget.badge.description : widget.badge.hint,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: AppTheme.secondaryTextColor),
                  ),
                  const SizedBox(height: 24),
                  TextButton(
                    child: const Text("Anlaşıldı"),
                    onPressed: () => Navigator.of(context).pop(),
                  )
                ],
              ),
            ),
          ),
        ),
        if(widget.badge.isUnlocked)
          ConfettiWidget(
            confettiController: _confettiController,
            blastDirectionality: BlastDirectionality.explosive,
            shouldLoop: false,
            colors: [widget.rarityColor, Colors.white, AppTheme.secondaryColor],
          ),
      ],
    );
  }
}