// lib/features/home/widgets/motivation_quotes_card.dart
import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class MotivationQuotesCard extends StatefulWidget {
  const MotivationQuotesCard({super.key});

  @override
  State<MotivationQuotesCard> createState() => _MotivationQuotesCardState();
}

class _MotivationQuotesCardState extends State<MotivationQuotesCard> {
  late final PageController _controller;
  Timer? _timer;
  int _index = 0;
  final _quotes = const [
    ('Zorluklar, fırsatların gizli kapılarıdır.', 'Albert Einstein'),
    ('Hayal gücü bilgiden daha önemlidir.', 'Albert Einstein'),
    ('Başarı, hazırlık ile fırsatın buluştuğu noktadır.', 'Bobby Unser'),
    ('Kendine inan, her şey mümkün.', 'Audrey Hepburn'),
    ('Yapabileceğin en büyük hata, hata yapmaktan korkmaktır.', 'Elbert Hubbard'),
    ('Düşünmeden konuşmak, nişan almadan ateş etmektir.', 'Miguel de Cervantes'),
    ('Başarı, azimle beslenen bir yolculuktur.', 'Zig Ziglar'),
  ];

  @override
  void initState() {
    super.initState();
    _controller = PageController(viewportFraction: 1);
    _startAuto();
  }

  void _startAuto() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted) return;
      final next = (_controller.page?.round() ?? _index) + 1;
      _controller.animateToPage(
        next % _quotes.length,
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
      elevation: isDark ? 8 : 6,
      shadowColor: isDark 
        ? Colors.black.withOpacity(0.4)
        : Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
        side: BorderSide(
          color: isDark 
            ? Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.25)
            : Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.4),
          width: 1.5,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
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
                          Theme.of(context).cardColor,
                          Theme.of(context).colorScheme.primary.withOpacity(0.08),
                          Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.12),
                        ]
                      : [
                          Theme.of(context).cardColor,
                          Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.2),
                          Theme.of(context).cardColor.withOpacity(0.95),
                        ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
              // Dekoratif parlama daireleri
              Positioned(
                left: -30, top: -20, 
                child: _glowCircle(
                  color: Theme.of(context).colorScheme.primary.withOpacity(isDark ? 0.15 : 0.12), 
                  size: 150
                ),
              ),
              Positioned(
                right: -24, bottom: -18, 
                child: _glowCircle(
                  color: (isDark ? Colors.teal : Colors.green).withOpacity(isDark ? 0.12 : 0.10), 
                  size: 130
                ),
              ),
              // İç blur ile yumuşatma (Glassmorphism effect)
              BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
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
                itemCount: _quotes.length,
                itemBuilder: (context, i) {
                  final (text, author) = _quotes[i];
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary.withOpacity(isDark ? 0.18 : 0.12),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: Theme.of(context).colorScheme.primary.withOpacity(isDark ? 0.4 : 0.5),
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              padding: const EdgeInsets.all(11),
                              child: Icon(
                                Icons.format_quote_rounded, 
                                color: Theme.of(context).colorScheme.primary,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                text,
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800, height: 1.15),
                                maxLines: 3,
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
                            _Dots(count: _quotes.length, index: i),
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
