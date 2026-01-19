import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:taktik/features/coach/models/saved_solution_model.dart';
import 'package:taktik/features/coach/providers/saved_solutions_provider.dart';
import 'package:taktik/features/coach/screens/question_solver_screen.dart'; // Markdown builder'lar için
import 'package:markdown/markdown.dart' as md;

class SavedSolutionDetailScreen extends ConsumerWidget {
  final SavedSolutionModel solution;

  const SavedSolutionDetailScreen({super.key, required this.solution});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final allSolutions = ref.watch(savedSolutionsProvider);

    SavedSolutionModel currentSolution;
    try {
      currentSolution = allSolutions.firstWhere(
        (s) => s.id == solution.id,
        orElse: () => solution,
      );
    } catch (_) {
      currentSolution = solution;
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
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Soru Resmi
            Padding(
              padding: const EdgeInsets.all(16.0),
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

            // Çözüm İçeriği
            if (isSolved)
              Padding(
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
                  child: MarkdownBody(
                    data: currentSolution.solutionText,
                    selectable: true,
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
                      strong: TextStyle(
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.w700,
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
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          // Görseli XFile olarak oluştur ve QuestionSolverScreen'e gönder
          final imageFile = XFile(currentSolution.localImagePath);

          // QuestionSolverScreen'e yönlendir (mevcut çözümün ID'sini ve metnini gönder)
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

