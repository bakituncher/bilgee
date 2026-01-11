import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:taktik/features/coach/models/saved_solution_model.dart';
import 'package:taktik/features/coach/providers/saved_solutions_provider.dart';
import 'package:taktik/features/coach/screens/question_solver_screen.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:flutter_math_fork/flutter_math.dart';

class SavedSolutionDetailScreen extends ConsumerWidget {
  final SavedSolutionModel solution;

  const SavedSolutionDetailScreen({super.key, required this.solution});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Çözüm Detayı'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Silinsin mi?'),
                  content: const Text('Bu çözüm kalıcı olarak silinecek.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('İptal')),
                    TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Sil', style: TextStyle(color: Colors.red))),
                  ],
                ),
              );

              if (confirm == true) {
                await ref.read(savedSolutionsProvider.notifier).deleteSolution(solution.id);
                if (context.mounted) Navigator.pop(context);
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Soru Resmi
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 300),
                child: Image.file(File(solution.localImagePath), fit: BoxFit.contain),
              ),
            ),
            const SizedBox(height: 24),

            // Çözüm Metni
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: MarkdownBody(
                data: solution.solutionText,
                selectable: true,
                styleSheet: MarkdownStyleSheet(
                  p: TextStyle(color: theme.colorScheme.onSurface, height: 1.5, fontSize: 15),
                  h1: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold),
                  strong: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.w700),
                ),
                builders: {
                  'latex': LatexElementBuilder(
                    textStyle: TextStyle(fontSize: 16, color: theme.colorScheme.onSurface),
                  ),
                },
                extensionSet: md.ExtensionSet(
                  [...md.ExtensionSet.gitHubFlavored.blockSyntaxes],
                  [...md.ExtensionSet.gitHubFlavored.inlineSyntaxes, LatexInlineSyntax()],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

