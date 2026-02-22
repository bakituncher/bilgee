import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart';
import '../models/game_config.dart';

enum QuestionFormat {
  authorToWork,  // Yazardan esere: "Aşağıdakilerin hangisi X yazarının eseridir?"
  workToAuthor,  // Eserden yazara: "X eserinin yazarı kimdir?"
}

class GameQuestion {
  final String displayText;
  final String? secondaryText;
  final bool isCorrect;
  final QuestionFormat? questionFormat;

  // 4 şıklı test için
  final List<String>? options;       // Şıklar (4 tane)
  final int? correctAnswerIndex;     // Doğru cevabın indeksi (0-3)

  GameQuestion({
    required this.displayText,
    this.secondaryText,
    required this.isCorrect,
    this.questionFormat,
    this.options,
    this.correctAnswerIndex,
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
      final questions = <GameQuestion>[];

      for (int i = 0; i < count && i < allItems.length; i++) {
        final item = allItems[i];

        // Rastgele soru formatı seç
        final format = Random().nextBool() ? QuestionFormat.authorToWork : QuestionFormat.workToAuthor;

        if (format == QuestionFormat.authorToWork) {
          // "Aşağıdakilerin hangisi X yazarının eseridir?" formatı
          final correctWork = item['work']!;

          // Yanlış şıklar için diğer eserleri al
          final otherWorks = allItems
              .where((a) => a['work'] != correctWork)
              .map((a) => a['work']!)
              .toList();
          otherWorks.shuffle(Random());

          // 4 şık oluştur
          final wrongOptions = otherWorks.take(3).toList();
          final allOptions = [correctWork, ...wrongOptions];

          // Şıkları karıştır
          allOptions.shuffle(Random());
          final correctIndex = allOptions.indexOf(correctWork);

          questions.add(GameQuestion(
            displayText: item['author']!,
            isCorrect: true,
            questionFormat: QuestionFormat.authorToWork,
            options: allOptions,
            correctAnswerIndex: correctIndex,
          ));
        } else {
          // "X eserinin yazarı kimdir?" formatı
          final correctAuthor = item['author']!;

          // Yanlış şıklar için diğer yazarları al
          final otherAuthors = allItems
              .where((a) => a['author'] != correctAuthor)
              .map((a) => a['author']!)
              .toSet()  // Tekrarları kaldır
              .toList();
          otherAuthors.shuffle(Random());

          // 4 şık oluştur
          final wrongOptions = otherAuthors.take(3).toList();
          final allOptions = [correctAuthor, ...wrongOptions];

          // Şıkları karıştır
          allOptions.shuffle(Random());
          final correctIndex = allOptions.indexOf(correctAuthor);

          questions.add(GameQuestion(
            displayText: item['work']!,
            isCorrect: true,
            questionFormat: QuestionFormat.workToAuthor,
            options: allOptions,
            correctAnswerIndex: correctIndex,
          ));
        }
      }

      return questions;
    } catch (e) {
      print('Sorular yüklenirken hata: $e');
      return [];
    }
  }
}

