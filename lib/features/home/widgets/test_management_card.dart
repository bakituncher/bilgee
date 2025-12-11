// lib/features/home/widgets/test_management_card.dart
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:taktik/data/providers/firestore_providers.dart';

class TestManagementCard extends ConsumerWidget {
  const TestManagementCard({super.key});

  Future<void> _showSubjectSelector(BuildContext context, WidgetRef ref) async {
    final user = ref.read(userProfileProvider).value;
    if (user == null || user.selectedExam == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lütfen önce bir sınav türü seçin')),
        );
      }
      return;
    }
    // Tam ekran ders seçimi için push kullan (stack'e ekle)
    context.push('/coach/select-subject');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final accentColor = colorScheme.secondary;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: accentColor.withOpacity(0.25),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: accentColor.withOpacity(isDark ? 0.15 : 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Başlık
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      accentColor.withOpacity(0.2),
                      accentColor.withOpacity(0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.assignment_rounded,
                  color: accentColor,
                  size: 16,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Sınav Yönetimi',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // İki buton yan yana
          Row(
            children: [
              Expanded(
                child: _ActionButton(
                  icon: Icons.add_chart_rounded,
                  label: 'Deneme Ekle',
                  gradientColors: const [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                  onTap: () => context.push('/home/add-test'),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _ActionButton(
                  icon: Icons.library_books_rounded,
                  label: 'Test Ekle',
                  gradientColors: const [Color(0xFF10B981), Color(0xFF06B6D4)],
                  onTap: () => _showSubjectSelector(context, ref),
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 250.ms).slideY(begin: .04, curve: Curves.easeOut);
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final List<Color> gradientColors;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.gradientColors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradientColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: gradientColors.first.withOpacity(isDark ? 0.3 : 0.25),
              blurRadius: 8,
              offset: const Offset(0, 3),
              spreadRadius: 0,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(7),
              ),
              child: Icon(
                icon,
                color: Colors.white,
                size: 16,
              ),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 10.5,
                  letterSpacing: -0.2,
                  shadows: [
                    Shadow(
                      color: Colors.black.withOpacity(0.2),
                      offset: const Offset(0, 1),
                      blurRadius: 2,
                    ),
                  ],
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 200.ms).scale(
          begin: const Offset(0.95, 0.95),
          duration: 200.ms,
          curve: Curves.easeOutBack,
        );
  }
}
