import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// Model ve Provider importlarını kendi proje yapınıza göre doğrulayın
import 'package:taktik/features/coach/models/saved_solution_model.dart';
import 'package:taktik/features/coach/providers/saved_solutions_provider.dart';
import 'package:taktik/features/coach/screens/saved_solution_detail_screen.dart';

class SavedSolutionsScreen extends ConsumerWidget {
  const SavedSolutionsScreen({super.key});

  // --- Türkçe Tarih Formatlayıcı ---
  String _formatDateTR(DateTime date) {
    const months = [
      "Ocak", "Şubat", "Mart", "Nisan", "Mayıs", "Haziran",
      "Temmuz", "Ağustos", "Eylül", "Ekim", "Kasım", "Aralık"
    ];

    String twoDigits(int n) => n.toString().padLeft(2, '0');

    final day = date.day;
    final month = months[date.month - 1];
    final year = date.year;
    final hour = twoDigits(date.hour);
    final minute = twoDigits(date.minute);

    // Örnek: 12 Ekim 2024, 14:30
    return '$day $month $year, $hour:$minute';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // DÜZELTİLDİ: Provider bir List döndürüyor, AsyncValue değil.
    final List<SavedSolutionModel> solutions = ref.watch(savedSolutionsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Çözüm Arşivi', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        centerTitle: true,
      ),
      // DÜZELTİLDİ: .when yerine if/else yapısı
      body: solutions.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_open_rounded, size: 80, color: theme.colorScheme.outline.withOpacity(0.5)),
            const SizedBox(height: 16),
            Text("Henüz kaydedilmiş çözüm yok", style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.6))),
          ],
        ),
      )
          : ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: solutions.length,
        itemBuilder: (context, index) {
          final solution = solutions[index];
          return Card(
            elevation: 0,
            color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: theme.colorScheme.outline.withOpacity(0.1)),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SavedSolutionDetailScreen(solution: solution),
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    // Küçük Resim (Thumbnail)
                    Hero(
                      tag: 'thumb_${solution.id}',
                      child: Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          // DÜZELTİLDİ: imagePath -> thumbnailPath
                          image: DecorationImage(
                            image: FileImage(File(solution.thumbnailPath)),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Bilgiler
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            solution.subject ?? "Matematik", // Null check eklendi
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          // DÜZELTİLDİ: date -> timestamp
                          Text(
                            _formatDateTR(solution.timestamp),
                            style: TextStyle(
                              fontSize: 13,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            solution.solutionText.replaceAll('\n', ' ').length > 50
                                ? '${solution.solutionText.replaceAll('\n', ' ').substring(0, 50)}...'
                                : solution.solutionText.replaceAll('\n', ' '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.onSurface.withOpacity(0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.arrow_forward_ios_rounded, size: 16, color: theme.colorScheme.onSurface.withOpacity(0.3)),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}