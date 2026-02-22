import 'package:flutter/material.dart';

enum GameType {
  spelling,
  authorWork,
}

class GameConfig {
  final String title;
  final String question;
  final IconData icon;
  final Color color;
  final GameType type;
  final String jsonPath;

  const GameConfig({
    required this.title,
    required this.question,
    required this.icon,
    required this.color,
    required this.type,
    required this.jsonPath,
  });
}

