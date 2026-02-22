import 'package:flutter/material.dart';
import 'widgets/game_card.dart';
import 'screens/game_screen.dart';
import 'models/game_config.dart';

class GamesHub extends StatelessWidget {
  const GamesHub({super.key});

  static final List<GameConfig> _games = [
    GameConfig(
      title: 'Yazım Kuralları',
      question: 'Bu yazım doğru mu?',
      icon: Icons.spellcheck_rounded,
      color: const Color(0xFF10B981),
      type: GameType.spelling,
      jsonPath: 'assets/data/confused_words.json',
    ),
    GameConfig(
      title: 'Yazar-Eser Eşleştirme',
      question: 'Bu eşleştirme doğru mu?',
      icon: Icons.auto_stories_rounded,
      color: const Color(0xFF8B5CF6),
      type: GameType.authorWork,
      jsonPath: 'assets/data/author_works.json',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Oyun Merkezi'),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _games.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final game = _games[index];
          return GameCard(
            title: game.title,
            subtitle: game.question,
            icon: game.icon,
            color: game.color,
            onTap: () => Navigator.push(
              context,
              PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) => GameScreen(config: game),
                transitionDuration: Duration.zero,
                reverseTransitionDuration: Duration.zero,
              ),
            ),
          );
        },
      ),
    );
  }
}

