import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AiHubWelcomeSheet extends StatelessWidget {
  const AiHubWelcomeSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    // Tema uyumlu, premium hissi veren amber vurgular
    final accent = Colors.amber;
    final bg = isDark ? const Color(0xFF0B1220) : cs.surface;
    final surface = isDark ? const Color(0xFF111827) : cs.surfaceContainerHighest;

    return SafeArea(
      top: false,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 18),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(28),
            topRight: Radius.circular(28),
          ),
          border: Border(
            top: BorderSide(color: accent.withOpacity(0.25), width: 1),
          ),
          boxShadow: [
            BoxShadow(
              color: accent.withOpacity(isDark ? 0.18 : 0.12),
              blurRadius: 34,
              spreadRadius: 2,
              offset: const Offset(0, -10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: cs.onSurface.withOpacity(isDark ? 0.25 : 0.18),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 18),

            // Üst rozet + başlık bloğu
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: surface.withOpacity(isDark ? 0.7 : 0.9),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: accent.withOpacity(0.22)),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          accent.withOpacity(0.22),
                          accent.withOpacity(0.06),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      border: Border.all(color: accent.withOpacity(0.35), width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: accent.withOpacity(isDark ? 0.25 : 0.18),
                          blurRadius: 18,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: Icon(Icons.auto_awesome, color: accent, size: 30),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Başlangıç Hediyen Hazır',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.4,
                      color: cs.onSurface,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Yeni başladığında her şey daha zor. O yüzden sana kısa bir “PRO deneme” tanımladık: önce bir dene, farkı gör.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      height: 1.45,
                      color: cs.onSurface.withOpacity(0.78),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _Chip(text: '7 Gün PRO Erişim', icon: Icons.workspace_premium, accent: accent, isDark: isDark),
                      _Chip(text: 'Sınırlı Süre', icon: Icons.timer_rounded, accent: accent, isDark: isDark),
                      _Chip(text: 'Tek tıkla aktif', icon: Icons.flash_on_rounded, accent: accent, isDark: isDark),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Fayda listesi (daha modern)
            _BenefitTile(
              icon: Icons.psychology_rounded,
              title: 'AI Koçluk',
              subtitle: 'Motivasyon + odak + doğru çalışma alışkanlığı.',
              color: const Color(0xFF6366F1),
            ),
            const SizedBox(height: 10),
            _BenefitTile(
              icon: Icons.map_rounded,
              title: 'Haftalık Plan',
              subtitle: 'Sıfırdan başlayana uygun, net hedefli program.',
              color: const Color(0xFF10B981),
            ),
            const SizedBox(height: 10),
            _BenefitTile(
              icon: Icons.radar_rounded,
              title: 'Analiz',
              subtitle: 'Hangi konuda zaman kaybediyorsun? Hızlıca gör.',
              color: const Color(0xFFF43F5E),
            ),

            const SizedBox(height: 18),

            // CTA
            GestureDetector(
              onTap: () {
                context.pop();
                context.push('/premium');
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFD700), Color(0xFFFFA000)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: accent.withOpacity(0.35),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Center(
                  child: Text(
                    'HEDİYEMİ AKTİVE ET',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Secondary
            InkWell(
              onTap: () => context.pop(),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(
                  'Şimdilik geç',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurface.withOpacity(0.55),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String text;
  final IconData icon;
  final Color accent;
  final bool isDark;

  const _Chip({
    required this.text,
    required this.icon,
    required this.accent,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: accent.withOpacity(isDark ? 0.10 : 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accent.withOpacity(0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: accent),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: cs.onSurface,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _BenefitTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;

  const _BenefitTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: (isDark ? const Color(0xFF0F172A) : cs.surfaceContainerHighest).withOpacity(isDark ? 0.75 : 0.9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.22)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withOpacity(0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    height: 1.35,
                    color: cs.onSurface.withOpacity(0.72),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
