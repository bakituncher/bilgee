// lib/features/profile/models/badge_model.dart
import 'package:flutter/material.dart';
import 'package:bilge_ai/core/theme/app_theme.dart';

// YENİ EKLENDİ: Madalya Rütbe Sistemi
enum BadgeRarity { common, rare, epic, legendary }

class Badge {
  final String name;
  final String description;
  final IconData icon;
  final Color color;
  final bool isUnlocked;
  final BadgeRarity rarity; // YENİ
  final String hint; // YENİ

  Badge({
    required this.name,
    required this.description,
    required this.icon,
    required this.color,
    this.isUnlocked = false,
    this.rarity = BadgeRarity.common, // YENİ
    this.hint = "Bu zafer henüz bir sır...", // YENİ
  });
}