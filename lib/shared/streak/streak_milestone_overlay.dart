// lib/shared/streak/streak_milestone_overlay.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:confetti/confetti.dart';
import 'package:lottie/lottie.dart';
import 'package:taktik/core/theme/app_theme.dart';
import 'streak_milestone_notifier.dart';

class _MilestoneInfo {
  final String title;
  final String subtitle;
  final String message;
  final String buttonText;
  final Color accentColor;
  final List<Color> gradient;

  const _MilestoneInfo({
    required this.title,
    required this.subtitle,
    required this.message,
    required this.buttonText,
    required this.accentColor,
    required this.gradient,
  });
}

_MilestoneInfo _getMilestoneInfo(int streak) {
  // Rastgele motivasyon mesajları
  final randomMessages = [
    "Hedeflerine giden yolda durmak yok. Harika ilerliyorsun!",
    "Disiplin, başarının anahtarıdır. Sen bunu başardın.",
    "Bu istikrar seni zirveye taşıyacak. Aynen böyle devam!",
    "Her gün bir adım daha ileriye. Potansiyelin sınırsız.",
    "Rakiplerin dinlenirken sen fark yaratıyorsun. Tebrikler!",
    "Başarı tesadüf değildir, senin gibi çalışmanın sonucudur.",
  ];

  final randomTitles = [
    "MUAZZAM!",
    "YAKIYORSUN!",
    "DURDURULAMAZ!",
    "MÜKEMMEL!",
    "HARİKASIN!",
  ];

  final randomButtonTexts = [
    "DEVAM ET",
    "HARİKA",
    "TAM GAZ",
    "SÜPERSİN",
    "İLERLE",
  ];

  final rand = Random();
  String getRandom(List<String> list) => list[rand.nextInt(list.length)];

  const fireColors = [Color(0xFFEA580C), Color(0xFFFB923C)];
  const fireAccent = Color(0xFFF97316);

  // Özel kilometre taşları
  switch (streak) {
    case 1:
      return const _MilestoneInfo(
        title: 'BAŞLANGIÇ YAPILDI!',
        subtitle: 'İLK GÜN TAMAMLANDI',
        message: 'En önemli adımı attın. Bu yolculukta seni harika şeyler bekliyor.',
        buttonText: 'BAŞLIYORUZ',
        accentColor: Color(0xFF22D3EE),
        gradient: [Color(0xFF0891B2), Color(0xFF22D3EE)],
      );
    case 3:
      return const _MilestoneInfo(
        title: 'RİTMİNİ BULDUN!',
        subtitle: '3 GÜNLÜK SERİ',
        message: 'Üç gündür aralıksız buradasın. Alışkanlıklar işte böyle kazanılır!',
        buttonText: 'DEVAM ET',
        accentColor: fireAccent,
        gradient: fireColors,
      );
    case 7:
      return const _MilestoneInfo(
        title: 'HAFTAYI KAPATTIN!',
        subtitle: '7 GÜNLÜK SERİ',
        message: 'Tam bir hafta boyunca zinciri kırmadın. Kararlılığın takdire şayan!',
        buttonText: 'HARİKASIN',
        accentColor: Color(0xFF94A3B8),
        gradient: [Color(0xFF475569), Color(0xFF94A3B8)],
      );
    case 14:
      return const _MilestoneInfo(
        title: 'İKİ HAFTA DOLDU!',
        subtitle: '14 GÜNLÜK SERİ',
        message: 'İki haftayı geride bıraktın. İstikrarın meyvelerini toplamaya başladın.',
        buttonText: 'İLERLE',
        accentColor: Color(0xFF818CF8),
        gradient: [Color(0xFF4F46E5), Color(0xFF818CF8)],
      );
    case 21:
      return const _MilestoneInfo(
        title: 'ALIŞKANLIK KAZANDIN!',
        subtitle: '21 GÜNLÜK SERİ',
        message: 'Bilimsel olarak bir alışkanlık kazandın. Artık başarı senin doğanda var.',
        buttonText: 'ZİHİN AÇIKLIĞI',
        accentColor: Color(0xFF3B82F6),
        gradient: [Color(0xFF1D4ED8), Color(0xFF3B82F6)],
      );
    case 30:
      return const _MilestoneInfo(
        title: 'DİSİPLİN TİMSALİ!',
        subtitle: '30 GÜNLÜK SERİ',
        message: 'Bir aydır her gün hedefin için çalıştın. Bu azimle başaramayacağın şey yok.',
        buttonText: 'DURMAK YOK',
        accentColor: Color(0xFFFFB020),
        gradient: [Color(0xFFB45309), Color(0xFFFFB020)],
      );
    case 50:
      return const _MilestoneInfo(
        title: 'YOLU YARILADIN!',
        subtitle: '50 GÜNLÜK SERİ',
        message: '50 gündür aralıksız devam ediyorsun. İraden çelikten farksız.',
        buttonText: 'EFSANE',
        accentColor: Color(0xFFF43F5E),
        gradient: [Color(0xFFBE123C), Color(0xFFF43F5E)],
      );
    case 75:
      return const _MilestoneInfo(
        title: 'ZİRVEYE DOĞRU!',
        subtitle: '75 GÜNLÜK SERİ',
        message: '75 gün dile kolay! Seninle gurur duyuyoruz. Hedeflerine koşar adımla gidiyorsun.',
        buttonText: 'YÜKSELİŞ',
        accentColor: Color(0xFFA855F7),
        gradient: [Color(0xFF7E22CE), Color(0xFFA855F7)],
      );
    case 100:
      return const _MilestoneInfo(
        title: 'YÜZ GÜNLÜK ZAFER!',
        subtitle: '100 GÜNLÜK SERİ',
        message: '100 GÜN! Bu artık bir seri değil, bir yaşam tarzı. Sen gerçek bir maratoncusun.',
        buttonText: 'ŞAMPİYON',
        accentColor: Color(0xFFF59E0B),
        gradient: [Color(0xFFD97706), Color(0xFFF59E0B)],
      );
    case 150:
      return const _MilestoneInfo(
        title: 'SINIRLARI AŞTIN!',
        subtitle: '150 GÜNLÜK KUSURSUZ SERİ',
        message: 'Yarım yıla yaklaşıyorsun. Bu kararlılık karşısında hiçbir zorluk duramaz.',
        buttonText: 'DURDURULAMAZ',
        accentColor: Color(0xFF10B981),
        gradient: [Color(0xFF047857), Color(0xFF10B981)],
      );
    case 200:
      return const _MilestoneInfo(
        title: 'YILDIZLAR LİGİ!',
        subtitle: '200 GÜNLÜK SERİ',
        message: '200 gün boyunca gösterdiğin azim, geleceğini inşa ediyor.',
        buttonText: 'MÜKEMMELİYET',
        accentColor: Color(0xFFEC4899),
        gradient: [Color(0xFFBE185D), Color(0xFFEC4899)],
      );
    case 365:
      return const _MilestoneInfo(
        title: 'TARİH YAZDIN!',
        subtitle: '365 GÜNLÜK EFSANE SERİ',
        message: 'Tam bir yıl! Bugün kendine bir teşekkür et, çünkü imkansızı başardın.',
        buttonText: 'EFSANEVİ',
        accentColor: Color(0xFF6366F1),
        gradient: [Color(0xFF4338CA), Color(0xFF6366F1)],
      );
    default:
      // Standart günlük seri mesajları
      return _MilestoneInfo(
        title: getRandom(randomTitles),
        subtitle: '$streak GÜNLÜK SERİ',
        message: getRandom(randomMessages),
        buttonText: getRandom(randomButtonTexts),
        accentColor: fireAccent,
        gradient: fireColors,
      );
  }
}

class StreakMilestoneOverlay extends ConsumerStatefulWidget {
  final int streak;
  const StreakMilestoneOverlay({super.key, required this.streak});

  @override
  ConsumerState<StreakMilestoneOverlay> createState() => _StreakMilestoneOverlayState();
}

class _StreakMilestoneOverlayState extends ConsumerState<StreakMilestoneOverlay> {
  late ConfettiController _confettiController;
  late final _MilestoneInfo info;

  @override
  void initState() {
    super.initState();
    info = _getMilestoneInfo(widget.streak); // Info should be stable per view
    _confettiController = ConfettiController(duration: const Duration(seconds: 4));
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _confettiController.play();
    });
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  void _dismiss() {
    ref.read(streakMilestoneProvider.notifier).dismiss();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Stack(
      alignment: Alignment.center,
      children: [
        // 1. Derinlik: Karartılmış Arka Plan
        GestureDetector(
          onTap: _dismiss,
          child: Container(
            color: Colors.black.withValues(alpha: 0.85),
            width: double.infinity,
            height: double.infinity,
          ),
        ).animate().fadeIn(duration: 400.ms),

        // 2. Derinlik: Konfeti
        Positioned(
          top: -50,
          child: ConfettiWidget(
            confettiController: _confettiController,
            blastDirectionality: BlastDirectionality.explosive,
            shouldLoop: false,
            numberOfParticles: 50,
            gravity: 0.1,
            colors: [...info.gradient, Colors.white],
          ),
        ),

        // 3. Derinlik: Ana Kart
        Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              width: double.infinity,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(32),
                border: Border.all(
                  color: info.gradient.first.withValues(alpha: 0.3),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: info.accentColor.withValues(alpha: 0.3),
                    blurRadius: 50,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Üst Animasyon Alanı
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            info.gradient[0].withValues(alpha: 0.1),
                            isDark ? const Color(0xFF1E293B) : Colors.white,
                          ],
                        ),
                      ),
                      padding: const EdgeInsets.only(top: 40, bottom: 20),
                      child: Column(
                        children: [
                          // Lottie Animasyonu
                          SizedBox(
                            height: 180,
                            width: 180,
                            child: Lottie.asset(
                              'assets/lotties/fire.json',
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) {
                                // Fallback icon if lottie missing
                                return Icon(
                                  Icons.local_fire_department,
                                  size: 100,
                                  color: info.gradient.first
                                );
                              },
                            ),
                          ).animate()
                           .scale(duration: 600.ms, curve: Curves.elasticOut)
                           .then()
                           .animate(onPlay: (c) => c.repeat())
                           .shimmer(duration: 2.seconds, delay: 1.seconds),

                          const SizedBox(height: 16),

                          // Streak Sayacı Rozeti
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.black26 : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: info.gradient[0].withValues(alpha: 0.5),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.bolt, color: info.gradient[1], size: 18),
                                const SizedBox(width: 4),
                                Text(
                                  info.subtitle,
                                  style: TextStyle(
                                    color: info.gradient[1],
                                    fontSize: 13,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1,
                                    fontFamily: 'Montserrat',
                                  ),
                                ),
                              ],
                            ),
                          ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.5, end: 0),
                        ],
                      ),
                    ),

                    // Metinler
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                      child: Column(
                        children: [
                          Text(
                            info.title,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                              fontFamily: 'Montserrat',
                              letterSpacing: -0.5,
                            ),
                          ).animate().fadeIn(delay: 600.ms),

                          const SizedBox(height: 12),

                          Text(
                            info.message,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              height: 1.4,
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.7)
                                  : const Color(0xFF64748B),
                              fontFamily: 'Montserrat',
                              fontWeight: FontWeight.w500,
                            ),
                          ).animate().fadeIn(delay: 800.ms),

                          const SizedBox(height: 32),

                          // Buton
                          Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              gradient: LinearGradient(colors: info.gradient),
                              boxShadow: [
                                BoxShadow(
                                  color: info.accentColor.withValues(alpha: 0.4),
                                  blurRadius: 15,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: ElevatedButton(
                              onPressed: _dismiss,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                foregroundColor: Colors.white,
                                shadowColor: Colors.transparent,
                                padding: const EdgeInsets.symmetric(vertical: 20),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: Text(
                                info.buttonText,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  fontFamily: 'Montserrat',
                                  letterSpacing: 1,
                                ),
                              ),
                            ),
                          ).animate().fadeIn(delay: 1.seconds).scale(
                            begin: const Offset(0.9, 0.9),
                            end: const Offset(1, 1),
                          ),

                          const SizedBox(height: 16),

                          // Pas geç butonu (Optional)
                          TextButton(
                            onPressed: _dismiss,
                            child: Text(
                              "ŞİMDİ DEĞİL",
                              style: TextStyle(
                                color: isDark ? Colors.white38: Colors.black38,
                                fontWeight: FontWeight.bold,
                                fontSize: 12
                              )
                            ),
                          ).animate().fadeIn(delay: 1.5.seconds),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ).animate().scale(
          begin: const Offset(0.8, 0.8),
          end: const Offset(1.0, 1.0),
          duration: 600.ms,
          curve: Curves.elasticOut,
        ),
      ],
    );
  }
}


