// lib/features/weakness_workshop/screens/saved_workshop_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:taktik/data/providers/firestore_providers.dart';
import 'package:taktik/features/auth/application/auth_controller.dart';
import 'package:taktik/features/weakness_workshop/models/workshop_model.dart';
import 'package:taktik/shared/widgets/markdown_with_math.dart';

class SavedWorkshopDetailScreen extends ConsumerStatefulWidget {
  final WorkshopModel workshop;

  const SavedWorkshopDetailScreen({super.key, required this.workshop});

  @override
  ConsumerState<SavedWorkshopDetailScreen> createState() => _SavedWorkshopDetailScreenState();
}

class _SavedWorkshopDetailScreenState extends ConsumerState<SavedWorkshopDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  Future<void> _confirmAndDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Silinsin mi?'),
        content: const Text('Bu kaydı kalıcı olarak silmek istiyor musun?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Sil'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final userId = ref.read(authControllerProvider).value?.uid;
      if (userId != null && widget.workshop.id != null) {
        try {
          await ref.read(firestoreServiceProvider).deleteSavedWorkshop(
            userId,
            widget.workshop.id!,
          );
          if (mounted) {
            context.pop(); // Detay sayfasından çık
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Kayıt silindi'),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Hata: $e'),
                behavior: SnackBarBehavior.floating,
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
            );
          }
        }
      }
    }
  }

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
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        elevation: 0,
        centerTitle: true,
        surfaceTintColor: Colors.transparent,
        title: Text(
          widget.workshop.topic,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: colorScheme.onSurface,
          ),
        ),
        iconTheme: IconThemeData(color: colorScheme.onSurface),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded),
            tooltip: 'Sil',
            onPressed: _confirmAndDelete,
          ),
        ],
        bottom: _tabController.length > 1
          ? PreferredSize(
              preferredSize: const Size.fromHeight(48),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    color: colorScheme.onSurface,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  labelColor: colorScheme.surface,
                  unselectedLabelColor: colorScheme.onSurface.withValues(alpha: 0.6),
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
                      text: "Test",
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
          : (widget.workshop.studyGuide?.isNotEmpty ?? false)
              ? _buildStudyGuideView()
              : _buildQuizReviewView(),
    );
  }

  Widget _buildStudyGuideView() {
    final studyGuideText = widget.workshop.studyGuide ??
        '# İçerik Bulunamadı\n\nBu çalışma kartı için konu anlatımı mevcut değil.';

    return SafeArea(
      bottom: true,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
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
            color: Theme.of(context).colorScheme.onSurface,
            height: 1.3,
          ),
          h2: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
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
            color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(8),
            border: Border(
              left: BorderSide(
                color: Theme.of(context).colorScheme.onSurface,
                width: 3,
              ),
            ),
          ),
          code: TextStyle(
            backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            color: Theme.of(context).colorScheme.onSurface,
            fontSize: 14,
          ),
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
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              "Bu konu için sınav kaydedilmemiş",
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
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
              color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              "Bu konu için sınav kaydedilmemiş",
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return SafeArea(
      bottom: true,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
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
              color: colorScheme.onSurface.withValues(alpha: 0.15),
              width: 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Soru numarası başlığı (siyah-beyaz)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: colorScheme.onSurface.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    "Soru ${index + 1}",
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: colorScheme.onSurface,
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
                      color: colorScheme.onSurface,
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Seçenekler (siyah-beyaz, yeşil accent için doğru cevap)
                ...List.generate(question.options.length, (optIndex) {
                  final isCorrect = optIndex == question.correctOptionIndex;
                  const greenColor = Color(0xFF4CAF50); // Doğru cevap için yeşil

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: isCorrect
                        ? greenColor.withValues(alpha: 0.1)
                        : colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isCorrect
                          ? greenColor
                          : colorScheme.onSurface.withValues(alpha: 0.2),
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
                            color: (isCorrect ? greenColor : colorScheme.onSurface)
                                .withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              String.fromCharCode(65 + optIndex), // A, B, C, D
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                color: isCorrect ? greenColor : colorScheme.onSurface,
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
                                color: colorScheme.onSurface,
                                fontWeight: isCorrect ? FontWeight.w600 : FontWeight.normal,
                              ),
                            ),
                          ),
                        ),

                        // Doğru işareti
                        if (isCorrect) ...[
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.check_circle_rounded,
                            color: greenColor,
                            size: 20,
                          ),
                        ],
                      ],
                    ),
                  );
                }),

                const SizedBox(height: 12),
                Divider(height: 1, color: colorScheme.onSurface.withValues(alpha: 0.1)),
                const SizedBox(height: 12),

                // Açıklama kartı (siyah-beyaz)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: colorScheme.onSurface.withValues(alpha: 0.15),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: colorScheme.onSurface.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.lightbulb_rounded,
                          color: colorScheme.onSurface,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Açıklama",
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
    ),
    );
  }
}

