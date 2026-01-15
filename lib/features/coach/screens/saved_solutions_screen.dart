import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:taktik/features/coach/models/saved_solution_model.dart';
import 'package:taktik/features/coach/providers/saved_solutions_provider.dart';
import 'package:taktik/features/coach/screens/subject_solutions_screen.dart';

class SavedSolutionsScreen extends ConsumerWidget {
  final bool isSelectionMode; // Ders seçim modu aktif mi?
  final List<String>? availableSubjects; // Seçilebilir dersler (seçim modunda)

  const SavedSolutionsScreen({
    super.key,
    this.isSelectionMode = false,
    this.availableSubjects,
  });

  // Derslere göre grupla
  Map<String, List<SavedSolutionModel>> _groupBySubject(List<SavedSolutionModel> solutions) {
    final Map<String, List<SavedSolutionModel>> grouped = {};
    for (final solution in solutions) {
      final subject = solution.subject ?? 'Genel';
      if (!grouped.containsKey(subject)) {
        grouped[subject] = [];
      }
      grouped[subject]!.add(solution);
    }
    return grouped;
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
  Color _getSubjectColor(String subject, ColorScheme colorScheme) {
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
    return colorScheme.primary;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<SavedSolutionModel> solutions = ref.watch(savedSolutionsProvider);
    final theme = Theme.of(context);
    final grouped = _groupBySubject(solutions);

    // Debug logs
    debugPrint('🔍 SavedSolutionsScreen build:');
    debugPrint('   - isSelectionMode: $isSelectionMode');
    debugPrint('   - solutions count: ${solutions.length}');
    debugPrint('   - availableSubjects: $availableSubjects');
    debugPrint('   - grouped keys: ${grouped.keys.join(", ")}');

    // Seçim modundaysa kullanıcının TÜM derslerini göster
    final List<String> subjects = isSelectionMode && availableSubjects != null
        ? availableSubjects! // Tüm dersleri göster (filtreleme yok!)
        : grouped.keys.toList();

    subjects.sort();

    debugPrint('   - subjects to display: ${subjects.join(", ")}');

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          isSelectionMode ? 'Nereye Kaydedelim?' : 'Çözüm Arşivi',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        centerTitle: true,
      ),
      body: (solutions.isEmpty && !isSelectionMode) || (isSelectionMode && subjects.isEmpty)
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.folder_open_rounded,
                    size: 80,
                    color: theme.colorScheme.outline.withOpacity(0.5),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    isSelectionMode
                        ? "Henüz hiç soru kaydetmedin.\nİlk sorun bu mu? 🎉"
                        : "Henüz kaydedilmiş çözüm yok",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.6)),
                  ),
                ],
              ),
            )
          : isSelectionMode
              ? _buildSelectionGrid(context, theme, subjects, grouped)
              : _buildNormalGrid(context, theme, subjects, grouped),
    );
  }

  // Normal mod: Klasörleri aç
  Widget _buildNormalGrid(BuildContext context, ThemeData theme, List<String> subjects, Map<String, List<SavedSolutionModel>> grouped) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemCount: subjects.length,
      itemBuilder: (context, index) {
        final subject = subjects[index];
        final subjectSolutions = grouped[subject]!;
        return _buildSubjectCard(
          context,
          theme,
          subject,
          subjectSolutions,
          onTap: () {
            Navigator.push(
              context,
              PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) => SubjectSolutionsScreen(
                  subject: subject,
                  solutions: subjectSolutions,
                ),
                transitionDuration: Duration.zero,
                reverseTransitionDuration: Duration.zero,
              ),
            );
          },
        );
      },
    );
  }

  // Seçim modu: Ders seç ve geri dön
  Widget _buildSelectionGrid(BuildContext context, ThemeData theme, List<String> subjects, Map<String, List<SavedSolutionModel>> grouped) {
    return Column(
      children: [
        // Bilgilendirme banner'ı
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer.withOpacity(0.3),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: theme.colorScheme.primary.withOpacity(0.2),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.info_outline_rounded,
                color: theme.colorScheme.primary,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Soruyu kaydetmek istediğin dersi seç',
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),

        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.85,
            ),
            itemCount: subjects.length,
            itemBuilder: (context, index) {
              final subject = subjects[index];
              final subjectSolutions = grouped[subject] ?? []; // Boş liste döndür eğer yoksa
              return _buildSubjectCard(
                context,
                theme,
                subject,
                subjectSolutions,
                isSelectionMode: true,
                onTap: () {
                  // Seçilen dersi geri döndür
                  Navigator.pop(context, subject);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  // Ortak kart widget'ı
  Widget _buildSubjectCard(
    BuildContext context,
    ThemeData theme,
    String subject,
    List<SavedSolutionModel> subjectSolutions, {
    bool isSelectionMode = false,
    required VoidCallback onTap,
  }) {
    final subjectColor = _getSubjectColor(subject, theme.colorScheme);
    final subjectIcon = _getSubjectIcon(subject);

    return Card(
      elevation: 2,
      shadowColor: subjectColor.withOpacity(0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                subjectColor.withOpacity(0.1),
                subjectColor.withOpacity(0.05),
              ],
            ),
          ),
          child: Column(
            children: [
              // İkon - Sabit yükseklik
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: subjectColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  subjectIcon,
                  size: 36,
                  color: subjectColor,
                ),
              ),
              const SizedBox(height: 10),

              // Ders İsmi - Sabit yükseklik (2 satır)
              SizedBox(
                height: 38, // 2 satır için sabit yükseklik
                child: Center(
                  child: Text(
                    subject,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: theme.colorScheme.onSurface,
                      height: 1.2,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 8),

              // Badge - Her zaman aynı yerde
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: subjectColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  isSelectionMode && subjectSolutions.isEmpty
                      ? 'Yeni Klasör'
                      : '${subjectSolutions.length} soru',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: subjectColor,
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