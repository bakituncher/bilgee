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
  bool _isAnySliderActive = false;

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

  void _setSliderActive(bool active) {
    if (_isAnySliderActive != active) {
      setState(() {
        _isAnySliderActive = active;
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

    // DİKKAT: selectedSection yerine activeSection kullanıyoruz.
    final section = state.activeSection;

    if (section == null) return const Center(child: Text("Bölüm hatası."));

    final subjects = section.subjects.entries.toList();

    return Column(
      children: [
        // Branş Modu Bilgisi
        if (state.isBranchMode)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8),
            color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
            child: Text(
              "BRANŞ DENEMESİ: ${subjects.first.key.toUpperCase()}",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
                letterSpacing: 1.1,
              ),
            ),
          ),

        Expanded(
          child: NotificationListener<ScrollNotification>(
            onNotification: (notification) => false,
            child: PageView.builder(
              controller: _pageController,
              physics: _isAnySliderActive
                  ? const NeverScrollableScrollPhysics()
                  : const PageScrollPhysics(),
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
                  onNext: () => _pageController.nextPage(duration: 200.ms, curve: Curves.easeOut),
                  onPrevious: () => _pageController.previousPage(duration: 200.ms, curve: Curves.easeOut),
                  pageController: _pageController,
                  onSliderActiveChanged: _setSliderActive,
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

// _SubjectScoreCard widget'ı öncekiyle aynı kalabilir,
// sadece build içinde activeSection'a bakması yeterli.
class _SubjectScoreCard extends ConsumerStatefulWidget {
  // ... parametreler aynı
  final String subjectName;
  final SubjectDetails details;
  final bool isFirst, isLast;
  final int currentPage, totalPages;
  final VoidCallback onNext, onPrevious;
  final PageController pageController;
  final ValueChanged<bool> onSliderActiveChanged;

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
    required this.pageController,
    required this.onSliderActiveChanged,
  });

  @override
  ConsumerState<_SubjectScoreCard> createState() => _SubjectScoreCardState();
}

class _SubjectScoreCardState extends ConsumerState<_SubjectScoreCard> {
  void _setSliding(bool value) {
    widget.onSliderActiveChanged(value);
  }

  @override
  Widget build(BuildContext context) {
    final notifier = ref.read(addTestProvider.notifier);
    final subjectScores = ref.watch(addTestProvider.select((s) => s.scores[widget.subjectName])) ?? {'dogru': 0, 'yanlis': 0};

    // BURASI ÖNEMLİ: activeSection'dan katsayıyı al
    final section = ref.watch(addTestProvider.select((s) => s.activeSection))!;

    int correct = subjectScores['dogru']!;
    int wrong = subjectScores['yanlis']!;
    int blank = widget.details.questionCount - correct - wrong;
    double net = correct - (wrong * section.penaltyCoefficient);

    // UI Kodunun geri kalanı tamamen aynı...
    // (LayoutBuilder, Text'ler, ScoreSlider'lar, Butonlar)
    return LayoutBuilder(
        builder: (context, constraints) {
          // ... (Aynı kodlar)
          // ScoreSlider onChanged içinde notifier.updateScores çağırılıyor
          // İstatistik row'u net gösteriyor
          // Son sayfada 'Özeti Görüntüle' butonu var

          // Kodu kısaltmak için burayı tekrarlamıyorum, önceki dosyadan ScoreSlider ve UI yapısını aynen kullanabilirsiniz.
          // Sadece 'section' değişkeninin activeSection olduğundan emin olun.

          // Kopyala-Yapıştır yapabilmeniz için minimal UI iskeleti:
          return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
              child: Column(
                  children: [
                    Text(widget.subjectName, style: Theme.of(context).textTheme.headlineSmall),
                    Text("${widget.details.questionCount} Soru"),
                    const Spacer(),
                    // Doğru Slider
                    GestureDetector(
                      onHorizontalDragStart: (_) => _setSliding(true),
                      onHorizontalDragEnd: (_) => _setSliding(false),
                      child: AbsorbPointer(
                        absorbing: false,
                        child: ScoreSlider(
                            label: "Doğru",
                            value: correct.toDouble(),
                            max: widget.details.questionCount.toDouble(),
                            color: Theme.of(context).colorScheme.secondary,
                            totalQuestions: widget.details.questionCount.toDouble(),
                            onChanged: (v) {
                              // Mantık aynı
                              final val = v.toInt();
                              if(val + wrong > widget.details.questionCount) {
                                notifier.updateScores(widget.subjectName, correct: val, wrong: widget.details.questionCount - val);
                              } else {
                                notifier.updateScores(widget.subjectName, correct: val);
                              }
                            }
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Yanlış Slider
                    GestureDetector(
                      onHorizontalDragStart: (_) => _setSliding(true),
                      onHorizontalDragEnd: (_) => _setSliding(false),
                      child: AbsorbPointer(
                        absorbing: false,
                        child: ScoreSlider(
                            label: "Yanlış",
                            value: wrong.toDouble(),
                            max: (widget.details.questionCount - correct).toDouble(),
                            color: Theme.of(context).colorScheme.error,
                            totalQuestions: widget.details.questionCount.toDouble(),
                            onChanged: (v) {
                              final val = v.toInt();
                              if(val + correct > widget.details.questionCount) {
                                notifier.updateScores(widget.subjectName, correct: widget.details.questionCount - val, wrong: val);
                              } else {
                                notifier.updateScores(widget.subjectName, wrong: val);
                              }
                            }
                        ),
                      ),
                    ),
                    const Spacer(),
                    // İstatistikler (Net vb.)
                    Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _StatDisplay(label: "Boş", value: blank.toString()),
                          _StatDisplay(label: "Net", value: net.toStringAsFixed(2)),
                        ]
                    ),
                    const Spacer(),
                    // Navigasyon
                    if(widget.isLast)
                      ElevatedButton.icon(
                          onPressed: notifier.nextStep,
                          icon: const Icon(Icons.summarize),
                          label: const Text("Özeti Görüntüle")
                      ),
                    // Sayfa okları...
                    Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          widget.isFirst ? const SizedBox(width: 48) : IconButton(icon: const Icon(Icons.arrow_back_ios), onPressed: widget.onPrevious),
                          Text("${widget.currentPage+1}/${widget.totalPages}"),
                          widget.isLast ? const SizedBox(width: 48) : IconButton(icon: const Icon(Icons.arrow_forward_ios), onPressed: widget.onNext),
                        ]
                    )
                  ]
              )
          );
        }
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
        Text(value, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }
}