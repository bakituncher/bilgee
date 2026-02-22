import 'dart:async';
import 'package:flutter/material.dart';
import '../models/game_config.dart';
import '../services/game_service.dart';
import '../widgets/answer_button.dart';
import '../widgets/game_result_dialog.dart';

class GameScreen extends StatefulWidget {
  final GameConfig config;

  const GameScreen({super.key, required this.config});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  int _score = 0;
  int _currentIndex = 0;
  bool _answered = false;
  String? _selected;
  bool _loading = true;
  List<GameQuestion> _questions = [];

  int _remainingSeconds = 90;
  Timer? _timer;
  bool _gameOver = false;

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadQuestions() async {
    setState(() => _loading = true);
    final questions = await GameService.loadQuestions(widget.config, count: 100);
    setState(() {
      _questions = questions;
      _loading = false;
    });
    _startTimer();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        setState(() {
          _remainingSeconds--;
        });
      } else {
        _timer?.cancel();
        if (!_gameOver) {
          _gameOver = true;
          _showResult();
        }
      }
    });
  }

  void _check(bool userAnswer) {
    if (_answered || _gameOver) return;
    final isCorrect = _questions[_currentIndex].isCorrect;
    final correct = (userAnswer == isCorrect);

    setState(() {
      _answered = true;
      _selected = userAnswer ? 'doğru' : 'yanlış';
      if (correct) {
        _score += 10;
        _remainingSeconds += 3; // Doğru cevap +3 saniye
      } else {
        _remainingSeconds -= 3; // Yanlış cevap -3 saniye
        if (_remainingSeconds < 0) _remainingSeconds = 0;
      }
    });

    Future.delayed(const Duration(milliseconds: 800), () {
      if (!mounted || _gameOver) return;
      if (_currentIndex < _questions.length - 1 && _remainingSeconds > 0) {
        setState(() {
          _currentIndex++;
          _answered = false;
          _selected = null;
        });
      } else if (_remainingSeconds <= 0) {
        _timer?.cancel();
        _gameOver = true;
        _showResult();
      }
    });
  }

  void _showResult() {
    _timer?.cancel();
    GameResultDialog.show(
      context: context,
      score: _score,
      totalQuestions: _currentIndex + 1,
      onRetry: () {
        setState(() {
          _score = 0;
          _currentIndex = 0;
          _answered = false;
          _selected = null;
          _remainingSeconds = 90;
          _gameOver = false;
        });
        _loadQuestions();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_loading) {
      return Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              // Üst Bar - Sadece Kapat Butonu
              Align(
                alignment: Alignment.topLeft,
                child: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      Text(widget.config.title, style: theme.textTheme.titleLarge),
                      const SizedBox(height: 8),
                      const Text('Sorular yükleniyor...'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_questions.isEmpty) {
      return Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              // Üst Bar - Sadece Kapat Butonu
              Align(
                alignment: Alignment.topLeft,
                child: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 64),
                      const SizedBox(height: 16),
                      Text('Sorular yüklenemedi', style: theme.textTheme.titleLarge),
                      const SizedBox(height: 8),
                      Text('Lütfen daha sonra tekrar deneyin', style: theme.textTheme.bodyMedium),
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Geri Dön'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final question = _questions[_currentIndex];

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Üst Bar - Süre ve Skor
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Row(
                    children: [
                      Icon(
                        Icons.timer_outlined,
                        size: 24,
                        color: _remainingSeconds <= 10 ? Colors.red : null,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$_remainingSeconds"',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: _remainingSeconds <= 10 ? Colors.red : null,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$_score',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              const Spacer(),

              Text(widget.config.question, style: theme.textTheme.titleMedium),
              const SizedBox(height: 24),

              // Soru Kartı
              Card(
                key: ValueKey(_currentIndex),
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: question.secondaryText != null
                      ? Column(
                          children: [
                            Text(
                              question.displayText,
                              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            const Icon(Icons.arrow_downward_rounded, size: 24),
                            const SizedBox(height: 16),
                            Text(
                              question.secondaryText!,
                              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        )
                      : Text(
                          question.displayText,
                          style: theme.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                ),
              ),

              const Spacer(),

              // Doğru/Yanlış Butonları (Doğru üstte, Yanlış altta)
              Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: AnswerButton(
                      label: 'DOĞRU',
                      icon: Icons.check_rounded,
                      color: Colors.green,
                      isSelected: _answered && _selected == 'doğru',
                      isCorrectAnswer: _answered && question.isCorrect,
                      isWrongAnswer: _answered && !question.isCorrect && _selected == 'doğru',
                      onTap: _answered ? null : () => _check(true),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: AnswerButton(
                      label: 'YANLIŞ',
                      icon: Icons.close_rounded,
                      color: Colors.red,
                      isSelected: _answered && _selected == 'yanlış',
                      isCorrectAnswer: _answered && !question.isCorrect,
                      isWrongAnswer: _answered && question.isCorrect && _selected == 'yanlış',
                      onTap: _answered ? null : () => _check(false),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

