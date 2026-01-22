// lib/features/weakness_workshop/widgets/quiz_view.dart
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:lottie/lottie.dart';
import 'package:taktik/features/weakness_workshop/models/workshop_model.dart';
import 'package:taktik/shared/widgets/markdown_with_math.dart';
import 'package:taktik/features/weakness_workshop/widgets/quiz_swipe_hint.dart';

class QuizView extends StatefulWidget {
  final WorkshopModel material;
  final VoidCallback onSubmit;
  final Map<int, int> selectedAnswers;
  final Function(int, int) onAnswerSelected;
  final void Function(int questionIndex) onReportIssue;
  final ValueChanged<int>? onPageChanged;

  const QuizView({
    super.key,
    required this.material,
    required this.onSubmit,
    required this.selectedAnswers,
    required this.onAnswerSelected,
    required this.onReportIssue,
    this.onPageChanged,
  });

  @override
  State<QuizView> createState() => _QuizViewState();
}

class _QuizViewState extends State<QuizView> {
  late PageController _pageController;
  int _currentPage = 0;
  bool _showHint = false;
  final Set<int> _shownAnimations = {};

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _checkAndShowHint();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onPageChanged?.call(_currentPage);
    });

    _pageController.addListener(() {
      final page = _pageController.page;
      if (page == null) return;
      final rounded = page.round();
      if (rounded != _currentPage) {
        setState(() {
          _currentPage = rounded;
        });
        widget.onPageChanged?.call(_currentPage);
      }
    });
  }

  Future<void> _checkAndShowHint() async {
    final shouldShow = await QuizSwipeHint.shouldShow();
    if (shouldShow && mounted) {
      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) {
        setState(() {
          _showHint = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.material.quiz == null || widget.material.quiz!.isEmpty) {
      return const Center(child: Text('Quiz bulunamadı'));
    }

    final quizLength = widget.material.quiz!.length;

    return Stack(
      children: [
        Column(
          children: [
            // İlerleme Çubuğu
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
              child: Row(
                children: List.generate(quizLength, (index) {
                  return Expanded(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      height: 3,
                      decoration: BoxDecoration(
                        color: index <= _currentPage
                            ? Theme.of(context).colorScheme.onSurface
                            : Theme.of(context).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  );
                }),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                scrollDirection: Axis.vertical,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: quizLength,
                itemBuilder: (context, index) {
                  final question = widget.material.quiz![index];
                  final isCorrect = widget.selectedAnswers[index] == question.correctOptionIndex;
                  final alreadyShown = _shownAnimations.contains(index);
                  final shouldPlay = isCorrect && !alreadyShown;

                  return QuestionCard(
                    question: question,
                    questionNumber: index + 1,
                    totalQuestions: quizLength,
                    selectedOptionIndex: widget.selectedAnswers[index],
                    shouldPlayAnimation: shouldPlay,
                    onOptionSelected: (optionIndex) {
                      if (!widget.selectedAnswers.containsKey(index)) {
                        widget.onAnswerSelected(index, optionIndex);
                      }
                    },
                    onReportIssue: () => widget.onReportIssue(index),
                    onSwipeUp: () {
                      if (_currentPage < quizLength - 1) {
                        _pageController.animateToPage(
                          _currentPage + 1,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      }
                    },
                    onSwipeDown: () {
                      if (_currentPage > 0) {
                        _pageController.animateToPage(
                          _currentPage - 1,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      }
                    },
                    onSubmit: widget.onSubmit,
                    onAnimationShown: () {
                      _shownAnimations.add(index);
                    },
                  );
                },
              ),
            ),
          ],
        ),
        if (_showHint)
          QuizSwipeHint(
            onDismiss: () {
              setState(() {
                _showHint = false;
              });
            },
          ),
      ],
    );
  }
}

class QuestionCard extends StatefulWidget {
  final QuizQuestion question;
  final int questionNumber;
  final int totalQuestions;
  final int? selectedOptionIndex;
  final bool shouldPlayAnimation;
  final VoidCallback? onAnimationShown;
  final Function(int) onOptionSelected;
  final void Function()? onReportIssue;
  final VoidCallback? onSwipeUp;
  final VoidCallback? onSwipeDown;
  final VoidCallback? onSubmit;

  const QuestionCard({
    super.key,
    required this.question,
    required this.questionNumber,
    required this.totalQuestions,
    required this.selectedOptionIndex,
    required this.onOptionSelected,
    required this.onReportIssue,
    this.shouldPlayAnimation = false,
    this.onAnimationShown,
    this.onSwipeUp,
    this.onSwipeDown,
    this.onSubmit,
  });

  @override
  State<QuestionCard> createState() => _QuestionCardState();
}

class _QuestionCardState extends State<QuestionCard> {
  final ScrollController _scrollController = ScrollController();
  bool _isAtTop = true;
  bool _isAtBottom = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkScrollPosition();
      _checkAnimationStatus();
    });
  }

  @override
  void didUpdateWidget(QuestionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.shouldPlayAnimation && !oldWidget.shouldPlayAnimation) {
      _checkAnimationStatus();
    }
  }

  void _checkAnimationStatus() {
    if (widget.shouldPlayAnimation) {
      widget.onAnimationShown?.call();
    }
  }

  void _onScroll() {
    _checkScrollPosition();
  }

  void _checkScrollPosition() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    setState(() {
      _isAtTop = pos.pixels <= 0;
      _isAtBottom = pos.pixels >= pos.maxScrollExtent - 10;
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      // 1. SizedBox.expand ile kartın her zaman tüm alanı kaplamasını sağlıyoruz.
      child: Stack(
        children: [
          NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              if (notification is ScrollUpdateNotification) {
                _checkScrollPosition();
              }
              // Sınırda daha fazla çekme (Overscroll) durumunda sayfa değiştir
              if (notification is OverscrollNotification) {
                // Scroll view'ın içeriği kısa olsa bile AlwaysScrollableScrollPhysics
                // sayesinde overscroll tetiklenir.
                if (notification.overscroll > 5) {
                  // Aşağıdan yukarı çekme (Next Question)
                  // Eğer içerik kısaysa _isAtBottom zaten true'dur.
                  widget.onSwipeUp?.call();
                } else if (notification.overscroll < -5) {
                  // Yukarıdan aşağı çekme (Prev Question)
                  // Eğer içerik kısaysa _isAtTop zaten true'dur.
                  widget.onSwipeDown?.call();
                }
              }
              return false;
            },
            child: LayoutBuilder(
              // 2. LayoutBuilder ile ebeveynin (ekranın) boyutlarını alıyoruz.
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    controller: _scrollController,
                    // 3. AlwaysScrollableScrollPhysics: İçerik kısa olsa bile scroll
                    // efektinin ve overscroll'un çalışmasını sağlar.
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: ConstrainedBox(
                      // 4. ConstrainedBox: İçeriğin minimum yüksekliğini ekran yüksekliğine eşitler.
                      // Böylece boş alana tıklayıp sürüklediğinizde de scroll view bunu algılar.
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          // MainAxisAlignment.start kullanarak içeriği yukarı yaslıyoruz,
                          // ama ConstrainedBox sayesinde tüm alan "tıklanabilir/kaydırılabilir" oluyor.
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            const SizedBox(height: 2),
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.surface,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2),
                                  width: 1.5,
                                ),
                              ),
                              child: MarkdownWithMath(
                                data: widget.question.question,
                                styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                                  p: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            ...List.generate(widget.question.options.length, (index) {
                              bool isSelected = widget.selectedOptionIndex == index;
                              bool isCorrect = widget.question.correctOptionIndex == index;
                              Color? tileColor;
                              Color? borderColor;
                              Color? letterBgColor;
                              Color? letterTextColor;
                              final colorScheme = Theme.of(context).colorScheme;
                              const greenColor = Color(0xFF4CAF50);
                              const redColor = Color(0xFFE53935);

                              if (widget.selectedOptionIndex != null) {
                                if (isSelected) {
                                  if (isCorrect) {
                                    tileColor = greenColor.withValues(alpha: 0.1);
                                    borderColor = greenColor;
                                    letterBgColor = greenColor;
                                    letterTextColor = Colors.white;
                                  } else {
                                    tileColor = redColor.withValues(alpha: 0.1);
                                    borderColor = redColor;
                                    letterBgColor = redColor;
                                    letterTextColor = Colors.white;
                                  }
                                } else if (isCorrect) {
                                  tileColor = greenColor.withValues(alpha: 0.1);
                                  borderColor = greenColor;
                                  letterBgColor = greenColor;
                                  letterTextColor = Colors.white;
                                } else {
                                  tileColor = colorScheme.surface;
                                  borderColor = colorScheme.onSurface.withValues(alpha: 0.2);
                                  letterBgColor = colorScheme.onSurface.withValues(alpha: 0.1);
                                  letterTextColor = colorScheme.onSurface.withValues(alpha: 0.6);
                                }
                              } else {
                                tileColor = colorScheme.surface;
                                borderColor = colorScheme.onSurface.withValues(alpha: 0.3);
                                letterBgColor = colorScheme.onSurface.withValues(alpha: 0.1);
                                letterTextColor = colorScheme.onSurface;
                              }

                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                decoration: BoxDecoration(
                                  color: tileColor,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: borderColor,
                                    width: 1.5,
                                  ),
                                ),
                                child: InkWell(
                                  onTap: widget.selectedOptionIndex == null ? () => widget.onOptionSelected(index) : null,
                                  borderRadius: BorderRadius.circular(12),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 30,
                                          height: 30,
                                          decoration: BoxDecoration(
                                            color: letterBgColor,
                                            shape: BoxShape.circle,
                                          ),
                                          child: Center(
                                            child: Text(
                                              String.fromCharCode(65 + index),
                                              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                                color: letterTextColor,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: MarkdownWithMath(
                                            data: widget.question.options[index],
                                            styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                                              p: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                                fontSize: 14,
                                                height: 1.4,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }),
                            if (widget.selectedOptionIndex != null || widget.questionNumber == widget.totalQuestions)
                              Padding(
                                padding: const EdgeInsets.only(top: 16),
                                child: Row(
                                  children: [
                                    if (widget.selectedOptionIndex != null)
                                      OutlinedButton.icon(
                                        onPressed: () => _showExplanationBottomSheet(context),
                                        icon: const Icon(Icons.lightbulb_outline_rounded),
                                        label: const FittedBox(child: Text("Açıklamayı Gör")),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: const Color(0xFFFF9800),
                                          side: const BorderSide(color: Color(0xFFFF9800), width: 1.5),
                                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                        ),
                                      ).animate().fadeIn(delay: 150.ms).slideY(begin: 0.2),
                                    const Spacer(),
                                    if (widget.questionNumber == widget.totalQuestions)
                                      OutlinedButton.icon(
                                        onPressed: widget.onSubmit,
                                        icon: const Icon(Icons.assignment_turned_in_rounded),
                                        label: const FittedBox(child: Text("Sonuçları Gör")),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: Theme.of(context).colorScheme.onSurface,
                                          backgroundColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
                                          side: BorderSide.none,
                                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                        ),
                                      ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2),
                                  ],
                                ),
                              ),
                            // Alt kısımda ekstra boşluk bırakarak scroll alanını garantile
                            const SizedBox(height: 50),
                          ],
                        ),
                      ),
                    ),
                  );
                }
            ),
          ),
          if (widget.shouldPlayAnimation)
            Center(
              child: IgnorePointer(
                child: Lottie.asset(
                  'assets/lotties/firework.json',
                  repeat: false,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showExplanationBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          bottom: true,
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(Icons.lightbulb_rounded, color: Theme.of(context).colorScheme.onSurface, size: 28),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              "Soru ${widget.questionNumber}",
                              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ),
                          IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Text("Soru", style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: MarkdownWithMath(data: widget.question.question, styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context))),
                      ),
                      const SizedBox(height: 24),
                      Text("Doğru Cevap", style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3), width: 2),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(color: Theme.of(context).colorScheme.onSurface, shape: BoxShape.circle),
                              child: Center(
                                child: Text(
                                  String.fromCharCode(65 + widget.question.correctOptionIndex),
                                  style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Theme.of(context).colorScheme.surface, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(child: MarkdownWithMath(data: widget.question.options[widget.question.correctOptionIndex], styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)))),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      ExplanationCard(explanation: widget.question.explanation),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ExplanationCard extends StatelessWidget {
  final String explanation;
  const ExplanationCard({super.key, required this.explanation});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.onSurface.withValues(alpha: 0.2), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb_outline_rounded, color: colorScheme.onSurface, size: 20),
              const SizedBox(width: 8),
              Text("Açıklama", style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          MarkdownWithMath(
            data: explanation,
            styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
              p: TextStyle(color: colorScheme.onSurface, height: 1.5, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}

class QuizReviewView extends StatelessWidget {
  final WorkshopModel material;
  final Map<int, int> selectedAnswers;

  const QuizReviewView({super.key, required this.material, required this.selectedAnswers});

  @override
  Widget build(BuildContext context) {
    if (material.quiz == null || material.quiz!.isEmpty) {
      return const Center(child: Padding(padding: EdgeInsets.all(24.0), child: Text('Quiz oluşturulmadı.', textAlign: TextAlign.center)));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16.0),
      itemCount: material.quiz!.length,
      itemBuilder: (context, index) {
        final question = material.quiz![index];
        final userAnswer = selectedAnswers[index];
        final isCorrect = userAnswer == question.correctOptionIndex;

        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MarkdownWithMath(data: "Soru ${index + 1}: ${question.question}", styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(p: Theme.of(context).textTheme.titleLarge)),
                const SizedBox(height: 16),
                ...List.generate(question.options.length, (optIndex) {
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: MarkdownWithMath(
                      data: question.options[optIndex],
                      styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                        p: TextStyle(
                          color: optIndex == question.correctOptionIndex
                              ? Theme.of(context).colorScheme.onSurface
                              : (optIndex == userAnswer && !isCorrect ? const Color(0xFFE53935) : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
                        ),
                      ),
                    ),
                    leading: Icon(
                      optIndex == question.correctOptionIndex
                          ? Icons.check_circle_rounded
                          : (optIndex == userAnswer && !isCorrect ? Icons.cancel_rounded : Icons.radio_button_unchecked_rounded),
                      color: optIndex == question.correctOptionIndex
                          ? Theme.of(context).colorScheme.onSurface
                          : (optIndex == userAnswer && !isCorrect ? const Color(0xFFE53935) : Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                  );
                }),
                const Divider(height: 24),
                ExplanationCard(explanation: question.explanation)
              ],
            ),
          ),
        );
      },
    );
  }
}