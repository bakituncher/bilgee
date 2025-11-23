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

    return Card(
      elevation: isDark ? 6 : 8,
      shadowColor: isDark
          ? Colors.black.withOpacity(0.4)
          : colorScheme.surfaceContainerHighest.withOpacity(0.45),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(
          color: isDark
              ? colorScheme.primary.withOpacity(0.2)
              : colorScheme.surfaceContainerHighest.withOpacity(0.35),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Başlık
            Row(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: colorScheme.primary.withOpacity(0.6)),
                  ),
                  padding: const EdgeInsets.all(6),
                  child: Icon(Icons.assignment_rounded, color: colorScheme.primary, size: 18),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sınav Yönetimi',
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      Text(
                        'Deneme ve test sonuçlarını ekle',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: 10.5,
                        ),
                      ),
                    ],
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
                    color: colorScheme.secondary,
                    onTap: () => context.push('/home/add-test'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ActionButton(
                    icon: Icons.library_books_rounded,
                    label: 'Test Ekle',
                    color: colorScheme.secondary,
                    onTap: () => _showSubjectSelector(context, ref),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 250.ms).slideY(begin: .04, curve: Curves.easeOut);
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  double _calculateFontSize(BuildContext context, String text, double maxWidth) {
    const minFontSize = 11.0;
    const maxFontSize = 14.0;

    for (double fontSize = maxFontSize; fontSize >= minFontSize; fontSize -= 0.5) {
      final textPainter = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w700),
        ),
        maxLines: 1,
        textDirection: TextDirection.ltr,
      )..layout();

      if (textPainter.width <= maxWidth) {
        return fontSize;
      }
    }
    return minFontSize;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: isDark
                ? [
                    colorScheme.surfaceContainer.withOpacity(0.5),
                    theme.cardColor.withOpacity(0.7),
                  ]
                : [
                    theme.cardColor,
                    theme.cardColor,
                  ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(
            color: isDark
                ? colorScheme.surfaceContainerHighest.withOpacity(0.3)
                : colorScheme.surfaceContainerHighest.withOpacity(0.45),
          ),
        ),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final availableWidth = constraints.maxWidth - 32; // icon + spacing için alan
            final fontSize = _calculateFontSize(context, label, availableWidth);

            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: color, size: 18),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    label,
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: colorScheme.onSurface,
                      fontSize: fontSize,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    ).animate().scale(duration: 120.ms, curve: Curves.easeOut);
  }
}
