// lib/features/home/widgets/add_test_step2.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:taktik/data/models/exam_model.dart';
import 'package:taktik/shared/widgets/score_slider.dart';
import 'package:taktik/features/home/logic/add_test_notifier.dart';

class Step2ScoreEntry extends ConsumerStatefulWidget {
  const Step2ScoreEntry({super.key});

  @override
  ConsumerState<Step2ScoreEntry> createState() => _Step2ScoreEntryState();
}

class _Step2ScoreEntryState extends ConsumerState<Step2ScoreEntry> {
  late PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _pageController.addListener(_onPageChanged);
  }

  void _onPageChanged() {
    final page = _pageController.page?.round() ?? 0;
    if (page != _currentPage) {
      setState(() {
        _currentPage = page;
      });
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(addTestProvider);
    final section = state.selectedSection;
    if (section == null) return const Center(child: Text("Bölüm seçilmedi."));

    final subjects = section.subjects.entries.toList();

    return Column(
      children: [
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            itemCount: subjects.length,
            itemBuilder: (context, index) {
              final subjectEntry = subjects[index];
              return _SubjectScoreCard(
                key: ValueKey(subjectEntry.key),
                subjectName: subjectEntry.key,
                details: subjectEntry.value,
                isFirst: index == 0,
                isLast: index == subjects.length - 1,
                currentPage: _currentPage,
                totalPages: subjects.length,
                onNext: () => _pageController.nextPage(duration: 300.ms, curve: Curves.easeOut),
                onPrevious: () => _pageController.previousPage(duration: 300.ms, curve: Curves.easeOut),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _SubjectScoreCard extends ConsumerWidget {
  final String subjectName;
  final SubjectDetails details;
  final bool isFirst, isLast;
  final int currentPage, totalPages;
  final VoidCallback onNext, onPrevious;

  const _SubjectScoreCard({
    super.key,
    required this.subjectName,
    required this.details,
    required this.isFirst,
    required this.isLast,
    required this.currentPage,
    required this.totalPages,
    required this.onNext,
    required this.onPrevious,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(addTestProvider.notifier);
    final subjectScores = ref.watch(addTestProvider.select((s) => s.scores[subjectName])) ?? {'dogru': 0, 'yanlis': 0};
    final section = ref.watch(addTestProvider.select((s) => s.selectedSection))!;

    int correct = subjectScores['dogru']!;
    int wrong = subjectScores['yanlis']!;
    int blank = details.questionCount - correct - wrong;
    double net = correct - (wrong * section.penaltyCoefficient);

    return LayoutBuilder(
      builder: (context, constraints) {
        // Ekran yüksekliğine göre dinamik boşluk hesaplama
        final availableHeight = constraints.maxHeight;
        final bool isCompact = availableHeight < 600;

        return Padding(
          padding: EdgeInsets.symmetric(
            horizontal: 16.0,
            vertical: isCompact ? 8.0 : 16.0,
          ),
          child: Column(
            children: [
              // Başlık bölümü
              Text(
                subjectName,
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: isCompact ? 2 : 4),
              Text(
                "${details.questionCount} Soru",
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),

              const Spacer(),

              // Slider'lar
              GestureDetector(
                onHorizontalDragStart: (_) {},
                onHorizontalDragUpdate: (_) {},
                child: ScoreSlider(
                  label: "Doğru",
                  value: correct.toDouble(),
                  max: details.questionCount.toDouble(),
                  color: Theme.of(context).colorScheme.secondary,
                  totalQuestions: details.questionCount.toDouble(),
                  onChanged: (value) {
                    final newCorrect = value.toInt();
                    if (newCorrect + wrong > details.questionCount) {
                      final adjustedWrong = details.questionCount - newCorrect;
                      notifier.updateScores(subjectName, correct: newCorrect, wrong: adjustedWrong);
                    } else {
                      notifier.updateScores(subjectName, correct: newCorrect);
                    }
                  },
                ),
              ),
              SizedBox(height: isCompact ? 8 : 12),
              GestureDetector(
                onHorizontalDragStart: (_) {},
                onHorizontalDragUpdate: (_) {},
                child: ScoreSlider(
                  label: "Yanlış",
                  value: wrong.toDouble(),
                  max: (details.questionCount - correct).toDouble(),
                  color: Theme.of(context).colorScheme.error,
                  totalQuestions: details.questionCount.toDouble(),
                  onChanged: (value) {
                    final newWrong = value.toInt();
                    if (newWrong + correct > details.questionCount) {
                      final adjustedCorrect = details.questionCount - newWrong;
                      notifier.updateScores(subjectName, correct: adjustedCorrect, wrong: newWrong);
                    } else {
                      notifier.updateScores(subjectName, wrong: newWrong);
                    }
                  },
                ),
              ),

              const Spacer(),

              // İstatistikler
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _StatDisplay(label: "Boş", value: blank.toString()),
                  Container(
                    height: 40,
                    width: 1,
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                  _StatDisplay(label: "Net", value: net.toStringAsFixed(2)),
                ],
              ),

              const Spacer(),

              // Özet butonu (sadece son sayfada) - sabit yükseklik
              SizedBox(
                height: isCompact ? 50 : 56,
                child: isLast
                    ? Center(
                        child: ElevatedButton.icon(
                          onPressed: () => notifier.nextStep(),
                          icon: const Icon(Icons.summarize, size: 20),
                          label: const Text('Özeti Görüntüle'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          ),
                        ),
                      )
                    : null,
              ),

              SizedBox(height: isCompact ? 4 : 8),

              // Sayfa göstergesi ve navigasyon - sabit alta
              SizedBox(
                height: 48,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    SizedBox(
                      width: 48,
                      height: 48,
                      child: !isFirst
                          ? IconButton(
                              icon: const Icon(Icons.arrow_back_ios),
                              onPressed: onPrevious,
                            )
                          : null,
                    ),
                    Text(
                      '${currentPage + 1} / $totalPages',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    SizedBox(
                      width: 48,
                      height: 48,
                      child: !isLast
                          ? IconButton(
                              icon: const Icon(Icons.arrow_forward_ios),
                              onPressed: onNext,
                            )
                          : null,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StatDisplay extends StatelessWidget {
  final String label;
  final String value;
  const _StatDisplay({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}