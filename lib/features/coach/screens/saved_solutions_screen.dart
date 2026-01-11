import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:taktik/features/coach/providers/saved_solutions_provider.dart';
import 'package:taktik/features/coach/screens/saved_solution_detail_screen.dart';

class SavedSolutionsScreen extends ConsumerWidget {
  const SavedSolutionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final solutions = ref.watch(savedSolutionsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Kaydedilen Çözümler'),
        centerTitle: true,
      ),
      body: solutions.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.bookmark_border, size: 64, color: theme.disabledColor),
                  const SizedBox(height: 16),
                  Text('Henüz kaydedilmiş bir çözüm yok.', style: theme.textTheme.bodyLarge),
                ],
              ),
            )
          : GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2, // Yan yana 2 kart
                childAspectRatio: 0.75, // Dikey kartlar
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: solutions.length,
              itemBuilder: (context, index) {
                final solution = solutions[index];
                return GestureDetector(
                  onTap: () {
                    // Detay sayfasına git (Navigasyon için normal push kullanıyoruz)
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SavedSolutionDetailScreen(solution: solution),
                      ),
                    );
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: theme.cardColor,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Resim Kısmı
                        Expanded(
                          child: ClipRRect(
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                            child: Image.file(
                              File(solution.localImagePath),
                              fit: BoxFit.cover,
                              errorBuilder: (c, o, s) => const Center(child: Icon(Icons.broken_image)),
                            ),
                          ),
                        ),
                        // Alt Bilgi
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                DateFormat('dd MMM yyyy').format(solution.timestamp),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.secondary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                solution.solutionText,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodyMedium?.copyWith(height: 1.2),
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

