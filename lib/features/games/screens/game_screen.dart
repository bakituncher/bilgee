import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../models/game_config.dart';
import '../services/game_service.dart';
import '../widgets/answer_button.dart';
import '../widgets/game_result_dialog.dart';
import '../../../data/providers/firestore_providers.dart';
import '../../../shared/providers/avatar_svg_provider.dart';

class GameScreen extends ConsumerStatefulWidget {
  final GameConfig config;

  const GameScreen({super.key, required this.config});

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen> {
  int _score = 0;
  int _currentIndex = 0;
  bool _answered = false;
  String? _selected;
  bool _loading = true;
  List<GameQuestion> _questions = [];

  int _remainingSeconds = 89;
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

    try {
      final questions = await GameService.loadQuestions(widget.config, count: 100);

      if (!mounted) return;

      setState(() {
        _questions = questions;
        _loading = false;
      });
      _startTimer();
    } catch (e) {
      // ÇÖZÜM: Arka planda sessiz bir çökme olursa yükleme ekranında asılı kalmasını engeller.
      print("Sorular yüklenirken bir hata oluştu: $e");
      if (!mounted) return;
      setState(() {
        _questions = [];
        _loading = false;
      });
    }
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
          _remainingSeconds = 89;
          _gameOver = false;
        });
        _loadQuestions();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: const Color(0xFF3B8E79),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: const Center(child: Text("Sorular yüklenemedi!")),
      );
    }

    final question = _questions[_currentIndex];

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF3B8E79),
              Color(0xFF343B71),
            ],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _buildTopBar(),
              const SizedBox(height: 16),
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: Color(0xFF3A2393),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24.0, 24.0, 24.0, 16.0),
                    child: Column(
                      children: [
                        _buildCardHeader(),
                        const SizedBox(height: 16),
                        Expanded(
                          flex: 4,
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                return SizedBox(
                                  width: constraints.maxWidth,
                                  height: constraints.maxHeight,
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: SizedBox(
                                      width: constraints.maxWidth,
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          if (question.questionFormat != null) ...[
                                            Text(
                                              question.questionFormat == QuestionFormat.authorToWork
                                                  ? 'Aşağıdakilerin hangisi\n${question.displayText}\nadlı yazarın eseridir?'
                                                  : '${question.displayText}\nadlı eserin yazarı kimdir?',
                                              style: const TextStyle(
                                                color: Color(0xFF1E1147),
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                          ],
                                          if (question.questionFormat == null)
                                            Text(
                                              question.displayText,
                                              style: const TextStyle(
                                                color: Color(0xFF1E1147),
                                                fontSize: 22,
                                                fontWeight: FontWeight.bold,
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Expanded(
                          flex: 6,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: widget.config.format == GameFormat.trueFalse
                                ? _buildTrueFalseButtons(question)
                                : _buildMultipleChoiceButtons(question),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildTrueFalseButtons(GameQuestion question) {
    return [
      SizedBox(
        width: double.infinity,
        child: AnswerButton(
          label: 'Doğru',
          isSelected: _answered && _selected == 'doğru',
          isCorrectAnswer: _answered && question.isCorrect,
          isWrongAnswer: _answered && !question.isCorrect && _selected == 'doğru',
          onTap: _answered ? null : () => _checkTrueFalse(true),
          isBigButton: true,
        ),
      ),
      const SizedBox(height: 24),
      SizedBox(
        width: double.infinity,
        child: AnswerButton(
          label: 'Yanlış',
          isSelected: _answered && _selected == 'yanlış',
          isCorrectAnswer: _answered && !question.isCorrect,
          isWrongAnswer: _answered && question.isCorrect && _selected == 'yanlış',
          onTap: _answered ? null : () => _checkTrueFalse(false),
          isBigButton: true,
        ),
      ),
    ];
  }

  List<Widget> _buildMultipleChoiceButtons(GameQuestion question) {
    if (question.options == null || question.correctAnswerIndex == null) {
      return [const Text('Seçenekler yüklenemedi', style: TextStyle(color: Colors.white))];
    }

    return [
      for (int i = 0; i < question.options!.length; i++) ...[
        SizedBox(
          width: double.infinity,
          child: AnswerButton(
            label: question.options![i],
            isSelected: _answered && _selected == i.toString(),
            isCorrectAnswer: _answered && i == question.correctAnswerIndex,
            isWrongAnswer: _answered && i != question.correctAnswerIndex && _selected == i.toString(),
            onTap: _answered ? null : () => _checkMultipleChoice(i),
          ),
        ),
        if (i < question.options!.length - 1) const SizedBox(height: 18),
      ],
    ];
  }

  void _checkTrueFalse(bool userAnswer) {
    if (_answered || _gameOver) return;
    final isCorrect = _questions[_currentIndex].isCorrect;
    final correct = (userAnswer == isCorrect);

    setState(() {
      _answered = true;
      _selected = userAnswer ? 'doğru' : 'yanlış';
      if (correct) {
        _score += 10;
        _remainingSeconds += 3;
      } else {
        _remainingSeconds -= 3;
        if (_remainingSeconds < 0) _remainingSeconds = 0;
      }
    });

    _handleNextQuestion();
  }

  void _checkMultipleChoice(int selectedIndex) {
    if (_answered || _gameOver) return;
    final question = _questions[_currentIndex];
    final correct = (selectedIndex == question.correctAnswerIndex);

    setState(() {
      _answered = true;
      _selected = selectedIndex.toString();
      if (correct) {
        _score += 10;
        _remainingSeconds += 3;
      } else {
        _remainingSeconds -= 3;
        if (_remainingSeconds < 0) _remainingSeconds = 0;
      }
    });

    _handleNextQuestion();
  }

  void _handleNextQuestion() {
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
      } else {
        _timer?.cancel();
        _gameOver = true;
        _showResult();
      }
    });
  }

  String? _avatarUrl(String? style, String? seed) {
    if (style == null || seed == null) return null;
    final s = style.trim();
    final sd = Uri.encodeComponent(seed);
    return 'https://api.dicebear.com/9.x/$s/svg?seed=$sd';
  }

  Widget _buildTopBar() {
    final userAsync = ref.watch(userProfileProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(
                Icons.arrow_back,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
          userAsync.when(
            data: (user) {
              if (user == null) {
                return Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFBCAAA4), width: 3),
                  ),
                  child: const CircleAvatar(
                    radius: 28,
                    backgroundColor: Colors.white,
                    child: Icon(Icons.person, size: 40, color: Colors.grey),
                  ),
                );
              }

              final avatarUrl = _avatarUrl(user.avatarStyle, user.avatarSeed);

              return Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFBCAAA4), width: 3),
                ),
                child: CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.white,
                  child: ClipOval(
                    child: (avatarUrl != null)
                        ? ref.watch(avatarSvgProvider(avatarUrl)).when(
                      data: (svg) => SvgPicture.string(
                        svg,
                        fit: BoxFit.cover,
                        width: 56,
                        height: 56,
                      ),
                      loading: () => const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 1.5),
                      ),
                      error: (_, __) => const Icon(
                        Icons.person,
                        size: 40,
                        color: Colors.grey,
                      ),
                    )
                        : const Icon(Icons.person, size: 40, color: Colors.grey),
                  ),
                ),
              );
            },
            loading: () => Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFBCAAA4), width: 3),
              ),
              child: const CircleAvatar(
                radius: 28,
                backgroundColor: Colors.white,
                child: SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 1.5),
                ),
              ),
            ),
            error: (_, __) => Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFBCAAA4), width: 3),
              ),
              child: const CircleAvatar(
                radius: 28,
                backgroundColor: Colors.white,
                child: Icon(Icons.person, size: 40, color: Colors.grey),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white, width: 2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              '${_currentIndex + 1}.',
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        SizedBox(
          width: 44,
          height: 44,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 44,
                height: 44,
                child: CircularProgressIndicator(
                  value: _remainingSeconds / 89,
                  strokeWidth: 2.5,
                  backgroundColor: Colors.white.withValues(alpha: 0.3),
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              Text(
                '$_remainingSeconds',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}