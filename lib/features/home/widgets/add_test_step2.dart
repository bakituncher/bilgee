// lib/features/home/widgets/add_test_step2.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:taktik/data/models/exam_model.dart';
import 'package:taktik/shared/widgets/score_slider.dart';
import 'package:taktik/features/home/logic/add_test_notifier.dart';
import 'package:taktik/data/providers/premium_provider.dart';

class Step2ScoreEntry extends ConsumerStatefulWidget {
  const Step2ScoreEntry({super.key});

  @override
  ConsumerState<Step2ScoreEntry> createState() => _Step2ScoreEntryState();
}

class _Step2ScoreEntryState extends ConsumerState<Step2ScoreEntry> {
  late PageController _pageController;
  final Set<int> _trackedPages = {}; // Track which pages have been counted

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    
    // Listen to page changes to track subject score updates
    _pageController.addListener(_onPageChanged);
  }

  void _onPageChanged() {
    if (!_pageController.hasClients) return;
    
    final currentPage = _pageController.page;
    if (currentPage == null) return;
    
    // Only track when we're settled on a page (not mid-animation)
    final pageIndex = currentPage.round();
    final isSettled = (currentPage - pageIndex).abs() < 0.1;
    
    // Only track each page once, even if user navigates back and forth
    // Start counting from page 1 (second subject) since page 0 is the first subject
    if (isSettled && !_trackedPages.contains(pageIndex) && pageIndex > 0) {
      _trackedPages.add(pageIndex);
      _trackSubjectScoreUpdate();
    }
  }

  Future<void> _trackSubjectScoreUpdate() async {
    try {
      // Check if user is already premium
      final isPremium = ref.read(premiumStatusProvider);
      if (isPremium) return;
      
      // Get the trigger service and track the subject update
      final triggerService = await ref.read(premiumTriggerServiceProvider.future);
      final shouldShow = await triggerService.trackSubjectScoreUpdate();
      
      if (shouldShow && mounted) {
        // Show premium screen
        context.push('/premium');
        debugPrint('[SubjectUpdate] Premium screen displayed');
      }
    } catch (e) {
      debugPrint('[SubjectUpdate] Error checking premium screen: $e');
    }
  }

  @override
  void dispose() {
    _pageController.removeListener(_onPageChanged);
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
                key: ValueKey(subjectEntry.key), // Hata buradaydı, key geri eklendi.
                subjectName: subjectEntry.key,
                details: subjectEntry.value,
                isFirst: index == 0,
                isLast: index == subjects.length - 1,
                onNext: () => _pageController.nextPage(duration: 300.ms, curve: Curves.easeOut),
                onPrevious: () => _pageController.previousPage(duration: 300.ms, curve: Curves.easeOut),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(24.0),
          child: ElevatedButton(
            onPressed: () => ref.read(addTestProvider.notifier).nextStep(),
            child: const Text('Özeti Görüntüle'),
          ),
        )
      ],
    );
  }
}

class _SubjectScoreCard extends ConsumerWidget {
  final String subjectName;
  final SubjectDetails details;
  final bool isFirst, isLast;
  final VoidCallback onNext, onPrevious;

  // DÜZELTİLDİ: Key parametresi tekrar eklendi.
  const _SubjectScoreCard({
    super.key,
    required this.subjectName,
    required this.details,
    required this.isFirst,
    required this.isLast,
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

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(subjectName, style: Theme.of(context).textTheme.displaySmall, textAlign: TextAlign.center,),
          Text("${details.questionCount} Soru", style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 48),
          ScoreSlider(
            label: "Doğru",
            value: correct.toDouble(),
            max: details.questionCount.toDouble(),
            color: Theme.of(context).colorScheme.secondary,
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
          ScoreSlider(
            label: "Yanlış",
            value: wrong.toDouble(),
            max: (details.questionCount - correct).toDouble(),
            color: Theme.of(context).colorScheme.error,
            onChanged: (value) {
              notifier.updateScores(subjectName, wrong: value.toInt());
            },
          ),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _StatDisplay(label: "Boş", value: blank.toString()),
              _StatDisplay(label: "Net", value: net.toStringAsFixed(2)),
            ],
          ),
          const Spacer(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (!isFirst) IconButton(icon: const Icon(Icons.arrow_back_ios), onPressed: onPrevious),
              if (isFirst) const Spacer(),
              if (!isLast) IconButton(icon: const Icon(Icons.arrow_forward_ios), onPressed: onNext),
              if (isLast) const Spacer(),
            ],
          )
        ],
      ),
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
      children: [
        Text(value, style: Theme.of(context).textTheme.headlineMedium),
        Text(label, style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
      ],
    );
  }
}