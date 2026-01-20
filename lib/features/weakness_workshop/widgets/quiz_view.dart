// lib/features/weakness_workshop/widgets/quiz_view.dart
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:taktik/features/weakness_workshop/models/workshop_model.dart';
import 'package:taktik/shared/widgets/markdown_with_math.dart';
import 'package:taktik/features/weakness_workshop/widgets/quiz_swipe_hint.dart';

/// Soru çözüm ekranı widget'ı
/// Quiz sorularını gösterir ve kullanıcının cevaplarını alır
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

  @override
  void initState() {
    super.initState();
    _pageController = PageController();

    // İpucunun gösterilmesi gerekip gerekmediğini kontrol et
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
      // Kısa bir gecikme ile göster (ekranın yüklenmesini bekle)
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
    // Quiz yoksa boş widget döndür
    if (widget.material.quiz == null || widget.material.quiz!.isEmpty) {
      return const Center(child: Text('Quiz bulunamadı'));
    }

    final quizLength = widget.material.quiz!.length;
    // ignore: unused_local_variable
    bool isQuizFinished = widget.selectedAnswers.length == quizLength;

    return Stack(
      children: [
        Column(
          children: [
            // Minimal progress bar - üstte küçük çizgiler (siyah-beyaz)
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
                scrollDirection: Axis.vertical, // DİKEY KAYDIRMA - Instagram Reels gibi
                physics: const NeverScrollableScrollPhysics(), // PageView kaydırmasını devre dışı bırak
                itemCount: quizLength,
                itemBuilder: (context, index) {
                  final question = widget.material.quiz![index];
                  return QuestionCard(
                    question: question,
                    questionNumber: index + 1,
                    totalQuestions: quizLength,
                    selectedOptionIndex: widget.selectedAnswers[index],
                    onOptionSelected: (optionIndex) {
                      if (!widget.selectedAnswers.containsKey(index)) {
                        widget.onAnswerSelected(index, optionIndex);
                      }
                    },
                    onReportIssue: () {
                      widget.onReportIssue(index);
                    },
                    onSwipeUp: () {
                      // Sonraki soruya geç
                      if (_currentPage < quizLength - 1) {
                        _pageController.animateToPage(
                          _currentPage + 1,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      }
                    },
                    onSwipeDown: () {
                      // Önceki soruya geç
                      if (_currentPage > 0) {
                        _pageController.animateToPage(
                          _currentPage - 1,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      }
                    },
                    onSubmit: widget.onSubmit,
                  );
                },
              ),
            ),
          ],
        ),

        // Şık kaydırma ipucu - ilk kullanımda göster
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

/// Tek bir soru kartı widget'ı
class QuestionCard extends StatefulWidget {
  final QuizQuestion question;
  final int questionNumber;
  final int totalQuestions;
  final int? selectedOptionIndex;
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
    // Başlangıçta scroll pozisyonunu kontrol et
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkScrollPosition();
    });
  }

  void _onScroll() {
    _checkScrollPosition();
  }

  void _checkScrollPosition() {
    if (!_scrollController.hasClients) return;

    setState(() {
      _isAtTop = _scrollController.position.pixels <= 0;
      _isAtBottom = _scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 10;
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
    return GestureDetector(
      onVerticalDragEnd: (details) {
        // Hızlı kaydırma kontrolü
        if (details.primaryVelocity == null) return;

        final velocity = details.primaryVelocity!;

        // Yukarı kaydırma (sonraki soru)
        if (velocity < -500 && _isAtBottom) {
          widget.onSwipeUp?.call();
        }
        // Aşağı kaydırma (önceki soru)
        else if (velocity > 500 && _isAtTop) {
          widget.onSwipeDown?.call();
        }
      },
      child: SingleChildScrollView(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header AppBar'a taşındı; burada yer kaplamasın
            const SizedBox(height: 2),

            // Soru kartı (siyah-beyaz)
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

              // Yeşil ve kırmızı renkler
              const greenColor = Color(0xFF4CAF50); // Yeşil
              const redColor = Color(0xFFE53935); // Kırmızı

              if (widget.selectedOptionIndex != null) {
                // Cevap verildikten sonra
                if (isSelected) {
                  // Seçilen şık
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
                  // Doğru cevap (seçilmemiş)
                  tileColor = greenColor.withValues(alpha: 0.1);
                  borderColor = greenColor;
                  letterBgColor = greenColor;
                  letterTextColor = Colors.white;
                } else {
                  // Diğer şıklar - siyah beyaz devam eder
                  tileColor = colorScheme.surface;
                  borderColor = colorScheme.onSurface.withValues(alpha: 0.2);
                  letterBgColor = colorScheme.onSurface.withValues(alpha: 0.1);
                  letterTextColor = colorScheme.onSurface.withValues(alpha: 0.6);
                }
              } else {
                // Cevap verilmeden önce - siyah beyaz tema
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
                        // Şık harf ikonları
                        Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: letterBgColor,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              String.fromCharCode(65 + index), // A, B, C, D
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

            // GÜNCELLENEN KISIM:
            // "Cevap Verildiyse" VEYA "Son Sorudaysa" buton satırını göster
            if (widget.selectedOptionIndex != null || widget.questionNumber == widget.totalQuestions)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Row(
                  children: [
                    // Açıklamayı Gör Butonu (Varsa Sola Yaslı)
                    if (widget.selectedOptionIndex != null)
                      OutlinedButton.icon(
                        onPressed: () {
                          _showExplanationBottomSheet(context);
                        },
                        icon: const Icon(Icons.lightbulb_outline_rounded),
                        label: const FittedBox(child: Text("Açıklamayı Gör")),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFFF9800),
                          side: const BorderSide(
                            color: Color(0xFFFF9800),
                            width: 1.5,
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                      ).animate().fadeIn(delay: 150.ms).slideY(begin: 0.2),

                    // Ortadaki boşluğu doldurarak Sonuçları Gör butonunu sağa iter
                    const Spacer(),

                    // Sonuçları Gör Butonu (Varsa Sağa Yaslı)
                    if (widget.questionNumber == widget.totalQuestions)
                      OutlinedButton.icon(
                        onPressed: widget.onSubmit,
                        icon: const Icon(Icons.assignment_turned_in_rounded),
                        label: const FittedBox(child: Text("Sonuçları Gör")),
                        style: OutlinedButton.styleFrom(
                          // SİYAH BEYAZ TEMA
                          foregroundColor: Theme.of(context).colorScheme.onSurface,
                          backgroundColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
                          side: BorderSide.none, // Kenarlık yok
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                      ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Açıklama detay sayfasını göster
  void _showExplanationBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true, // Status bar ve alt nav bar ile çakışmayı önler
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        // SafeArea: İçeriği güvenli alana hapseder (alt barın üzerine çıkmaz)
        child: SafeArea(
          bottom: true,
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
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
                      // Başlık
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.lightbulb_rounded,
                              color: Theme.of(context).colorScheme.onSurface,
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
                          color: Theme.of(context).colorScheme.onSurface,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
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
                          color: Theme.of(context).colorScheme.onSurface,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                            width: 2,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.onSurface,
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  String.fromCharCode(65 + widget.question.correctOptionIndex),
                                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                    color: Theme.of(context).colorScheme.surface,
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.onSurface.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Basit başlık (siyah-beyaz)
          Row(
            children: [
              Icon(
                Icons.lightbulb_outline_rounded,
                color: colorScheme.onSurface,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                "Açıklama",
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Açıklama metni
          MarkdownWithMath(
            data: explanation,
            styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
              p: TextStyle(
                color: colorScheme.onSurface,
                height: 1.5,
                fontSize: 14,
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
                              ? Theme.of(context).colorScheme.onSurface
                              : (optIndex == userAnswer && !isCorrect
                              ? const Color(0xFFE53935) // Kırmızı - yanlış cevap
                              : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
                        ),
                      ),
                    ),
                    leading: Icon(
                      optIndex == question.correctOptionIndex
                          ? Icons.check_circle_rounded
                          : (optIndex == userAnswer && !isCorrect ? Icons.cancel_rounded : Icons.radio_button_unchecked_rounded),
                      color: optIndex == question.correctOptionIndex
                          ? Theme.of(context).colorScheme.onSurface
                          : (optIndex == userAnswer && !isCorrect
                          ? const Color(0xFFE53935) // Kırmızı - yanlış cevap
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