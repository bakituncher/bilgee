import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:taktik/data/models/exam_model.dart';
import 'package:taktik/data/providers/firestore_providers.dart';
import 'package:taktik/core/utils/exam_utils.dart';
import 'package:flutter_animate/flutter_animate.dart';

final weeklySelectedTopicsProvider = StateProvider<Set<String>>((ref) => {});

class WeeklyTopicSelectionScreen extends ConsumerStatefulWidget {
  final VoidCallback onContinue;

  const WeeklyTopicSelectionScreen({super.key, required this.onContinue});

  @override
  ConsumerState<WeeklyTopicSelectionScreen> createState() => _WeeklyTopicSelectionScreenState();
}

class _WeeklyTopicSelectionScreenState extends ConsumerState<WeeklyTopicSelectionScreen> {
  String? _expandedSubject;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(userProfileProvider).value;
    if (user == null || user.selectedExam == null) return const SizedBox();

    final examType = ExamType.values.byName(user.selectedExam!);
    final selectedTopics = ref.watch(weeklySelectedTopicsProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Text(
                "Bu Hafta Hangi Konular?",
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                "İstersen bu hafta özellikle çalışmak istediğin konuları seçebilirsin. Seçmezsen, eksiklerine göre ben belirleyeceğim.",
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        Expanded(
          child: FutureBuilder<Exam>(
            future: ExamData.getExamByType(examType),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snap.hasError || !snap.hasData) {
                return const Center(child: Text("Müfredat yüklenemedi."));
              }

              final exam = snap.data!;
              final sections = ExamUtils.getRelevantSectionsForUser(user, exam);

              // Flatten subjects: List of {subjectName, topics}
              final allSubjects = <MapEntry<String, List<String>>>[];
              for (final section in sections) {
                section.subjects.forEach((subjName, details) {
                   // Add section prefix if needed or just use subject name
                   // For YKS, subject names are usually unique enough or we can group.
                   // Let's keep it simple.
                   allSubjects.add(MapEntry(subjName, details.topics.map((t) => t.name).toList()));
                });
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: allSubjects.length,
                itemBuilder: (context, index) {
                  final entry = allSubjects[index];
                  final subjectName = entry.key;
                  final topics = entry.value;
                  final isExpanded = _expandedSubject == subjectName;

                  // Count selected in this subject
                  final selectedCount = topics.where((t) => selectedTopics.contains("$subjectName: $t")).length;

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: selectedCount > 0
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.outlineVariant.withOpacity(0.5),
                      ),
                    ),
                    child: Theme(
                      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                      child: ExpansionTile(
                        initiallyExpanded: isExpanded,
                        onExpansionChanged: (val) {
                          setState(() {
                            _expandedSubject = val ? subjectName : null;
                          });
                        },
                        leading: CircleAvatar(
                          backgroundColor: selectedCount > 0
                              ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
                              : Theme.of(context).colorScheme.surfaceContainerHighest,
                          child: Icon(
                            selectedCount > 0 ? Icons.check_circle_rounded : Icons.book_rounded,
                            color: selectedCount > 0
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.onSurfaceVariant,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          subjectName,
                          style: TextStyle(
                            fontWeight: selectedCount > 0 ? FontWeight.bold : FontWeight.normal,
                            color: selectedCount > 0 ? Theme.of(context).colorScheme.primary : null,
                          ),
                        ),
                        subtitle: selectedCount > 0
                            ? Text("$selectedCount konu seçildi", style: const TextStyle(fontSize: 12))
                            : null,
                        children: [
                          ...topics.map((topic) {
                            final fullKey = "$subjectName: $topic";
                            final isSelected = selectedTopics.contains(fullKey);
                            return CheckboxListTile(
                              value: isSelected,
                              activeColor: Theme.of(context).colorScheme.primary,
                              title: Text(topic, style: const TextStyle(fontSize: 14)),
                              onChanged: (val) {
                                final current = ref.read(weeklySelectedTopicsProvider);
                                final newSet = Set<String>.from(current);
                                if (val == true) {
                                  newSet.add(fullKey);
                                } else {
                                  newSet.remove(fullKey);
                                }
                                ref.read(weeklySelectedTopicsProvider.notifier).state = newSet;
                              },
                              contentPadding: const EdgeInsets.only(left: 16, right: 8),
                              dense: true,
                            );
                          }),
                        ],
                      ),
                    ),
                  ).animate().fadeIn(delay: (50 * index).ms).slideX();
                },
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: widget.onContinue,
                  child: const Text("Seçmeden Devam Et"),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: widget.onContinue,
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text("Devam Et"),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
