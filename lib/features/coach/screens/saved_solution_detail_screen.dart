import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:taktik/features/coach/models/saved_solution_model.dart';
import 'package:taktik/features/coach/providers/daily_question_limit_provider.dart';
import 'package:taktik/features/coach/providers/saved_solutions_provider.dart';
import 'package:taktik/features/coach/screens/question_solver_screen.dart';
import 'package:taktik/features/coach/widgets/daily_limit_dialog.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:taktik/shared/widgets/full_screen_image_viewer.dart';
import 'package:taktik/features/quests/logic/quest_notifier.dart';

class SavedSolutionDetailScreen extends ConsumerStatefulWidget {
  final SavedSolutionModel solution;

  const SavedSolutionDetailScreen({super.key, required this.solution});

  @override
  ConsumerState<SavedSolutionDetailScreen> createState() => _SavedSolutionDetailScreenState();
}

class _SavedSolutionDetailScreenState extends ConsumerState<SavedSolutionDetailScreen> {
  @override
  void initState() {
    super.initState();
    // Quest takibi: Soru inceleme (Review)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(questNotifierProvider.notifier).userReviewedQuestionBox();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final allSolutions = ref.watch(savedSolutionsProvider);

    SavedSolutionModel currentSolution;
    try {
      currentSolution = allSolutions.firstWhere(
            (s) => s.id == widget.solution.id,
        orElse: () => widget.solution,
      );
    } catch (_) {
      currentSolution = widget.solution;
    }

    final bool isSolved = currentSolution.solutionText != 'Görsel Soru';

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(isSolved ? 'Çözüm' : 'Soru'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Silinsin mi?'),
                  content: const Text('Bu işlem geri alınamaz.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('İptal'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Sil', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              );

              if (confirm == true) {
                await ref
                    .read(savedSolutionsProvider.notifier)
                    .deleteSolution(currentSolution);
                if (context.mounted) Navigator.pop(context);
              }
            },
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          // Soru Resmi
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: GestureDetector(
                onTap: () {
                  // Tam ekran resim görüntüleyici aç
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => FullScreenImageViewer(
                        imagePath: currentSolution.localImagePath,
                      ),
                    ),
                  );
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      border: Border.all(color: theme.dividerColor),
                      borderRadius: BorderRadius.circular(16),
                      color: Colors.black,
                    ),
                    constraints: const BoxConstraints(maxHeight: 300),
                    child: Image.file(
                      File(currentSolution.localImagePath),
                      width: double.infinity,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Çözüm İçeriği - OPTİMİZE EDİLMİŞ HALİ
          if (isSolved)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  // DEĞİŞİKLİK: Markdown yerine MarkdownBody kullanıldı
                  child: MarkdownBody(
                    data: currentSolution.solutionText,
                    selectable: false, // Performans için seçim kapatıldı
                    styleSheet: MarkdownStyleSheet(
                      p: TextStyle(
                        color: theme.colorScheme.onSurface,
                        height: 1.5,
                        fontSize: 15,
                      ),
                      h1: TextStyle(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                      h2: TextStyle(
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                      strong: TextStyle(
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                      blockquote: TextStyle(
                        color: theme.colorScheme.secondary,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    builders: {
                      'latex': LatexElementBuilder(
                        textStyle: TextStyle(
                          fontSize: 16,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    },
                    extensionSet: md.ExtensionSet(
                      [...md.ExtensionSet.gitHubFlavored.blockSyntaxes],
                      [
                        ...md.ExtensionSet.gitHubFlavored.inlineSyntaxes,
                        LatexInlineSyntax()
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // FloatingActionButton için boşluk
          const SliverToBoxAdapter(
            child: SizedBox(height: 80),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          // AI kullanım hakkını kontrol et
          final dailyLimit = await ref.read(dailyQuestionLimitProvider.future);

          // Pro değilse ve limit dolduysa pro dialogu göster
          if (!dailyLimit.isPremium && dailyLimit.hasReachedLimit) {
            if (context.mounted) {
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => const DailyLimitDialog(),
              );
            }
            return;
          }

          // Görseli XFile olarak oluştur ve QuestionSolverScreen'e gönder
          final imageFile = XFile(currentSolution.localImagePath);

          // QuestionSolverScreen'e yönlendir
          Navigator.push(
            context,
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) => QuestionSolverScreen(
                preselectedImage: imageFile,
                existingSolutionId: currentSolution.id, // Güncelleme için ID gönder
                existingSolutionText: isSolved ? currentSolution.solutionText : null, // Çözüm varsa gönder
              ),
              transitionDuration: Duration.zero,
              reverseTransitionDuration: Duration.zero,
            ),
          );
        },
        icon: const Icon(Icons.chat_bubble_outline),
        label: const Text('Soru Sor'),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
      ),
    );
  }
}