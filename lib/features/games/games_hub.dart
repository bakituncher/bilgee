import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'widgets/game_card.dart';
import 'models/game_config.dart';

class GamesHub extends StatelessWidget {
  const GamesHub({super.key});

  static final Map<String, List<GameConfig>> _categorizedGames = {
    'Türkçe': [
      GameConfig(
        title: 'Yazım Kuralları',
        question: 'Bu yazım doğru mu?',
        icon: Icons.spellcheck_rounded,
        color: const Color(0xFF10B981),
        type: GameType.spelling,
        jsonPath: 'assets/data/confused_words.json',
        format: GameFormat.trueFalse,
      ),
      GameConfig(
        title: 'Yazar-Eser Eşleştirme',
        question: 'Yazar ve eserlerini eşleştir',
        icon: Icons.auto_stories_rounded,
        color: const Color(0xFF8B5CF6),
        type: GameType.authorWork,
        jsonPath: 'assets/data/author_works.json',
        format: GameFormat.multipleChoice,
      ),
    ],
    'Matematik': [
      GameConfig(
        title: 'Dört İşlem',
        question: 'İşlem sonucunu seç',
        icon: Icons.calculate_rounded,
        color: const Color(0xFF3B82F6),
        type: GameType.mathOperations,
        jsonPath: '', // Dinamik soru üretimi kullanıldığı için gerekli değil
        format: GameFormat.multipleChoice,
      ),
    ],
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Oyun Merkezi'),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 16),
        itemCount: _categorizedGames.length,
        itemBuilder: (context, index) {
          final categoryName = _categorizedGames.keys.elementAt(index);
          final gamesInCategory = _categorizedGames[categoryName]!;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min, // Sadece gerektiği kadar yer kapla
            children: [
              // Kategori Başlığı
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Text(
                  categoryName,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Kartları kendi doğal yüksekliğinde bırakan yatay kaydırma yapısı
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: gamesInCategory.map((game) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 16.0), // Kartlar arası boşluk
                      child: SizedBox(
                        width: 200, // Sadece genişliği sabitledik, yükseklik GameCard'a emanet
                        child: GameCard(
                          title: game.title,
                          subtitle: game.question,
                          icon: game.icon,
                          color: game.color,
                          onTap: () => context.goNamed(
                            'GamePlay',
                            extra: game,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 32),
            ],
          );
        },
      ),
    );
  }
}