import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:taktik/features/coach/models/saved_solution_model.dart';
import 'package:taktik/features/coach/screens/saved_solution_detail_screen.dart';

class SubjectSolutionsScreen extends ConsumerWidget {
  final String subject;
  final List<SavedSolutionModel> solutions;

  const SubjectSolutionsScreen({
    super.key,
    required this.subject,
    required this.solutions,
  });

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

  // Ders ikonunu getir
  IconData _getSubjectIcon(String subject) {
    if (subject.contains('Matematik')) return Icons.calculate_rounded;
    if (subject.contains('Fizik')) return Icons.science_rounded;
    if (subject.contains('Kimya')) return Icons.biotech_rounded;
    if (subject.contains('Biyoloji')) return Icons.eco_rounded;
    if (subject.contains('Türkçe')) return Icons.menu_book_rounded;
    if (subject.contains('Tarih')) return Icons.history_edu_rounded;
    if (subject.contains('Coğrafya')) return Icons.public_rounded;
    if (subject.contains('İngilizce') || subject.contains('Almanca') || subject.contains('Fransızca')) {
      return Icons.translate_rounded;
    }
    return Icons.folder_rounded;
  }

  // Ders rengi getir
  Color _getSubjectColor(String subject) {
    if (subject.contains('Matematik')) return Colors.blue;
    if (subject.contains('Fizik')) return Colors.purple;
    if (subject.contains('Kimya')) return Colors.green;
    if (subject.contains('Biyoloji')) return Colors.teal;
    if (subject.contains('Türkçe')) return Colors.red;
    if (subject.contains('Tarih')) return Colors.brown;
    if (subject.contains('Coğrafya')) return Colors.lightBlue;
    if (subject.contains('İngilizce') || subject.contains('Almanca') || subject.contains('Fransızca')) {
      return Colors.orange;
    }
    return Colors.indigo;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final subjectColor = _getSubjectColor(subject);
    final subjectIcon = _getSubjectIcon(subject);

    // Tarihe göre sırala (en yeni en üstte)
    final sortedSolutions = List<SavedSolutionModel>.from(solutions)
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(subjectIcon, color: subjectColor, size: 24),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                subject,
                style: const TextStyle(fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Üst bilgi kartı
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  subjectColor.withOpacity(0.15),
                  subjectColor.withOpacity(0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: subjectColor.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: subjectColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.quiz_rounded,
                    color: subjectColor,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Toplam Soru',
                        style: TextStyle(
                          fontSize: 13,
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${solutions.length}',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: subjectColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Sorular listesi
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: sortedSolutions.length,
              itemBuilder: (context, index) {
                final solution = sortedSolutions[index];
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
                        PageRouteBuilder(
                          pageBuilder: (context, animation, secondaryAnimation) => SavedSolutionDetailScreen(solution: solution),
                          transitionDuration: Duration.zero,
                          reverseTransitionDuration: Duration.zero,
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
                              width: 70,
                              height: 70,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: subjectColor.withOpacity(0.3),
                                  width: 2,
                                ),
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
                                Row(
                                  children: [
                                    Icon(
                                      Icons.access_time_rounded,
                                      size: 14,
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      _formatDateTR(solution.timestamp),
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  solution.solutionText.replaceAll('\n', ' ').length > 80
                                      ? '${solution.solutionText.replaceAll('\n', ' ').substring(0, 80)}...'
                                      : solution.solutionText.replaceAll('\n', ' '),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: theme.colorScheme.onSurface.withOpacity(0.8),
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 16,
                            color: theme.colorScheme.onSurface.withOpacity(0.3),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

