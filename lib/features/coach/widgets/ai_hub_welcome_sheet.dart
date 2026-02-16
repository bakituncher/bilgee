import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:taktik/data/providers/premium_provider.dart';

class AiHubWelcomeSheet extends ConsumerStatefulWidget {
  const AiHubWelcomeSheet({super.key});

  @override
  ConsumerState<AiHubWelcomeSheet> createState() => _AiHubWelcomeSheetState();
}

class _AiHubWelcomeSheetState extends ConsumerState<AiHubWelcomeSheet>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final bgColor = isDark ? const Color(0xFF0D0D0F) : Colors.white;
    final cardBg = isDark ? Colors.white.withOpacity(0.06) : Colors.grey.shade50;
    final textPrimary = isDark ? Colors.white : const Color(0xFF1A1A1A);
    final textSecondary = isDark ? Colors.white60 : Colors.grey.shade600;
    final borderColor = isDark ? Colors.white10 : Colors.grey.shade200;

    // Offerings'i kontrol et ve hasFreeTrial'ı belirle
    final offeringsAsync = ref.watch(offeringsProvider);
    final hasFreeTrial = offeringsAsync.when(
      data: (offerings) {
        final current = offerings.current;
        if (current == null || current.availablePackages.isEmpty) return false;

        // Herhangi bir pakette trial varsa, kullanıcı trial'ı kullanmamış demektir
        // Trial kullanılmışsa hiçbir pakette trial olmaz
        return current.availablePackages.any(
          (package) => package.storeProduct.introductoryPrice?.price == 0,
        );
      },
      loading: () => false,
      error: (_, __) => false,
    );

    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 12,
        bottom: MediaQuery.of(context).viewPadding.bottom + 32,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: textSecondary.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),

          // Logo & Badge Row
          Row(
            children: [
              // Tavşan logosu
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF6366F1).withOpacity(0.25),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.asset(
                    'assets/images/bunnyy.webp',
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Taktik Tavşan',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: textPrimary,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFD700),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'PRO',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: Colors.black,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Kişisel sınav koçun seni bekliyor',
                      style: TextStyle(
                        fontSize: 13,
                        color: textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Features Grid
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _FeatureItem(
                        icon: Icons.chat_bubble_outline_rounded,
                        title: 'Bire Bir Koçluk',
                        color: const Color(0xFF6366F1),
                        textColor: textPrimary,
                        subtitleColor: textSecondary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _FeatureItem(
                        icon: Icons.camera_alt_rounded,
                        title: 'Soru Çözücü',
                        color: const Color(0xFFF59E0B),
                        textColor: textPrimary,
                        subtitleColor: textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _FeatureItem(
                        icon: Icons.calendar_month_outlined,
                        title: 'Haftalık Plan',
                        color: const Color(0xFF10B981),
                        textColor: textPrimary,
                        subtitleColor: textSecondary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _FeatureItem(
                        icon: Icons.menu_book_rounded,
                        title: 'Etüt Odası',
                        color: const Color(0xFF8B5CF6),
                        textColor: textPrimary,
                        subtitleColor: textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _FeatureItem(
                        icon: Icons.account_tree_rounded,
                        title: 'Zihin Haritası',
                        color: const Color(0xFF6366F1),
                        textColor: textPrimary,
                        subtitleColor: textSecondary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _FeatureItem(
                        icon: Icons.bolt,
                        title: 'Not Defteri',
                        color: const Color(0xFF0EA5E9),
                        textColor: textPrimary,
                        subtitleColor: textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Trial Banner
          if (hasFreeTrial)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF6366F1).withOpacity(isDark ? 0.2 : 0.1),
                    const Color(0xFF8B5CF6).withOpacity(isDark ? 0.2 : 0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: const Color(0xFF6366F1).withOpacity(0.3),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.verified_outlined,
                    size: 16,
                    color: const Color(0xFF10B981),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        '7 gün ücretsiz dene, istediğin zaman iptal et',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: textPrimary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

          SizedBox(height: hasFreeTrial ? 20 : 0),

          // CTA Button
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              final glowOpacity = 0.3 + (_pulseController.value * 0.15);
              return GestureDetector(
                onTap: () {
                  context.pop();
                  context.push('/premium');
                },
                child: Container(
                  width: double.infinity,
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF6366F1).withOpacity(glowOpacity),
                        blurRadius: 20,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      hasFreeTrial ? 'Şimdi Ücretsiz Başla' : 'Hemen Başla',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 8),

          // Skip - FOMO & Loss Aversion
          TextButton(
            onPressed: () => context.pop(),
            style: TextButton.styleFrom(
              foregroundColor: textSecondary.withOpacity(0.5),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text(
              'Daha Sonra',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _FeatureItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  final Color textColor;
  final Color subtitleColor;

  const _FeatureItem({
    required this.icon,
    required this.title,
    required this.color,
    required this.textColor,
    required this.subtitleColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            size: 18,
            color: color,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ),
      ],
    );
  }
}