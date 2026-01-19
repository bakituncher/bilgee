// lib/features/weakness_workshop/widgets/quiz_view.dart
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:taktik/features/weakness_workshop/models/workshop_model.dart';
import 'package:taktik/shared/widgets/markdown_with_math.dart';

/// Soru çözüm ekranı widget'ı
/// Quiz sorularını gösterir ve kullanıcının cevaplarını alır
class QuizView extends StatefulWidget {
  final WorkshopModel material;
  final VoidCallback onSubmit;
  final Map<int,int> selectedAnswers;
  final Function(int, int) onAnswerSelected;
  final void Function(int questionIndex) onReportIssue;

  const QuizView({
    super.key,
    required this.material,
    required this.onSubmit,
    required this.selectedAnswers,
    required this.onAnswerSelected,
    required this.onReportIssue
  });

  @override
  State<QuizView> createState() => _QuizViewState();
}

class _QuizViewState extends State<QuizView> {
  late PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _pageController.addListener(() {
      if(_pageController.page!.round() != _currentPage){
        setState(() {
          _currentPage = _pageController.page!.round();
        });
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Quiz yoksa boş widget döndür
    if (widget.material.quiz == null || widget.material.quiz!.isEmpty) {
      return const Center(child: Text('Quiz bulunamadı'));
    }

    final quizLength = widget.material.quiz!.length;
    bool isQuizFinished = widget.selectedAnswers.length == quizLength;

    return Column(
      children: [
        // Minimal progress bar - üstte küçük çizgiler
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
                        ? Theme.of(context).colorScheme.secondary
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
            scrollDirection: Axis.vertical, // DİKEY KAYDIRMA - Instagram Reels gibi
            physics: const BouncingScrollPhysics(),
            itemCount: quizLength,
            itemBuilder: (context, index) {
              final question = widget.material.quiz![index];
              return QuestionCard(
                question: question,
                questionNumber: index + 1,
                totalQuestions: quizLength,
                selectedOptionIndex: widget.selectedAnswers[index],
                onOptionSelected: (optionIndex) {
                  if(!widget.selectedAnswers.containsKey(index)){
                    widget.onAnswerSelected(index, optionIndex);
                  }
                },
                onReportIssue: () {
                  widget.onReportIssue(index);
                },
              );
            },
          ),
        ),
        if (isQuizFinished)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            child: SafeArea(
              top: false,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.assignment_turned_in_rounded, size: 20),
                label: const Text("Sonuçları Gör"),
                onPressed: widget.onSubmit,
              ),
            ),
          ).animate().fadeIn().slideY(begin: 0.5),
      ],
    );
  }
}

/// Tek bir soru kartı widget'ı
class QuestionCard extends StatefulWidget {
  final QuizQuestion question;
  final int questionNumber;
  final int totalQuestions;
  final int? selectedOptionIndex;
  final Function(int) onOptionSelected;
  final void Function()? onReportIssue;

  const QuestionCard({
    super.key,
    required this.question,
    required this.questionNumber,
    required this.totalQuestions,
    required this.selectedOptionIndex,
    required this.onOptionSelected,
    required this.onReportIssue,
  });

  @override
  State<QuestionCard> createState() => _QuestionCardState();
}

class _QuestionCardState extends State<QuestionCard> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Kompakt header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Text(
                    "${widget.questionNumber}/${widget.totalQuestions}",
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: widget.onReportIssue,
                  icon: const Icon(Icons.flag_outlined, size: 18),
                  tooltip: 'Sorunu Bildir',
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Soru kartı
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
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

            final colorScheme = Theme.of(context).colorScheme;

            if (widget.selectedOptionIndex != null) {
              if (isSelected) {
                tileColor = isCorrect ? colorScheme.secondary.withOpacity(0.2) : colorScheme.error.withOpacity(0.2);
                borderColor = isCorrect ? colorScheme.secondary : colorScheme.error;
              } else if (isCorrect) {
                tileColor = colorScheme.secondary.withOpacity(0.2);
                borderColor = colorScheme.secondary;
              }
            }

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: tileColor ?? colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: borderColor ?? colorScheme.surfaceContainerHighest.withOpacity(0.5),
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
                      // Şık harf ikonları
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: (borderColor ?? colorScheme.primary).withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            String.fromCharCode(65 + index), // A, B, C, D
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: borderColor ?? colorScheme.primary,
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

          // Yanlış cevap için "Açıklamayı Gör" butonu
          if (widget.selectedOptionIndex != null && widget.selectedOptionIndex != widget.question.correctOptionIndex)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: OutlinedButton.icon(
                onPressed: () {
                  _showExplanationBottomSheet(context);
                },
                icon: const Icon(Icons.lightbulb_outline_rounded),
                label: const Text("Açıklamayı Gör"),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.secondary,
                  side: BorderSide(
                    color: Theme.of(context).colorScheme.secondary,
                    width: 1.5,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ).animate().fadeIn(delay: 150.ms).slideY(begin: 0.2),
            ),
        ],
      ),
    );
  }

  // Açıklama detay sayfasını göster
  void _showExplanationBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Başlık
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.secondary.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.lightbulb_rounded,
                              color: Theme.of(context).colorScheme.secondary,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              "Soru ${widget.questionNumber}",
                              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Soru
                      Text(
                        "Soru",
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: MarkdownWithMath(
                          data: widget.question.question,
                          styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Doğru cevap
                      Text(
                        "Doğru Cevap",
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Theme.of(context).colorScheme.secondary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.secondary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Theme.of(context).colorScheme.secondary,
                            width: 2,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.secondary,
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  String.fromCharCode(65 + widget.question.correctOptionIndex),
                                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: MarkdownWithMath(
                                data: widget.question.options[widget.question.correctOptionIndex],
                                styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Açıklama
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

/// Soru açıklama kartı widget'ı
class ExplanationCard extends StatelessWidget {
  final String explanation;

  const ExplanationCard({super.key, required this.explanation});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.secondary.withOpacity(0.15),
            colorScheme.secondary.withOpacity(0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.secondary.withOpacity(0.4),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.secondary.withOpacity(0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Başlık satırı
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      colorScheme.secondary,
                      colorScheme.secondary.withOpacity(0.8),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: colorScheme.secondary.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.lightbulb_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.auto_awesome_rounded,
                          color: colorScheme.secondary,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          "Taktik Tavşan'ın Açıklaması",
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: colorScheme.secondary,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      "Doğru cevabın detayları",
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Ayırıcı çizgi
          Container(
            height: 2,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  colorScheme.secondary.withOpacity(0.5),
                  colorScheme.secondary.withOpacity(0.1),
                  colorScheme.secondary.withOpacity(0.5),
                ],
              ),
              borderRadius: BorderRadius.circular(1),
            ),
          ),

          const SizedBox(height: 14),

          // Açıklama metni
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colorScheme.surface.withOpacity(0.7),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
                width: 1,
              ),
            ),
            child: MarkdownWithMath(
              data: explanation,
              styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                p: TextStyle(
                  color: colorScheme.onSurface,
                  height: 1.5,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                strong: TextStyle(
                  color: colorScheme.secondary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Quiz gözden geçirme ekranı widget'ı
class QuizReviewView extends StatelessWidget {
  final WorkshopModel material;
  final Map<int, int> selectedAnswers;

  const QuizReviewView({
    super.key,
    required this.material,
    required this.selectedAnswers,
  });

  @override
  Widget build(BuildContext context) {
    // Quiz yoksa boş durum göster
    if (material.quiz == null || material.quiz!.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Text('Quiz oluşturulmadı.', textAlign: TextAlign.center),
        ),
      );
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
                MarkdownWithMath(
                  data: "Soru ${index + 1}: ${question.question}",
                  styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                    p: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
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
                              ? Theme.of(context).colorScheme.secondary
                              : (optIndex == userAnswer && !isCorrect
                                  ? Theme.of(context).colorScheme.error
                                  : Theme.of(context).colorScheme.onSurface),
                        ),
                      ),
                    ),
                    leading: Icon(
                      optIndex == question.correctOptionIndex
                          ? Icons.check_circle_rounded
                          : (optIndex == userAnswer && !isCorrect ? Icons.cancel_rounded : Icons.radio_button_unchecked_rounded),
                      color: optIndex == question.correctOptionIndex
                          ? Theme.of(context).colorScheme.secondary
                          : (optIndex == userAnswer && !isCorrect
                              ? Theme.of(context).colorScheme.error
                              : Theme.of(context).colorScheme.onSurfaceVariant),
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

