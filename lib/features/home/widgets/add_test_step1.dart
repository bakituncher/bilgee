// lib/features/home/widgets/add_test_step1.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:taktik/data/models/exam_model.dart';
import 'package:taktik/features/home/logic/add_test_notifier.dart';

class Step1TestInfo extends ConsumerWidget {
  const Step1TestInfo({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(addTestProvider);
    final notifier = ref.read(addTestProvider.notifier);
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    final isButtonEnabled =
        state.testName.trim().isNotEmpty && state.selectedSection != null;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      children: [
        /// HEADER
        Column(
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: theme.colorScheme.surfaceVariant,
              ),
              child: Icon(
                Icons.edit_note_rounded,
                size: 36,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              "Yeni Deneme Ekle",
              style: textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Denemenin temel bilgilerini girerek başlayalım.",
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),

        const SizedBox(height: 48),

        /// TEST NAME
        Text(
          "Deneme Adı",
          style: textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          initialValue: state.testName,
          decoration: InputDecoration(
            hintText: "Örn: 3D Türkiye Geneli",
            prefixIcon: Icon(
              Icons.description_outlined,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            filled: true,
            fillColor: theme.colorScheme.surfaceVariant,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: theme.colorScheme.primary,
                width: 2,
              ),
            ),
          ),
          onChanged: notifier.setTestName,
        ),

        const SizedBox(height: 40),

        /// SECTION SELECTION
        if (state.availableSections.length > 1) ...[
          Text(
            "Deneme Türü",
            style: textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          ...state.availableSections.map(
                (section) => _SectionSelectionCard(
              section: section,
              isSelected: state.selectedSection == section,
              onTap: () => notifier.setSection(section),
            ),
          ),
        ],

        const SizedBox(height: 48),

        /// CTA
        SafeArea(
          top: false,
          child: SizedBox(
            height: 52,
            width: double.infinity,
            child: ElevatedButton(
              onPressed: isButtonEnabled ? notifier.nextStep : null,
              style: ElevatedButton.styleFrom(
                elevation: isButtonEnabled ? 2 : 0,
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
                disabledBackgroundColor:
                theme.colorScheme.surfaceVariant,
                disabledForegroundColor:
                theme.colorScheme.onSurfaceVariant,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                "Netleri Girmeye Başla",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ]
          .animate(interval: 70.ms)
          .fadeIn(duration: 300.ms)
          .slideY(begin: 0.12),
    );
  }
}

/// SECTION CARD (RENK ÇAKIŞMASI YOK)
class _SectionSelectionCard extends StatelessWidget {
  final ExamSection section;
  final bool isSelected;
  final VoidCallback onTap;

  const _SectionSelectionCard({
    required this.section,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: isSelected
            ? theme.colorScheme.surfaceVariant
            : theme.colorScheme.surface,
        border: Border.all(
          color: isSelected
              ? theme.colorScheme.primary
              : theme.colorScheme.surfaceVariant,
          width: 2,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          child: Row(
            children: [
              Icon(
                isSelected
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked,
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 16),
              Text(
                section.name,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
