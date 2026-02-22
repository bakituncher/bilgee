import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart';
import '../models/game_config.dart';

enum QuestionFormat {
  authorToWork,
  workToAuthor,
}

class GameQuestion {
  final String displayText;
  final String? secondaryText;
  final bool isCorrect;
  final QuestionFormat? questionFormat;
  final List<String>? options;
  final int? correctAnswerIndex;

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
      case GameType.mathOperations:
        return _loadMathOperationsQuestions(config.jsonPath, count);
    }
  }

  static Future<List<GameQuestion>> _loadSpellingQuestions(String jsonPath, int count) async {
    try {
      final String response = await rootBundle.loadString(jsonPath);
      final List<dynamic> data = json.decode(response);

      final allWords = <Map<String, dynamic>>[];
      for (var item in data) {
        allWords.add({
          'correct': item['correct'],
          'wrong': List<String>.from(item['wrong']),
        });
      }

      allWords.shuffle(Random());
      final selectedWords = allWords.take(count * 2).toList();

      final questions = <GameQuestion>[];
      for (var word in selectedWords) {
        final correct = word['correct'] as String;
        final wrongList = List<String>.from(word['wrong']);

        questions.add(GameQuestion(
          displayText: correct,
          isCorrect: true,
        ));

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
        final format = Random().nextBool() ? QuestionFormat.authorToWork : QuestionFormat.workToAuthor;

        if (format == QuestionFormat.authorToWork) {
          final correctWork = item['work']!;
          final otherWorks = allItems
              .where((a) => a['work'] != correctWork)
              .map((a) => a['work']!)
              .toList();
          otherWorks.shuffle(Random());

          final wrongOptions = otherWorks.take(3).toList();
          final allOptions = [correctWork, ...wrongOptions];
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
          final correctAuthor = item['author']!;
          final otherAuthors = allItems
              .where((a) => a['author'] != correctAuthor)
              .map((a) => a['author']!)
              .toSet()
              .toList();
          otherAuthors.shuffle(Random());

          final wrongOptions = otherAuthors.take(3).toList();
          final allOptions = [correctAuthor, ...wrongOptions];
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

  static Future<List<GameQuestion>> _loadMathOperationsQuestions(String jsonPath, int count) async {
    final questions = <GameQuestion>[];
    final random = Random();

    for (int i = 0; i < count; i++) {
      try {
        final operationType = random.nextInt(10);
        late String question;
        late int correctAnswer;

        if (operationType <= 2) {
          final basicOp = random.nextInt(4);
          switch (basicOp) {
            case 0:
              if (random.nextBool()) {
                final a = random.nextInt(900) + 10;
                final b = random.nextInt(900) + 10;
                question = '$a + $b';
                correctAnswer = a + b;
              } else {
                final a = random.nextInt(300) + 10;
                final b = random.nextInt(300) + 10;
                final c = random.nextInt(300) + 10;
                question = '$a + $b + $c';
                correctAnswer = a + b + c;
              }
              break;

            case 1:
              final subType = random.nextInt(3);
              if (subType == 0) {
                final a = random.nextInt(900) + 100;
                final b = random.nextInt(a - 10) + 10;
                question = '$a - $b';
                correctAnswer = a - b;
              } else if (subType == 1) {
                final a = random.nextInt(400) + 200;
                final b = random.nextInt(100) + 20;
                final c = random.nextInt(50) + 10;
                if (a > b + c) {
                  question = '$a - $b - $c';
                  correctAnswer = a - b - c;
                } else {
                  final a2 = random.nextInt(900) + 100;
                  final b2 = random.nextInt(a2 - 10) + 10;
                  question = '$a2 - $b2';
                  correctAnswer = a2 - b2;
                }
              } else {
                final b = random.nextInt(100) + 50;
                final c = random.nextInt(b - 10) + 10;
                final a = random.nextInt(200) + 100;
                question = '$a - ($b - $c)';
                correctAnswer = a - (b - c);
              }
              break;

            case 2:
              final multType = random.nextInt(3);
              if (multType == 0) {
                final a = random.nextInt(20) + 2;
                final b = random.nextInt(20) + 2;
                question = '$a × $b';
                correctAnswer = a * b;
              } else if (multType == 1) {
                final a = random.nextInt(8) + 2;
                final b = random.nextInt(8) + 2;
                final c = random.nextInt(5) + 2;
                question = '$a × $b × $c';
                correctAnswer = a * b * c;
              } else {
                final a = random.nextInt(15) + 5;
                final b = random.nextInt(15) + 5;
                final c = random.nextInt(8) + 2;
                question = '($a + $b) × $c';
                correctAnswer = (a + b) * c;
              }
              break;

            case 3:
              if (random.nextBool()) {
                final divisor = random.nextInt(15) + 2;
                final quotient = random.nextInt(20) + 2;
                final dividend = divisor * quotient;
                question = '$dividend ÷ $divisor';
                correctAnswer = quotient;
              } else {
                final c = random.nextInt(10) + 2;
                final quotient = random.nextInt(15) + 2;
                final product = c * quotient;
                final factors = _getFactors(product);
                if (factors.length >= 2) {
                  final a = factors[random.nextInt(factors.length)];
                  final b = product ~/ a;
                  question = '($a × $b) ÷ $c';
                  correctAnswer = product ~/ c;
                } else {
                  final divisor = random.nextInt(15) + 2;
                  final quot = random.nextInt(20) + 2;
                  final dividend = divisor * quot;
                  question = '$dividend ÷ $divisor';
                  correctAnswer = quot;
                }
              }
              break;
          }
        } else if (operationType >= 3 && operationType <= 4) {
          // Sadece işlemli üslü sayı soruları (tek başına üs yok)
          final powerType = random.nextInt(4);

          if (powerType == 0) {
            // Kareler toplamı
            final a = random.nextInt(7) + 2;  // 2-8 arası
            final b = random.nextInt(7) + 2;  // 2-8 arası
            question = '$a² + $b²';
            correctAnswer = (a * a) + (b * b);
          } else if (powerType == 1) {
            // Küp ve kare karışık
            final a = random.nextInt(4) + 2;  // 2, 3, 4, 5
            final b = random.nextInt(5) + 2;  // 2-6 arası
            final aValue = a * a * a;
            final bValue = b * b;
            if (aValue > bValue) {
              question = '$a³ - $b²';
              correctAnswer = aValue - bValue;
            } else {
              question = '$a² + $b²';
              correctAnswer = (a * a) + (b * b);
            }
          } else if (powerType == 2) {
            // Kare × basit sayı
            final a = random.nextInt(6) + 2;  // 2-7 arası
            final b = random.nextInt(6) + 2;  // 2-7 arası
            question = '$a² × $b';
            correctAnswer = (a * a) * b;
          } else {
            // Toplam kareleri
            final a = random.nextInt(6) + 2;  // 2-7 arası
            final b = random.nextInt(6) + 2;  // 2-7 arası
            question = '($a + $b)²';
            correctAnswer = (a + b) * (a + b);
          }
        } else if (operationType >= 5 && operationType <= 7) {
          final equationType = random.nextInt(8);

          if (equationType == 0) {
            final x = random.nextInt(50) + 1;
            final a = random.nextInt(70) + 1;
            final b = x + a;
            question = 'x + $a = $b';
            correctAnswer = x;
          } else if (equationType == 1) {
            final x = random.nextInt(50) + 30;
            final a = random.nextInt(25) + 1;
            final b = x - a;
            question = 'x - $a = $b';
            correctAnswer = x;
          } else if (equationType == 2) {
            final x = random.nextInt(50) + 1;
            final a = random.nextInt(70) + 1;
            final b = a + x;
            question = '$a + x = $b';
            correctAnswer = x;
          } else if (equationType == 3) {
            final a = random.nextInt(50) + 30;
            final x = random.nextInt(25) + 1;
            final b = a - x;
            question = '$a - x = $b';
            correctAnswer = x;
          } else if (equationType == 4) {
            final x = random.nextInt(12) + 2;
            final a = random.nextInt(10) + 2;
            final b = a * x;
            question = '$a × x = $b';
            correctAnswer = x;
          } else if (equationType == 5) {
            final x = random.nextInt(12) + 2;
            final a = random.nextInt(10) + 2;
            final b = x * a;
            question = 'x × $a = $b';
            correctAnswer = x;
          } else if (equationType == 6) {
            final a = random.nextInt(10) + 2;
            final b = random.nextInt(15) + 2;
            final x = a * b;
            question = 'x ÷ $a = $b';
            correctAnswer = x;
          } else {
            final x = random.nextInt(40) + 5;
            final a = random.nextInt(30) + 5;
            final b = x + a;
            question = '(x + $a) = $b';
            correctAnswer = x;
          }
        } else {
          // ÇÖZÜM: Hata çıkaran durumlar tamamen KESİLDİ ve ATILDI.
          // Sadece %100 RangeError vermeyecek 6 basit kombinasyon bırakıldı.
          final comboType = random.nextInt(6);

          if (comboType == 0) {
            final a = random.nextInt(12) + 2;
            final b = random.nextInt(12) + 2;
            final c = random.nextInt(50) + 10;
            question = '$a × $b + $c';
            correctAnswer = (a * b) + c;
          } else if (comboType == 1) {
            final a = random.nextInt(12) + 3;
            final b = random.nextInt(12) + 3;
            final c = random.nextInt(30) + 5;
            question = '$a × $b - $c';
            correctAnswer = (a * b) - c;
          } else if (comboType == 2) {
            final a = random.nextInt(15) + 5;
            final b = random.nextInt(15) + 5;
            final c = random.nextInt(15) + 10;
            final d = random.nextInt(8) + 2;
            question = '($a + $b) × ($c - $d)';
            correctAnswer = (a + b) * (c - d);
          } else if (comboType == 3) {
            final a = random.nextInt(50) + 10;
            final b = random.nextInt(10) + 2;
            final c = random.nextInt(10) + 2;
            question = '$a + $b × $c';
            correctAnswer = a + (b * c);
          } else if (comboType == 4) {
            final b = random.nextInt(8) + 2;
            final c = random.nextInt(8) + 2;
            final product = b * c;
            final a = product + random.nextInt(50) + 20;
            question = '$a - $b × $c';
            correctAnswer = a - (b * c);
          } else {
            final a = random.nextInt(8) + 2;
            final b = random.nextInt(10) + 2;
            final c = random.nextInt(10) + 2;
            question = '$a² + $b × $c';
            correctAnswer = (a * a) + (b * c);
          }
        }

        final wrongAnswers = <String>{};
        int attempts = 0;

        while (wrongAnswers.length < 3) {
          attempts++;
          int wrongAnswer;

          if (attempts < 20) {
            if (correctAnswer < 10) {
              wrongAnswer = correctAnswer + random.nextInt(10) - 4;
            } else if (correctAnswer < 100) {
              wrongAnswer = correctAnswer + random.nextInt(20) - 10;
            } else {
              wrongAnswer = correctAnswer + random.nextInt(40) - 20;
            }
          } else {
            wrongAnswer = correctAnswer + attempts;
          }

          if (wrongAnswer > 0 && wrongAnswer != correctAnswer) {
            wrongAnswers.add(wrongAnswer.toString());
          }
        }

        final allOptions = [correctAnswer.toString(), ...wrongAnswers];
        allOptions.shuffle(random);
        final correctIndex = allOptions.indexOf(correctAnswer.toString());

        questions.add(GameQuestion(
          displayText: question,
          isCorrect: true,
          options: allOptions,
          correctAnswerIndex: correctIndex,
        ));

      } catch (e) {
        // En kötü senaryoda güvenlik ağı (Fail-safe)
        final a = random.nextInt(15) + 5;
        final b = random.nextInt(15) + 5;
        final ans = a + b;

        final options = [
          ans.toString(),
          (ans + 2).toString(),
          (ans + 5).toString(),
          (ans > 2 ? ans - 2 : ans + 7).toString()
        ]..shuffle(random);

        questions.add(GameQuestion(
          displayText: '$a + $b',
          isCorrect: true,
          options: options,
          correctAnswerIndex: options.indexOf(ans.toString()),
        ));
      }
    }

    return questions;
  }


  static List<int> _getFactors(int number) {
    final factors = <int>[];
    for (int i = 2; i <= number / 2; i++) {
      if (number % i == 0) {
        factors.add(i);
      }
    }
    return factors;
  }
}