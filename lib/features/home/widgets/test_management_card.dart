// lib/features/home/widgets/test_management_card.dart
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:taktik/data/providers/firestore_providers.dart';
import 'package:taktik/data/models/exam_model.dart';
import 'package:taktik/core/utils/exam_utils.dart';

class TestManagementCard extends ConsumerWidget {
  const TestManagementCard({super.key});

  Future<void> _showSubjectSelector(BuildContext context, WidgetRef ref) async {
    final user = ref.read(userProfileProvider).value;
    if (user == null || user.selectedExam == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lütfen önce bir sınav türü seçin')),
        );
      }
      return;
    }

    try {
      final examType = ExamType.values.byName(user.selectedExam!);
      final exam = await ExamData.getExamByType(examType);

      // İlgili (CoachScreen ile aynı) section'lardaki dersleri topla
      final relevantSections = ExamUtils.getRelevantSectionsForUser(user, exam);
      final Map<String, SubjectDetails> relevantSubjectsMap = {};
      for (final section in relevantSections) {
        for (final entry in section.subjects.entries) {
          // Aynı isimli ders varsa son section'ın verisi ile güncellenir (CoachScreen mantığına paralel)
          relevantSubjectsMap[entry.key] = entry.value;
        }
      }
      final subjects = relevantSubjectsMap.keys.toList(); // kaldırıldı: ..sort() — sınav tanım sırası korunur

      if (!context.mounted) return;

      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Theme.of(context).cardColor.withOpacity(0.98),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (sheetCtx) {
          return _SubjectPickerSheet(
            subjects: subjects,
            subjectsMap: relevantSubjectsMap,
            onSelect: (subject) {
              Navigator.of(sheetCtx).pop();
              final route = Uri(path: '/coach', queryParameters: {'subject': subject.trim()}).toString();
              context.go(route);
            },
          );
        },
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Dersler yüklenemedi: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: isDark ? 8 : 10,
      shadowColor: isDark
          ? Colors.black.withOpacity(0.4)
          : colorScheme.surfaceContainerHighest.withOpacity(0.45),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color: isDark
              ? colorScheme.primary.withOpacity(0.2)
              : colorScheme.surfaceContainerHighest.withOpacity(0.35),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Başlık
            Row(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: colorScheme.primary.withOpacity(0.6)),
                  ),
                  padding: const EdgeInsets.all(8),
                  child: Icon(Icons.assignment_rounded, color: colorScheme.primary, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sınav Yönetimi',
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Deneme ve test sonuçlarını ekle',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            // İki buton yan yana
            Row(
              children: [
                Expanded(
                  child: _ActionButton(
                    icon: Icons.add_chart_rounded,
                    label: 'Deneme Ekle',
                    color: colorScheme.primary,
                    onTap: () => context.push('/home/add-test'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ActionButton(
                    icon: Icons.library_books_rounded,
                    label: 'Test Ekle',
                    color: colorScheme.secondary,
                    onTap: () => _showSubjectSelector(context, ref),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 250.ms).slideY(begin: .04, curve: Curves.easeOut);
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: isDark
                ? [
                    colorScheme.surfaceContainer.withOpacity(0.5),
                    theme.cardColor.withOpacity(0.7),
                  ]
                : [
                    theme.cardColor,
                    theme.cardColor,
                  ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(
            color: isDark
                ? colorScheme.surfaceContainerHighest.withOpacity(0.3)
                : colorScheme.surfaceContainerHighest.withOpacity(0.45),
          ),
        ),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    ).animate().scale(duration: 120.ms, curve: Curves.easeOut);
  }
}

class _SubjectPickerSheet extends StatefulWidget {
  final List<String> subjects;
  final Map<String, SubjectDetails> subjectsMap;
  final ValueChanged<String> onSelect;
  const _SubjectPickerSheet({required this.subjects, required this.subjectsMap, required this.onSelect});
  @override
  State<_SubjectPickerSheet> createState() => _SubjectPickerSheetState();
}

class _SubjectPickerSheetState extends State<_SubjectPickerSheet> {
  final TextEditingController _searchCtrl = TextEditingController();
  @override
  void dispose(){ _searchCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final query = _searchCtrl.text.trim().toLowerCase();
    final filtered = widget.subjects.where((s)=> query.isEmpty || s.toLowerCase().contains(query)).toList();

    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.9, // daha fazla alan
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withOpacity(.15),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: colorScheme.primary.withOpacity(.5)),
                    ),
                    padding: const EdgeInsets.all(10),
                    child: Icon(Icons.library_books_rounded, color: colorScheme.primary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text('Test eklemek istediğin dersi seç',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                      maxLines: 2,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: ()=> Navigator.of(context).pop(),
                    tooltip: 'Kapat',
                  )
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (_)=> setState((){}),
                decoration: InputDecoration(
                  hintText: 'Ders ara...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  isDense: true,
                  filled: true,
                  fillColor: colorScheme.surfaceContainerHighest.withOpacity(.15),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: colorScheme.surfaceContainerHighest.withOpacity(.3)),
                  ),
                ),
              ),
            ),
            Expanded(
              child: filtered.isEmpty ? Center(
                child: Text('Hiç ders bulunamadı', style: theme.textTheme.labelLarge?.copyWith(color: colorScheme.onSurfaceVariant)),
              ) : ListView.separated(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                itemCount: filtered.length,
                separatorBuilder: (_, __)=> const SizedBox(height: 10),
                itemBuilder: (ctx, i) {
                  final subject = filtered[i];
                  final details = widget.subjectsMap[subject];
                  return _SubjectTile(
                    subject: subject,
                    onTap: ()=> widget.onSelect(subject),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SubjectTile extends StatelessWidget {
  final String subject;
  final VoidCallback onTap;

  const _SubjectTile({
    required this.subject,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: colorScheme.surfaceContainerHighest.withOpacity(0.35),
          ),
          color: colorScheme.surfaceContainer.withOpacity(0.25),
        ),
        child: Row(
          children: [
            Icon(Icons.book_rounded, color: colorScheme.primary, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                subject,
                style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: colorScheme.onSurfaceVariant.withOpacity(.7),
              size: 14,
            ),
          ],
        ),
      ),
    );
  }
}
