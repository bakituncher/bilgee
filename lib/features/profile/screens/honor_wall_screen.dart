// lib/features/profile/screens/honor_wall_screen.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:taktik/features/profile/models/badge_model.dart' as app_badge;
import 'package:confetti/confetti.dart'; // YENİ: Partikül efekti için
import 'package:taktik/shared/widgets/custom_back_button.dart';

class HonorWallScreen extends StatelessWidget {
  final List<app_badge.Badge> allBadges;
  const HonorWallScreen({super.key, required this.allBadges});

  @override
  Widget build(BuildContext context) {
    final unlockedBadges = allBadges.where((b) => b.isUnlocked).toList();
    final lockedBadges = allBadges.where((b) => !b.isUnlocked).toList();
    final progress = allBadges.isNotEmpty ? unlockedBadges.length / allBadges.length : 0.0;

    return Scaffold(
      appBar: AppBar(
        leading: const CustomBackButton(),
        title: const Text("Şeref Duvarı"),
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Progress Section
          Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Madalya Koleksiyonu", style: Theme.of(context).textTheme.titleMedium),
                  Text("${unlockedBadges.length} / ${allBadges.length}", style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Theme.of(context).colorScheme.primary)),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
                  valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.primary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Unlocked Badges Section
          Text(
            "Kazanılan Zaferler (${unlockedBadges.length})",
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _buildBadgeGrid(context, unlockedBadges, true),
          const SizedBox(height: 24),
          // Locked Badges Section
          Text(
            "Gelecek Hedefler (${lockedBadges.length})",
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _buildBadgeGrid(context, lockedBadges, false),
        ],
      ),
    );
  }

  Widget _buildBadgeGrid(BuildContext context, List<app_badge.Badge> badges, bool isUnlocked) {
    if (badges.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 48.0),
          child: Column(
            children: [
              Icon( isUnlocked ? Icons.shield_moon_rounded : Icons.flag_rounded, size: 64, color: Theme.of(context).colorScheme.onSurfaceVariant),
              const SizedBox(height: 16),
              Text( isUnlocked ? 'Henüz Madalya Kazanılmadı' : 'Tüm Hedefler Fethedildi!', style: Theme.of(context).textTheme.headlineSmall),
            ],
          ),
        ),
      );
    }
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 20,
        mainAxisSpacing: 20,
        childAspectRatio: 0.85,
      ),
      itemCount: badges.length,
      itemBuilder: (context, index) => BadgeCard(badge: badges[index])
          .animate()
          .fadeIn(delay: (100 * (index % 9)).ms)
          .slideY(begin: 0.5, curve: Curves.easeOutCubic),
    );
  }
}


class BadgeCard extends StatelessWidget {
  final app_badge.Badge badge;
  const BadgeCard({super.key, required this.badge});

  Color _getRarityColor(BuildContext context, app_badge.BadgeRarity rarity) {
    final colorScheme = Theme.of(context).colorScheme;
    switch (rarity) {
      case app_badge.BadgeRarity.rare: return colorScheme.primary;
      case app_badge.BadgeRarity.epic: return colorScheme.tertiary;
      case app_badge.BadgeRarity.legendary: return colorScheme.primaryContainer;
      default: return badge.color ?? colorScheme.secondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final rarityColor = _getRarityColor(context, badge.rarity);
    final bool isShiny = badge.isUnlocked && (badge.rarity == app_badge.BadgeRarity.epic || badge.rarity == app_badge.BadgeRarity.legendary);

    Widget iconWidget = Icon(
      badge.isUnlocked ? badge.icon : Icons.question_mark_rounded,
      size: 40,
      color: badge.isUnlocked ? rarityColor : Theme.of(context).colorScheme.onSurfaceVariant,
    );
    if (isShiny) {
      iconWidget = Animate(
        effects: [ShimmerEffect(duration: 2200.ms, color: rarityColor.withOpacity(0.5))],
        child: iconWidget,
      );
    }

    Widget cardContent = Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: badge.isUnlocked ? rarityColor.withOpacity(0.1) : Theme.of(context).cardColor.withOpacity(0.5),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: badge.isUnlocked ? rarityColor : Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5), width: 2),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          iconWidget,
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              badge.name,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: badge.isUnlocked ? Theme.of(context).colorScheme.onSurface : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );

    // Dikdörtgen parıltı veren global shimmer kaldırıldı

    return InkWell(
      onTap: () => _showBadgeDetails(context, rarityColor),
      borderRadius: BorderRadius.circular(24),
      child: cardContent,
    );
  }

  void _showBadgeDetails(BuildContext context, Color rarityColor) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
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
    final onSurfaceVariant = Theme.of(context).colorScheme.onSurfaceVariant;
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
                  color: Theme.of(context).cardColor.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: widget.badge.isUnlocked ? widget.rarityColor : onSurfaceVariant, width: 2),
                  boxShadow: [BoxShadow(color: (widget.badge.isUnlocked ? widget.rarityColor : onSurfaceVariant).withOpacity(0.3), blurRadius: 20)]
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    widget.badge.isUnlocked ? widget.badge.icon : Icons.lock_outline_rounded,
                    color: widget.badge.isUnlocked ? widget.rarityColor : onSurfaceVariant,
                    size: 60,
                  ),
                  const SizedBox(height: 16),
                  Text(widget.badge.name, style: Theme.of(context).textTheme.headlineSmall, textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  Text(
                    widget.badge.isUnlocked ? widget.badge.description : widget.badge.hint,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: onSurfaceVariant),
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
            colors: [widget.rarityColor, Theme.of(context).colorScheme.onSurface, Theme.of(context).colorScheme.primary],
          ),
      ],
    );
  }
}