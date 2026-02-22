import 'package:flutter/material.dart';

enum GameType {
  spelling,
  authorWork,
}

enum GameFormat {
  trueFalse,      // Doğru/Yanlış formatı
  multipleChoice, // 4 şıklı test formatı
}

class GameConfig {
  final String title;
  final String question;
  final IconData icon;
  final Color color;
  final GameType type;
  final String jsonPath;
  final GameFormat format;

  const GameConfig({
    required this.title,
    required this.question,
    required this.icon,
    required this.color,
    required this.type,
    required this.jsonPath,
    required this.format,
  });
}



