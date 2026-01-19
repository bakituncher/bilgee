// lib/features/onboarding/widgets/interactive_demo_widget.dart

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:taktik/utils/subject_utils.dart';

class InteractiveDemoWidget extends StatefulWidget {
  final VoidCallback onContinue;

  const InteractiveDemoWidget({
    super.key,
    required this.onContinue,
  });

  @override
  State<InteractiveDemoWidget> createState() => _InteractiveDemoWidgetState();
}

class _InteractiveDemoWidgetState extends State<InteractiveDemoWidget>
    with TickerProviderStateMixin {
  int _currentDemo = 0;
  bool _isAnswered = false;
  int? _selectedAnswer;
  late AnimationController _confettiController;

  final List<DemoQuestion> _demoQuestions = [
    DemoQuestion(
      question: "Matematik: 2x + 5 = 11 denkleminde x kaçtır?",
      options: ["x = 2", "x = 3", "x = 4", "x = 8"],
      correctAnswer: 1,
      explanation: "2x + 5 = 11\n2x = 11 - 5\n2x = 6\nx = 3",
      subject: "Matematik",
    ),
    DemoQuestion(
      question: "Tarih: Osmanlı İmparatorluğu hangi yılda kurulmuştur?",
      options: ["1299", "1326", "1453", "1389"],
      correctAnswer: 0,
      explanation: "Osmanlı İmparatorluğu 1299 yılında Osman Gazi tarafından kurulmuştur.",
      subject: "Tarih",
    ),
    DemoQuestion(
      question: "Fizik: Serbest düşen bir cismin ivmesi nedir?",
      options: ["9.8 m/s²", "10 m/s²", "8.9 m/s²", "9.81 m/s²"],
      correctAnswer: 3,
      explanation: "Dünya'da yerçekimi ivmesi yaklaşık 9.81 m/s²'dir.",
      subject: "Fizik",
    ),
  ];

  @override
  void initState() {
    super.initState();
    _confettiController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  void _selectAnswer(int index) {
    if (_isAnswered) return;

    setState(() {
      _selectedAnswer = index;
      _isAnswered = true;
    });

    if (index == _demoQuestions[_currentDemo].correctAnswer) {
      _confettiController.forward();
    }
  }

  void _nextQuestion() {
    if (_currentDemo < _demoQuestions.length - 1) {
      setState(() {
        _currentDemo++;
        _isAnswered = false;
        _selectedAnswer = null;
      });
      _confettiController.reset();
    } else {
      widget.onContinue();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final question = _demoQuestions[_currentDemo];

    return Stack(
      children: [
        Column(
          children: [
            // Başlık
            Container(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Text(
                    'Hadi Deneyelim! 🚀',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                    textAlign: TextAlign.center,
                  )
                  .animate()
                  .fadeIn(duration: 800.ms)
                  .slideY(begin: -0.2, end: 0),

                  const SizedBox(height: 16),

                  Text(
                    'Birkaç örnek soru ile uygulamayı keşfedelim',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.7),
                    ),
                    textAlign: TextAlign.center,
                  )
                  .animate(delay: 300.ms)
                  .fadeIn(duration: 800.ms),

                  const SizedBox(height: 16),

                  // İlerleme göstergesi
                  LinearProgressIndicator(
                    value: (_currentDemo + 1) / _demoQuestions.length,
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
                  )
                  .animate(delay: 500.ms)
                  .fadeIn(duration: 800.ms),
                ],
              ),
            ),

            // Soru kartı
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                child: Card(
                  elevation: 8,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          theme.colorScheme.surface,
                          SubjectUtils.getSubjectColor(question.subject).withOpacity(0.1),
                        ],
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Konu etiketi
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: SubjectUtils.getSubjectColor(question.subject),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            question.subject,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        )
                        .animate()
                        .fadeIn(duration: 600.ms)
                        .slideX(begin: -0.3, end: 0),

                        const SizedBox(height: 20),

                        // Soru metni
                        Text(
                          question.question,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                            height: 1.4,
                          ),
                        )
                        .animate(delay: 200.ms)
                        .fadeIn(duration: 800.ms)
                        .slideY(begin: 0.2, end: 0),

                        const SizedBox(height: 24),

                        // Seçenekler
                        Expanded(
                          child: ListView.builder(
                            itemCount: question.options.length,
                            itemBuilder: (context, index) {
                              return _buildOptionCard(question, index, theme);
                            },
                          ),
                        ),

                        // Açıklama (cevap verildikten sonra)
                        if (_isAnswered) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: _selectedAnswer == question.correctAnswer
                                  ? Colors.green.withOpacity(0.1)
                                  : Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _selectedAnswer == question.correctAnswer
                                    ? Colors.green
                                    : Colors.red,
                                width: 1,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      _selectedAnswer == question.correctAnswer
                                          ? Icons.check_circle
                                          : Icons.cancel,
                                      color: _selectedAnswer == question.correctAnswer
                                          ? Colors.green
                                          : Colors.red,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      _selectedAnswer == question.correctAnswer
                                          ? 'Doğru cevap! 🎉'
                                          : 'Yanlış cevap 😔',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: _selectedAnswer == question.correctAnswer
                                            ? Colors.green
                                            : Colors.red,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  question.explanation,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          )
                          .animate()
                          .fadeIn(duration: 600.ms)
                          .slideY(begin: 0.3, end: 0),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Alt buton
            Container(
              padding: const EdgeInsets.all(24),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isAnswered ? _nextQuestion : null,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    disabledBackgroundColor: theme.colorScheme.surfaceContainerHighest,
                  ),
                  child: Text(
                    _currentDemo < _demoQuestions.length - 1
                        ? 'Sonraki Soru'
                        : 'Demo Tamamlandı',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),

        // Konfeti animasyonu
        if (_selectedAnswer == _demoQuestions[_currentDemo].correctAnswer && _isAnswered)
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _confettiController,
                builder: (context, child) {
                  return CustomPaint(
                    painter: ConfettiPainter(_confettiController.value),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildOptionCard(DemoQuestion question, int index, ThemeData theme) {
    final isSelected = _selectedAnswer == index;
    final isCorrect = index == question.correctAnswer;
    final isWrong = _isAnswered && isSelected && !isCorrect;

    Color cardColor;
    if (!_isAnswered) {
      cardColor = theme.colorScheme.surface;
    } else if (isCorrect) {
      cardColor = Colors.green.withOpacity(0.1);
    } else if (isWrong) {
      cardColor = Colors.red.withOpacity(0.1);
    } else {
      cardColor = theme.colorScheme.surfaceContainerHighest;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _selectAnswer(index),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? (isCorrect ? Colors.green : Colors.red)
                  : theme.colorScheme.outline.withOpacity(0.2),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected
                      ? (isCorrect ? Colors.green : Colors.red)
                      : theme.colorScheme.outline.withOpacity(0.3),
                ),
                child: Center(
                  child: Text(
                    String.fromCharCode(65 + index), // A, B, C, D
                    style: TextStyle(
                      color: isSelected ? Colors.white : theme.colorScheme.onSurface,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  question.options[index],
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
              if (_isAnswered && isCorrect)
                const Icon(
                  Icons.check_circle,
                  color: Colors.green,
                ),
              if (_isAnswered && isWrong)
                const Icon(
                  Icons.cancel,
                  color: Colors.red,
                ),
            ],
          ),
        ),
      ),
    )
    .animate(delay: Duration(milliseconds: 400 + (index * 100)))
    .fadeIn(duration: 600.ms)
    .slideX(begin: 0.3, end: 0);
  }
}

class DemoQuestion {
  final String question;
  final List<String> options;
  final int correctAnswer;
  final String explanation;
  final String subject;

  DemoQuestion({
    required this.question,
    required this.options,
    required this.correctAnswer,
    required this.explanation,
    required this.subject,
  });
}

class ConfettiPainter extends CustomPainter {
  final double progress;

  ConfettiPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    final random = DateTime.now().millisecondsSinceEpoch;

    for (int i = 0; i < 50; i++) {
      final x = (random + i * 123) % size.width.toInt();
      final y = (progress * size.height + (random + i * 456) % 100 - 50);

      paint.color = [
        Colors.red,
        Colors.blue,
        Colors.yellow,
        Colors.green,
        Colors.purple,
        Colors.orange,
      ][i % 6];

      canvas.drawCircle(
        Offset(x.toDouble(), y),
        3,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
