import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:taktik/data/providers/firestore_providers.dart';
import 'package:taktik/features/coach/models/saved_solution_model.dart';
import 'package:taktik/features/coach/providers/saved_solutions_provider.dart';
import 'package:taktik/features/coach/screens/question_solver_screen.dart'; // Markdown builder'lar için
import 'package:markdown/markdown.dart' as md;
import 'package:taktik/features/coach/services/question_solver_service.dart';

class SavedSolutionDetailScreen extends ConsumerStatefulWidget {
  final SavedSolutionModel solution;

  const SavedSolutionDetailScreen({super.key, required this.solution});

  @override
  ConsumerState<SavedSolutionDetailScreen> createState() =>
      _SavedSolutionDetailScreenState();
}

class _SavedSolutionDetailScreenState
    extends ConsumerState<SavedSolutionDetailScreen> {
  bool _isSolving = false; // Çözüm işlemi sürüyor mu?

  Future<void> _solveQuestion(SavedSolutionModel currentSolution) async {
    setState(() => _isSolving = true);

    try {
      final service = ref.read(questionSolverServiceProvider);
      final user = ref.read(userProfileProvider).value;

      // Kayıtlı resim yolunu XFile'a çevir
      final imageFile = XFile(currentSolution.localImagePath);

      // Soruyu çözdür
      final result = await service.solveQuestion(
        imageFile,
        examType: user?.selectedExam,
      );

      // Sonucu kaydet (Modeli güncelle)
      await ref
          .read(savedSolutionsProvider.notifier)
          .updateSolution(currentSolution, result);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Soru başarıyla çözüldü!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata: ${e.toString().replaceAll("Exception:", "")}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSolving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Listeyi dinle
    final allSolutions = ref.watch(savedSolutionsProvider);

    // SORUNUN ÇÖZÜMÜ: Key yerine ID ile eşleştirme yapıyoruz ve hata durumunda eskisini kullanıyoruz.
    // Bu sayede 'firstWhere' hata fırlatsa bile uygulama çökmez veya beyaz ekranda kalmaz.
    SavedSolutionModel currentSolution;
    try {
      currentSolution = allSolutions.firstWhere(
            (s) => s.id == widget.solution.id,
        orElse: () => widget.solution, // Bulamazsa mevcut olanı kullan (Fallback)
      );
    } catch (_) {
      currentSolution = widget.solution;
    }

    // Çözüldü mü kontrolü (Varsayılan metin: "Görsel Soru")
    final bool isSolved = currentSolution.solutionText != 'Görsel Soru';

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        // Çözülmemişse "Soru", çözülmüşse "Çözüm" yazsın
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
                        child: const Text('İptal')),
                    TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Sil',
                            style: TextStyle(color: Colors.red))),
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
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Soru Resmi
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: theme.dividerColor),
                  borderRadius: BorderRadius.circular(16),
                  color: Colors.black, // Resim yüklenirken arka plan
                ),
                constraints: const BoxConstraints(maxHeight: 400),
                child: Image.file(File(currentSolution.localImagePath),
                    fit: BoxFit.contain),
              ),
            ),
            const SizedBox(height: 24),

            // DURUMA GÖRE İÇERİK
            if (_isSolving) ...[
              // Yükleniyor Durumu
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(
                      "Soru İnceleniyor...",
                      style: TextStyle(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Taktik Tavşan çözümü hazırlıyor 🐰",
                      style: TextStyle(color: theme.colorScheme.outline),
                    ),
                  ],
                ),
              ),
            ] else if (!isSolved) ...[
              // Çözülmemiş Durum: ÇÖZ BUTONU
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: theme.colorScheme.primary.withOpacity(0.2)),
                ),
                child: Column(
                  children: [
                    const Text(
                      "Bu soru henüz çözülmemiş.",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Çözümü görmek için butona tıkla.",
                      style: TextStyle(
                          color: theme.colorScheme.onSurface.withOpacity(0.7)),
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: () => _solveQuestion(currentSolution),
                      icon: const Icon(Icons.auto_awesome_rounded),
                      label: const Text("Yapay Zeka ile Çöz"),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 32, vertical: 16),
                        textStyle: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ).animate(onPlay: (c) => c.repeat(reverse: true)).shimmer(
                        delay: 1.seconds, duration: 2.seconds),
                  ],
                ),
              ),
            ] else ...[
              // Çözülmüş Durum: ÇÖZÜM METNİ
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4)),
                  ],
                ),
                child: MarkdownBody(
                  data: currentSolution.solutionText,
                  selectable: true,
                  styleSheet: MarkdownStyleSheet(
                    p: TextStyle(
                        color: theme.colorScheme.onSurface,
                        height: 1.5,
                        fontSize: 15),
                    h1: TextStyle(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold),
                    strong: TextStyle(
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.w700),
                  ),
                  builders: {
                    'latex': LatexElementBuilder(
                      textStyle: TextStyle(
                          fontSize: 16, color: theme.colorScheme.onSurface),
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
              ).animate().fadeIn().slideY(begin: 0.1, end: 0),
            ],
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
