// lib/features/home/widgets/motivation_quotes_card.dart
import 'dart:async';
import 'dart:ui';
import 'package:bilge_ai/core/theme/app_theme.dart';
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
    ('Hayatta en hakiki mürşit ilimdir, fendir.', 'M. Kemal Atatürk'),
    ('Geleceği tahmin etmenin en iyi yolu, onu yaratmaktır.', 'Peter Drucker'),
    ('Başarının sırrı, sıradan işleri sıra dışı bir şekilde yapmaktır.', 'John D. Rockefeller'),
    ('Dehanın %1\'i ilham, %99\'u alın teridir.', 'Thomas Edison'),
    ('Şimdi acı çek ve hayatının geri kalanını bir şampiyon olarak yaşa.', 'Muhammed Ali'),
    ('Tek bildiğim, hiçbir şey bilmediğimdir.', 'Sokrates'),
    ('Hayal gücü bilgiden daha önemlidir. Çünkü bilgi sınırlıyken, hayal gücü tüm dünyayı kapsar.', 'Albert Einstein'),
    ('Yenilginin en büyük zaferden tek farkı, ayağa kalkma cesaretidir.', 'Bilge Baykuş'),
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
    final height = 168.0;
    return Card(
      elevation: 10,
      shadowColor: AppTheme.lightSurfaceColor.withValues(alpha: .45),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
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
                    colors: [
                      AppTheme.cardColor,
                      AppTheme.lightSurfaceColor.withValues(alpha: .35),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
              // Dekoratif parlama daireleri
              Positioned(
                left: -30, top: -20, child: _glowCircle(color: AppTheme.secondaryColor.withValues(alpha: .18), size: 140),
              ),
              Positioned(
                right: -24, bottom: -18, child: _glowCircle(color: AppTheme.successColor.withValues(alpha: .16), size: 120),
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
                                color: AppTheme.secondaryColor.withValues(alpha: .15),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppTheme.secondaryColor.withValues(alpha: .6)),
                              ),
                              padding: const EdgeInsets.all(10),
                              child: const Icon(Icons.format_quote_rounded, color: AppTheme.secondaryColor),
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
                                color: AppTheme.lightSurfaceColor.withValues(alpha: .25),
                                border: Border.all(color: AppTheme.lightSurfaceColor.withValues(alpha: .45)),
                              ),
                              child: Text('— $author', style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AppTheme.secondaryTextColor)),
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
            color: active ? AppTheme.secondaryColor : AppTheme.secondaryTextColor.withValues(alpha: .5),
            borderRadius: BorderRadius.circular(6),
          ),
        );
      }),
    );
  }
}
