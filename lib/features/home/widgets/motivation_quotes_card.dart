// lib/features/home/widgets/motivation_quotes_card.dart
import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:taktik/data/motivation_quotes_data.dart';

class MotivationQuotesCard extends StatefulWidget {
  const MotivationQuotesCard({super.key});

  @override
  State<MotivationQuotesCard> createState() => _MotivationQuotesCardState();
}

class _MotivationQuotesCardState extends State<MotivationQuotesCard> {
  late final PageController _controller;
  Timer? _timer;
  int _index = 0;
  late List<(String, String)> _dailyQuotes;

  /// Her gün için rastgele 5 söz seçer (günlük seed ile)
  List<(String, String)> _selectDailyQuotes() {
    final now = DateTime.now();
    final daysSinceEpoch = now.millisecondsSinceEpoch ~/ (1000 * 60 * 60 * 24);
    final random = Random(daysSinceEpoch);

    final allQuotes = List<(String, String)>.from(MotivationQuotesData.quotes);
    allQuotes.shuffle(random);

    return allQuotes.take(5).toList();
  }

  @override
  void initState() {
    super.initState();
    _dailyQuotes = _selectDailyQuotes();
    _controller = PageController(viewportFraction: 1);
    _startAuto();
  }

  void _startAuto() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted) return;
      final next = (_controller.page?.round() ?? _index) + 1;
      _controller.animateToPage(
        next % _dailyQuotes.length,
        duration: const Duration(milliseconds: 550),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const height = 180.0;

    return Card(
      elevation: isDark ? 8 : 10,
      shadowColor: isDark
          ? Colors.black.withOpacity(0.4)
          : Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.45),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color: isDark
              ? Theme.of(context).colorScheme.primary.withOpacity(0.2)
              : Colors.transparent,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: SizedBox(
          height: height,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Premium degrade arka plan
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? [
                            Theme.of(context).colorScheme.surfaceContainer.withOpacity(0.7),
                            Theme.of(context).cardColor.withOpacity(0.9),
                          ]
                        : [
                            Theme.of(context).cardColor,
                            Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.35),
                          ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
              // Dekoratif parlama daireleri
              Positioned(
                left: -30, top: -20, child: _glowCircle(color: Theme.of(context).colorScheme.primary.withOpacity(0.18), size: 140),
              ),
              Positioned(
                right: -24, bottom: -18, child: _glowCircle(color: Colors.green.withOpacity(0.16), size: 120),
              ),
              // İç blur ile yumuşatma
              BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: const SizedBox.expand(),
              ),

              // Alıntılar
              PageView.builder(
                controller: _controller,
                physics: const BouncingScrollPhysics(),
                onPageChanged: (i) {
                  setState(() => _index = i);
                  _startAuto();
                },
                itemCount: _dailyQuotes.length,
                itemBuilder: (context, i) {
                  final (text, author) = _dailyQuotes[i];
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.6)),
                              ),
                              padding: const EdgeInsets.all(10),
                              child: Icon(Icons.format_quote_rounded, color: Theme.of(context).colorScheme.primary),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                text,
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  height: 1.2,
                                  fontSize: 15,
                                ),
                                maxLines: 4,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.25),
                                border: Border.all(color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.45)),
                              ),
                              child: Text('— $author', style: Theme.of(context).textTheme.labelMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                            ),
                            const Spacer(),
                            _Dots(count: _dailyQuotes.length, index: i),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(duration: 260.ms).slideY(begin: .04, curve: Curves.easeOut);
  }

  Widget _glowCircle({required Color color, required double size}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  final int count; final int index;
  const _Dots({required this.count, required this.index});
  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(count, (i) {
        final active = i == index;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: active ? 18 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: active ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.5),
            borderRadius: BorderRadius.circular(6),
          ),
        );
      }),
    );
  }
}
