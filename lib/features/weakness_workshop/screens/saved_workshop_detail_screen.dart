// lib/features/weakness_workshop/screens/saved_workshop_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:taktik/features/weakness_workshop/models/workshop_model.dart';
import 'package:taktik/shared/widgets/markdown_with_math.dart';

class SavedWorkshopDetailScreen extends StatefulWidget {
  final WorkshopModel workshop;

  const SavedWorkshopDetailScreen({super.key, required this.workshop});

  @override
  State<SavedWorkshopDetailScreen> createState() => _SavedWorkshopDetailScreenState();
}

class _SavedWorkshopDetailScreenState extends State<SavedWorkshopDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    // Eğer quiz yoksa direkt konu anlatımında başla
    final hasQuiz = widget.workshop.quiz?.isNotEmpty ?? false;
    final hasStudyGuide = widget.workshop.studyGuide?.isNotEmpty ?? false;

    if (!hasQuiz && hasStudyGuide) {
      _tabController = TabController(length: 1, vsync: this);
    } else if (hasQuiz && !hasStudyGuide) {
      _tabController = TabController(length: 1, vsync: this);
    } else {
      _tabController = TabController(length: 2, vsync: this);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasQuiz = widget.workshop.quiz?.isNotEmpty ?? false;
    final hasStudyGuide = widget.workshop.studyGuide?.isNotEmpty ?? false;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.workshop.topic,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            Text(
              widget.workshop.subject,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
          ],
        ),
        bottom: _tabController.length > 1
          ? PreferredSize(
              preferredSize: const Size.fromHeight(48),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    color: colorScheme.primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  labelColor: colorScheme.onPrimary,
                  unselectedLabelColor: colorScheme.onSurfaceVariant,
                  labelStyle: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                  tabs: const [
                    Tab(
                      icon: Icon(Icons.school_rounded, size: 20),
                      text: "Konu Anlatımı",
                      height: 44,
                    ),
                    Tab(
                      icon: Icon(Icons.quiz_rounded, size: 20),
                      text: "Ustalık Sınavı",
                      height: 44,
                    ),
                  ],
                ),
              ),
            )
          : null,
      ),
      body: _tabController.length > 1
          ? TabBarView(
              controller: _tabController,
              children: [
                _buildStudyGuideView(),
                _buildQuizReviewView(),
              ],
            )
          : hasStudyGuide
              ? _buildStudyGuideView()
              : _buildQuizReviewView(),
    );
  }

  Widget _buildStudyGuideView() {
    final studyGuideText = widget.workshop.studyGuide ??
        '# İçerik Bulunamadı\n\nBu çalışma kartı için konu anlatımı mevcut değil.';

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: MarkdownWithMath(
        data: studyGuideText,
        styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
          p: TextStyle(
            fontSize: 15,
            height: 1.6,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          h1: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
            height: 1.3,
          ),
          h2: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.secondary,
            height: 1.3,
          ),
          h3: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
            height: 1.3,
          ),
          blockquotePadding: const EdgeInsets.all(12),
          blockquoteDecoration: BoxDecoration(
            color: Theme.of(context).colorScheme.secondaryContainer.withOpacity(0.3),
            borderRadius: BorderRadius.circular(8),
            border: Border(
              left: BorderSide(
                color: Theme.of(context).colorScheme.secondary,
                width: 3,
              ),
            ),
          ),
          code: TextStyle(
            backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
            color: Theme.of(context).colorScheme.primary,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildQuizReviewView() {
    final quizQuestions = widget.workshop.quiz ?? [];

    if (quizQuestions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.quiz_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              "Bu cevher için sınav kaydedilmemiş",
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return _QuizReviewView(quizQuestions: quizQuestions);
  }
}

// Sadece bu ekranda kullanılacak özel bir Karne widget'ı
class _QuizReviewView extends StatelessWidget {
  final List<QuizQuestion> quizQuestions;

  const _QuizReviewView({required this.quizQuestions});

  @override
  Widget build(BuildContext context) {
    if (quizQuestions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.quiz_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              "Bu cevher için sınav kaydedilmemiş",
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: quizQuestions.length,
      itemBuilder: (context, index) {
        final question = quizQuestions[index];
        final colorScheme = Theme.of(context).colorScheme;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 0,
          color: colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
              width: 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Soru numarası başlığı
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    "Soru ${index + 1}",
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Soru metni
                MarkdownWithMath(
                  data: question.question,
                  styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                    p: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Seçenekler (kompakt tasarım)
                ...List.generate(question.options.length, (optIndex) {
                  final isCorrect = optIndex == question.correctOptionIndex;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: isCorrect
                        ? colorScheme.secondary.withOpacity(0.12)
                        : colorScheme.surfaceContainerHighest.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isCorrect
                          ? colorScheme.secondary
                          : colorScheme.surfaceContainerHighest.withOpacity(0.5),
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        // Şık harf ikonu
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: (isCorrect ? colorScheme.secondary : colorScheme.onSurfaceVariant)
                                .withOpacity(0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              String.fromCharCode(65 + optIndex), // A, B, C, D
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                color: isCorrect ? colorScheme.secondary : colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),

                        // Seçenek metni
                        Expanded(
                          child: MarkdownWithMath(
                            data: question.options[optIndex],
                            styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                              p: TextStyle(
                                fontSize: 14,
                                height: 1.4,
                                color: Theme.of(context).colorScheme.onSurface,
                                fontWeight: isCorrect ? FontWeight.w600 : FontWeight.normal,
                              ),
                            ),
                          ),
                        ),

                        // Doğru işareti
                        if (isCorrect) ...[
                          const SizedBox(width: 8),
                          Icon(
                            Icons.check_circle_rounded,
                            color: colorScheme.secondary,
                            size: 20,
                          ),
                        ],
                      ],
                    ),
                  );
                }),

                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 12),

                // Açıklama kartı (kompakt ve şık)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.secondaryContainer.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: colorScheme.secondary.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: colorScheme.secondary.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.lightbulb_rounded,
                          color: colorScheme.secondary,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Usta'nın Açıklaması",
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                color: colorScheme.secondary,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 6),
                            MarkdownWithMath(
                              data: question.explanation,
                              styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                                p: TextStyle(
                                  color: colorScheme.onSurface,
                                  height: 1.5,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

