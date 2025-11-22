import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:taktik/data/models/exam_model.dart';
import 'package:taktik/data/providers/firestore_providers.dart';
import 'package:taktik/core/utils/exam_utils.dart';

class SelectSubjectScreen extends ConsumerWidget {
  const SelectSubjectScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userProfileProvider).value;
    if (user == null || user.selectedExam == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Ders Seç')),
        body: const Center(child: Text('Önce sınav seçmelisiniz.')),
      );
    }
    final examType = ExamType.values.byName(user.selectedExam!);
    return FutureBuilder<Exam>(
      future: ExamData.getExamByType(examType),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return Scaffold(
            appBar: AppBar(title: const Text('Ders Seç')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        if (snap.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text('Ders Seç')),
            body: Center(child: Text('Dersler yüklenemedi: ${snap.error}')),
          );
        }
        final exam = snap.data!;
        final relevantSections = ExamUtils.getRelevantSectionsForUser(user, exam);
        final Map<String, SubjectDetails> subjectsMap = {};
        for (final section in relevantSections) {
          subjectsMap.addAll(section.subjects);
        }
        final subjects = subjectsMap.keys.toList();
        return Scaffold(
          appBar: AppBar(
            title: const Text('Ders Seç'),
            centerTitle: false,
          ),
          body: subjects.isEmpty
              ? const Center(child: Text('Hiç ders bulunamadı.'))
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                      child: Text(
                        'Test eklemek istediğin dersi seç',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                              fontSize: 14,
                            ),
                      ),
                    ),
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                        itemCount: subjects.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (ctx, i) {
                          final subject = subjects[i];
                          return _SubjectRow(
                            subject: subject,
                            onTap: () {
                              final route = Uri(path: '/coach', queryParameters: {'subject': subject}).toString();
                              context.go(route);
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }
}

class _SubjectRow extends StatelessWidget {
  final String subject;
  final VoidCallback onTap;
  const _SubjectRow({required this.subject, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark
                ? cs.surfaceContainerHighest.withOpacity(.4)
                : cs.surfaceContainerHighest.withOpacity(.5),
            width: 1.5,
          ),
          color: isDark
              ? cs.surfaceContainer.withOpacity(.3)
              : cs.surface,
          boxShadow: isDark
              ? null
              : [
                  BoxShadow(
                    color: cs.shadow.withOpacity(0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: cs.primary.withOpacity(.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: cs.primary.withOpacity(.3)),
              ),
              child: Icon(Icons.book_rounded, color: cs.primary, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                subject,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                    ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 18,
              color: cs.onSurfaceVariant.withOpacity(.7),
            )
          ],
        ),
      ),
    );
  }
}

