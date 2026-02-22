import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart';
import '../models/game_config.dart';

class GameQuestion {
  final String displayText;
  final String? secondaryText;
  final bool isCorrect;

  GameQuestion({
    required this.displayText,
    this.secondaryText,
    required this.isCorrect,
  });
}

class GameService {
  static Future<List<GameQuestion>> loadQuestions(GameConfig config, {int count = 10}) async {
    switch (config.type) {
      case GameType.spelling:
        return _loadSpellingQuestions(config.jsonPath, count);
      case GameType.authorWork:
        return _loadAuthorWorkQuestions(config.jsonPath, count);
    }
  }

  static Future<List<GameQuestion>> _loadSpellingQuestions(String jsonPath, int count) async {
    try {
      final String response = await rootBundle.loadString(jsonPath);
      final List<dynamic> data = json.decode(response);

      // Tüm kelimeleri topla
      final allWords = <Map<String, dynamic>>[];
      for (var item in data) {
        allWords.add({
          'correct': item['correct'],
          'wrong': List<String>.from(item['wrong']),
        });
      }

      // Rastgele kelime seç
      allWords.shuffle(Random());
      final selectedWords = allWords.take(count * 2).toList();

      // Doğru/Yanlış soruları hazırla
      final questions = <GameQuestion>[];
      for (var word in selectedWords) {
        final correct = word['correct'] as String;
        final wrongList = List<String>.from(word['wrong']);

        // Doğru yazım
        questions.add(GameQuestion(
          displayText: correct,
          isCorrect: true,
        ));

        // Yanlış yazım
        if (wrongList.isNotEmpty) {
          wrongList.shuffle(Random());
          questions.add(GameQuestion(
            displayText: wrongList.first,
            isCorrect: false,
          ));
        }
      }

      questions.shuffle(Random());
      return questions.take(count).toList();
    } catch (e) {
      print('Sorular yüklenirken hata: $e');
      return [];
    }
  }

  static Future<List<GameQuestion>> _loadAuthorWorkQuestions(String jsonPath, int count) async {
    try {
      final String response = await rootBundle.loadString(jsonPath);
      final List<dynamic> data = json.decode(response);

      final allItems = <Map<String, String>>[];
      for (var item in data) {
        allItems.add({
          'work': item['work'] as String,
          'author': item['author'] as String,
        });
      }

      allItems.shuffle(Random());
      final selected = allItems.take(count).toList();

      final questions = <GameQuestion>[];
      for (var item in selected) {
        // Doğru eşleştirme
        questions.add(GameQuestion(
          displayText: item['work']!,
          secondaryText: item['author'],
          isCorrect: true,
        ));

        // Yanlış eşleştirme
        final wrongAuthors = allItems.where((a) => a['author'] != item['author']).toList();
        if (wrongAuthors.isNotEmpty) {
          wrongAuthors.shuffle(Random());
          questions.add(GameQuestion(
            displayText: item['work']!,
            secondaryText: wrongAuthors.first['author'],
            isCorrect: false,
          ));
        }
      }

      questions.shuffle(Random());
      return questions.take(count).toList();
    } catch (e) {
      print('Sorular yüklenirken hata: $e');
      return [];
    }
  }
}

